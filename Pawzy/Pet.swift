//
//  Pet.swift
//  Pawzy
//
//  SwiftData Model — Evcil hayvan
//

import Foundation
import SwiftData

@Model
final class Pet {
    var name: String = ""
    var breed: String = ""
    var age: Int = 0
    var weight: Double = 0
    var sex: String = ""          // "Erkek" veya "Dişi"
    var tintColor: String = ""    // Hex renk kodu (örn: "#E05A67")
    var iconName: String = ""     // SF Symbol adı
    var activityLevel: String = "normal"  // "low" (hareketsiz/kısır), "normal", "high" (çok aktif/yavru)
    var photo: Data?  // UIImage JPEG verisi (nil = fotoğraf yok, ikon göster)

    init(
        name: String,
        breed: String,
        age: Int,
        weight: Double,
        sex: String,
        tintColor: String,
        iconName: String,
        activityLevel: String = "normal",
        photo: Data? = nil
    ) {
        self.name = name
        self.breed = breed
        self.age = age
        self.weight = weight
        self.sex = sex
        self.tintColor = tintColor
        self.iconName = iconName
        self.activityLevel = activityLevel
        self.photo = photo
    }
}
