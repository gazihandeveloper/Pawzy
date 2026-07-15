//
//  CabinetView.swift
//  Pawzy
//
//  İlaç Dolabı Ekranı — Zeynep'in tasarımından birebir implementasyon
//

import SwiftUI
import SwiftData

// MARK: - Category Filter

enum CabinetCategory: String, CaseIterable {
    case tumu
    case asi
    case tablet
    case damla
    case merhem

    var displayName: String {
        switch self {
        case .tumu: return L.string("Tümü")
        case .asi: return L.string("Aşı")
        case .tablet: return L.string("Tablet")
        case .damla: return L.string("Damla")
        case .merhem: return L.string("Merhem")
        }
    }

    /// Model'deki category alanıyla eşleşme; nil = tümü
    var modelValue: String? {
        switch self {
        case .tumu: return nil
        case .asi: return "aşı"
        case .tablet: return "tablet"
        case .damla: return "damla"
        case .merhem: return "merhem"
        }
    }
}

// MARK: - CabinetView

struct CabinetView: View {

    // MARK: SwiftData

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \MedicationCabinetItem.name) private var items: [MedicationCabinetItem]

    @State private var selectedCategory: CabinetCategory = .tumu
    @State private var showAddMedicationSheet = false

    // MARK: Edit State
    @State private var showEditSheet: Bool = false
    @State private var editingItem: MedicationCabinetItem? = nil
    @State private var editName: String = ""
    @State private var editDose: String = ""
    @State private var editCategory: String = "tablet"
    @State private var editStock: Int = 0
    @State private var editStockLabel: String = ""

    // MARK: Computed

    private var filteredItems: [MedicationCabinetItem] {
        guard let modelValue = selectedCategory.modelValue else {
            return items
        }
        return items.filter { $0.category == modelValue }
    }

    private var lowStockCount: Int {
        items.filter(\.isLowStock).count
    }

    private var headerSubtitle: String {
        let format = L.string("ürün · stok azalıyor")
        return String(format: format, items.count, lowStockCount)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // a) Header
                headerSection
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.top, .pzSpaceMD)

                // b) Kategori Filtre Strip
                categoryFilterStrip
                    .padding(.top, .pzSpaceXL)

                // c) İlaç Dolabı Kart Listesi
                if filteredItems.isEmpty {
                    emptyState
                        .padding(.top, .pzSpaceXXL)
                } else {
                    cabinetList
                        .padding(.horizontal, .pzSpaceXL)
                        .padding(.top, .pzSpaceLG)
                        .padding(.bottom, 100) // Tab bar alanı
                }
            }
        }
        .background(Color.pzBackground)
        .sheet(isPresented: $showAddMedicationSheet) {
            AddMedicationSheetView(isPresented: $showAddMedicationSheet)
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section(L.string("İlaç Adı")) {
                        TextField(L.string("İlaç adı"), text: $editName)
                    }

                    Section(L.string("Dozaj")) {
                        TextField(L.string("Dozaj (örn: 1 tablet)"), text: $editDose)
                    }

                    Section(L.string("Kategori")) {
                        Picker(L.string("Kategori"), selection: $editCategory) {
                            Text(L.string("Tablet")).tag("tablet")
                            Text(L.string("Damla")).tag("damla")
                            Text(L.string("Merhem")).tag("merhem")
                            Text(L.string("Aşı")).tag("aşı")
                        }
                        .pickerStyle(.menu)
                    }

                    Section(L.string("Stok")) {
                        Stepper("\("\(L.string("Adet")): \(editStock)")", value: $editStock, in: 0...999)
                        TextField(L.string("Stok etiketi"), text: $editStockLabel)
                    }
                }
                .navigationTitle(L.string("İlaç Düzenle"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.string("İptal")) {
                            showEditSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.string("Kaydet")) {
                            if let item = editingItem {
                                item.name = editName
                                item.category = editCategory
                                item.stock = editStock
                                item.stockLabel = editStockLabel
                                item.iconName = iconForCategory(editCategory)
                                item.colorHex = colorHexForCategory(editCategory)
                                try? modelContext.save()
                            }
                            showEditSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - a) Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 0) {
            // Sol: Başlık + Alt açıklama
            VStack(alignment: .leading, spacing: .pzSpaceXS) {
                Text(L.string("İlaç Dolabı"))
                    .font(.pzTitleLarge)
                    .foregroundColor(.pzTextPrimary)
                    .tracking(-0.6)
                    .accessibilityAddTraits(.isHeader)

                Text(headerSubtitle)
                    .font(.pzCallout)
                    .foregroundColor(.pzTextSecondary)
                    .accessibilityLabel(headerSubtitle)
            }

            Spacer()

            // Sağ: 38×38 yuvarlak mavi buton
            addButton
        }
    }

    /// 38×38 yuvarlak mavi buton — shadow: 0 6px 14px -4px rgba(10,132,255,0.6)
    private var addButton: some View {
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
        .accessibilityLabel(L.string("Yeni ilaç ekle"))
        .accessibilityHint(L.string("İlaç dolabına yeni ilaç ekleme formunu açar"))
    }

    // MARK: - b) Kategori Filtre Strip

    /// Yatay scroll, chip'ler: "Tümü", "Aşı", "Tablet", "Damla", "Merhem"
    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .pzSpaceSM) {
                ForEach(CabinetCategory.allCases, id: \.self) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, .pzSpaceXL)
        }
    }

    /// Her chip: 8px dikey 16px yatay padding, 18pt radius, captionBold
    private func categoryChip(_ category: CabinetCategory) -> some View {
        let isSelected = category == selectedCategory

        return Button {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(category.displayName)
                .font(.pzCaptionBold)
                .foregroundColor(isSelected ? .white : .pzTextSecondary)
                .padding(.vertical, .pzSpaceSM)   // 8px dikey
                .padding(.horizontal, .pzSpaceLG) // 16px yatay
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSelected ? Color.pzBlue : Color.pzSurface)
                )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.2), value: isSelected)
        .accessibilityLabel("\(category.displayName)\(L.string(" kategorisi"))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - c) Cabinet List

    private var cabinetList: some View {
        VStack(spacing: .pzSpaceMD) {
            ForEach(filteredItems) { item in
                cabinetCard(item)
            }
        }
    }

    /// CabinetCard — Design System 6d anatomisi
    private func cabinetCard(_ item: MedicationCabinetItem) -> some View {
        let color = Color(hex: item.colorHex)

        return HStack(spacing: .pzSpaceMD) {

            // Sol: 46×46 ikon kutusu (14pt radius, tint bg, SF Symbol 23pt)
            RoundedRectangle(cornerRadius: 14)
                .fill(color.withTintOpacity())
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: item.iconName)
                        .font(.system(size: 23))
                        .foregroundColor(color)
                )
                .accessibilityHidden(true)

            // Orta: İlaç adı + Kategori
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.pzBodyBold)
                    .foregroundColor(.pzTextPrimary)

                Text(categoryDisplay(for: item))
                    .font(.pzCaption)
                    .foregroundColor(.pzTextSecondary)
            }

            Spacer()

            // Sağ: Stok label + Stok chip
            VStack(alignment: .trailing, spacing: 4) {
                Text(L.string("Stok"))
                    .font(.pzBadgeLabel)
                    .foregroundColor(.pzTextTertiary)

                stockChip(item: item)
            }
        }
        .padding(14) // 14pt — spec: container padding
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusXL) // 20pt
                .fill(Color.pzSurface)
        )
        .pzShadowCardLifted()
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .default) {
                    modelContext.delete(item)
                    try? modelContext.save()
                }
            } label: {
                Label(L.string("Sil"), systemImage: "trash")
            }
            .tint(.pzRed)
        }
        .onTapGesture {
            editingItem = item
            editName = item.name
            editDose = item.stockLabel
            editCategory = item.category
            editStock = item.stock
            editStockLabel = item.stockLabel
            showEditSheet = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.name), \(categoryDisplay(for: item)), \(L.string("Stok")): \(localizedStockLabel(for: item))\(item.isLowStock ? ", \(L.string("az kaldı"))" : "")"
        )
        .accessibilityHint(L.string("Düzenlemek için dokunun"))
    }

    /// Stok chip: az → pzRedLight bg + pzRed yazı. normal → pzBackground bg + pzTextSecondary yazı.
    /// 9pt radius, 3px 9px padding, captionBold.
    private func stockChip(item: MedicationCabinetItem) -> some View {
        Text(localizedStockLabel(for: item))
            .font(.pzCaptionBold)
            .foregroundColor(item.isLowStock ? .pzRed : .pzTextSecondary)
            .padding(.horizontal, 9)  // 9px yatay
            .padding(.vertical, 3)    // 3px dikey
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(item.isLowStock ? Color.pzRedLight : Color.pzChipBackground)
            )
            .accessibilityLabel(
                item.isLowStock ? "\(localizedStockLabel(for: item)), \(L.string("az kaldı"))" : localizedStockLabel(for: item)
            )
    }

    /// stockLabel içindeki Türkçe kelimeleri (adet, şişe, Son doz) locale'e göre çevirir.
    private func localizedStockLabel(for item: MedicationCabinetItem) -> String {
        let trimmed = item.stockLabel.trimmingCharacters(in: .whitespaces)

        // "Son doz: ..." pattern
        let lastDosePrefixTR = "Son doz:"
        if trimmed.hasPrefix(lastDosePrefixTR) {
            let remaining = trimmed.dropFirst(lastDosePrefixTR.count)
            return "\(L.string("Son doz")):\(remaining)"
        }

        // "number unit" pattern — örn: "4 adet", "1 şişe"
        if let _ = Int(trimmed.components(separatedBy: " ").first ?? "") {
            let parts = trimmed.components(separatedBy: " ")
            if parts.count >= 2 {
                let number = parts[0]
                let unit = parts[1]
                let localizedUnit: String
                switch unit {
                case "adet": localizedUnit = L.string("adet")
                case "şişe": localizedUnit = L.string("şişe")
                default: localizedUnit = unit
                }
                return "\(number) \(localizedUnit)"
            }
        }

        return item.stockLabel
    }

    /// Kategori değerine göre görünen adı döndürür
    private func categoryDisplay(for item: MedicationCabinetItem) -> String {
        switch item.category {
        case "aşı": return L.string("Aşı")
        case "tablet": return L.string("Tablet")
        case "damla": return L.string("Damla")
        case "merhem": return L.string("Merhem")
        default: return item.category
        }
    }

    /// Kategoriye göre SF Symbol ikonu döndürür
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "aşı": return "syringe.fill"
        case "tablet": return "pill.fill"
        case "damla": return "drop.fill"
        case "merhem": return "cross.case.fill"
        default: return "pill.fill"
        }
    }

    /// Kategoriye göre renk hex kodu döndürür
    private func colorHexForCategory(_ category: String) -> String {
        switch category {
        case "aşı": return "#AF82E8"
        case "tablet": return "#E05A67"
        case "damla": return "#34C759"
        case "merhem": return "#FF8A65"
        default: return "#E05A67"
        }
    }

    // MARK: - d) Empty State

    /// Filtrelenmiş liste boşsa gösterilir
    private var emptyState: some View {
        VStack(spacing: .pzSpaceMD) {
            Image(systemName: "pill.fill")
                .font(.system(size: 40))
                .foregroundColor(.pzTextQuaternary)
                .accessibilityHidden(true)

            Text(L.string("Bu kategoride ilaç yok"))
                .font(.pzCallout)
                .foregroundColor(.pzTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .pzSpaceXL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L.string("Bu kategoride ilaç yok"))
    }
}

// MARK: - Previews

#Preview("Populated - Tümü") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MedicationCabinetItem.self, configurations: config)
    // Seed some sample data
    let context = container.mainContext
    let items: [(String, String, String, String, Int, String, Bool)] = [
        ("Bravecto Plus", "tablet", "pill.fill", "#FF8A65", 3, "3 adet", false),
        ("Omega-3 Damla", "damla", "drop.fill", "#34C759", 1, "1 şişe", true),
        ("Kuduz Aşısı", "aşı", "syringe.fill", "#AF82E8", 0, "Son doz: 12.06", true),
        ("Göz Merhemi", "merhem", "cross.case.fill", "#E05A67", 2, "2 adet", false),
    ]
    for (name, cat, icon, hex, stock, label, low) in items {
        let item = MedicationCabinetItem(name: name, category: cat, iconName: icon, colorHex: hex, stock: stock, stockLabel: label, isLowStock: low)
        context.insert(item)
    }
    return CabinetView()
        .modelContainer(container)
}

#Preview("Dark Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MedicationCabinetItem.self, configurations: config)
    return CabinetView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
