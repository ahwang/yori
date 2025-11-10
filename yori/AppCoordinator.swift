//
//  AppCoordinator.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct AppCoordinator: View {
    @State private var isAuthenticated = false
    @State private var isOnboardingCompleted = false
    @State private var isLoading = true
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?

    var body: some View {
        Group {
            if isLoading {
                // Loading screen
                VStack {
                    Image("app-title-screen")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)

                    ProgressView()
                        .padding(.top, 20)
                }
                .background(Color(.systemBackground))
            } else if !isAuthenticated {
                // Authentication screen
                AuthenticationView()
            } else if !isOnboardingCompleted {
                // Onboarding flow
                OnboardingCoordinator()
            } else {
                // Main app
                DashboardView()
            }
        }
        .onAppear {
            checkAuthenticationState()
            setupAuthStateListener()
        }
        .onDisappear {
            if let handle = authStateHandle {
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { _, user in
            withAnimation(.easeInOut(duration: 0.3)) {
                isAuthenticated = user != nil
                if user != nil {
                    checkOnboardingState()
                } else {
                    isOnboardingCompleted = false
                }
            }
        }
    }

    private func checkAuthenticationState() {
        // Check if user is already signed in
        isAuthenticated = Auth.auth().currentUser != nil

        if isAuthenticated {
            checkOnboardingState()
        }

        withAnimation(.easeInOut(duration: 0.5)) {
            isLoading = false
        }
    }

    private func checkOnboardingState() {
        // Check if user has completed onboarding
        isOnboardingCompleted = UserDefaults.standard.bool(forKey: "onboarding_completed")

        // TODO: Also check backend for user profile completion
        // This would make an API call to check if user has:
        // - Connected bank accounts
        // - Set up financial goals
        // - Completed profile setup

        checkUserProfileFromBackend()
    }

    private func checkUserProfileFromBackend() {
        guard Auth.auth().currentUser != nil else { return }

        Task {
            do {
                let userProfile = try await AmplifyAPIService.shared.getCurrentUserProfile()

                // Update local state to match backend state
                await MainActor.run {
                    // If backend says onboarding is completed, update local state
                    if let onboardingComplete = userProfile.onboardingCompleted, onboardingComplete {
                        UserDefaults.standard.set(true, forKey: "onboarding_completed")
                        isOnboardingCompleted = true
                    } else {
                        // Backend says onboarding is not complete, ensure local state matches
                        UserDefaults.standard.set(false, forKey: "onboarding_completed")
                        isOnboardingCompleted = false
                    }
                }

                print("✅ User profile synced from backend: onboarding=\(userProfile.onboardingCompleted), hasAccounts=\(userProfile.hasConnectedAccounts)")
            } catch {
                print("⚠️ Failed to fetch user profile from backend: \(error.localizedDescription)")
                // On error, fall back to local UserDefaults
                // This ensures the app can still work offline or if backend is unavailable
            }
        }
    }
}

#Preview {
    AppCoordinator()
}
