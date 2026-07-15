//
//  MedicationCabinetItem.swift
//  Pawzy
//
//  SwiftData Model — İlaç Dolabı öğesi
//

import Foundation
import SwiftData

@Model
final class MedicationCabinetItem {
    var name: String = ""
    var category: String = ""     // "tablet", "damla", "merhem", "aşı"
    var iconName: String = ""     // SF Symbol adı
    var colorHex: String = ""     // Renk (hex)
    var stock: Int = 0            // Mevcut stok adedi
    var stockLabel: String = ""   // "3 kutu", "10 tablet" vb.
    var isLowStock: Bool = false  // Stok az uyarısı

    init(
        name: String,
        category: String,
        iconName: String,
        colorHex: String,
        stock: Int,
        stockLabel: String,
        isLowStock: Bool = false
    ) {
        self.name = name
        self.category = category
        self.iconName = iconName
        self.colorHex = colorHex
        self.stock = stock
        self.stockLabel = stockLabel
        self.isLowStock = isLowStock
    }
}
