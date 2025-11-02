# Authentication Setup Guide

This guide will help you complete the setup for the iOS authentication screen with email, Google, and Apple Sign-In.

## What's Already Implemented

✅ **Basic Authentication UI** - Complete signup/login interface with email and password fields
✅ **Apple Sign-In** - Fully implemented with proper UI and handling
✅ **Email Authentication** - UI ready (backend integration needed)
✅ **Google Sign-In** - UI ready (SDK integration needed)

## Required Next Steps

### 1. Xcode Project Configuration

#### Apple Sign-In
1. Open `yori.xcodeproj` in Xcode
2. Select your app target
3. Go to "Signing & Capabilities"
4. Click "+" and add "Sign in with Apple" capability
5. Make sure the `yori.entitlements` file is properly linked to your target

#### Google Sign-In
1. Add the Google Sign-In SDK to your project:
   ```swift
   // In Xcode: File > Add Package Dependencies
   // Add: https://github.com/google/GoogleSignIn-iOS
   ```

2. Replace the placeholder `GoogleService-Info.plist` with your actual file from Firebase Console:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or select existing
   - Add an iOS app with your bundle identifier
   - Download the real `GoogleService-Info.plist`
   - Replace the placeholder file

3. Configure URL schemes in your app target:
   - Go to your target's Info tab
   - Add a URL scheme with your `REVERSED_CLIENT_ID` from GoogleService-Info.plist

### 2. Code Integration

#### Update yoriApp.swift for Google Sign-In
Add this import and configuration:

```swift
import SwiftUI
import GoogleSignIn

@main
struct yoriApp: App {
    var body: some Scene {
        WindowGroup {
            AuthenticationView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
```

#### Update AuthenticationView.swift for Google Sign-In
Replace the `handleGoogleSignIn()` method:

```swift
import GoogleSignIn

private func handleGoogleSignIn() {
    guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
        return
    }

    GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
        if let error = error {
            alertMessage = "Google Sign In failed: \\(error.localizedDescription)"
        } else if let user = result?.user {
            alertMessage = "Google Sign In successful! User: \\(user.profile?.email ?? "Unknown")"
        }
        showAlert = true
    }
}
```

### 3. Backend Integration

#### Email Authentication
You'll need to implement the actual authentication logic in `handleEmailAuthentication()`:
- Connect to your backend authentication service
- Handle user registration and login
- Store authentication tokens securely

#### Social Authentication
For both Apple and Google Sign-In:
- Send the authentication tokens to your backend
- Verify tokens server-side
- Create or link user accounts
- Return your app's authentication tokens

### 4. Testing

1. **Apple Sign-In**: Works immediately once capability is added
2. **Google Sign-In**: Requires valid GoogleService-Info.plist and URL scheme setup
3. **Email Auth**: Ready for backend integration

## Security Best Practices

- Never store passwords in plain text
- Use secure token storage (Keychain)
- Implement proper session management
- Validate all authentication tokens server-side
- Use HTTPS for all authentication endpoints

## Additional Features to Consider

- Password reset functionality
- Email verification
- Biometric authentication (Face ID/Touch ID)
- Two-factor authentication
- Social account linking
- Account deletion

The authentication screen is now ready to use and can be easily extended with your specific backend requirements!