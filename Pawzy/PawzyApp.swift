//
//  PawzyApp.swift
//  Pawzy
//

import SwiftUI
import SwiftData

@main
struct PawzyApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = "auto"
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    
    @Environment(\.scenePhase) private var scenePhase
    private let storeManager = IAPManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Pet.self,
            Medication.self,
            MedicationCabinetItem.self,
            ChatMessage.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // CloudKit kapalı
        )
        
        // Önce disk-based container dene
        if let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
            return container
        }
        
        // Disk hatası olursa in-memory container'a düş, app açılsın
        #if DEBUG
        print("⚠️ Disk ModelContainer oluşturulamadı, in-memory kullanılıyor")
        #endif
        
        let inMemoryConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [inMemoryConfig])
        } catch {
            // Son çare: crash log ama uygulama ölmesin
            #if DEBUG
            print("❌ ModelContainer hatası: \(error)")
            #endif
            guard let modelContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfig]) else {
                fatalError("ModelContainer başlatılamadı")
            }
            return modelContainer
        }
    }()

    init() {
        // İlk açılışta dil algılama
        if UserDefaults.standard.string(forKey: "appLanguage") == nil
            || UserDefaults.standard.string(forKey: "appLanguage") == "auto" {
            let preferredLang = Locale.preferredLanguages.first ?? "en"
            let code = Locale(identifier: preferredLang).language.languageCode?.identifier ?? "en"

            // Desteklenen diller
            let supportedLanguages = [
                "en", "tr"
            ]

            if supportedLanguages.contains(code) {
                appLanguage = code
            } else {
                appLanguage = "en"
            }
        }

    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(resolvedColorScheme)
                .sheet(isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { newlyPresented in
                        if !newlyPresented {
                            hasCompletedOnboarding = true
                        }
                    }
                )) {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                    .interactiveDismissDisabled()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                storeManager.listenForTransactions()
                // Ayrıca abonelik durumunu da yeniden kontrol et
                Task { await storeManager.checkSubscriptionStatusPublic() }
            }
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil // sistem
        }
    }
}
