//
//  PawzyIAPManager.swift
//  Pawzy
//
//  StoreKit 2 Abonelik Yöneticisi — DEMIR'in ALANI
//  TEK DOGRULUK KAYNAGI: Product yükleme, purchase akisi,
//  Transaction.currentEntitlements, Transaction.updates,
//  verification, transaction.finish(), restore, entitlement
//

import Foundation
import StoreKit
import Observation
import os

// MARK: - StoreKit Product IDs

enum StoreKitProductID {
    static let yearly = "com.mahmutgazihan.pawzy.yearly"
    static let monthly = "com.mahmutgazihan.pawzy.monthly"
}

// MARK: - IAPManager Protocol (Entitlement API — Baran bu protokolü kullanır)

protocol IAPManagerProtocol: AnyObject {
    var isPremium: Bool { get }
    var isFreeMode: Bool { get set }
    func presentPaywall()
    func purchase(plan: PremiumPlan)
    func restorePurchases()
    func setFreeMode()
}

// MARK: - PawzyIAPManager (StoreKit 2, @Observable)

/// StoreKit 2 implementasyonu — @Observable ile SwiftUI binding desteği
/// Erişim: IAPManager.shared (typealias)
@Observable
final class PawzyIAPManager: IAPManagerProtocol {
    static let shared = PawzyIAPManager()

    // MARK: Entitlement State

    var isPremium: Bool = UserDefaults.standard.bool(forKey: "isPremium") {
        didSet {
            UserDefaults.standard.set(isPremium, forKey: "isPremium")
            if isPremium { isFreeMode = false }
        }
    }

    var isFreeMode: Bool = UserDefaults.standard.bool(forKey: "isFreeMode") {
        didSet { UserDefaults.standard.set(isFreeMode, forKey: "isFreeMode") }
    }

    // MARK: Loaded Products (dynamic pricing)

    var yearlyProduct: Product?
    var monthlyProduct: Product?

    // MARK: UI Feedback State

    /// Satın alma tamamlandığında PaywallView'a bildirim
    var purchaseCompleted = false
    /// Satın alma hatası oluştuğunda PaywallView'a bildirim
    var purchaseError: String?
    /// Geri yükleme tamamlandığında SettingsView'a bildirim
    var restoreCompleted = false
    /// Geri yükleme hatası
    var restoreError: String?

    // MARK: Private

    private let yearlyID = StoreKitProductID.yearly
    private let monthlyID = StoreKitProductID.monthly
    private var updateListenerTask: Task<Void, Error>?

    // MARK: Init

    init() {
        if isPremium { isFreeMode = false }
        listenForTransactions()
        Task { await loadProducts() }
        Task { await checkSubscriptionStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
        #if DEBUG
        print("🗑️ PawzyIAPManager deinit")
        #endif
    }

    // MARK: - Product Loading

    /// StoreKit'ten ürünleri yükler. Fiyatlar ASLA hardcode değil — Product.displayPrice
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [yearlyID, monthlyID])
            os_log(.info, "StoreKit: %{public}d ürün yüklendi", products.count)
            await MainActor.run {
                for product in products {
                    if product.id == yearlyID { yearlyProduct = product }
                    if product.id == monthlyID { monthlyProduct = product }
                }
            }
        } catch {
            os_log(.error, "StoreKit ürün yüklenemedi: %{public}@", error.localizedDescription)
            #if DEBUG
            print("❌ StoreKit ürün yüklenemedi: \(error)")
            #endif
        }
    }

    // MARK: - Purchase

    func purchase(plan: PremiumPlan) {
        let product = plan == .yearly ? yearlyProduct : monthlyProduct
        guard let product else {
            os_log(.error, "Ürün henüz yüklenmedi (%{public}@), satın alma başarısız", plan.rawValue)
            Task { @MainActor in
                self.purchaseError = L.string("purchase_product_not_loaded")
            }
            return
        }
        Task {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    // HER transaction verify edilir — unverified'a entitlement VERILMEZ
                    switch verification {
                    case .verified(let transaction):
                        await MainActor.run {
                            self.isPremium = true
                            self.isFreeMode = false
                            self.purchaseCompleted = true
                        }
                        // Trial başladıysa hatırlatma bildirimi planla
                        if #available(iOS 17.2, *), transaction.offer != nil {
                            await MainActor.run {
                                NotificationManager.shared.scheduleTrialReminder(daysAfter: 5)
                            }
                            #if DEBUG
                            print("✅ Trial başladı, 5 gün sonra hatırlatma planlandı")
                            #endif
                        }
                        // Baseline: transaction.finish() HER başarılı teslimattan SONRA
                        await transaction.finish()
                        #if DEBUG
                        print("✅ Satın alma başarılı, premium aktif")
                        #endif

                    case .unverified:
                        // KIRMIZI CIZGI: unverified transaction'a entitlement verilmez
                        await MainActor.run {
                            self.purchaseError = L.string("purchase_verification_failed")
                        }
                        #if DEBUG
                        print("⚠️ Satın alma doğrulanamadı — entitlement VERILMEDI")
                        #endif
                    }

                case .userCancelled:
                    await MainActor.run {
                        self.purchaseCompleted = true
                    }
                    #if DEBUG
                    print("💰 Satın alma kullanıcı tarafından iptal edildi")
                    #endif

                case .pending:
                    await MainActor.run {
                        self.purchaseCompleted = true
                    }
                    #if DEBUG
                    print("⏳ Satın alma beklemede")
                    #endif

                @unknown default:
                    break
                }
            } catch {
                await MainActor.run {
                    self.purchaseError = error.localizedDescription
                }
                #if DEBUG
                print("❌ Satın alma hatası: \(error)")
                #endif
            }
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() {
        Task {
            do {
                try await AppStore.sync()
                await checkSubscriptionStatus()
                await MainActor.run {
                    self.restoreCompleted = true
                }
            } catch {
                await MainActor.run {
                    self.restoreError = error.localizedDescription
                    self.restoreCompleted = true
                }
            }
        }
    }

    // MARK: - Subscription Status Check

    /// Transaction.currentEntitlements ile aktif aboneligi kontrol eder
    private func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable && !transaction.isUpgraded {
                    await MainActor.run {
                        self.isPremium = true
                        self.isFreeMode = false
                    }
                    #if DEBUG
                    print("✅ Abonelik bulundu, premium aktif")
                    #endif
                    return
                }
            }
        }
        // Döngü bittiyse ve hiç entitlement bulunamadıysa
        await MainActor.run {
            self.isPremium = false
        }
        // Trial iptal edildiyse hatırlatma bildirimini kaldır
        await MainActor.run {
            NotificationManager.shared.cancelTrialReminder()
        }
        #if DEBUG
        print("ℹ️ Aktif abonelik bulunamadı")
        #endif
    }

    /// Uygulama foreground'a geldiğinde abonelik durumunu yeniden kontrol etmek için public wrapper
    func checkSubscriptionStatusPublic() async {
        await checkSubscriptionStatus()
    }

    // MARK: - Transaction Listener

    /// Transaction.updates dinleyicisi — uygulama yaşam döngüsü boyunca aktif
    func listenForTransactions() {
        updateListenerTask?.cancel()
        updateListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = result {
                    await MainActor.run {
                        if !transaction.isUpgraded {
                            self.isPremium = true
                            self.isFreeMode = false
                        } else {
                            self.isPremium = true
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Free Mode

    func setFreeMode() {
        isFreeMode = true
        // isPremium korunur — kullanıcı premium ise premium'u kaybetmez.
        // isFreeMode ile sınırlı erişim sağlanır; isPremium=true zaten her şeyi açar.
    }

    // MARK: - Paywall Trigger

    func presentPaywall() {
        #if DEBUG
        print("💰 Paywall açılıyor")
        #endif
    }
}

// MARK: - Type Alias (Temiz API)

/// Kısa erişim: IAPManager.shared
typealias IAPManager = PawzyIAPManager

// MARK: - Premium Plan Enum

enum PremiumPlan: String, CaseIterable {
    case yearly
    case monthly

    var title: String {
        switch self {
        case .yearly: return L.string("Yıllık")
        case .monthly: return L.string("Aylık")
        }
    }

    func subtitle(storeManager: IAPManager) -> String {
        switch self {
        case .yearly:
            if let monthlyProduct = storeManager.monthlyProduct,
               storeManager.yearlyProduct != nil {
                return "\(monthlyProduct.displayPrice)/\(L.string("ay"))"
            }
            return L.string("En popüler")
        case .monthly:
            return L.string("İstediğin zaman iptal et")
        }
    }

    func price(storeManager: IAPManager) -> String {
        switch self {
        case .yearly:
            return storeManager.yearlyProduct?.displayPrice ?? ""
        case .monthly:
            return storeManager.monthlyProduct?.displayPrice ?? ""
        }
    }

    func period(storeManager: IAPManager) -> String {
        let product = self == .yearly ? storeManager.yearlyProduct : storeManager.monthlyProduct
        guard let product, let subscription = product.subscription else {
            return self == .yearly ? L.string("/yıl") : L.string("/ay")
        }
        switch subscription.subscriptionPeriod.unit {
        case .year: return L.string("/yıl")
        case .month: return L.string("/ay")
        case .week: return L.string("/hafta")
        case .day: return L.string("/gün")
        @unknown default: return self == .yearly ? L.string("/yıl") : L.string("/ay")
        }
    }
}

// MARK: - IAP Price Info Display Helpers

struct IAPPriceInfo {

    /// Bir Product'ın displayPrice'ını güvenli döndürür
    static func displayPrice(for product: Product?) -> String {
        product?.displayPrice ?? ""
    }

    /// Deneme sonrası fiyat metni — StoreKit ürün fiyatından dinamik
    static func postTrialText(
        for plan: PremiumPlan,
        storeManager: IAPManager
    ) -> String {
        let product = plan == .yearly ? storeManager.yearlyProduct : storeManager.monthlyProduct
        guard let product, let subscription = product.subscription else {
            return ""
        }
        let periodUnit: String
        switch subscription.subscriptionPeriod.unit {
        case .year: periodUnit = L.string("/yıl")
        case .month: periodUnit = L.string("/ay")
        case .week: periodUnit = L.string("/hafta")
        case .day: periodUnit = L.string("/gün")
        @unknown default: periodUnit = plan.period(storeManager: storeManager)
        }
        let cancelText = L.string("İstediğin zaman iptal et")
        return "\(L.string("Sonra")) \(product.displayPrice)\(periodUnit) · \(cancelText)"
    }

    /// CTA buton başlığı: intro offer varsa onu, yoksa ürün fiyatından dinamik
    static func ctaButtonTitle(
        for plan: PremiumPlan,
        storeManager: IAPManager,
        productsNotLoaded: Bool
    ) -> String {
        if productsNotLoaded {
            return ""
        }
        let product = plan == .yearly ? storeManager.yearlyProduct : storeManager.monthlyProduct
        if let introOffer = product?.subscription?.introductoryOffer,
           introOffer.paymentMode == .freeTrial {
            let period = introOffer.period
            let unit: String
            switch period.unit {
            case .day: unit = L.string("Gün")
            case .week: unit = L.string("Hafta")
            case .month: unit = L.string("Ay")
            case .year: unit = L.string("Yıl")
            @unknown default: unit = L.string("Gün")
            }
            return "\(period.value) \(unit) \(L.string("Ücretsiz Başla"))"
        }
        if let product, let subscription = product.subscription {
            let periodUnit: String
            switch subscription.subscriptionPeriod.unit {
            case .year: periodUnit = L.string("/yıl")
            case .month: periodUnit = L.string("/ay")
            case .week: periodUnit = L.string("/hafta")
            case .day: periodUnit = L.string("/gün")
            @unknown default: periodUnit = plan == .yearly ? L.string("/yıl") : L.string("/ay")
            }
            return "\(L.string("paywall_cta_start")) — \(product.displayPrice)\(periodUnit)"
        }
        return ""
    }

    /// Tasarruf yüzdesini hesapla (yıllık plan için)
    static func savingsPercent(storeManager: IAPManager) -> Int? {
        guard let monthlyPrice = storeManager.monthlyProduct?.price,
              let yearlyPrice = storeManager.yearlyProduct?.price,
              monthlyPrice > 0 else { return nil }
        let savings = Int(truncating: ((1 - yearlyPrice / (monthlyPrice * 12)) * 100) as NSDecimalNumber)
        return savings > 0 ? savings : nil
    }
}
