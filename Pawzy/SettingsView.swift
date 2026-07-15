//
//  SettingsView.swift
//  Pawzy
//
//  Ayarlar Ekranı — Sıfırdan, temiz ve modern tasarım
//  Apple HIG: List + insetGrouped, native NavigationStack
//

import SwiftUI
import SwiftData
import StoreKit
import SafariServices

// MARK: - SettingsView

struct SettingsView: View {

    // MARK: SwiftData

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query(sort: \MedicationCabinetItem.name) private var cabinetItems: [MedicationCabinetItem]
    @Query(sort: \ChatMessage.timestamp) private var chatMessages: [ChatMessage]

    // MARK: State

    @State private var remindersOn: Bool = true
    @AppStorage("soundOn") private var soundOn: Bool = true
    @State private var badgeOn: Bool = true
    @State private var showPaywall: Bool = false
    @State private var showLanguageSheet: Bool = false
    @State private var showAppearanceSheet: Bool = false
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @State private var showBackupSuccess: Bool = false
    @State private var showRestoreSuccess: Bool = false
    @State private var showBackupError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showRestorePurchaseSuccess: Bool = false
    @State private var showRestorePurchaseNotFound: Bool = false
    
    // Spam koruması
    @State private var isBackingUp: Bool = false
    @State private var isRestoringFromCloud: Bool = false
    @State private var isRestoringPurchases: Bool = false

    // Tüm verileri sil
    @State private var showDeleteDataConfirmation: Bool = false

    // R1: Dil değişikliği uyarısı
    @State private var showLanguageChangedAlert: Bool = false

    // R21: Safari sheet
    @State private var showSafari: Bool = false
    @State private var safariURL: URL? = nil

    // MARK: StoreManager

    private let storeManager = IAPManager.shared

    // MARK: Dil

    @AppStorage("appLanguage") private var appLanguage: String = "auto"

    private var selectedLanguageName: String {
        switch appLanguage {
        case "auto": return resolvedAutoLanguageName
        case "tr": return "Türkçe"
        default: return "English"
        }
    }

    private var resolvedAutoLanguageName: String {
        let preferredLang = Locale.preferredLanguages.first ?? "en"
        let code = Locale(identifier: preferredLang).language.languageCode?.identifier ?? "en"
        switch code {
        case "tr": return "Türkçe"
        default: return "English"
        }
    }

    // MARK: Görünüm

    private var selectedAppearanceName: String {
        switch appColorScheme {
        case "light": return L.string("Aydınlık")
        case "dark": return L.string("Karanlık")
        default: return L.string("Sistem")
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                premiumSection
                aboutSection
                notificationsSection
                dataPrivacySection
                footerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L.string("Ayarlar"))
            .navigationBarTitleDisplayMode(.large)
            .scrollContentBackground(.hidden)
            .background(Color.pzBackground)
        }
        .tint(.pzBlue)
        .onChange(of: storeManager.restoreCompleted) { _, completed in
            if completed {
                isRestoringPurchases = false
                storeManager.restoreCompleted = false // reset
                if storeManager.isPremium {
                    showRestorePurchaseSuccess = true
                } else {
                    showRestorePurchaseNotFound = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            guard storeManager.isPremium else { return }
            performAutoBackup()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall, storeManager: storeManager)
        }
        .sheet(isPresented: $showLanguageSheet) {
            languageSelectionSheet
        }
        .sheet(isPresented: $showAppearanceSheet) {
            appearanceSelectionSheet
        }
        .alert(L.string("Yedeklendi"), isPresented: $showBackupSuccess) {
            Button(L.string("Tamam"), role: .cancel) { }
        } message: {
            Text(L.string("Verilerin iCloud'a başarıyla yedeklendi."))
        }
        .alert(L.string("Geri Yüklendi"), isPresented: $showRestoreSuccess) {
            Button(L.string("Tamam"), role: .cancel) { }
        } message: {
            Text(L.string("Verilerin iCloud'dan başarıyla geri yüklendi."))
        }
        .alert(L.string("Hata"), isPresented: $showBackupError) {
            Button(L.string("Tamam"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert(L.string("Satın alımlarınız başarıyla geri yüklendi."), isPresented: $showRestorePurchaseSuccess) {
            Button(L.string("Tamam"), role: .cancel) { }
        }
        .alert(L.string("Geri yüklenecek satın alım bulunamadı."), isPresented: $showRestorePurchaseNotFound) {
            Button(L.string("Tamam"), role: .cancel) { }
        }
        .alert(L.string("Dil Değiştirildi"), isPresented: $showLanguageChangedAlert) {
            Button(L.string("Tamam"), role: .cancel) { }
        } message: {
            Text(L.string("Dil değişikliğinin tam olarak uygulanması için uygulamayı yeniden başlatmanız önerilir."))
        }
        .alert(L.string("Veriler Silinsin mi?"), isPresented: $showDeleteDataConfirmation) {
            Button(L.string("İptal"), role: .cancel) { }
            Button(L.string("Sil"), role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text(L.string("Tüm evcil hayvan, ilaç ve sohbet verileri kalıcı olarak silinecek. Bu işlem geri alınamaz."))
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }

    // MARK: - Premium Section

    @ViewBuilder
    private var premiumSection: some View {
        if storeManager.isPremium {
            Section {
                premiumActiveCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } else {
            Section {
                premiumUpgradeCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    /// Premium aktif — teşekkür kartı
    private var premiumActiveCard: some View {
        HStack(spacing: .pzSpaceMD) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: .pzRadiusMD))

            VStack(alignment: .leading, spacing: 2) {
                Text(L.string("Pawzy Premium"))
                    .font(.pzHeadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(L.string("Premium üyeliğin aktif. Desteklediğin için teşekkürler!"))
                    .font(.pzCaption)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.pzSpaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.pzGreen, Color(hex: "30B0C7")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: .pzRadiusXL))
        .padding(.horizontal, .pzSpaceLG)
        .padding(.vertical, .pzSpaceSM)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(L.string("Pawzy Premium")), \(L.string("Premium üyeliğin aktif. Desteklediğin için teşekkürler!"))")
    }

    /// Premium değil — yükseltme kartı
    private var premiumUpgradeCard: some View {
        let gradientColors: [Color] = colorScheme == .dark
            ? [Color.pzBlue.opacity(0.3), Color.pzBlue.opacity(0.15)]
            : [Color.pzBlueGradientStart, Color.pzBlueGradientEnd]

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: .pzSpaceMD) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: .pzRadiusMD))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.string("Pawzy Premium"))
                        .font(.pzHeadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(L.string("Sınırsız pati, akıllı hatırlatıcılar."))
                        .font(.pzCaption)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()
            }

            Button {
                showPaywall = true
            } label: {
                Text(L.string("Yükselt"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.pzBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: .pzRadiusMD)
                            .fill(Color.white)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, .pzSpaceLG)
            .accessibilityLabel(L.string("Yükselt, Pawzy Premium'a geç"))
        }
        .padding(.pzSpaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: .pzRadiusXL))
        .padding(.horizontal, .pzSpaceLG)
        .padding(.vertical, .pzSpaceSM)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(L.string("Pawzy Premium")), \(L.string("Sınırsız pati, akıllı hatırlatıcılar.")), \(L.string("Yükselt"))")
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            languageRow
            appearanceRow
            rateAppRow
            versionRow
            termsOfUseRow
            privacyPolicyRow
            eulaRow
        } header: {
            sectionHeaderText(L.string("HAKKINDA"))
        }
    }

    private var languageRow: some View {
        Button {
            showLanguageSheet = true
        } label: {
            HStack(spacing: .pzSpaceMD) {
                Text(L.string("Dil / Language"))
                    .font(.pzBody)
                    .foregroundColor(.pzTextPrimary)
                Spacer()
                Text(selectedLanguageName)
                    .font(.pzCallout)
                    .foregroundColor(.pzTextTertiary)
            }
        }
        .accessibilityLabel("\(L.string("Dil / Language")), \(selectedLanguageName)")
        .accessibilityHint(L.string("Dil seçimi ekranını açar"))
    }

    private var appearanceRow: some View {
        Button {
            showAppearanceSheet = true
        } label: {
            HStack(spacing: .pzSpaceMD) {
                Text(L.string("Görünüm"))
                    .font(.pzBody)
                    .foregroundColor(.pzTextPrimary)
                Spacer()
                Text(selectedAppearanceName)
                    .font(.pzCallout)
                    .foregroundColor(.pzTextTertiary)
            }
        }
        .accessibilityLabel("\(L.string("Görünüm")), \(selectedAppearanceName)")
        .accessibilityHint(L.string("Görünüm seçeneklerini açar"))
    }

    private var rateAppRow: some View {
        Button {
            // Önce requestReview dene (yılda 3 kere limit)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
            // 1 saniye sonra App Store'a yönlendir (requestReview gösterilmezse fallback)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let url = URL(string: "https://apps.apple.com/app/id6745252109") {
                    UIApplication.shared.open(url)
                }
            }
        } label: {
            Text(L.string("Pawzy'i Değerlendir"))
                .font(.pzBody)
                .foregroundColor(.pzTextPrimary)
        }
        .accessibilityLabel(L.string("Pawzy'i Değerlendir"))
    }

    private var versionRow: some View {
        HStack {
            Text(L.string("Sürüm"))
                .font(.pzBody)
                .foregroundColor(.pzTextPrimary)
            Spacer()
            Text(bundleVersion)
                .font(.pzCallout)
                .foregroundColor(.pzTextTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L.string("Sürüm")), \(bundleVersion)")
    }

    private var bundleVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "26.6.3 (1)"
    }

    private var termsOfUseRow: some View {
        linkRow(
            title: L.string("Kullanım Koşulları"),
            urlString: "https://mahmutgazihanarslan.com.tr/pawzy/termsofuse.html"
        )
    }

    private var privacyPolicyRow: some View {
        linkRow(
            title: L.string("Gizlilik Politikası"),
            urlString: "https://mahmutgazihanarslan.com.tr/pawzy/privacy.html"
        )
    }

    private var eulaRow: some View {
        linkRow(
            title: L.string("EULA"),
            urlString: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        )
    }

    private func linkRow(title: String, urlString: String) -> some View {
        Button {
            safariURL = URL(string: urlString)
            showSafari = true
        } label: {
            HStack(spacing: .pzSpaceMD) {
                Text(title)
                    .font(.pzBody)
                    .foregroundColor(.pzTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.pzTextQuaternary)
            }
        }
        .accessibilityLabel(title)
        .accessibilityHint(L.string("Web sayfasını açar"))
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            toggleRow(
                title: L.string("Hatırlatıcılar"),
                subtitle: L.string("İlaç saatlerinde bildir"),
                iconName: "bell.fill",
                iconColor: .pzCoral,
                isOn: $remindersOn
            )

            toggleRow(
                title: L.string("Sesli Uyarı"),
                subtitle: L.string("Bildirim sesi çal"),
                iconName: "speaker.wave.2.fill",
                iconColor: .pzBlue,
                isOn: $soundOn
            )

            toggleRow(
                title: L.string("Rozet Sayacı"),
                subtitle: L.string("Simgede bekleyen doz"),
                iconName: "bell.badge.fill",
                iconColor: .pzRed,
                isOn: $badgeOn
            )
        } header: {
            sectionHeaderText(L.string("BİLDİRİMLER"))
        }
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        iconName: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: .pzSpaceMD) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.pzBody)
                    .foregroundColor(.pzTextPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.pzTextTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(.pzGreen)
                .labelsHidden()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityValue(isOn.wrappedValue ? L.string("Açık") : L.string("Kapalı"))
        .accessibilityHint(L.string("Açmak veya kapatmak için çift dokunun"))
    }

    // MARK: - Data & Privacy Section

    private var dataPrivacySection: some View {
        Section {
            // Satın Alımları Yükle — herkese açık
            Button {
                if !isRestoringPurchases { performRestorePurchases() }
            } label: {
                iCloudRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .pzPurple,
                    title: isRestoringPurchases ? L.string("Kontrol ediliyor...") : L.string("Satın Alımları Yükle")
                )
            }
            .disabled(isRestoringPurchases)
            .opacity(isRestoringPurchases ? 0.6 : 1.0)
            .accessibilityLabel(L.string("Satın Alımları Yükle"))
            .accessibilityHint(L.string("Önceki satın almaları geri yüklemek için çift dokunun"))

            // Tüm verileri sil
            Button(role: .destructive) {
                showDeleteDataConfirmation = true
            } label: {
                iCloudRow(
                    icon: "trash.fill",
                    iconColor: .pzRed,
                    title: L.string("Tüm Verileri Sil")
                )
            }
            .accessibilityLabel(L.string("Tüm Verileri Sil"))
            .accessibilityHint(L.string("Tüm evcil hayvan ve ilaç verilerini kalıcı olarak siler"))
        } header: {
            HStack {
                sectionHeaderText(L.string("VERİ & GİZLİLİK"))
                if !storeManager.isPremium {
                    Text(L.string("Premium"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.pzBlue)
                        )
                }
            }
        }
    }

    private func iCloudRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: .pzSpaceMD) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 22)
            Text(title)
                .font(.pzBody)
                .foregroundColor(.pzTextPrimary)
        }
    }

    // MARK: - Backup Operations

    private func performBackup() {
        guard !isBackingUp else { return }
        isBackingUp = true
        Task {
            do {
                let data = try BackupManager.shared.exportBackup(
                    pets: pets,
                    medications: medications,
                    cabinetItems: cabinetItems,
                    chatMessages: chatMessages
                )
                try await BackupManager.shared.saveToCloud(data: data)
                await MainActor.run {
                    isBackingUp = false
                    showBackupSuccess = true
                }
            } catch {
                await MainActor.run {
                    isBackingUp = false
                    errorMessage = error.localizedDescription
                    showBackupError = true
                }
            }
        }
    }

    private func performRestore() {
        guard !isRestoringFromCloud else { return }
        isRestoringFromCloud = true
        Task {
            do {
                let data = try await BackupManager.shared.loadFromCloud()
                try BackupManager.shared.importBackup(data: data, modelContext: modelContext)
                await MainActor.run {
                    isRestoringFromCloud = false
                    showRestoreSuccess = true
                }
            } catch {
                await MainActor.run {
                    isRestoringFromCloud = false
                    errorMessage = error.localizedDescription
                    showBackupError = true
                }
            }
        }
    }

    private func performAutoBackup() {
        Task {
            do {
                let data = try BackupManager.shared.exportBackup(
                    pets: pets,
                    medications: medications,
                    cabinetItems: cabinetItems,
                    chatMessages: chatMessages
                )
                try await BackupManager.shared.saveToCloud(data: data)
                #if DEBUG
                print("✅ Otomatik yedekleme başarılı")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Otomatik yedekleme hatası: \(error)")
                #endif
            }
        }
    }

    // MARK: - Purchase Restore

    private func performRestorePurchases() {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true
        storeManager.restorePurchases()
    }

    // MARK: - Delete All Data

    private func deleteAllData() {
        // Tüm verileri sil
        for pet in pets { modelContext.delete(pet) }
        for med in medications { modelContext.delete(med) }
        for item in cabinetItems { modelContext.delete(item) }
        for msg in chatMessages { modelContext.delete(msg) }
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("⚠️ Veri silme hatası: \(error)")
            #endif
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        Section {
            VStack(spacing: .pzSpaceSM) {
                Text("© Pawzy")
                    .font(.system(size: 12))
                    .foregroundColor(.pzTextTertiary)

                HStack(spacing: 0) {
                    Button(L.string("Kullanım Koşulları")) {
                        safariURL = URL(string: "https://mahmutgazihanarslan.com.tr/pawzy/termsofuse.html")
                        showSafari = true
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.pzBlue)

                    Text("  ·  ")
                        .font(.system(size: 11))
                        .foregroundColor(.pzTextQuaternary)

                    Button(L.string("Gizlilik Politikası")) {
                        safariURL = URL(string: "https://mahmutgazihanarslan.com.tr/pawzy/privacy.html")
                        showSafari = true
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.pzBlue)

                    Text("  ·  ")
                        .font(.system(size: 11))
                        .foregroundColor(.pzTextQuaternary)

                    Button(L.string("EULA")) {
                        safariURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                        showSafari = true
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.pzBlue)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .pzSpaceMD)
            .padding(.horizontal, .pzSpaceMD)
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .fill(Color.pzSurface)
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Section Header

    private func sectionHeaderText(_ title: String) -> some View {
        Text(title)
            .font(.pzCaptionBold)
            .foregroundColor(.pzTextSecondary)
            .textCase(nil)
            .tracking(0.4)
    }

    // MARK: - Appearance Selection Sheet

    private var appearanceSelectionSheet: some View {
        NavigationStack {
            List {
                Button {
                    appColorScheme = "system"
                    showAppearanceSheet = false
                } label: {
                    HStack {
                        Text(L.string("Sistem"))
                            .font(.pzBody)
                            .foregroundColor(.pzTextPrimary)
                        Spacer()
                        if appColorScheme == "system" {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.pzBlue)
                        }
                    }
                }

                Button {
                    appColorScheme = "light"
                    showAppearanceSheet = false
                } label: {
                    HStack {
                        Text(L.string("Aydınlık"))
                            .font(.pzBody)
                            .foregroundColor(.pzTextPrimary)
                        Spacer()
                        if appColorScheme == "light" {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.pzBlue)
                        }
                    }
                }

                Button {
                    appColorScheme = "dark"
                    showAppearanceSheet = false
                } label: {
                    HStack {
                        Text(L.string("Karanlık"))
                            .font(.pzBody)
                            .foregroundColor(.pzTextPrimary)
                        Spacer()
                        if appColorScheme == "dark" {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.pzBlue)
                        }
                    }
                }
            }
            .navigationTitle(L.string("Görünüm"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("Kapat")) {
                        showAppearanceSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Language Selection Sheet

    private var languageSelectionSheet: some View {
        NavigationStack {
            List {
                languageOption("en", "English")
                languageOption("tr", "Türkçe")
            }
            .navigationTitle(L.string("Dil / Language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("Kapat")) {
                        showLanguageSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func languageOption(_ code: String, _ name: String) -> some View {
        Button {
            selectLanguage(code)
        } label: {
            HStack {
                Text(name)
                    .font(.pzBody)
                    .foregroundColor(.pzTextPrimary)
                Spacer()
                if appLanguage == code {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.pzBlue)
                }
            }
        }
    }

    private func selectLanguage(_ lang: String) {
        appLanguage = lang
        showLanguageSheet = false
        // Dil değişikliğini uygula — .id() ile force-refresh yapılacak
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Kullanıcıya alert göstererek manuel restart öner
            showLanguageChangedAlert = true
        }
    }
}

// MARK: - SafariView Wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Previews

#Preview("Ayarlar — Light") {
    SettingsView()
        .modelContainer(for: [Pet.self, Medication.self])
}

#Preview("Ayarlar — Dark") {
    SettingsView()
        .modelContainer(for: [Pet.self, Medication.self])
        .preferredColorScheme(.dark)
}
