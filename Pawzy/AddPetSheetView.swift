//
//  AddPetSheetView.swift
//  Pawzy
//
//  Yeni Pati Ekleme Sheet'i — Apple Health stili, Arda'nın vizyonu
//

import SwiftUI
import SwiftData
import PhotosUI
import os

// MARK: - Logger

private let logger = Logger(subsystem: "com.pawzy.app", category: "AddPetSheet")

// MARK: - Pet Type Enum

enum PetType: String, CaseIterable, Identifiable {
    case kedi = "Kedi"
    case kopek = "Köpek"
    case kus = "Kuş"
    case diger = "Diğer"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kedi: return L.string("Kedi")
        case .kopek: return L.string("Köpek")
        case .kus: return L.string("Kuş")
        case .diger: return L.string("Diğer")
        }
    }

    var iconName: String {
        switch self {
        case .kedi: return "cat.fill"
        case .kopek: return "dog.fill"
        case .kus: return "bird.fill"
        case .diger: return "pawprint.fill"
        }
    }

    var tintColor: String {
        switch self {
        case .kedi: return "#E05A67"
        case .kopek: return "#FF8A65"
        case .kus: return "#34C759"
        case .diger: return "#AF82E8"
        }
    }
}

// MARK: - Sex Enum

enum PetSex: String, CaseIterable, Identifiable {
    case disi = "Dişi"
    case erkek = "Erkek"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .disi: return L.string("Dişi")
        case .erkek: return L.string("Erkek")
        }
    }

    var symbolName: String {
        switch self {
        case .disi: return "female"
        case .erkek: return "male"
        }
    }
}

// MARK: - Activity Level Enum

enum ActivityLevel: String, CaseIterable, Identifiable {
    case low = "low"
    case normal = "normal"
    case high = "high"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return L.string("Düşük")
        case .normal: return L.string("Normal")
        case .high: return L.string("Yüksek")
        }
    }

    var subtitle: String {
        switch self {
        case .low: return L.string("Hareketsiz / Kısırlaştırılmış")
        case .normal: return L.string("Orta seviye hareketli")
        case .high: return L.string("Çok Aktif / Yavru")
        }
    }

    var iconName: String {
        switch self {
        case .low: return "tortoise.fill"
        case .normal: return "hare.fill"
        case .high: return "bolt.fill"
        }
    }
}

// MARK: - AddPetSheetView

struct AddPetSheetView: View {

    @Binding var isPresented: Bool
    var editingPet: Pet? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.name) private var pets: [Pet]

    private let storeManager = IAPManager.shared

    // MARK: Form State

    @State private var petName: String = ""
    @State private var selectedType: PetType = .kedi
    @State private var breedText: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    @State private var weightText: String = ""
    @State private var selectedSex: PetSex = .disi
    @State private var activityLevel: String = "normal"
    @State private var petPhoto: Data? = nil
    @State private var showPhotoSourceDialog: Bool = false
    @State private var showCamera: Bool = false
    @State private var showGallery: Bool = false
    @State private var showFullScreenPhoto: Bool = false
    @State private var showBreedGroup: Bool = false

    // Spam koruması
    @State private var isSaving: Bool = false

    // Save button animation
    @State private var saveButtonOpacity: Double = 0.6

    // MARK: Init

    init(isPresented: Binding<Bool>, editingPet: Pet? = nil) {
        self._isPresented = isPresented
        self.editingPet = editingPet
    }

    // MARK: Computed

    private var sheetTitle: String {
        editingPet != nil ? L.string("Pati Düzenle") : L.string("Yeni Pati")
    }

    private var isFormValid: Bool {
        !petName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !weightText.trimmingCharacters(in: .whitespaces).isEmpty &&
        weightInKg > 0
    }

    private var calculatedAge: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return max(0, ageComponents.year ?? 0)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .pzSpaceLG) {
                    // Fotoğraf
                    photoCard

                    Divider()
                        .padding(.horizontal, .pzSpaceXL)

                    // İsim + Tür birleşik kart
                    nameTypeCard

                    Divider()
                        .padding(.horizontal, .pzSpaceXL)

                    // Cinsiyet
                    sexCard

                    Divider()
                        .padding(.horizontal, .pzSpaceXL)

                    // Doğum Tarihi
                    dateCard

                    Divider()
                        .padding(.horizontal, .pzSpaceXL)

                    // Kilo
                    weightCard

                    Divider()
                        .padding(.horizontal, .pzSpaceXL)

                    // Aktivite
                    activityLevelCard

                    Divider()
                        .padding(.horizontal, .pzSpaceXL)

                    // Cins (opsiyonel, collapsed)
                    breedGroup
                }
                .padding(.top, .pzSpaceLG)
                .padding(.bottom, .pzSpaceXXL)
            }
            .background(Color.pzBackground)
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("İptal")) {
                        isPresented = false
                    }
                    .accessibilityLabel(L.string("İptal"))
                    .accessibilityHint(L.string("Pati eklemeyi iptal eder"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if !isSaving { savePet() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.pzBlue)
                        } else {
                            Text(L.string("Kaydet"))
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isSaving)
                    .opacity(isFormValid ? saveButtonOpacity : 0.6)
                    .accessibilityLabel(L.string("Kaydet"))
                    .accessibilityHint(isFormValid ? L.string("Yeni patiyi kaydeder") : L.string("Gerekli alanları doldurun"))
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L.string("Kapat")) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.pzBlue)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if !isFormValid { saveButtonOpacity = 0.6 } else { saveButtonOpacity = 1.0 }
            if editingPet == nil && !storeManager.isPremium && pets.count >= 1 {
                isPresented = false
                return
            }
            guard let pet = editingPet else { return }
            petName = pet.name
            breedText = pet.breed
            if breedText.trimmingCharacters(in: .whitespaces).isEmpty == false {
                showBreedGroup = true
            }
            if pet.age > 0 {
                birthDate = Calendar.current.date(byAdding: .year, value: -pet.age, to: Date()) ?? birthDate
            }
            weightText = displayWeightFromKg(pet.weight)
            selectedSex = PetSex(rawValue: pet.sex) ?? .disi
            activityLevel = pet.activityLevel
            petPhoto = pet.photo
            if let matchedType = PetType.allCases.first(where: { $0.iconName == pet.iconName }) {
                selectedType = matchedType
            }
        }
        .onChange(of: isFormValid) { _, valid in
            withAnimation(.easeInOut(duration: 0.3)) {
                saveButtonOpacity = valid ? 1.0 : 0.6
            }
        }
    }

    // MARK: - Fotoğraf Kartı

    private var photoCard: some View {
        VStack(spacing: .pzSpaceSM) {
            ZStack {
                if let photoData = petPhoto, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .pzShadowCardLifted()
                } else {
                    Circle()
                        .fill(Color.pzBlueLight)
                        .frame(width: 120, height: 120)
                        .pzShadowCardLifted()
                        .overlay(
                            VStack(spacing: .pzSpaceXS) {
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.pzBlue)
                                Text(L.string("Fotoğraf Ekle"))
                                    .font(.pzCaptionBold)
                                    .foregroundColor(.pzBlue)
                            }
                        )
                }
            }
            .contentShape(Circle())
            .onTapGesture {
                if petPhoto != nil {
                    showFullScreenPhoto = true
                } else {
                    showPhotoSourceDialog = true
                }
            }
            .accessibilityLabel(petPhoto != nil ? L.string("Fotoğrafı büyüt") : L.string("Fotoğraf ekle"))
            .accessibilityHint(L.string("Profil fotoğrafı eklemek için dokunun"))

            if petPhoto != nil {
                Button {
                    showPhotoSourceDialog = true
                } label: {
                    Text(L.string("Fotoğrafı Değiştir"))
                        .font(.pzCallout)
                        .fontWeight(.semibold)
                        .foregroundColor(.pzBlue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .pzSpaceXL)
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
            CameraPicker(imageData: $petPhoto)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showGallery) {
            PhotoPicker(imageData: $petPhoto)
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            if let photoData = petPhoto, let uiImage = UIImage(data: photoData) {
                FullScreenPhotoView(image: uiImage)
            }
        }
    }

    // MARK: - İsim + Tür Kartı (Birleşik)

    private var nameTypeCard: some View {
        HStack(spacing: .pzSpaceMD) {
            // Sol: isim TextField
            VStack(alignment: .leading, spacing: 6) {
                Text(L.string("İsim"))
                    .font(.pzCaptionBold)
                    .foregroundColor(.pzTextSecondary)
                TextField(L.string("Örn. Pamuk"), text: $petName)
                    .font(.pzBody)
                    .foregroundColor(.pzTextPrimary)
                    .textFieldStyle(.plain)
                    .accessibilityLabel(L.string("İsim"))
                    .accessibilityHint(L.string("Patinizin adını girin"))
            }

            Divider()
                .frame(height: 44)

            // Sağ: tür seçici
            VStack(alignment: .center, spacing: 6) {
                Text(L.string("Tür"))
                    .font(.pzCaptionBold)
                    .foregroundColor(.pzTextSecondary)

                HStack(spacing: .pzSpaceSM) {
                    ForEach(PetType.allCases) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedType = type
                            }
                        } label: {
                            Image(systemName: type.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(selectedType == type ? .white : Color(hex: type.tintColor))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(selectedType == type ? Color(hex: type.tintColor) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            selectedType == type ? Color.clear : Color(hex: type.tintColor).opacity(0.4),
                                            lineWidth: 1.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(type.displayName)\(selectedType == type ? ", \(L.string("seçilmedi").replacingOccurrences(of: L.string("seçilmedi"), with: ""))" : "")")
                    }
                }
            }
            .frame(width: 170)
        }
        .padding(.pzSpaceLG)
        .padding(.horizontal, .pzSpaceXS)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusLG)
                .fill(Color.pzSurface)
        )
        .padding(.horizontal, .pzSpaceXL)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(L.string("İsim")): \(petName.isEmpty ? L.string("Seçilmedi") : petName), \(L.string("Tür")): \(selectedType.displayName)")
    }

    // MARK: - Cinsiyet Kartı

    private var sexCard: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            Text(L.string("Cinsiyet"))
                .font(.pzCaptionBold)
                .foregroundColor(.pzTextSecondary)
                .padding(.horizontal, .pzSpaceXL)

            HStack(spacing: .pzSpaceMD) {
                ForEach(PetSex.allCases) { sex in
                    sexButton(sex)
                }
            }
            .padding(.horizontal, .pzSpaceXL)
        }
    }

    private func sexButton(_ sex: PetSex) -> some View {
        let isSelected = selectedSex == sex
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedSex = sex
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: sex == .disi ? "female" : "male")
                    .font(.system(size: 22))
                Text(sex.displayName)
                    .font(.pzBodyBold)
            }
            .foregroundColor(isSelected ? .white : .pzTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(
                            gradient: Gradient(colors: [.pzBlueGradientStart, .pzBlueGradientEnd]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(Color.pzSurface)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .strokeBorder(isSelected ? Color.clear : Color.pzBorderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sex.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Doğum Tarihi Kartı

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            Text(L.string("Doğum Tarihi"))
                .font(.pzCaptionBold)
                .foregroundColor(.pzTextSecondary)
                .padding(.horizontal, .pzSpaceXL)

            VStack(spacing: .pzSpaceSM) {
                HStack(spacing: .pzSpaceMD) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.pzBlue)
                        .frame(width: 24)

                    DatePicker(
                        "",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityLabel("\(L.string("Doğum Tarihi")): \(formattedBirthDate)")
                }

                Text(String(format: L.string("Yaklaşık %d yaşında"), calculatedAge))
                    .font(.pzCaption)
                    .foregroundColor(.pzTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 36)
            }
            .padding(.pzSpaceLG)
            .padding(.horizontal, .pzSpaceXS)
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .fill(Color.pzSurface)
            )
            .padding(.horizontal, .pzSpaceXL)
        }
    }

    // MARK: - Kilo Kartı

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            Text(L.string("Kilo"))
                .font(.pzCaptionBold)
                .foregroundColor(.pzTextSecondary)
                .padding(.horizontal, .pzSpaceXL)

            HStack(spacing: .pzSpaceMD) {
                TextField(weightPlaceholder, text: $weightText)
                    .font(.pzBody)
                    .foregroundColor(.pzTextPrimary)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .accessibilityLabel(L.string("Kilo"))

                Text(weightUnitLabel)
                    .font(.pzCallout)
                    .foregroundColor(.pzTextTertiary)

                Spacer()

                HStack(spacing: 8) {
                    // - button
                    Button {
                        decrementWeight()
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.pzBlue)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .strokeBorder(Color.pzBorderLight, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: weightText)

                    // + button
                    Button {
                        incrementWeight()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.pzBlue)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .strokeBorder(Color.pzBorderLight, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: weightText)
                }
            }
            .padding(.pzSpaceLG)
            .padding(.horizontal, .pzSpaceXS)
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .fill(Color.pzSurface)
            )
            .padding(.horizontal, .pzSpaceXL)
        }
    }

    private func decrementWeight() {
        let current = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let newValue = max(0, current - 0.1)
        weightText = String(format: isImperial ? "%.1f" : "%.1f", newValue)
    }

    private func incrementWeight() {
        let current = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let newValue = current + 0.1
        weightText = String(format: isImperial ? "%.1f" : "%.1f", newValue)
    }

    // MARK: - Aktivite Seviyesi Kartı

    private var activityLevelCard: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            Text(L.string("Hareketlilik Seviyesi"))
                .font(.pzCaptionBold)
                .foregroundColor(.pzTextSecondary)
                .padding(.horizontal, .pzSpaceXL)

            VStack(spacing: .pzSpaceSM) {
                ForEach(ActivityLevel.allCases) { level in
                    activityChip(level)
                }
            }
            .padding(.horizontal, .pzSpaceXL)
        }
    }

    private func activityChip(_ level: ActivityLevel) -> some View {
        let isSelected = activityLevel == level.rawValue
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                activityLevel = level.rawValue
            }
        } label: {
            HStack(spacing: .pzSpaceMD) {
                Image(systemName: level.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .white : .pzBlue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.pzBodyBold)
                        .foregroundColor(isSelected ? .white : .pzTextPrimary)
                    Text(level.subtitle)
                        .font(.pzCaption)
                        .foregroundColor(isSelected ? .white.opacity(0.85) : .pzTextTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
            .padding(.pzSpaceLG)
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .fill(isSelected ? Color.pzBlue : Color.pzSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .strokeBorder(isSelected ? Color.clear : Color.pzBorderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.displayName), \(level.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Cins Kartı (DisclosureGroup)

    private var breedGroup: some View {
        VStack(alignment: .leading, spacing: .pzSpaceSM) {
            DisclosureGroup(isExpanded: $showBreedGroup) {
                TextField(L.string("Örn. British Shorthair"), text: $breedText)
                    .font(.pzBody)
                    .foregroundColor(.pzTextPrimary)
                    .textFieldStyle(.plain)
                    .padding(.top, .pzSpaceSM)
                    .accessibilityLabel(L.string("Cins"))
                    .accessibilityHint(L.string("Patinizin cinsini girin"))
            } label: {
                Text(L.string("Cins"))
                    .font(.pzCaptionBold)
                    .foregroundColor(.pzTextSecondary)
            }
            .padding(.pzSpaceLG)
            .padding(.horizontal, .pzSpaceXS)
            .background(
                RoundedRectangle(cornerRadius: .pzRadiusLG)
                    .fill(Color.pzSurface)
            )
        }
        .padding(.horizontal, .pzSpaceXL)
    }

    // MARK: - Helpers

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        formatter.locale = Locale(identifier: lang == "tr" ? "tr_TR" : "en_US")
        formatter.dateStyle = .medium
        return formatter
    }()

    private var formattedBirthDate: String {
        Self.birthDateFormatter.string(from: birthDate)
    }

    private var isImperial: Bool {
        Locale.current.measurementSystem == .us
    }

    private var weightUnitLabel: String {
        isImperial ? "lb" : "kg"
    }

    private var weightPlaceholder: String {
        isImperial ? "9.2" : "4.2"
    }

    private var weightInKg: Double {
        guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return 0 }
        return isImperial ? value / 2.20462 : value
    }

    private func displayWeightFromKg(_ kg: Double) -> String {
        guard kg > 0 else { return "" }
        if isImperial {
            return String(format: "%g", kg * 2.20462)
        } else {
            return String(format: "%g", kg)
        }
    }

    // MARK: - Actions

    private func savePet() {
        guard isFormValid, !isSaving else { return }
        isSaving = true

        let weightValue = weightInKg

        if let existingPet = editingPet {
            existingPet.name = petName.trimmingCharacters(in: .whitespaces)
            existingPet.breed = breedText.trimmingCharacters(in: .whitespaces)
            existingPet.age = calculatedAge
            existingPet.weight = weightValue
            existingPet.sex = selectedSex.rawValue
            existingPet.tintColor = selectedType.tintColor
            existingPet.iconName = selectedType.iconName
            existingPet.activityLevel = activityLevel
            existingPet.photo = petPhoto

            do {
                try modelContext.save()
                #if DEBUG
                print("✅ Pati güncellendi: \(existingPet.name)")
                #endif
            } catch {
                logger.error("Pati güncelleme hatası: \(error.localizedDescription)")
            }
        } else {
            let pet = Pet(
                name: petName.trimmingCharacters(in: .whitespaces),
                breed: breedText.trimmingCharacters(in: .whitespaces),
                age: calculatedAge,
                weight: weightValue,
                sex: selectedSex.rawValue,
                tintColor: selectedType.tintColor,
                iconName: selectedType.iconName,
                activityLevel: activityLevel,
                photo: petPhoto
            )

            modelContext.insert(pet)

            do {
                try modelContext.save()
                #if DEBUG
                print("✅ Yeni pati kaydedildi: \(pet.name)")
                #endif
            } catch {
                logger.error("Pati kaydetme hatası: \(error.localizedDescription)")
            }
        }

        isSaving = false
        isPresented = false
    }
}

// MARK: - PhotoPicker

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage else { return }
                let data = image.jpegData(compressionQuality: 0.8)
                DispatchQueue.main.async {
                    self?.parent.imageData = data
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("AddPetSheet") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Pet.self, configurations: config)

    return Color.pzBackground.ignoresSafeArea()
        .modelContainer(container)
}
