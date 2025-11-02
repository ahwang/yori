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
        guard let user = Auth.auth().currentUser else { return }

        user.getIDToken { idToken, error in
            guard let idToken = idToken, error == nil else {
                print("Failed to get ID token")
                return
            }

            // TODO: Make API call to check user profile
            // GET /api/user/profile
            // Headers: Authorization: Bearer {idToken}
            //
            // Response should indicate:
            // - has_connected_accounts: boolean
            // - has_completed_profile: boolean
            // - onboarding_step: string

            // For now, we'll rely on local UserDefaults
            // In production, this would override local state with backend state
        }
    }
}

#Preview {
    AppCoordinator()
}