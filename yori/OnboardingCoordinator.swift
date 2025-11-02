//
//  OnboardingCoordinator.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct OnboardingCoordinator: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var showWelcome = true
    @State private var showPlaidConnection = false

    enum OnboardingStep {
        case welcome
        case plaidConnection
        case completed
    }

    var body: some View {
        Group {
            switch currentStep {
            case .welcome:
                OnboardingWelcomeView(showOnboarding: $showWelcome)
                    .onChange(of: showWelcome) { newValue in
                        if !newValue {
                            currentStep = .plaidConnection
                            showPlaidConnection = true
                        }
                    }

            case .plaidConnection:
                PlaidConnectionView(showPlaidConnection: $showPlaidConnection)
                    .onChange(of: showPlaidConnection) { newValue in
                        if !newValue {
                            completeOnboarding()
                        }
                    }

            case .completed:
                DashboardView()
            }
        }
    }

    private func completeOnboarding() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        currentStep = .completed
    }
}

#Preview {
    OnboardingCoordinator()
}