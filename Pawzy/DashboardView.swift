//
//  DashboardView.swift
//  Pawzy
//
//  Dashboard (Bugün) Ekranı — Arda HIG vizyonuyla yeniden tasarlandı
//  SwiftData entegrasyonlu, pembe/mercan marka renkleri, temiz layout
//

import SwiftUI
import SwiftData
import StoreKit
import os

// MARK: - Logger

private let logger = Logger(subsystem: "com.pawzy.app", category: "Dashboard")

// MARK: - DashboardView

struct DashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Medication.time) private var medications: [Medication]
    @Query(sort: \Pet.name) private var pets: [Pet]

    @State private var showAddMedicationSheet: Bool = false
    @State private var showPaywall: Bool = false

    // MARK: - Daily AI Tip

    private let storeManager = IAPManager.shared

    @State private var dailyTip: String? = nil
    @State private var isTipLoading: Bool = false
    @State private var isTipExpanded: Bool = false

    private let dailyTipCacheKey = "dailyTip"
    private let dailyTipDateKey = "dailyTipDate"
    private let dailyTipLangKey = "dailyTipLang"

    // MARK: Computed

    private var completedCount: Int {
        medications.filter(\.isDone).count
    }

    private var totalCount: Int {
        medications.count
    }

    private var completionRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    /// Statik DateFormatter — header metni için
    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        f.locale = Locale(identifier: lang == "tr" ? "tr_TR" : "en_US_POSIX")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    /// Statik zaman formatter — ilaç saatleri için
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var todayHeader: String {
        let str = Self.headerDateFormatter.string(from: Date())
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let locale = Locale(identifier: lang == "tr" ? "tr_TR" : "en_US_POSIX")
        return str.capitalized(with: locale)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // 1. Header: Tarih + "Bugün" + [+] butonu
                headerSection
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.top, .pzSpaceMD)

                // 2. Progress kartı — pembe/mercan gradient
                progressCard
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.top, .pzSpaceXL)

                // 3. GÜNÜN İLACI bölümü
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader(L.string("dashboard_section_meds"))
                        .padding(.horizontal, .pzSpaceXL)

                    if medications.isEmpty {
                        emptyState
                            .padding(.horizontal, .pzSpaceXL)
                    } else {
                        timelineList
                            .padding(.horizontal, .pzSpaceXL)
                    }
                }
                .padding(.top, .pzSpaceXXL)

                // 4. GÜNÜN İPUCU bölümü
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader(L.string("dashboard_section_tip"))
                        .padding(.horizontal, .pzSpaceXL)

                    dailyTipSection
                        .padding(.horizontal, .pzSpaceXL)
                }
                .padding(.top, .pzSpaceXXL)

                // 5. Premium banner — sadece premium olmayanlara
                if !storeManager.isPremium {
                    premiumBanner
                        .padding(.horizontal, .pzSpaceXL)
                        .padding(.top, .pzSpaceLG)
                }

            }
            .padding(.bottom, 100) // Tab bar alanı
        }
        .background(Color.pzBackground)
        .onAppear { loadDailyTip() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { loadDailyTip() }
        }
        .sheet(isPresented: $showAddMedicationSheet) {
            AddMedicationSheetView(isPresented: $showAddMedicationSheet)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
        }
    }

    // MARK: - 1. Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: .pzSpaceXS) {
                Text(todayHeader)
                    .font(.pzCaptionBold)
                    .foregroundColor(.pzTextSecondary)
                    .tracking(0.5)
                    .accessibilityLabel("\(L.string("Bugün")): \(todayHeader)")

                Text(L.string("Bugün"))
                    .font(.pzTitleLarge)
                    .foregroundColor(.pzTextPrimary)
                    .tracking(-0.6)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer()

            Button {
                showAddMedicationSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.pzBlue)
                    )
            }
            .buttonStyle(.plain)
            .pzAddButtonShadow()
            .accessibilityLabel(L.string("Yeni hatırlatıcı ekle"))
            .accessibilityHint(L.string("İlaç hatırlatıcı ekleme formunu açar"))
        }
    }

    // MARK: - 2. Progress Card (Pembe/Mercan Gradient)

    private var progressCard: some View {
        HStack(spacing: .pzSpaceLG) {
            // Sol: Progress ring
            ProgressRingView(completed: completedCount, total: totalCount, size: 74)
                .accessibilityHidden(true)

            // Sağ: Metin
            VStack(alignment: .leading, spacing: .pzSpaceXS) {
                Text(L.string("Bugünün dozları"))
                    .font(.pzTitleSmall)
                    .foregroundColor(.white)

                if totalCount > 0 {
                    Text("\(completedCount) \(L.string("doz tamamlandı · harika gidiyorsun"))")
                        .font(.pzCallout)
                        .foregroundColor(.white.opacity(0.92))

                    if completionRatio > 0.5 {
                        Text(L.string("dashboard_great_job"))
                            .font(.pzCaption)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.top, 1)
                    }
                } else {
                    Text(L.string("Henüz hatırlatıcı yok"))
                        .font(.pzCallout)
                        .foregroundColor(.white.opacity(0.92))
                }
            }

            Spacer()
        }
        .padding(.pzSpaceLG)
        .background(
            RoundedRectangle(cornerRadius: .pzRadius2XL)
                .fill(LinearGradient.pzBlueGradient)
        )
        .pzShadowProgress()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            totalCount > 0
            ? "\(L.string("Bugünün dozları")), \(completedCount) \(L.string("tamamlandı")), \(totalCount) total"
            : "\(L.string("Bugünün dozları")), \(L.string("Henüz hatırlatıcı yok"))"
        )
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pzCaptionBold)
            .foregroundColor(.pzTextSecondary)
            .tracking(0.5)
            .padding(.bottom, .pzSpaceMD)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Empty State (Sıcak & davetkar)

    private var emptyState: some View {
        VStack(spacing: .pzSpaceMD) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 60))
                .foregroundColor(.pzBlue)
                .accessibilityHidden(true)

            Text(L.string("dashboard_empty_title"))
                .font(.pzBodyBold)
                .foregroundColor(.pzTextPrimary)

            Text(L.string("dashboard_empty_body"))
                .font(.pzCallout)
                .foregroundColor(.pzTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                showAddMedicationSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text(L.string("dashboard_empty_cta"))
                        .font(.pzBodyBold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .pzSpaceMD)
                .background(
                    RoundedRectangle(cornerRadius: .pzRadiusLG)
                        .fill(LinearGradient.pzBlueGradient)
                )
            }
            .buttonStyle(.plain)
            .pzShadowProgress()
            .padding(.top, .pzSpaceSM)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .pzSpaceXXL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L.string("dashboard_empty_title")). \(L.string("dashboard_empty_body"))")
    }

    // MARK: - Timeline List

    private var timelineList: some View {
        VStack(spacing: 12) {
            ForEach(Array(medications.enumerated()), id: \.element.persistentModelID) { index, medication in
                medicationCardRow(index: index, medication: medication)
            }
        }
    }

    private func medicationCardRow(index: Int, medication: Medication) -> some View {
        HStack(alignment: .top, spacing: .pzSpaceMD) {
            // Zaman etiketi
            Text(timeString(from: medication.time))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.pzTextPrimary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 17)

            // İlaç kartı
            medicationCard(medication: medication, index: index)
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            )
        )
        .animation(
            (reduceMotion ? Animation.easeInOut(duration: 0.25) : .spring(response: 0.4, dampingFraction: 0.7)).delay(Double(index) * 0.08),
            value: medications.map(\.isDone)
        )
        .onAppearWithAnimation(index: index)
    }

    @ViewBuilder
    private func medicationCard(medication: Medication, index: Int) -> some View {
        let color = Color(hex: medication.colorHex)
        let isDone = medication.isDone

        HStack(spacing: .pzSpaceMD) {
            // İkon kutusu
            RoundedRectangle(cornerRadius: .pzRadiusMD)
                .fill(color.withTintOpacity())
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: medication.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                )
                .accessibilityHidden(true)

            // İlaç bilgisi
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.pzBodyBold)
                    .foregroundColor(.pzTextPrimary)
                    .strikethrough(isDone, color: .pzTextPrimary)

                Text("\(medication.dose) · \(medication.petName)")
                    .font(.pzCaption)
                    .foregroundColor(.pzTextSecondary)

                Text(L.string(medication.category))
                    .font(.pzCaption)
                    .foregroundColor(.pzTextTertiary)
            }

            Spacer()

            // Check circle
            checkCircleView(isDone: isDone, color: color, medication: medication)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusXL)
                .fill(Color.pzSurface)
        )
        .pzShadowCardLifted()
        .opacity(isDone ? 0.55 : 1.0)
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.3), value: isDone)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(medication.name), \(medication.dose), \(medication.petName), \(timeString(from: medication.time))"
            + (isDone ? ", \(L.string("tamamlandı"))" : ", \(L.string("tamamlanmadı"))")
        )
        .accessibilityHint(isDone ? "" : L.string("Tamamlandı olarak işaretlemek için çift dokunun"))
    }

    // MARK: - Check Circle (haptic feedback'li)

    private func checkCircleView(isDone: Bool, color: Color, medication: Medication) -> some View {
        Button {
                            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.3)) {
                medication.isDone.toggle()
                do {
                    try modelContext.save()
                } catch {
                    logger.error("İlaç durumu güncelleme hatası: \(error.localizedDescription)")
                }

                // Review isteği: 3 doz tamamlandığında tetikle
                if medication.isDone {
                    let completedCount = UserDefaults.standard.integer(forKey: "totalCompletedDoses") + 1
                    UserDefaults.standard.set(completedCount, forKey: "totalCompletedDoses")

                    let hasRequested = UserDefaults.standard.bool(forKey: "hasRequestedReview")
                    if completedCount >= 3 && !hasRequested {
                        UserDefaults.standard.set(true, forKey: "hasRequestedReview")
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            AppStore.requestReview(in: scene)
                        }
                    }
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
        .sensoryFeedback(.success, trigger: medication.isDone)
        .accessibilityLabel(isDone ? L.string("Tamamlandı olarak işaretli") : L.string("Tamamlanmadı"))
        .accessibilityAddTraits(isDone ? [.isSelected] : [])
    }

    // MARK: - Daily AI Tip Section

    private var dailyTipSection: some View {
        Group {
            if storeManager.isPremium {
                if isTipLoading {
                    tipLoadingView
                } else if let tip = dailyTip {
                    tipCard(tip: tip)
                }
            } else {
                lockedTipCard
            }
        }
    }

    private var tipLoadingView: some View {
        HStack(spacing: .pzSpaceSM) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.pzBlue)
            Text(L.string("Günlük ipucu hazırlanıyor..."))
                .font(.pzCaption)
                .foregroundColor(.pzTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.pzSpaceMD)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusLG)
                .fill(Color.pzBlueLight.opacity(0.5))
        )
    }

    private func tipCard(tip: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: .pzSpaceSM) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.pzBlue)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tip)
                        .font(.pzCallout)
                        .foregroundColor(.pzTextPrimary)
                        .lineLimit(isTipExpanded ? nil : 2)
                        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.3), value: isTipExpanded)

                    if tipExceedsTwoLines(tip) {
                        Button {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.3)) {
                                isTipExpanded.toggle()
                            }
                        } label: {
                            Text(isTipExpanded ? L.string("Kapat") : L.string("Devamını oku"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.pzBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.pzSpaceMD)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusLG)
                .fill(Color.pzBlueLight.opacity(0.5))
        )
    }

    private var lockedTipCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text(L.string("Premium"))
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.pzBlue)
                )

                Spacer()
            }

            Text(L.string("Yapay zeka destekli günlük bakım ipuçları, dostunun sağlığı için kişiselleştirilmiş öneriler."))
                .font(.pzCallout)
                .foregroundColor(.pzTextPrimary)
                .lineLimit(3)
                .blur(radius: 6)
                .opacity(0.5)
        }
        .padding(.pzSpaceMD)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusLG)
                .fill(Color.pzBlueLight.opacity(0.5))
        )
        .onTapGesture {
            showPaywall = true
        }
    }

    // MARK: - Premium Banner (sayfa altı)

    private var premiumBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: .pzSpaceMD) {
                Text("👑")
                    .font(.system(size: 28))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.string("dashboard_premium_banner_title"))
                        .font(.pzBodyBold)
                        .foregroundColor(.pzTextPrimary)

                    Text(L.string("dashboard_premium_banner_body"))
                        .font(.pzCaption)
                        .foregroundColor(.pzTextSecondary)
                }

                Spacer()

                Text(L.string("dashboard_premium_banner_cta"))
                    .font(.pzCaptionBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, .pzSpaceMD)
                    .padding(.vertical, .pzSpaceSM)
                    .background(
                        RoundedRectangle(cornerRadius: .pzRadiusSM)
                            .fill(Color.pzBlue)
                    )
            }
            .padding(.pzSpaceLG)
            .background(
                RoundedRectangle(cornerRadius: .pzRadius2XL)
                    .fill(Color.pzSurface)
            )
            .pzShadowCardLifted()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L.string("dashboard_premium_banner_title")): \(L.string("dashboard_premium_banner_body"))")
        .accessibilityHint(L.string("Yükselt, Pawzy Premium'a geç"))
    }

    // MARK: - Daily AI Tip Logic

    private func loadDailyTip() {
        let defaults = UserDefaults.standard
        let currentLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"

        // Cache: 24 saat + aynı dil
        if let cachedDate = defaults.object(forKey: dailyTipDateKey) as? Date,
           let cachedTip = defaults.string(forKey: dailyTipCacheKey),
           let cachedLang = defaults.string(forKey: dailyTipLangKey),
           cachedLang == currentLang,
           Date().timeIntervalSince(cachedDate) < 24 * 3600 {
            self.dailyTip = cachedTip
            return
        }

        isTipLoading = true

        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let petDescriptions: String
        if pets.isEmpty {
            petDescriptions = lang == "tr" ? "Genel" : "General"
        } else {
            petDescriptions = pets.map { "\($0.name) (\($0.breed), \($0.age) yaş, \($0.sex))" }.joined(separator: ", ")
        }

        let prompt: String
        if lang == "tr" {
            prompt = """
            Bugün için kısa bir evcil hayvan bakım ipucu ver.
            Kullanıcının evcil hayvan(lar)ı: \(petDescriptions)

            Kurallar:
            - Maksimum 1-2 cümle olsun.
            - Samimi ve sıcak bir dil kullan.
            - Mümkünse hayvanın adını kullan.
            - Tıbbi uyarı ekleme.
            - Çok kısa ve öz ol.
            """
        } else {
            prompt = """
            Give a very short pet care tip for today.
            User's pet(s): \(petDescriptions)

            Rules:
            - Maximum 1-2 sentences.
            - Warm and friendly tone.
            - Use the pet's name if possible.
            - No medical disclaimer needed.
            - Keep it extremely concise.
            """
        }

        Task {
            do {
                let response = try await DeepSeekService.sendMessage(
                    messages: [["role": "user", "content": prompt]],
                    pet: pets.first
                )
                await MainActor.run {
                    self.dailyTip = response
                    self.isTipLoading = false

                    UserDefaults.standard.set(response, forKey: self.dailyTipCacheKey)
                    UserDefaults.standard.set(Date(), forKey: self.dailyTipDateKey)
                    UserDefaults.standard.set(currentLang, forKey: self.dailyTipLangKey)
                }
            } catch {
                logger.error("AI günlük ipucu hatası: \(error.localizedDescription)")
                await MainActor.run {
                    self.isTipLoading = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func timeString(from date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func tipExceedsTwoLines(_ text: String) -> Bool {
        text.count > 70
    }
}

// MARK: - Görünüm Animasyonu Yardımcısı

private struct OnAppearWithAnimation: ViewModifier {
    let index: Int
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 36)
            .animation(
                (reduceMotion ? Animation.easeInOut(duration: 0.25) : .spring(response: 0.4, dampingFraction: 0.7)).delay(Double(index) * 0.1),
                value: hasAppeared
            )
            .onAppear {
                hasAppeared = true
            }
    }
}

extension View {
    func onAppearWithAnimation(index: Int) -> some View {
        modifier(OnAppearWithAnimation(index: index))
    }
}

// MARK: - Preview

#Preview("Empty Dashboard") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Medication.self, Pet.self, configurations: config)
    return DashboardView()
        .modelContainer(container)
}

#Preview("Populated Dashboard") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Medication.self, Pet.self, configurations: config)
    let context = container.mainContext

    let pamuk = Pet(name: "Pamuk", breed: "Kedi", age: 3, weight: 4.2, sex: "Dişi", tintColor: "#E05A67", iconName: "cat.fill")
    context.insert(pamuk)

    var time08 = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    time08.hour = 8; time08.minute = 0
    var time12 = time08; time12.hour = 12
    var time18 = time08; time18.hour = 18
    var time21 = time08; time21.hour = 21

    let meds = [
        Medication(name: "Bravecto Plus", dose: "1 tablet", time: Calendar.current.date(from: time08)!, category: "tablet", iconName: "pill.fill", colorHex: "#FF8A65", isDone: true, petName: "Pamuk"),
        Medication(name: "Omega-3 Damla", dose: "3 damla", time: Calendar.current.date(from: time12)!, category: "damla", iconName: "drop.fill", colorHex: "#34C759", isDone: true, petName: "Pamuk"),
        Medication(name: "Vitamin Pat", dose: "2 tablet", time: Calendar.current.date(from: time18)!, category: "tablet", iconName: "circle.hexagongrid.fill", colorHex: "#E05A67", isDone: false, petName: "Pamuk"),
        Medication(name: "Göz Merhemi", dose: "1 uygulama", time: Calendar.current.date(from: time21)!, category: "merhem", iconName: "cross.case.fill", colorHex: "#AF82E8", isDone: false, petName: "Pamuk"),
    ]
    for med in meds { context.insert(med) }

    return DashboardView()
        .modelContainer(container)
}
