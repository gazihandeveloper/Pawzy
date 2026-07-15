//
//  PaywallView.swift
//  Pawzy
//
//  Apple iCloud+ / Apple Music stili sade paywall.
//  Tüm Liquid Glass efektleri kaldırıldı — temiz kart + shadow.
//  StoreKit mekanizması Demir'in alanı — sadece görsel düzen değişti.
//

import SwiftUI
import StoreKit
import Network

// MARK: - PaywallView

struct PaywallView: View {

    @Binding var isPresented: Bool
    @State private var selectedPlan: PremiumPlan = .yearly
    @State private var isPurchasing: Bool = false
    @State private var isRestoring: Bool = false
    @State private var showOfflineAlert: Bool = false
    @State private var showPurchaseErrorAlert: Bool = false
    @State private var purchaseErrorMessage: String = ""
    @State private var productsLoadTimedOut: Bool = false
    @State private var isReloadingProducts: Bool = false

    var storeManager: IAPManager

    init(isPresented: Binding<Bool>, storeManager: IAPManager = .shared) {
        self._isPresented = isPresented
        self.storeManager = storeManager
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                benefitsSection
                    .padding(.top, .pzSpaceXL)
                    .padding(.horizontal, .pzSpaceXL)
                planSelectionSection
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.top, .pzSpaceXL)
                ctaButton
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.top, .pzSpaceLG)
                freeUseButton
                    .padding(.top, .pzSpaceSM)
                bottomLinks
                    .padding(.top, .pzSpaceLG)
                    .padding(.bottom, .pzSpaceLG)
                    .padding(.horizontal, .pzSpaceXL)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.pzBackground.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.top, .pzSpaceSM)
                .padding(.trailing, .pzSpaceLG)
        }
        .alert(L.string("İnternet Bağlantısı"), isPresented: $showOfflineAlert) {
            Button(L.string("Tamam"), role: .cancel) { }
            Button(L.string("Ayarlar")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(L.string("İnternet bağlantınızı kontrol edin. Satın alma işlemi için internet bağlantısı gereklidir."))
        }
        .alert(L.string("Hata"), isPresented: $showPurchaseErrorAlert) {
            Button(L.string("Tamam"), role: .cancel) { }
        } message: {
            Text(purchaseErrorMessage)
        }
        .onChange(of: storeManager.isPremium) { _, newValue in
            if newValue {
                isPurchasing = false
                isPresented = false
            }
        }
        .onChange(of: storeManager.purchaseCompleted) { _, completed in
            if completed {
                isPurchasing = false
                storeManager.purchaseCompleted = false
            }
        }
        .onChange(of: storeManager.purchaseError) { _, error in
            if let error {
                isPurchasing = false
                purchaseErrorMessage = error
                showPurchaseErrorAlert = true
                storeManager.purchaseError = nil
            }
        }
        .onChange(of: storeManager.restoreCompleted) { _, completed in
            if completed {
                isRestoring = false
                storeManager.restoreCompleted = false
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            if storeManager.yearlyProduct == nil && storeManager.monthlyProduct == nil {
                await MainActor.run {
                    productsLoadTimedOut = true
                }
            }
        }
        .onChange(of: storeManager.yearlyProduct) { _, _ in
            if storeManager.yearlyProduct != nil || storeManager.monthlyProduct != nil {
                productsLoadTimedOut = false
            }
        }
        .onChange(of: storeManager.monthlyProduct) { _, _ in
            if storeManager.yearlyProduct != nil || storeManager.monthlyProduct != nil {
                productsLoadTimedOut = false
            }
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isPresented = false
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.pzTextSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.pzSurface)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )
        }
        .accessibilityLabel(L.string("Kapat"))
        .accessibilityHint(L.string("Paywall ekranını kapatmak için çift dokunun"))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: .pzSpaceMD) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 60))
                .foregroundColor(.pzBlue)

            Text(L.string("Pawzy Premium"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.pzTextPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(L.string("Evcil dostlarımızın sağlığı için ihtiyacın olan her şey."))
                .font(.pzCallout)
                .foregroundColor(.pzTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, .pzSpaceXL)
        .padding(.bottom, .pzSpaceSM)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(spacing: .pzSpaceSM) {
            ForEach(Array(benefitItems.enumerated()), id: \.offset) { _, item in
                benefitRow(item: item)
            }
        }
        .padding(.pzSpaceMD)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusLG)
                .fill(Color.pzSurface)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    private struct BenefitItem {
        let text: String
        let iconName: String
        let color: Color
    }

    private let benefitItems: [BenefitItem] = [
        BenefitItem(text: L.string("Sınırsız evcil hayvan ekle"), iconName: "pawprint.fill", color: .pzBlue),
        BenefitItem(text: L.string("Akıllı, tekrarlayan hatırlatıcılar"), iconName: "bell.badge.fill", color: .pzTeal),
        BenefitItem(text: L.string("Pawzy AI: Yapay zeka destekli danışman"), iconName: "sparkles", color: .pzPurple)
    ]

    private func benefitRow(item: BenefitItem) -> some View {
        HStack(spacing: .pzSpaceSM) {
            Image(systemName: item.iconName)
                .font(.system(size: 18))
                .foregroundColor(item.color)
                .frame(width: 28, height: 28)

            Text(item.text)
                .font(.pzCallout)
                .foregroundColor(.pzTextPrimary)

            Spacer()
        }
        .padding(.vertical, .pzSpaceXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.text)
    }

    // MARK: - Plan Selection Section

    private var planSelectionSection: some View {
        VStack(spacing: .pzSpaceSM) {
            planCard(.yearly)
            planCard(.monthly)
        }
    }

    private func planCard(_ plan: PremiumPlan) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlan = plan
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.pzTextPrimary)

                    if plan == .yearly, let monthlyProduct = storeManager.monthlyProduct {
                        Text("\(monthlyProduct.displayPrice)/\(L.string("ay"))")
                            .font(.pzCaption)
                            .foregroundColor(.pzTextSecondary)
                    }

                    if plan == .monthly {
                        Text(L.string("İstediğin zaman iptal et"))
                            .font(.pzCaption)
                            .foregroundColor(.pzTextSecondary)
                    }
                }

                Spacer()

                let price = planPrice(plan)
                if !price.isEmpty {
                    Text(price)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.pzTextPrimary)
                }

                if plan == .yearly, let savings = IAPPriceInfo.savingsPercent(storeManager: storeManager) {
                    Text("%\(savings) \(L.string("tasarruf"))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.pzGreen)
                        .padding(.horizontal, .pzSpaceXS)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.pzGreenLight)
                        )
                        .padding(.leading, 4)
                }
            }
            .padding(.pzSpaceLG)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .fill(Color.pzSurface)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .strokeBorder(isSelected ? Color.pzBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(planAccessibilityLabel(plan, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func planPrice(_ plan: PremiumPlan) -> String {
        plan == .yearly ? storeManager.yearlyProduct?.displayPrice ?? "" : storeManager.monthlyProduct?.displayPrice ?? ""
    }

    private func planAccessibilityLabel(_ plan: PremiumPlan, isSelected: Bool) -> String {
        let selectedText = isSelected ? L.string("Seçili") : ""
        return "\(plan.title) \(planPrice(plan)) \(selectedText)"
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            if productsLoadTimedOut && productsNotLoaded {
                retryLoadProducts()
            } else {
                purchase()
            }
        } label: {
            HStack(spacing: 8) {
                if isPurchasing || isReloadingProducts || (productsNotLoaded && !productsLoadTimedOut) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }

                let buttonText = ctaButtonText
                if !buttonText.isEmpty {
                    Text(buttonText)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .disabled(isPurchasing || isReloadingProducts || (productsNotLoaded && !productsLoadTimedOut))
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusMD)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.pzBlueGradientStart, Color.pzBlueGradientEnd]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: .pzBlue.opacity(0.2), radius: 8, y: 2)
        .sensoryFeedback(.impact(weight: .medium), trigger: isPurchasing)
        .accessibilityLabel(ctaAccessibilityLabel)
        .accessibilityHint(L.string("Satın alma işlemini başlatmak için çift dokunun"))
    }

    private var ctaButtonText: String {
        if isPurchasing { return L.string("İşleniyor...") }
        if isReloadingProducts { return L.string("Yükleniyor...") }
        if productsLoadTimedOut && productsNotLoaded { return L.string("Yeniden Dene") }
        return IAPPriceInfo.ctaButtonTitle(for: selectedPlan, storeManager: storeManager, productsNotLoaded: productsNotLoaded)
    }

    private var ctaAccessibilityLabel: String {
        if isPurchasing { return L.string("İşleniyor...") }
        if isReloadingProducts { return L.string("Yükleniyor...") }
        if productsLoadTimedOut && productsNotLoaded { return L.string("Yeniden Dene") }
        if productsNotLoaded { return L.string("Yükleniyor...") }
        return "\(ctaButtonText), \(selectedPlan.title)"
    }

    private var productsNotLoaded: Bool {
        storeManager.yearlyProduct == nil && storeManager.monthlyProduct == nil
    }

    // MARK: - Free Use Button

    private var freeUseButton: some View {
        Button {
            freeUse()
        } label: {
            Text(L.string("Ücretsiz Kullan"))
                .font(.pzCallout)
                .foregroundColor(.pzTextSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.string("Ücretsiz Kullan, premium olmadan devam et"))
        .accessibilityHint(L.string("Premium özellikler olmadan uygulamayı kullanmaya devam eder"))
    }

    // MARK: - Bottom Links

    private var bottomLinks: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                linkButton(L.string("Kullanıcı Sözleşmesi")) { openTermsURL() }

                Text(" · ")
                    .font(.system(size: 13))
                    .foregroundColor(.pzTextQuaternary)

                linkButton(L.string("Gizlilik")) { openPrivacyURL() }

                Text(" · ")
                    .font(.system(size: 13))
                    .foregroundColor(.pzTextQuaternary)

                linkButton(L.string("EULA")) { openEULAURL() }
            }

            Button {
                restorePurchases()
            } label: {
                HStack(spacing: 4) {
                    if isRestoring {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .pzBlue))
                            .scaleEffect(0.6)
                    }
                    Text(L.string("Satın Alımları Yükle"))
                        .font(.system(size: 13))
                        .foregroundColor(.pzBlue)
                }
            }
            .disabled(isRestoring)
            .accessibilityLabel(L.string("Satın Alımları Yükle"))
            .accessibilityHint(L.string("Önceki satın almaları geri yüklemek için çift dokunun"))
        }
        .frame(maxWidth: .infinity)
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.pzBlue)
        }
    }

    // MARK: - Actions (StoreKit mantığına DOKUNULMADI)

    private func checkNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.resume(returning: path.status == .satisfied)
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue.global())
        }
    }

    private func purchase() {
        guard !isPurchasing else { return }
        isPurchasing = true

        Task {
            let hasNetwork = await checkNetwork()
            if !hasNetwork {
                await MainActor.run {
                    isPurchasing = false
                    showOfflineAlert = true
                }
                return
            }
            await MainActor.run {
                storeManager.purchase(plan: selectedPlan)
            }
        }
    }

    private func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true
        storeManager.restorePurchases()
    }

    private func freeUse() {
        storeManager.setFreeMode()
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }

    private func retryLoadProducts() {
        guard !isReloadingProducts else { return }
        isReloadingProducts = true
        productsLoadTimedOut = false
        Task {
            await storeManager.loadProducts()
            await MainActor.run {
                isReloadingProducts = false
                if storeManager.yearlyProduct == nil && storeManager.monthlyProduct == nil {
                    productsLoadTimedOut = true
                }
            }
        }
    }

    // MARK: - URL Actions

    private func openTermsURL() {
        if let url = URL(string: "https://mahmutgazihanarslan.com.tr/pawzy/termsofuse.html") {
            UIApplication.shared.open(url)
        }
    }

    private func openPrivacyURL() {
        if let url = URL(string: "https://mahmutgazihanarslan.com.tr/pawzy/privacy.html") {
            UIApplication.shared.open(url)
        }
    }

    private func openEULAURL() {
        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Previews

#Preview("Paywall — Light Mode") {
    PaywallView(isPresented: .constant(true))
}

#Preview("Paywall — Dark Mode") {
    PaywallView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}
