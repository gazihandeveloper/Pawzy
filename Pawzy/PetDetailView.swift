//
//  PetDetailView.swift
//  Pawzy
//
//  Pet Detay Ekranı — Header, bilgi kartları, ilaç listesi, premium banner
//

import SwiftUI
import SwiftData
import PhotosUI
import os

// MARK: - Logger

private let logger = Logger(subsystem: "com.pawzy.app", category: "PetDetail")

// MARK: - Cached Nutrition Advice

struct CachedAdvice: Codable {
    let advice: String
    let cachedDate: Date
}

// MARK: - PetDetailView

struct PetDetailView: View {

    let pet: Pet

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Medication.time) private var allMedications: [Medication]

    // MARK: StoreManager

    private var storeManager = IAPManager.shared
    @State private var showPaywall: Bool = false

    // MARK: Photo Picker State

    @State private var tempPhotoData: Data? = nil
    @State private var showPhotoSourceDialog: Bool = false
    @State private var showCamera: Bool = false
    @State private var showGallery: Bool = false
    @State private var showFullScreenPhoto: Bool = false

    // MARK: Edit Pet State

    @State private var showEditPet: Bool = false

    // MARK: AI Nutrition State (otomatik yükleme + 2 hafta cache)

    private var nutritionCacheKey: String { "nutritionAdvice_\(pet.name)" }
    private var nutritionCacheLangKey: String { "nutritionAdviceLang_\(pet.name)" }
    @State private var cachedAdvice: String? = nil
    @State private var isLoadingAdvice: Bool = false
    @State private var cachedPhoto: UIImage? = nil

    init(pet: Pet) {
        self.pet = pet
    }

    // MARK: Computed

    private var petMedications: [Medication] {
        allMedications.filter { $0.petName == pet.name }
    }

    private var petColor: Color {
        Color(hex: pet.tintColor)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: .pzSpaceXL) {

                // Header
                headerSection
                    .padding(.top, .pzSpaceMD)

                // Bilgi Kartları (3'lü)
                infoCards

                // Günlük Beslenme Özeti + AI
                dailyNutritionSection

                // İlaçları
                medicationsSection

                // Premium Banner — sadece ne premium ne de free mode olan kullanıcılara göster
                if !storeManager.isPremium && !storeManager.isFreeMode {
                    premiumBanner
                }

                // NRC Hesaplama (en alt)
                nutritionDetailSection
            }
            .padding(.horizontal, .pzSpaceXL)
            .padding(.bottom, 100) // Tab bar alanı
        }
        .background(Color.pzBackground)
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEditPet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.pzBlue)
                }
                .accessibilityLabel(L.string("Düzenle"))
            }
        }
        .onAppear {
            loadCachedAdvice()
            if let photoData = pet.photo {
                cachedPhoto = UIImage(data: photoData)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall, storeManager: storeManager)
        }
        .confirmationDialog(L.string("Fotoğraf Ekle"), isPresented: $showPhotoSourceDialog) {
            Button(L.string("Kamera")) {
                showCamera = true
            }
            Button(L.string("Galeri")) {
                showGallery = true
            }
            Button(L.string("İptal"), role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(imageData: $tempPhotoData)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showGallery) {
            PhotoPicker(imageData: $tempPhotoData)
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            if let uiImage = cachedPhoto {
                FullScreenPhotoView(image: uiImage)
            }
        }
        .sheet(isPresented: $showEditPet) {
            AddPetSheetView(isPresented: $showEditPet, editingPet: pet)
        }
        .onChange(of: tempPhotoData) { _, newValue in
            if let data = newValue {
                pet.photo = data
                cachedPhoto = UIImage(data: data)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: .pzSpaceMD) {
            // Avatar + Kamera butonu
            ZStack(alignment: .bottomTrailing) {
                // Avatar: 100×100, pet tint renginde bg, pet ikonu — veya fotoğraf
                if let uiImage = cachedPhoto {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .onTapGesture {
                            showFullScreenPhoto = true
                        }
                } else {
                    Circle()
                        .fill(petColor)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: pet.iconName)
                                .font(.system(size: 42))
                                .foregroundColor(.white)
                        )
                }

                // Kamera butonu (sağ alt köşede)
                Button {
                    showPhotoSourceDialog = true
                } label: {
                    Circle()
                        .fill(Color.pzBlue)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.string("Fotoğrafı değiştir"))
            }
            .frame(width: 110, height: 110)

            VStack(spacing: .pzSpaceXS) {
                Text(pet.name)
                    .font(.pzTitleLarge)
                    .foregroundColor(.pzTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: .pzSpaceXS) {
                    Text(L.string(pet.breed))
                    Text("·")
                    Text("\(pet.age) \(L.string("yaş"))")
                }
                .font(.pzCallout)
                .foregroundColor(.pzTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pet.name), \(L.string(pet.breed)), \(pet.age) \(L.string("yaşında"))")
    }

    // MARK: - Bilgi Kartları (3'lü HStack)

    private var infoCards: some View {
        HStack(spacing: .pzSpaceMD) {
            infoCard(
                iconName: "birthday.cake.fill",
                iconColor: .pzCoral,
                value: "\(pet.age)",
                label: L.string("Yaş")
            )

            infoCard(
                iconName: "scalemass.fill",
                iconColor: .pzTeal,
                value: formattedWeightValue(pet.weight),
                label: formattedWeightUnit()
            )

            infoCard(
                iconName: pet.sex == "Dişi" ? "f.square.fill" : "m.square.fill",
                iconColor: .pzPurple,
                value: L.string(pet.sex),
                label: L.string("Cinsiyet")
            )
        }
    }

    private func formattedWeightValue(_ kg: Double) -> String {
        let isImperial = Locale.current.measurementSystem == .us
        if isImperial {
            let totalOz = kg * 35.274
            let lbs = Int(totalOz / 16)
            let oz = Int(totalOz.truncatingRemainder(dividingBy: 16))
            if lbs > 0 {
                return "\(lbs).\(oz)"
            } else {
                return String(format: "%g", totalOz)
            }
        } else {
            return String(format: "%g", kg)
        }
    }

    private func formattedWeightUnit() -> String {
        Locale.current.measurementSystem == .us ? "lb" : "kg"
    }

    /// Bireysel bilgi kartı: ikon + değer + label
    private func infoCard(
        iconName: String,
        iconColor: Color,
        value: String,
        label: String
    ) -> some View {
        VStack(spacing: .pzSpaceXS) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
                .frame(height: 26)

            Text(value)
                .font(.pzHeadline)
                .foregroundColor(.pzTextPrimary)

            Text(label)
                .font(.pzCaption)
                .foregroundColor(.pzTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .pzSpaceLG)
        .padding(.horizontal, .pzSpaceSM)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusLG)
                .fill(Color.pzSurface)
        )
        .pzShadowCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - İlaçları Section

    private var medicationsSection: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            Text(L.string("İlaçları"))
                .font(.pzCaptionBold)
                .foregroundColor(.pzTextSecondary)
                .tracking(0.5)
                .accessibilityAddTraits(.isHeader)

            if petMedications.isEmpty {
                emptyMedsState
            } else {
                VStack(spacing: .pzSpaceMD) {
                    ForEach(petMedications) { medication in
                        medicationCard(medication)
                    }
                }
            }
        }
    }

    private var emptyMedsState: some View {
        VStack(spacing: .pzSpaceSM) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 28))
                .foregroundColor(.pzTextQuaternary)
                .accessibilityHidden(true)

            Text(L.string("Henüz ilaç eklenmemiş"))
                .font(.pzCallout)
                .foregroundColor(.pzTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .pzSpaceXL)
    }

    /// Dashboard'daki ilaç kartı stilinde
    private func medicationCard(_ medication: Medication) -> some View {
        let color = Color(hex: medication.colorHex)
        let isDone = medication.isDone

        return HStack(spacing: .pzSpaceMD) {

            // Sol: İkon kutusu
            RoundedRectangle(cornerRadius: .pzRadiusMD)
                .fill(color.withTintOpacity())
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: medication.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                )
                .accessibilityHidden(true)

            // Orta: İlaç adı + dozaj
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.pzBodyBold)
                    .foregroundColor(.pzTextPrimary)
                    .strikethrough(isDone, color: .pzTextPrimary)

                HStack(spacing: .pzSpaceXS) {
                    Text(timeString(from: medication.time))
                        .font(.pzCaption)
                        .foregroundColor(.pzTextTertiary)

                    Text("·")
                        .font(.pzCaption)
                        .foregroundColor(.pzTextQuaternary)

                    Text(medication.dose)
                        .font(.pzCaption)
                        .foregroundColor(.pzTextSecondary)
                }
            }

            Spacer()

            // Check circle
            checkCircleView(isDone: isDone, color: color, medication: medication)
        }
        .padding(.pzSpaceMD)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusXL)
                .fill(Color.pzSurface)
        )
        .pzShadowCardLifted()
        .opacity(isDone ? 0.55 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.name), \(medication.dose), \(timeString(from: medication.time))\(isDone ? ", \(L.string("tamamlandı"))" : ", \(L.string("tamamlanmadı"))")")
    }

    // MARK: - Check Circle

    private func checkCircleView(isDone: Bool, color: Color, medication: Medication) -> some View {
        Button {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.3)) {
                medication.isDone.toggle()
                do {
                    try modelContext.save()
                } catch {
                    logger.error("İlaç durumu güncelleme hatası: \(error.localizedDescription)")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isDone ? color : Color.pzSurface)
                    .frame(width: 30, height: 30)

                Circle()
                    .stroke(isDone ? color : Color.pzTextQuaternary, lineWidth: 2)
                    .frame(width: 30, height: 30)

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.clear)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? L.string("Tamamlandı olarak işaretli") : L.string("Tamamlanmadı"))
    }

    // MARK: - Premium Banner

    private var premiumBanner: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)

                Text(L.string("Pawzy Premium"))
                    .font(.pzHeadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(L.string("Detaylı sağlık raporları için Premium'a yükselt"))
                .font(.pzCallout)
                .foregroundColor(.white.opacity(0.95))

            // Yükselt butonu
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 6) {
                    Text(L.string("Yükselt"))
                        .font(.system(size: 15, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.pzBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.string("Yükselt, Pawzy Premium'a geç"))
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.pzBlue, Color.pzTeal]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .pzShadowPremium()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(L.string("Pawzy Premium")), \(L.string("Detaylı sağlık raporları için Premium'a yükselt"))")
    }

    // MARK: - Helpers

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func timeString(from date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    // MARK: - Beslenme Hesaplama

    /// RER = 70 * (weight)^0.75
    private func calculateRER() -> Double {
        70 * pow(pet.weight, 0.75)
    }

    /// MER = RER × k (aktivite faktörü)
    private func calculateMER() -> Double {
        calculateRER() * activityFactor()
    }

    /// Aktivite faktörü (k): yaş + activity level'e göre
    private func activityFactor() -> Double {
        // Yaş kontrolü: < 1 yaş = yavru
        if pet.age < 1 {
            return 2.5
        }
        // Yaşlı: > 7 yaş
        let ageMultiplier: Double = pet.age > 7 ? 0.8 : 1.0

        // Activity level baz faktör
        let baseFactor: Double
        switch pet.activityLevel {
        case "low":
            baseFactor = 1.3
        case "normal":
            baseFactor = 1.6
        case "high":
            baseFactor = 2.5
        default:
            baseFactor = 1.6
        }

        return baseFactor * ageMultiplier
    }

    /// Günlük mama miktarı (gram) — NRC formülüne göre, varsayılan 380 kcal/100g mama yoğunluğu ile
    private func calculateDailyFood(caloriesPer100g: Double = 380) -> Double {
        let mer = calculateMER()
        guard caloriesPer100g > 0 else { return 0 }
        return (mer / caloriesPer100g) * 100
    }

    // MARK: - Günlük Beslenme Özeti Section (üstte)

    private var dailyNutritionSection: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            sectionHeader(L.string("GÜNLÜK BESLENME ÖZETİ"))

            VStack(spacing: .pzSpaceMD) {
                nutritionSummaryCard

                // AI Önerisi (premium'da DeepSeek, değilse locked placeholder)
                if storeManager.isPremium || storeManager.isFreeMode {
                    aiAdviceSection
                } else {
                    lockedNutritionAdvice
                }
            }
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusXL)
                    .fill(Color.pzSurface)
            )
            .pzShadowCard()
        }
    }

    // MARK: - Kilitli Beslenme Önerisi (Premium olmayana)

    private var lockedNutritionAdvice: some View {
        VStack(spacing: .pzSpaceSM) {
            HStack(spacing: .pzSpaceSM) {
                Image(systemName: "sparkles")
                    .foregroundColor(.pzBlue)
                Text(L.string("Yapay zekadan beslenme önerisi al"))
                    .font(.pzCallout)
                    .foregroundColor(.pzTextSecondary)
                Spacer()
                Button {
                    showPaywall = true
                } label: {
                    Text(L.string("Premium"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.pzBlue)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, .pzSpaceMD)
            .padding(.bottom, .pzSpaceMD)
        }
    }

    // MARK: - Beslenme Hesaplama Section (en altta)

    private var nutritionDetailSection: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            sectionHeader(L.string("BESLENME HESAPLAMA"))

            VStack(spacing: .pzSpaceMD) {
                nutritionDetailCard

                Text(L.string("NRC formülü (RER = 70 × kg^0.75), 380 kcal/100g varsayılan mama yoğunluğudur. Gerçek değerler için mama etiketine bakınız. Bu bilgiler tıbbi tavsiye niteliği taşımaz, öneri amaçlıdır. Kesin beslenme programı için veteriner hekiminize danışınız."))
                    .font(.pzCaption)
                    .foregroundColor(.pzTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, .pzSpaceXS)
            }
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusXL)
                    .fill(Color.pzSurface)
            )
            .pzShadowCard()
        }
    }

    // MARK: AI Advice Section (otomatik)

    @ViewBuilder
    private var aiAdviceSection: some View {
        if isLoadingAdvice {
            VStack(spacing: .pzSpaceSM) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.pzBlue)
                Text(L.string("Yükleniyor..."))
                    .font(.pzCallout)
                    .foregroundColor(.pzTextSecondary)
            }
            .padding(.vertical, .pzSpaceMD)
        } else if let advice = cachedAdvice {
            VStack(alignment: .leading, spacing: .pzSpaceSM) {
                Text(L.string("AI Önerisi"))
                    .font(.pzCaptionBold)
                    .foregroundColor(.pzTextSecondary)

                Text(advice)
                    .font(.pzCallout)
                    .foregroundColor(.pzTextPrimary)
                    .padding(.pzSpaceSM)
                    .background(
                        RoundedRectangle(cornerRadius: .pzRadiusLG)
                            .fill(Color.pzChipBackground)
                    )
                    .pzShadowCard()
            }
            .padding(.horizontal, .pzSpaceMD)
            .padding(.bottom, .pzSpaceMD)
        }
    }

    // MARK: Nutrition Summary Card

    private var nutritionSummaryCard: some View {
        let rer = calculateRER()
        let mer = calculateMER()
        let dailyFood = calculateDailyFood()

        return VStack(spacing: .pzSpaceSM) {
            // Başlık
            HStack {
                Image(systemName: "fork.knife")
                    .font(.system(size: 16))
                    .foregroundColor(.pzCoral)
                Text(L.string("Günlük Beslenme Özeti"))
                    .font(.pzBodyBold)
                    .foregroundColor(.pzTextPrimary)
                Spacer()
            }

            Divider()
                .background(Color.pzSeparator)

            // RER + MER tek satır
            HStack(spacing: 0) {
                nutritionStat(label: L.string("Bazal Kalori (RER)"), value: String(format: "%.0f", rer), unit: L.string("kcal"))
                Spacer()
                nutritionStat(label: L.string("Günlük Kalori (MER)"), value: String(format: "%.0f", mer), unit: L.string("kcal"))
            }

            Divider()
                .background(Color.pzSeparator)

            // Mama miktarı
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.pzTeal)
                Text(L.string("Önerilen günlük mama"))
                    .font(.pzCallout)
                    .foregroundColor(.pzTextSecondary)
                Spacer()
                Text(String(format: "%.0f", dailyFood))
                    .font(.pzTitleMedium)
                    .foregroundColor(.pzTextPrimary)
                Text(L.string("gram"))
                    .font(.pzCaption)
                    .foregroundColor(.pzTextSecondary)
                    .padding(.leading, 2)
            }
        }
        .padding(.pzSpaceMD)
    }

    private func nutritionStat(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.pzTitleSmall)
                .foregroundColor(.pzTextPrimary)
            Text(label)
                .font(.pzCaption)
                .foregroundColor(.pzTextSecondary)
                .multilineTextAlignment(.center)
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.pzTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }

    // MARK: Nutrition Detail Card

    private var nutritionDetailCard: some View {
        VStack(spacing: .pzSpaceSM) {
            // Aktivite faktörü satırı
            HStack {
                Text(L.string("Aktivite Faktörü (k)"))
                    .font(.pzCallout)
                    .foregroundColor(.pzTextSecondary)
                Spacer()
                Text(String(format: "%.1f", activityFactor()))
                    .font(.pzHeadline)
                    .foregroundColor(.pzBlue)
            }

            // Activity level göster
            HStack {
                Text(L.string("Hareketlilik Seviyesi"))
                    .font(.pzCallout)
                    .foregroundColor(.pzTextSecondary)
                Spacer()
                Text(activityLabel(for: pet.activityLevel))
                    .font(.pzCallout)
                    .foregroundColor(.pzTextPrimary)
            }

            // Yaş durumu
            HStack {
                Text(L.string("Yaş Durumu"))
                    .font(.pzCallout)
                    .foregroundColor(.pzTextSecondary)
                Spacer()
                Text(ageStatusLabel())
                    .font(.pzCallout)
                    .foregroundColor(.pzTextPrimary)
            }
        }
        .padding(.horizontal, .pzSpaceMD)
        .padding(.bottom, .pzSpaceMD)
    }

    private func activityLabel(for level: String) -> String {
        switch level {
        case "low": return L.string("Hareketsiz / Kısırlaştırılmış")
        case "normal": return L.string("Normal")
        case "high": return L.string("Çok Aktif / Yavru")
        default: return L.string("Normal")
        }
    }

    private func ageStatusLabel() -> String {
        if pet.age < 1 { return L.string("Yavru (büyüme dönemi)") }
        if pet.age > 7 { return L.string("Yetişkin / Yaşlı") }
        return L.string("Yetişkin")
    }

    // MARK: AI Cache + Otomatik Yükleme

    /// Cache'i kontrol et, 2 haftadan eskiyse veya dil değişmişse yeni öneri al
    private func loadCachedAdvice() {
        let defaults = UserDefaults.standard
        let currentLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"

        if let cachedData = defaults.data(forKey: nutritionCacheKey),
           let cached = try? JSONDecoder().decode(CachedAdvice.self, from: cachedData),
           let cachedLang = defaults.string(forKey: nutritionCacheLangKey),
           cachedLang == currentLang,
           Date().timeIntervalSince(cached.cachedDate) < 14 * 24 * 3600 {
            self.cachedAdvice = cached.advice
            return
        }

        // Cache yok, süresi dolmuş veya dil değişmiş → yeni öneri al
        fetchNutritionAdvice()
    }

    /// DeepSeek'ten beslenme önerisi al ve cache'e kaydet
    private func fetchNutritionAdvice() {
        isLoadingAdvice = true

        let rer = calculateRER()
        let mer = calculateMER()
        let dailyFood = calculateDailyFood()

        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let isEnglish = lang != "tr"

        let prompt: String
        if isEnglish {
            prompt = """
            I need a nutrition recommendation for the user's pet.

            Pet Information:
            - Name: \(pet.name)
            - Species/Breed: \(pet.breed)
            - Age: \(pet.age)
            - Weight: \(pet.weight) kg
            - Gender: \(pet.sex)
            - Activity Level: \(activityLabel(for: pet.activityLevel))

            Calculated Values:
            - Basal Energy (RER): \(String(format: "%.0f", rer)) kcal
            - Daily Energy (MER): \(String(format: "%.0f", mer)) kcal
            - Activity Factor (k): \(String(format: "%.1f", activityFactor()))
            - Recommended Daily Food: \(String(format: "%.0f", dailyFood)) grams (based on 380 kcal/100g food)

            Provide brief, concise advice on:
            1. Is the daily calorie intake adequate for this pet?
            2. Food selection recommendations (fat/protein ratio)
            3. Any special considerations (age, weight, activity)
            4. Are additional supplements needed?

            At the end of your response, add: "This information is not medical advice, for informational purposes only. Consult your veterinarian for a definitive nutrition plan."
            """
        } else {
            prompt = """
            Kullanıcının evcil hayvanı için beslenme önerisi istiyorum.

            Hayvan Bilgileri:
            - İsim: \(pet.name)
            - Tür/Irk: \(pet.breed)
            - Yaş: \(pet.age)
            - Kilo: \(pet.weight) kg
            - Cinsiyet: \(pet.sex)
            - Hareketlilik: \(activityLabel(for: pet.activityLevel))

            Hesaplanan Değerler:
            - Bazal Enerji (RER): \(String(format: "%.0f", rer)) kcal
            - Günlük Enerji (MER): \(String(format: "%.0f", mer)) kcal
            - Aktivite Faktörü (k): \(String(format: "%.1f", activityFactor()))
            - Önerilen Günlük Mama Miktarı: \(String(format: "%.0f", dailyFood)) gram (380 kcal/100g mama baz alınarak)

            Kullanıcıya şu konularda kısa ve öz önerilerde bulun:
            1. Bu hayvan için günlük kalori ihtiyacı yeterli mi?
            2. Mama seçimi için öneriler (yağ/protein oranı)
            3. Varsa özel durumlar (yaş, kilo, aktivite)
            4. Ek besin takviyesi gerekli mi?

            Yanıtının sonuna şu notu ekle: "Bu bilgiler tıbbi tavsiye niteliği taşımaz, öneri amaçlıdır. Kesin beslenme programı için veteriner hekiminize danışınız."
            """
        }

        Task {
            do {
                let response = try await DeepSeekService.sendMessage(
                    messages: [["role": "user", "content": prompt]],
                    pet: pet
                )
                await MainActor.run {
                    self.cachedAdvice = response
                    self.isLoadingAdvice = false

                    // Cache'e kaydet
                    let cached = CachedAdvice(advice: response, cachedDate: Date())
                    if let data = try? JSONEncoder().encode(cached) {
                        UserDefaults.standard.set(data, forKey: nutritionCacheKey)
                        UserDefaults.standard.set(lang, forKey: nutritionCacheLangKey)
                    }
                }
            } catch {
                logger.error("AI beslenme tavsiyesi hatası: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingAdvice = false
                    // Hata durumunda sessizce başarısız ol
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pzCaptionBold)
            .foregroundColor(.pzTextSecondary)
            .tracking(0.5)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Preview

#Preview("PetDetail — Populated") {
    PopulatedPetDetailPreview()
}

private struct PopulatedPetDetailPreview: View {
    let container: ModelContainer
    let pet: Pet

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Pet.self, Medication.self, configurations: config)
        self.container = container
        let context = container.mainContext

        let pamuk = Pet(
            name: "Pamuk",
            breed: "British Shorthair",
            age: 3,
            weight: 4.2,
            sex: "Dişi",
            tintColor: "#E05A67",
            iconName: "cat.fill",
            activityLevel: "high"
        )
        context.insert(pamuk)
        self.pet = pamuk

        var time08 = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        time08.hour = 8; time08.minute = 0
        let med = Medication(
            name: "Bravecto Plus",
            dose: "1 tablet",
            time: Calendar.current.date(from: time08) ?? Date(),
            category: "tablet",
            iconName: "pill.fill",
            colorHex: "#FF8A65",
            isDone: false,
            petName: "Pamuk"
        )
        context.insert(med)
    }

    var body: some View {
        NavigationStack {
            PetDetailView(pet: pet)
        }
        .modelContainer(container)
    }
}

#Preview("PetDetail — Empty Meds") {
    EmptyPetDetailPreview()
}

private struct EmptyPetDetailPreview: View {
    let container: ModelContainer
    let pet: Pet

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Pet.self, Medication.self, configurations: config)
        self.container = container

        let zeytin = Pet(
            name: "Zeytin",
            breed: "Tekir",
            age: 1,
            weight: 2.8,
            sex: "Erkek",
            tintColor: "#34C759",
            iconName: "cat.fill",
            activityLevel: "low"
        )
        self.pet = zeytin
    }

    var body: some View {
        NavigationStack {
            PetDetailView(pet: pet)
        }
        .modelContainer(container)
    }
}
