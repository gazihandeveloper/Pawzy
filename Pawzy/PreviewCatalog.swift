//
//  PreviewCatalog.swift
//  Pawzy
//
//  Tüm ekranların tek Preview'da toplandığı tasarım kataloğu
//  Xcode Preview Canvas'ta incelemek için
//

import SwiftUI
import SwiftData

// MARK: - Sample Data Factory

private func makeSampleContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Pet.self, Medication.self, MedicationCabinetItem.self, ChatMessage.self,
        configurations: config
    )
    let ctx = container.mainContext

    // Sample Pets
    let pamuk = Pet(
        name: "Pamuk",
        breed: "Golden Retriever",
        age: 3,
        weight: 25.0,
        sex: "Dişi",
        tintColor: "#FF8B94",
        iconName: "dog.fill"
    )
    let duman = Pet(
        name: "Duman",
        breed: "British Shorthair",
        age: 2,
        weight: 4.5,
        sex: "Erkek",
        tintColor: "#A0A0FF",
        iconName: "cat.fill"
    )
    let boncuk = Pet(
        name: "Boncuk",
        breed: "Muhabbet Kuşu",
        age: 1,
        weight: 0.04,
        sex: "Erkek",
        tintColor: "#FFD700",
        iconName: "bird.fill"
    )
    ctx.insert(pamuk)
    ctx.insert(duman)
    ctx.insert(boncuk)

    // Sample Medications
    let med1 = Medication(
        name: "Vitamin C",
        dose: "1 tablet",
        time: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
        category: "tablet",
        iconName: "pills.fill",
        colorHex: "#FF8B94",
        petName: "Pamuk"
    )
    let med2 = Medication(
        name: "Kuduz Aşısı",
        dose: "1 doz",
        time: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
        category: "aşı",
        iconName: "syringe.fill",
        colorHex: "#34C759",
        petName: "Duman"
    )
    let med3 = Medication(
        name: "Antibiyotik",
        dose: "2 damla",
        time: Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date(),
        category: "damla",
        iconName: "drop.fill",
        colorHex: "#FF453A",
        petName: "Pamuk"
    )
    ctx.insert(med1)
    ctx.insert(med2)
    ctx.insert(med3)

    // Sample Cabinet Items
    let cab1 = MedicationCabinetItem(
        name: "Antibiyotik",
        category: "tablet",
        iconName: "cross.case.fill",
        colorHex: "#FF453A",
        stock: 2,
        stockLabel: "2 tablet",
        isLowStock: true
    )
    let cab2 = MedicationCabinetItem(
        name: "Vitamin D",
        category: "damla",
        iconName: "drop.fill",
        colorHex: "#FFD700",
        stock: 5,
        stockLabel: "5 ml",
        isLowStock: false
    )
    ctx.insert(cab1)
    ctx.insert(cab2)

    // Sample Chat
    let chat1 = ChatMessage(role: "user", content: "Pamuk'un vitamin saatini unuttum mu?", petName: "Pamuk")
    let chat2 = ChatMessage(role: "assistant", content: "Hayır, Vitamin C 14:30'da alındı. Sıradaki Antibiyotik 20:00'da.", petName: nil)
    ctx.insert(chat1)
    ctx.insert(chat2)

    return container
}

// MARK: - Helper: Screen Card Wrapper

private struct ScreenCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            Text(title)
                .font(.pzTitleSmall)
                .foregroundColor(.pzTextPrimary)
                .padding(.horizontal, .pzSpaceLG)

            content()
                .clipShape(RoundedRectangle(cornerRadius: .pzRadiusXL))
                .overlay(
                    RoundedRectangle(cornerRadius: .pzRadiusXL)
                        .stroke(Color.pzBorderLight, lineWidth: 1)
                )
                .padding(.horizontal, .pzSpaceLG)
        }
        .padding(.bottom, .pzSpaceXL)
    }
}

// MARK: - Preview Catalog View

struct PreviewCatalogView: View {
    @State private var showPaywall = false
    @State private var showAddPet = false
    @State private var showAddMed = false

    private let container = makeSampleContainer()
    private let samplePet: Pet

    init() {
        let ctx = container.mainContext
        let fetch = FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)])
        let pets = (try? ctx.fetch(fetch)) ?? []
        samplePet = pets.first!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Page Header
                pageHeader
                    .padding(.bottom, .pzSpaceXL)

                // 1. Onboarding
                ScreenCard(title: "1. Onboarding — 3 aşamalı karşılama") {
                    OnboardingView()
                        .modelContext(container.mainContext)
                        .frame(height: 700)
                }

                // 2. Dashboard (Bugün)
                ScreenCard(title: "2. Dashboard — Bugün sekmesi") {
                    DashboardView()
                        .modelContainer(container)
                        .frame(height: 700)
                }

                // 3. Pets List (Patilerim)
                ScreenCard(title: "3. Patilerim — Evcil hayvan listesi") {
                    PetsListView()
                        .modelContainer(container)
                        .frame(height: 700)
                }

                // 4. Pet Detail
                ScreenCard(title: "4. Pet Detay — \(samplePet.name)") {
                    PetDetailView(pet: samplePet)
                        .modelContainer(container)
                        .frame(height: 700)
                }

                // 5. Cabinet (Dolap)
                ScreenCard(title: "5. Dolap — İlaç stoğu") {
                    CabinetView()
                        .modelContainer(container)
                        .frame(height: 700)
                }

                // 6. AI Chat
                ScreenCard(title: "6. Pawzy AI — Sohbet asistanı") {
                    AIView()
                        .modelContainer(container)
                        .frame(height: 700)
                }

                // 7. Settings (Ayarlar)
                ScreenCard(title: "7. Ayarlar — Yeni tasarım") {
                    SettingsView()
                        .modelContainer(container)
                        .frame(height: 700)
                }

                // 8. Paywall
                ScreenCard(title: "8. Paywall — Premium satın alma") {
                    PaywallView(isPresented: .constant(true), storeManager: .shared)
                        .frame(height: 700)
                }

                // 9. Add Pet Sheet
                ScreenCard(title: "9. Pati Ekle — Form sheet") {
                    AddPetSheetView(isPresented: .constant(true))
                        .modelContainer(container)
                        .frame(height: 700)
                }

                // 10. Add Medication Sheet
                ScreenCard(title: "10. Hatırlatıcı Ekle — Form sheet") {
                    AddMedicationSheetView(isPresented: .constant(true))
                        .modelContainer(container)
                        .frame(height: 700)
                }

                // 11. Main TabView (tüm sekmeler bir arada)
                ScreenCard(title: "11. Main TabView — 5 sekme") {
                    MainTabView()
                        .modelContainer(container)
                        .frame(height: 750)
                }

                // Footer
                VStack(spacing: .pzSpaceXS) {
                    Text("Pawzy Tasarım Kataloğu")
                        .font(.pzCaptionBold)
                        .foregroundColor(.pzTextSecondary)
                    Text("Toplam 11 ekran · iOS 17+ · SwiftUI · SwiftData")
                        .font(.pzCaption)
                        .foregroundColor(.pzTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, .pzSpaceXXL)
            }
        }
        .background(Color.pzBackground)
        .ignoresSafeArea(edges: .bottom)
    }

    private var pageHeader: some View {
        VStack(spacing: 4) {
            Text("Pawzy")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.pzBlue)
            Text("Tüm Ekranlar")
                .font(.pzTitleLarge)
                .foregroundColor(.pzTextPrimary)
                .tracking(-0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Previews

#Preview("PreviewCatalog — Light Mode") {
    PreviewCatalogView()
}

#Preview("PreviewCatalog — Dark Mode") {
    PreviewCatalogView()
        .preferredColorScheme(.dark)
}
