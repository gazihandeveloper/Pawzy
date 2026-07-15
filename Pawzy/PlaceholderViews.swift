//
//  PlaceholderViews.swift
//  Pawzy
//
//  Geçici placeholder ekranlar — ileride gerçek implementasyonla değiştirilecek
//  NOT: Patilerim sekmesi → PetsListView.swift (tam implementasyon)
//  NOT: Dolap sekmesi → CabinetView.swift (tam implementasyon)
//

import SwiftUI

/// Eski placeholder — artık PetsListView kullanılıyor
/// Bu typealias MainTabView geçişinde backward-compat için bırakıldı,
/// asıl implementasyon PetsListView.swift dosyasındadır.
typealias PatilerimView = PetsListView

/// Eski Dolap placeholder — artık CabinetView kullanılıyor
typealias DolapView = CabinetView

/// Eski Ayarlar placeholder — artık SettingsView kullanılıyor
/// Asıl implementasyon SettingsView.swift dosyasındadır.
typealias AyarlarView = SettingsView

// NOTE: Patilerim preview → PetsListView.swift dosyasında
// NOTE: Dolap preview → CabinetView.swift dosyasında

#Preview("Ayarlar") {
    AyarlarView()
}
