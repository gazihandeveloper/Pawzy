//
//  PetsListView.swift
//  Pawzy
//
//  Patilerim Ekranı — SwiftData + Pet Kartları tam implementasyon
//

import SwiftUI
import SwiftData

// MARK: - PetsListView

struct PetsListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Pet.name) private var pets: [Pet]

    @State private var showAddPetSheet: Bool = false
    @State private var showAddMedSheet: Bool = false
    @State private var selectedPetForMed: Pet? = nil
    @State private var showFullScreenPhoto: Bool = false
    @State private var fullScreenPhotoImage: UIImage? = nil
    @State private var showPaywall: Bool = false
    @State private var showAIView: Bool = false
    @State private var aiPetName: String = ""

    private let storeManager = IAPManager.shared

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                if pets.isEmpty {
                    emptyState
                } else {
                    populatedContent
                }
            }
            .background(Color.pzBackground)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showAIView) {
                AIView(preselectedPetName: aiPetName)
            }
        }
        .sheet(isPresented: $showAddPetSheet) {
            AddPetSheetView(isPresented: $showAddPetSheet)
        }
        .sheet(isPresented: $showAddMedSheet) {
            if let pet = selectedPetForMed {
                AddMedicationSheetView(isPresented: $showAddMedSheet, preselectedPet: pet)
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            if let image = fullScreenPhotoImage {
                FullScreenPhotoView(image: image)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
        }
    }

    // MARK: - Populated Content

    private var populatedContent: some View {
        ScrollView {
            VStack(spacing: 0) {

                // a) Header
                headerSection
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.top, .pzSpaceMD)

                // b) Pet Kartları
                petsList
                    .padding(.top, .pzSpaceXL)

                // c) Yeni Pati Ekle
                addPetButton
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.top, .pzSpaceXL)
                    .padding(.bottom, 100) // Tab bar alanı
            }
        }
        .background(Color.pzBackground)
    }

    // MARK: - a) Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 0) {
            // Sol: Başlık + Alt açıklama
            VStack(alignment: .leading, spacing: .pzSpaceXS) {
                Text(L.string("Patilerim"))
                    .font(.pzTitleLarge)
                    .foregroundColor(.pzTextPrimary)
                    .tracking(-0.6)
                    .accessibilityAddTraits(.isHeader)

                Text("\(pets.count) \(L.string("sevimli dostun"))")
                    .font(.pzCallout)
                    .foregroundColor(.pzTextSecondary)
                    .accessibilityLabel("\(pets.count) \(L.string("sevimli dostun")) var")
            }

            Spacer()

            // Sağ: + butonu
            addPetFloatingButton
        }
    }

    /// 38×38 yuvarlak mavi buton — shadow: 0 6px 14px -4px rgba(10,132,255,0.6)
    private var addPetFloatingButton: some View {
        Button {
            if storeManager.isPremium || pets.count < 1 {
                showAddPetSheet = true
            } else {
                showPaywall = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.pzBlue)
                )
        }
        .buttonStyle(.plain)
        .pzAddButtonShadow()
        .accessibilityLabel(L.string("Yeni pati ekle"))
        .accessibilityHint(L.string("Evcil hayvan ekleme formunu açar"))
    }

    // MARK: - b) Pet Kartları

    private var petsList: some View {
        LazyVStack(spacing: .pzSpaceMD) {
            ForEach(pets) { pet in
                petCardNavigation(for: pet)
                    .padding(.horizontal, .pzSpaceXL)
            }
        }
    }

    @ViewBuilder
    private func petCardNavigation(for pet: Pet) -> some View {
        NavigationLink(destination: PetDetailView(pet: pet)) {
            petCardView(pet: pet)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                selectedPetForMed = pet
                showAddMedSheet = true
            } label: {
                Label(L.string("İlaç Ekle"), systemImage: "pill.fill")
            }
            .tint(.pzBlue)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .default) {
                    modelContext.delete(pet)
                    try? modelContext.save()
                }
            } label: {
                Label(L.string("Sil"), systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                selectedPetForMed = pet
                showAddMedSheet = true
            } label: {
                Label(L.string("İlaç Ekle"), systemImage: "pill.fill")
            }
            Button(role: .destructive) {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .default) {
                    modelContext.delete(pet)
                    try? modelContext.save()
                }
            } label: {
                Label(L.string("Sil"), systemImage: "trash")
            }
            .accessibilityLabel("\(pet.name) sil")
        }
        .accessibilityHint("\(pet.name) \(L.string("detaylarına gitmek için çift dokunun"))")
    }

    /// PetCard — Design System 6b anatomisi
    private func petCardView(pet: Pet) -> some View {
        let tintColor = Color(hex: pet.tintColor)

        return HStack(spacing: .pzSpaceMD) {

            // Sol: 66×66 yuvarlak avatar
            avatarView(pet: pet, tintColor: tintColor)

            // Orta: İsim, ırk, chip'ler
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.pzTitleMedium)
                    .foregroundColor(.pzTextPrimary)

                Text(L.string(pet.breed))
                    .font(.pzCaption)
                    .foregroundColor(.pzTextSecondary)

                // Chip'ler (HStack, 6pt gap) — sadece yaş, kilo ve AI badge
                HStack(spacing: 6) {
                    // Yaş chip
                    chipView(
                        iconName: "birthday.cake.fill",
                        iconColor: .pzCoral,
                        label: "\(pet.age) \(L.string("yaş"))"
                    )

                    // Kilo chip
                    chipView(
                        iconName: "scalemass.fill",
                        iconColor: .pzTeal,
                        label: formattedWeight(pet.weight)
                    )

                    // Cinsiyet chip
                    chipView(
                        iconName: pet.sex == "Dişi" ? "female" : "male",
                        iconColor: .pzPurple,
                        label: L.string(pet.sex)
                    )

                    // AI Badge — tıklanınca o pet için AI sohbetini açar
                    Button {
                        aiPetName = pet.name
                        showAIView = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "brain")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.pzBlue)
                            Text(L.string("AI"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.pzBlue)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.pzBlue.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // En sağ: chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 18))
                .foregroundColor(.pzTextQuaternary)
                .accessibilityHidden(true)
        }
        .padding(.pzSpaceLG) // 16pt padding
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusXL) // 20pt
                .fill(Color.pzSurface)
        )
        .pzShadowCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(pet.name), \(L.string(pet.breed)), \(pet.age) \(L.string("yaşında")), \(String(format: "%g", pet.weight)) \(L.string("kg"))"
        )
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatarView(pet: Pet, tintColor: Color) -> some View {
        if let photoData = pet.photo, let uiImage = UIImage(data: photoData) {
            let resized = uiImage.preparingThumbnail(of: CGSize(width: 66, height: 66)) ?? uiImage
            Image(uiImage: resized)
                .resizable()
                .scaledToFill()
                .frame(width: 66, height: 66)
                .clipShape(Circle())
                .onTapGesture {
                    fullScreenPhotoImage = UIImage(data: photoData)
                    showFullScreenPhoto = true
                }
        } else {
            Circle()
                .fill(tintColor)
                .frame(width: 66, height: 66)
                .overlay(
                    Image(systemName: pet.iconName)
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                )
        }
    }

    // MARK: - Weight Formatter

    private func formattedWeight(_ kg: Double) -> String {
        let isImperial = Locale.current.measurementSystem == .us
        if isImperial {
            let totalOz = kg * 35.274
            let lbs = Int(totalOz / 16)
            let oz = Int(totalOz.truncatingRemainder(dividingBy: 16))
            if lbs > 0 && oz > 0 {
                return "\(lbs) lb \(oz) oz"
            } else if lbs > 0 {
                return "\(lbs) lb"
            } else {
                return String(format: "%g oz", totalOz)
            }
        } else {
            return String(format: "%g kg", kg)
        }
    }

    // MARK: - Chip

    /// Yaş / Kilo chip bileşeni
    private func chipView(iconName: String, iconColor: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(iconColor)
            Text(label)
                .font(.pzCaptionBold)
                .foregroundColor(.pzTextPrimary)
        }
        .padding(.horizontal, .pzSpaceSM)     // 8pt yatay
        .padding(.vertical, .pzSpaceXS)        // 4pt dikey
        .background(
            RoundedRectangle(cornerRadius: 9)   // 9pt — Design System spec §6b
                .fill(Color.pzChipBackground)
        )
    }

    // MARK: - c) Yeni Pati Ekle Butonu

    /// Dashed border, ortalanmış buton
    private var addPetButton: some View {
        VStack(spacing: .pzSpaceSM) {
            Button {
                if storeManager.isPremium || pets.count < 1 {
                    showAddPetSheet = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: .pzSpaceSM) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L.string("Yeni Pati Ekle"))
                        .font(.pzBodyBold)
                }
                .foregroundColor(.pzBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        Color.pzBorderDashed,
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
            )

        }
        .accessibilityLabel(L.string("Yeni Pati Ekle"))
        .accessibilityHint(L.string("Evcil hayvan ekleme formunu açar"))
    }

    // MARK: - d) Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: .pzSpaceLG) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.pzTextQuaternary)
                    .accessibilityHidden(true)

                VStack(spacing: .pzSpaceXS) {
                    Text(L.string("Henüz pati yok"))
                        .font(.pzTitleMedium)
                        .foregroundColor(.pzTextPrimary)

                    Text(L.string("İlk evcil hayvanını ekleyerek başla"))
                        .font(.pzCallout)
                        .foregroundColor(.pzTextSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(L.string("Henüz pati yok")). \(L.string("İlk evcil hayvanını ekleyerek başla"))")

                // Boş hal için de Yeni Pati Ekle butonu
                emptyAddButton
                    .padding(.top, .pzSpaceSM)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pzBackground)
    }

    private var emptyAddButton: some View {
        VStack(spacing: .pzSpaceSM) {
            Button {
                if storeManager.isPremium || pets.count < 1 {
                    showAddPetSheet = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: .pzSpaceSM) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L.string("Yeni Pati Ekle"))
                        .font(.pzBodyBold)
                }
                .foregroundColor(.pzBlue)
                .padding(.horizontal, .pzSpaceXL)
                .padding(.vertical, .pzSpaceMD)
                .background(
                    RoundedRectangle(cornerRadius: .pzRadiusLG)
                        .strokeBorder(Color.pzBlue, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.string("Yeni Pati Ekle"))
        }
    }
}

// MARK: - Shadow Modifier (Yüzen + butonu)

extension View {
    /// 0 6px 14px -4px rgba(10,132,255, 0.60)
    func pzAddButtonShadow() -> some View {
        self.shadow(color: .pzBlue.opacity(0.60), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Previews

#Preview("Populated") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Pet.self, configurations: config)
    let context = container.mainContext

    let pamuk = Pet(
        name: "Pamuk",
        breed: "British Shorthair",
        age: 3,
        weight: 4.2,
        sex: "Dişi",
        tintColor: "#E05A67",
        iconName: "cat.fill"
    )
    let zeytin = Pet(
        name: "Zeytin",
        breed: "Tekir",
        age: 1,
        weight: 2.8,
        sex: "Erkek",
        tintColor: "#34C759",
        iconName: "cat.fill"
    )
    context.insert(pamuk)
    context.insert(zeytin)

    return PetsListView()
        .modelContainer(container)
}

#Preview("Empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Pet.self, configurations: config)
    return PetsListView()
        .modelContainer(container)
}
