# 🐾 Pawzy

> **Yeni nesil evcil hayvan ilaç & sağlık takip uygulaması.**  
> *Next-generation pet medication & health tracker.*

---

[![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.10%2B-F05138?logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-007AFF?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Xcode](https://img.shields.io/badge/Xcode-16%2B-147EFB?logo=xcode)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](LICENSE)

<p align="center">
  <img src="Pawzy/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="Pawzy Logo" width="180" />
</p>

---

## 🧠 Pawzy Nedir? / What is Pawzy?

**TR** — Pawzy, evcil hayvan sahiplerinin ilaç takibini, sağlık rutinlerini ve veteriner süreçlerini kolaylaştıran, **yapay zeka destekli**, tamamen **cihaz üstünde** çalışan bir iOS uygulamasıdır. Hiçbir sağlık verisi buluta gitmez — gizlilik ön plandadır.

**EN** — Pawzy is an **AI-powered**, fully **on-device** iOS app that simplifies medication tracking, health routines, and vet processes for pet owners. No health data ever leaves the device — privacy-first by design.

---

## ✨ Özellikler / Features

| Özellik | Açıklama |
|---|---|
| 🐶 **Çoklu Evcil Hayvan** | Birden fazla evcil hayvan profili oluştur; her biri için ayrı ilaç ve sağlık takibi |
| 💊 **Akıllı İlaç Takibi** | İlaç ekle, dozaj ve zaman ayarla; yerel bildirimlerle hiç kaçırma |
| 🤖 **AI Veteriner Asistanı** | DeepSeek entegrasyonlu yapay zeka sohbet — ilaç, beslenme, semptom sorularına anında yanıt |
| 📊 **Dashboard** | Tüm evcil hayvanların bugünkü ilaç durumunu tek ekranda gör |
| 🗄️ **İlaç Dolabı** | Geçmiş ve aktif tüm ilaçları listele, filtrele |
| 🔔 **Hatırlatıcılar** | UserNotifications ile her ilaç zamanı için bildirim — arka planda çalışır |
| 🌙 **Dark Mode** | Sistem genelinde otomatik karanlık mod desteği |
| ♿ **Accessibility** | Dynamic Type, VoiceOver etiketleri, yüksek kontrast |
| 🌍 **Türkçe & İngilizce** | Tam lokalizasyon (TR + EN) |
| 🔒 **Cihaz-Üstü Gizlilik** | Tüm veri SwiftData ile yerelde saklanır — sunucuya veri GİTMEZ |
| ☁️ **Yedekleme** | Cihaz içi JSON yedekleme ve geri yükleme |
| 🎨 **Apple Tasarım Dili** | HIG uyumlu, ferah, sıcak ve sevimli arayüz |
| 💳 **StoreKit 2 Abonelik** | Şeffaf fiyatlandırma, dinamik fiyat, ücretsiz deneme |

---

## 🛠 Teknoloji Yığını / Tech Stack

| Katman | Teknoloji |
|---|---|
| **Dil** | Swift 5.10+ |
| **UI Framework** | SwiftUI (native, UIKit-free) |
| **Veritabanı** | SwiftData (on-device) |
| **Bildirimler** | UserNotifications (UNUserNotificationCenter) |
| **Ödeme** | StoreKit 2 (`Product`, `Transaction`, `AppTransaction`) |
| **AI** | DeepSeek API (isteğe bağlı, kullanıcı izniyle) |
| **Minimum iOS** | iOS 18.0 |
| **Mimari** | MVVM + `@Observable` |
| **Lokalizasyon** | String Catalog (Localizable.strings) |
| **Bağımlılık** | **Sıfır** — tümü native Apple framework'leri |

---

## 📂 Proje Yapısı / Project Structure

```
Pawzy/
├── PawzyApp.swift                  # App entry, transaction listener
├── ContentView.swift               # Root view (onboarding gate)
├── OnboardingView.swift            # First-time user experience
├── MainTabView.swift               # TabBar: Dashboard, Cabinet, AI, Settings
│
├── DashboardView.swift             # Today's medication overview
├── CabinetView.swift               # Medication history & cabinet
├── AIView.swift                    # AI pet assistant chat
├── PetsListView.swift              # Pet profiles list
├── PetDetailView.swift             # Single pet detail + medications
├── SettingsView.swift              # App settings, restore, about
│
├── AddPetSheetView.swift           # Add/edit pet profile
├── AddMedicationSheetView.swift    # Add/edit medication
├── PaywallView.swift               # Premium subscription paywall
│
├── PawzyIAPManager.swift           # StoreKit 2 — ALL payment logic (Demir)
├── NotificationManager.swift       # Local notification scheduling
├── DeepSeekService.swift           # AI service integration
├── BackupManager.swift             # Local JSON backup/restore
├── DesignSystem.swift              # Color tokens, spacing, typography
├── ProgressRingView.swift          # Circular progress indicator
├── ImagePickerView.swift           # Photo picker wrapper
├── PlaceholderViews.swift          # Empty/loading/error states
├── PreviewCatalog.swift            # SwiftUI preview helpers
│
├── Pet.swift                       # SwiftData model — Pet
├── Medication.swift                # SwiftData model — Medication
├── MedicationCabinetItem.swift     # SwiftData model — Cabinet item
├── ChatMessage.swift               # SwiftData model — AI chat message
│
├── tr.lproj/Localizable.strings    # Türkçe lokalizasyon
├── en.lproj/Localizable.strings    # English localization
│
├── PrivacyPolicy.md / .pdf         # Gizlilik politikası
├── TermsOfUse.md / .pdf            # Kullanım koşulları
│
└── Assets.xcassets/                # App icon, renkler, SF Symbols
```

---

## 🚀 Kurulum / Getting Started

```bash
# 1. Repo'yu klonla
git clone https://github.com/gazihandeveloper/Pawzy.git

# 2. Pawzy.xcodeproj'u Xcode 16+ ile aç
open Pawzy/Pawzy.xcodeproj

# 3. Scheme: Pawzy, Simulator: iPhone 17 (veya üstü)
# 4. ⌘R ile çalıştır
```

> ⚠️ **Bağımlılık yok.** Sıfır CocoaPods, SPM, Carthage. Aç ve çalıştır.

---

## 🧩 Mimari Prensipler / Architecture

| Prensip | Uygulama |
|---|---|
| **Tek sorumluluk** | Her dosya tek bir domain'e hizmet eder |
| **Ödeme izolasyonu** | Tüm StoreKit kodu `PawzyIAPManager.swift`'te — UI sadece protokol üzerinden erişir |
| **Token-tabanlı tasarım** | `DesignSystem.swift` → tüm renk/spacing/font token'ları tek kaynaktan |
| **Sıfır hardcoded metin** | Kullanıcıya görünen her metin `L.string("key")` ile lokalizasyondan gelir |
| **Cihaz-üstü öncelikli** | SwiftData, UserNotifications — her şey yerelde |
| **Apple HIG %100 uyumlu** | NavigationStack, TabView — sıfır özel navigasyon |

---

## 🔒 Gizlilik / Privacy

Pawzy **hiçbir evcil hayvan sağlık verisini** sunucuya göndermez. Tüm veri SwiftData ile cihaz üstünde saklanır. AI özelliği isteğe bağlıdır ve yalnızca kullanıcı soruları anonimleştirilerek işlenir.

Detaylı gizlilik politikası: [Pawzy Privacy Policy](Pawzy/privacy.html)

---

## 📱 App Store

Pawzy, iOS 18.0+ için tasarlanmıştır:

- **Ekranlar:** iPhone (tüm modeller) ve iPad (Slide Over / Split View)
- **Diller:** Türkçe, İngilizce
- **Fiyatlandırma:** Ücretsiz (sınırlı) + Premium abonelik (StoreKit 2)

---

## 👥 Ekip / Team

| Rol | İsim |
|---|---|
| Ürün Sahibi | Mahmut Gazihan Arslan |
| UI/UX Tasarım & Lider | Zeynep |
| iOS Geliştirme | Baran |
| Tasarım Danışmanı | Arda (45 yıllık efsane) |
| Ödeme Sistemleri | Demir |
| Onboarding Uzmanı | Elif |
| Lokalizasyon | Leyla |
| Clean Code | Kerem |
| Pazarlama | Ayhan |
| Ürün Vizyoneri | Selin |

---

## 📄 Lisans / License

© 2026 Mahmut Gazihan Arslan. Tüm hakları saklıdır.

*Bu yazılım özel mülkiyettir. İzinsiz kopyalama, dağıtma veya kullanma yasaktır.*

---

<p align="center">
  <b>🐾 Pawzy — Patili dostların sağlığı için.</b><br/>
  <sub>Made with ❤️ in Türkiye</sub>
</p>
