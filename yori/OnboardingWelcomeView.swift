//
//  OnboardingWelcomeView.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    @Binding var showOnboarding: Bool
    @State private var currentStep = 0

    private let onboardingSteps = [
        OnboardingStep(
            icon: "chart.line.uptrend.xyaxis",
            title: "Welcome to Yori",
            description: "Your AI-powered financial planning companion that helps you make smarter money decisions.",
            color: .blue
        ),
        OnboardingStep(
            icon: "building.columns",
            title: "Connect Your Accounts",
            description: "Securely link your bank accounts, credit cards, and investments to get a complete financial picture.",
            color: .green
        ),
        OnboardingStep(
            icon: "brain.head.profile",
            title: "AI-Powered Insights",
            description: "Get personalized recommendations, spending analysis, and financial planning powered by AI.",
            color: .purple
        ),
        OnboardingStep(
            icon: "target",
            title: "Achieve Your Goals",
            description: "Set financial goals and let Yori create a personalized plan to help you reach them faster.",
            color: .orange
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<onboardingSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .padding(.bottom, 40)

            // Main content with swipe support
            TabView(selection: $currentStep) {
                ForEach(0..<onboardingSteps.count, id: \.self) { index in
                    VStack(spacing: 30) {
                        // Icon
                        Image(systemName: onboardingSteps[index].icon)
                            .font(.system(size: 80))
                            .foregroundColor(onboardingSteps[index].color)

                        // Title and description
                        VStack(spacing: 16) {
                            Text(onboardingSteps[index].title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            Text(onboardingSteps[index].description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal, 40)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            Spacer()

            // Navigation buttons
            VStack(spacing: 16) {
                if currentStep < onboardingSteps.count - 1 {
                    // Next button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }) {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)

                    // Skip button
                    Button(action: {
                        showOnboarding = false
                    }) {
                        Text("Skip for now")
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Get started button
                    Button(action: {
                        showOnboarding = false
                    }) {
                        Text("Connect Your Accounts")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }
}

struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

#Preview {
    OnboardingWelcomeView(showOnboarding: .constant(true))
}