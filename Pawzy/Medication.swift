//
//  Medication.swift
//  Pawzy
//
//  SwiftData Model — İlaç / Takviye
//

import Foundation
import SwiftData

@Model
final class Medication {
    var name: String = ""
    var dose: String = ""         // Dozaj (örn: "1 tablet", "2 damla")
    var time: Date = Date()       // Hatırlatma zamanı (bugünün saati)
    var category: String = ""     // "tablet", "damla", "merhem", "aşı"
    var iconName: String = ""     // SF Symbol adı
    var colorHex: String = ""     // İlaç rengi (hex)
    var isDone: Bool = false
    var petName: String = "" // İlişki yerine pet adı (ileride relation'a geçilebilir)
    var frequency: String = "daily" // "daily", "12hours", "weekly"
    var note: String = "" // Opsiyonel not

    init(
        name: String,
        dose: String,
        time: Date,
        category: String,
        iconName: String,
        colorHex: String,
        isDone: Bool = false,
        petName: String = "",
        frequency: String = "daily",
        note: String = ""
    ) {
        self.name = name
        self.dose = dose
        self.time = time
        self.category = category
        self.iconName = iconName
        self.colorHex = colorHex
        self.isDone = isDone
        self.petName = petName
        self.frequency = frequency
        self.note = note
    }
}
