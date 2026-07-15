//
//  AddMedicationSheetView.swift
//  Pawzy
//
//  Basit ilaç ekleme sheet'i — Apple Form stili, sıfır karmaşıklık
//

import SwiftUI
import SwiftData

// MARK: - Category Helpers (String-based, no enums)

private let categoryOptions = [
    ("tablet", L.string("Tablet"), "pill.fill", "#E05A67"),
    ("damla", L.string("Damla"), "drop.fill", "#34C759"),
    ("merhem", L.string("Merhem"), "cross.case.fill", "#AF82E8"),
    ("aşı", L.string("Aşı"), "syringe.fill", "#FF8A65"),
]

private let frequencyOptions = [
    ("daily", L.string("Her gün")),
    ("12hours", L.string("12 saatte")),
    ("weekly", L.string("Haftalık")),
]

private let dosageUnitOptions = [L.string("Tablet"), "mL", L.string("Damla"), "gr"]

// MARK: - AddMedicationSheetView

struct AddMedicationSheetView: View {

    @Binding var isPresented: Bool
    var preselectedPet: Pet? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.name) private var pets: [Pet]

    @State private var medicationName: String = ""
    @State private var doseText: String = ""
    @State private var selectedPetID: PersistentIdentifier? = nil
    @State private var selectedTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var selectedFrequency: Int = 0
    @State private var selectedCategory: Int = 0
    @State private var selectedDosageUnit: Int = 0
    @State private var isSaving: Bool = false

    private var isFormValid: Bool {
        !medicationName.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedPetID != nil &&
        !doseText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.string("İlaç Adı")) {
                    TextField(L.string("Örn. Bravecto"), text: $medicationName)
                }

                Section(L.string("Dozaj")) {
                    HStack {
                        TextField(L.string("1"), text: $doseText)
                            .keyboardType(.decimalPad)
                        Picker("", selection: $selectedDosageUnit) {
                            ForEach(0..<dosageUnitOptions.count, id: \.self) { i in
                                Text(dosageUnitOptions[i]).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section(L.string("Hangi Pati")) {
                    Picker(L.string("Pati"), selection: $selectedPetID) {
                        Text(L.string("Seçilmedi")).tag(nil as PersistentIdentifier?)
                        ForEach(pets) { pet in
                            Text(pet.name).tag(pet.persistentModelID as PersistentIdentifier?)
                        }
                    }
                }

                Section(L.string("Hatırlatma Saati")) {
                    DatePicker(L.string("Zaman"), selection: $selectedTime, displayedComponents: .hourAndMinute)
                }

                Section(L.string("Sıklık")) {
                    Picker(L.string("Sıklık"), selection: $selectedFrequency) {
                        ForEach(0..<frequencyOptions.count, id: \.self) { i in
                            Text(frequencyOptions[i].1).tag(i)
                        }
                    }
                }

                Section(L.string("Kategori")) {
                    Picker(L.string("Kategori"), selection: $selectedCategory) {
                        ForEach(0..<categoryOptions.count, id: \.self) { i in
                            Label(categoryOptions[i].1, systemImage: categoryOptions[i].2).tag(i)
                        }
                    }
                }
            }
            .navigationTitle(L.string("Yeni Hatırlatıcı"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("İptal")) { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("Kaydet")) { saveMedication() }
                        .disabled(!isFormValid || isSaving)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if let pet = preselectedPet {
                selectedPetID = pet.persistentModelID
            }
        }
    }

    // MARK: - Save

    private func saveMedication() {
        guard isFormValid, !isSaving else { return }
        isSaving = true

        let cat = categoryOptions[selectedCategory]
        let freq = frequencyOptions[selectedFrequency]

        let medication = Medication(
            name: medicationName.trimmingCharacters(in: .whitespaces),
            dose: doseText.trimmingCharacters(in: .whitespaces),
            time: selectedTime,
            category: cat.0,
            iconName: cat.2,
            colorHex: cat.3,
            isDone: false,
            petName: pets.first(where: { $0.persistentModelID == selectedPetID })?.name ?? ""
        )
        medication.frequency = freq.0

        modelContext.insert(medication)

        do {
            try modelContext.save()
            NotificationManager.shared.schedule(for: medication)
        } catch {
            print("❌ İlaç kaydetme hatası: \(error.localizedDescription)")
        }

        isSaving = false
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Pet.self, Medication.self, configurations: config)
    return Color.pzBackground.ignoresSafeArea()
        .modelContainer(container)
}
