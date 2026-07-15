//
//  OnboardingView.swift
//  Pawzy
//
//  Apple Health stili onboarding — 3 sayfa, sade bilgilendirme
//

import SwiftUI

// MARK: - Localization Helper

enum L {
    static func string(_ key: String) -> String {
        var lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "auto"
        if lang == "auto" {
            let preferred = Locale.preferredLanguages.first ?? "en"
            let code = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
            let supported = ["en", "tr"]
            if supported.contains(code) {
                lang = code
            } else {
                lang = "en"
            }
        }

        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {

    @State private var currentPage: Int = 0
    var onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    pageView(
                        icon: "pawprint.fill",
                        titleKey: "onboarding_welcome_title",
                        bodyKey: "onboarding_welcome_body"
                    )
                    .tag(0)

                    pageView(
                        icon: "bell.badge.fill",
                        titleKey: "onboarding_notify_title",
                        bodyKey: "onboarding_notify_body"
                    )
                    .tag(1)

                    pageView(
                        icon: "heart.fill",
                        titleKey: "onboarding_ready_title",
                        bodyKey: "onboarding_ready_body"
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                bottomControls
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Page View

    private func pageView(icon: String, titleKey: String, bodyKey: String) -> some View {
        VStack(spacing: .pzSpaceXXL) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 90))
                .foregroundColor(.pzBlue)
                .accessibilityHidden(true)

            VStack(spacing: .pzSpaceMD) {
                Text(L.string(titleKey))
                    .font(.pzTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.pzTextPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(L.string(bodyKey))
                    .font(.pzBody)
                    .foregroundColor(.pzTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .pzSpaceXL)
            }

            Spacer()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: .pzSpaceLG) {
            primaryButton
                .padding(.horizontal, .pzSpaceSM)

            pageControl
        }
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button {
            if currentPage < 2 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage += 1
                }
            } else {
                onComplete?()
            }
        } label: {
            Text(currentPage < 2 ? L.string("Sürdür") : L.string("Başla"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.pzBlueGradientStart, .pzBlueGradientEnd]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint(currentPage < 2
            ? String(format: L.string("onboarding_page_indicator"), currentPage + 1)
            : L.string("Başla"))
    }

    // MARK: - Page Control Dots

    private var pageControl: some View {
        HStack(spacing: .pzSpaceSM) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index == currentPage ? Color.pzBlue : Color.pzTextQuaternary)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: L.string("onboarding_page_indicator"), currentPage + 1))
    }
}

// MARK: - Preview

#Preview("Onboarding - Light") {
    OnboardingView()
}

#Preview("Onboarding - Dark") {
    OnboardingView()
        .preferredColorScheme(.dark)
}
