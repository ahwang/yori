//
//  AuthenticationView.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn
import LocalAuthentication
import FirebaseAuth
import CryptoKit
import FirebaseCore

struct AuthenticationView: View {
    @State private var emailOrPhone = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isBiometricAvailable = false
    @State private var verificationCode = ""
    @State private var verificationID: String?
    @State private var showCodeVerification = false
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App Logo/Title
            VStack(spacing: 0) {
                Image("app-title-screen")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 170)

                Text("Data-driven financial planning, enhanced with AI")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)

            // Email/Phone and Password Fields
            VStack(spacing: 15) {
                if showCodeVerification {
                    TextField("Verification Code", text: $verificationCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .autocapitalization(.none)
                        .textContentType(.oneTimeCode)
                } else {
                    
                    TextField("Email or Phone Number", text: $emailOrPhone)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textContentType(.telephoneNumber)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if !isPhoneNumber(emailOrPhone) {
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(isSignUp ? .newPassword : .password)
                    }
                    
                }
            }
            .padding(.horizontal, 30)

            // Sign In/Sign Up Button
            Button(action: {
                if showCodeVerification {
                    verifyPhoneCode()
                } else {
                    handleAuthentication()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(showCodeVerification ? "Verify Code" : (isSignUp ? "Sign Up" : "Sign In"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isButtonDisabled() || isLoading)
            .padding(.horizontal, 30)

            // Toggle between Sign In and Sign Up (only for email)
            if !showCodeVerification && !isPhoneNumber(emailOrPhone) {
                Button(action: {
                    isSignUp.toggle()
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
            }

            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                Text("or")
                    .foregroundColor(.gray)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)

            // Social Authentication Buttons
            VStack(spacing: 15) {
                // Apple Sign In
                SignInWithAppleButton(.signIn) { request in
                    handleAppleSignIn(request)
                } onCompletion: { result in
                    handleAppleSignInCompletion(result)
                }
                .frame(height: 50)
                .cornerRadius(10)
                .padding(.horizontal, 30)

                // Google Sign In
                Button(action: {
                    handleGoogleSignIn()
                }) {
                    HStack {
                        Image("google-logo")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("Sign in with Google")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                .padding(.horizontal, 30)

                // Face ID / Touch ID Button
                if isBiometricAvailable {
                    Button(action: {
                        authenticateWithBiometrics()
                    }) {
                        HStack {
                            Image(systemName: "faceid")
                                .foregroundColor(.blue)
                            Text("Sign in with Face ID")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 30)
                }
            }

            Spacer()
        }
        .background(Color(.systemBackground))
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .alert("Authentication", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            checkBiometricAvailability()
            restoreVerificationID()
        }
    }

    // MARK: - Helper Functions

    private func isPhoneNumber(_ input: String) -> Bool {
        return input.hasPrefix("+") || input.allSatisfy { $0.isNumber || $0.isWhitespace || $0 == "-" || $0 == "(" || $0 == ")" }
    }

    private func isButtonDisabled() -> Bool {
        if showCodeVerification {
            return verificationCode.isEmpty
        } else if isPhoneNumber(emailOrPhone) {
            return emailOrPhone.isEmpty
        } else {
            return emailOrPhone.isEmpty || password.isEmpty
        }
    }

    private func handleAuthentication() {
        if isPhoneNumber(emailOrPhone) {
            handlePhoneAuthentication()
        } else {
            handleEmailAuthentication()
        }
    }

    private func handleEmailAuthentication() {
        guard !emailOrPhone.isEmpty, !password.isEmpty else { return }

        isLoading = true

        if isSignUp {
            Auth.auth().createUser(withEmail: emailOrPhone, password: password) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.alertMessage = "Sign up failed: \(error.localizedDescription)"
                    } else {
                        self.alertMessage = "Account created successfully!"
                    }
                    self.showAlert = true
                }
            }
        } else {
            Auth.auth().signIn(withEmail: emailOrPhone, password: password) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.alertMessage = "Sign in failed: \(error.localizedDescription)"
                    } else {
                        self.alertMessage = "Signed in successfully!"
                    }
                    self.showAlert = true
                }
            }
        }
    }

    private func handlePhoneAuthentication() {
        guard !emailOrPhone.isEmpty else { return }

        isLoading = true

        // Format phone number if needed
        let phoneNumber = emailOrPhone.hasPrefix("+") ? emailOrPhone : "+1\(emailOrPhone)"

        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    // Handle specific APNs-related errors
                    if (error as NSError).code == AuthErrorCode.missingAppToken.rawValue {
                        self.alertMessage = "Push notifications are required for phone authentication. Please enable notifications in Settings."
                    } else if (error as NSError).code == AuthErrorCode.notificationNotForwarded.rawValue {
                        self.alertMessage = "Phone verification failed. Please make sure notifications are enabled."
                    } else if (error as NSError).code == AuthErrorCode.invalidPhoneNumber.rawValue {
                        self.alertMessage = "Invalid phone number format. Please enter a valid phone number with country code."
                    } else if (error as NSError).code == AuthErrorCode.quotaExceeded.rawValue {
                        self.alertMessage = "SMS quota exceeded. Please try again later."
                    } else {
                        self.alertMessage = "Phone verification failed: \(error.localizedDescription)\nError code: \((error as NSError).code)"
                    }
                    self.showAlert = true
                } else {
                    self.verificationID = verificationID
                    // Save verification ID to UserDefaults
                    UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
                    UserDefaults.standard.set(phoneNumber, forKey: "authPhoneNumber")

                    self.showCodeVerification = true
                    self.alertMessage = "Verification code sent to \(phoneNumber)"
                    self.showAlert = true
                }
            }
        }
    }

    private func verifyPhoneCode() {
        guard let verificationID = verificationID, !verificationCode.isEmpty else { return }

        isLoading = true

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        Auth.auth().signIn(with: credential) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.alertMessage = "Verification failed: \(error.localizedDescription)"
                } else {
                    self.alertMessage = "Phone number verified successfully!"
                }
                self.showAlert = true
                self.showCodeVerification = false
                self.verificationCode = ""

                // Clear stored verification data on successful authentication
                self.clearStoredVerificationData()
            }
        }
    }

    private func handleAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    alertMessage = "Invalid state: A login callback was received, but no login request was sent."
                    showAlert = true
                    return
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    alertMessage = "Unable to fetch identity token"
                    showAlert = true
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    alertMessage = "Unable to serialize token string from data"
                    showAlert = true
                    return
                }
                guard let fullName = appleIDCredential.fullName else {
                    alertMessage = "Unable to fetch full name"
                    showAlert = true
                    return
                }

                let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: fullName)

                Auth.auth().signIn(with: credential) { result, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.alertMessage = "Apple Sign In failed: \(error.localizedDescription)"
                        } else {
                            self.alertMessage = "Apple Sign In successful!"
                        }
                        self.showAlert = true
                    }
                }
            }
        case .failure(let error):
            alertMessage = "Apple Sign In failed: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func handleGoogleSignIn() {
        guard let presentingViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            alertMessage = "Could not find presenting view controller"
            showAlert = true
            return
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            alertMessage = "Could not get Firebase client ID"
            showAlert = true
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "Google Sign In failed: \(error.localizedDescription)"
                    self.showAlert = true
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.alertMessage = "Failed to get Google ID token"
                    self.showAlert = true
                    return
                }

                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)

                Auth.auth().signIn(with: credential) { result, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.alertMessage = "Firebase Google Sign In failed: \(error.localizedDescription)"
                        } else {
                            self.alertMessage = "Google Sign In successful!"
                        }
                        self.showAlert = true
                    }
                }
            }
        }
    }

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
        } else {
            isBiometricAvailable = false
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        let reason = "Use Face ID or Touch ID to sign in to your account"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
            DispatchQueue.main.async {
                if success {
                    // TODO: Handle successful biometric authentication
                    // This would typically retrieve stored credentials or tokens
                    alertMessage = "Biometric authentication successful! You would now be signed in."
                } else {
                    if let error = authenticationError {
                        alertMessage = "Biometric authentication failed: \(error.localizedDescription)"
                    } else {
                        alertMessage = "Biometric authentication failed"
                    }
                }
                showAlert = true
            }
        }
    }

    // MARK: - Apple Sign In Helper Functions

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    // MARK: - UserDefaults Helper Functions

    private func restoreVerificationID() {
        if let storedVerificationID = UserDefaults.standard.string(forKey: "authVerificationID"),
           let storedPhoneNumber = UserDefaults.standard.string(forKey: "authPhoneNumber") {
            verificationID = storedVerificationID
            emailOrPhone = storedPhoneNumber
            showCodeVerification = true
            alertMessage = "Continue entering verification code for \(storedPhoneNumber)"
            showAlert = true
        }
    }

    private func clearStoredVerificationData() {
        UserDefaults.standard.removeObject(forKey: "authVerificationID")
        UserDefaults.standard.removeObject(forKey: "authPhoneNumber")
    }
}

#Preview {
    AuthenticationView()
}
