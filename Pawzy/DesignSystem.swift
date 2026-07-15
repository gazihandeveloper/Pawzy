//
//  DesignSystem.swift
//  Pawzy
//
//  Tasarım Token'ları — Zeynep'in DesignSystem.md spec'inden birebir
//

import SwiftUI

// MARK: - Renk Token'ları

extension Color {
    // Accent / Primary — Pembe/Mercan
    static let pzBlue = Color(hex: "E05A67")
    static let pzBlueLight = Color(hex: "FFF3EB")
    static let pzBlueGradientStart = Color(hex: "FF8B94")
    static let pzBlueGradientEnd = Color(hex: "E05A67")

    // Semantic Colors
    static let pzGreen = Color(hex: "34C759")
    static let pzGreenLight = Color(hex: "E6F7F1")
    static let pzCoral = Color(hex: "FF8A65")
    static let pzPurple = Color(hex: "AF82E8")
    static let pzRed = Color(hex: "FF453A")
    static let pzRedLight = Color(hex: "FFE9E7")
    static let pzTeal = Color(hex: "34C7A4")

    // Neutral / Surface
    static let pzBackground = Color(lightHex: "FFFFFF", darkHex: "1C1C1E")  // Light: beyaz, Dark: antrasit (saf siyah yok)
    static let pzChipBackground = Color(lightHex: "F2F2F7", darkHex: "2C2C2E")  // Chip arka planı — kart üstünde kontrast için
    static let pzSurface = Color(lightHex: "FFFFFF", darkHex: "2C2C2E")  // Light: #FFFFFF, Dark: #2C2C2E (kartlar)
    static let pzTextPrimary = Color(.label)                    // Light: #1C1C1E, Dark: #FFFFFF
    static let pzTextSecondary = Color(.secondaryLabel)         // Light: #8A8A8E
    static let pzTextTertiary = Color(.tertiaryLabel)           // Light: #A0A0A5
    static let pzTextQuaternary = Color(.quaternaryLabel)       // Light: #C7C7CC
    static let pzSeparator = Color(.separator)                  // rgba(60,60,67,0.08)
    static let pzSegmentBg = Color(hex: "E7E7EA")
    static let pzToggleOff = Color(hex: "E9E9EA")
    static let pzBorderLight = Color(hex: "E5E5EA")
    static let pzBorderDashed = Color(hex: "BFD6EE")

    // Overlay / Tab Bar
    static let pzOverlay = Color(hex: "1C1C1E").opacity(0.55)

    // Paywall
    static let pzPaywallBg = Color.white
    static let pzPaywallHeaderGradientStart = Color(hex: "FFF3EB")
    static let pzPaywallHeaderGradientEnd = Color.white

    /// HEX string'den Color init: "#E05A67" veya "E05A67"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Light/Dark adaptive Color: lightHex aydınlık mod, darkHex karanlık mod
    init(lightHex: String, darkHex: String) {
        self.init(UIColor { traitCollection in
            let hexStr = (traitCollection.userInterfaceStyle == .dark ? darkHex : lightHex)
                .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hexStr).scanHexInt64(&int)
            let a, r, g, b: UInt64
            switch hexStr.count {
            case 6:
                (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
            case 8:
                (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
            default:
                (a, r, g, b) = (255, 0, 0, 0)
            }
            return UIColor(
                red: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: CGFloat(a) / 255
            )
        })
    }
}

// MARK: - Gradient Tanımları

extension LinearGradient {
    static let pzBlueGradient = LinearGradient(
        gradient: Gradient(colors: [.pzBlueGradientStart, .pzBlueGradientEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Tipografi Stilleri

extension Font {
    /// 32pt Bold → Large Title
    static let pzTitleLarge = Font.system(.largeTitle, design: .default).bold()
    /// 20pt Bold → Title 2
    static let pzTitleMedium = Font.system(.title2, design: .default).bold()
    /// 18pt Bold → Title 3
    static let pzTitleSmall = Font.system(.title3, design: .default).bold()
    /// 17pt Semibold → Headline
    static let pzHeadline = Font.system(.headline, design: .default).weight(.semibold)
    /// 16pt Regular → Body
    static let pzBody = Font.system(.body, design: .default)
    /// 16pt Semibold → Body bold
    static let pzBodyBold = Font.system(.body, design: .default).weight(.semibold)
    /// 14pt Regular → Callout
    static let pzCallout = Font.system(.callout, design: .default)
    /// 13pt Regular → Footnote
    static let pzCaption = Font.system(.footnote, design: .default)
    /// 12pt Bold → Caption bold
    static let pzCaptionBold = Font.system(.caption, design: .default).bold()
    /// 11pt Bold → Caption 2 bold
    static let pzBadgeLabel = Font.system(.caption2, design: .default).bold()
    /// 10pt Medium → Caption 2 medium
    static let pzTabLabel = Font.system(.caption2, design: .default).weight(.medium)
    /// 10pt Semibold → Caption 2 semibold
    static let pzTabLabelActive = Font.system(.caption2, design: .default).weight(.semibold)
}

// MARK: - Spacing Ölçeği

extension CGFloat {
    static let pzSpaceXS: CGFloat = 4
    static let pzSpaceSM: CGFloat = 8
    static let pzSpaceMD: CGFloat = 12
    static let pzSpaceLG: CGFloat = 16
    static let pzSpaceXL: CGFloat = 20
    static let pzSpaceXXL: CGFloat = 24
}

// MARK: - Radius Token'ları

extension CGFloat {
    static let pzRadiusSM: CGFloat = 8
    static let pzRadiusMD: CGFloat = 13
    static let pzRadiusLG: CGFloat = 16
    static let pzRadiusXL: CGFloat = 20
    static let pzRadius2XL: CGFloat = 26
    static let pzRadiusFull: CGFloat = 9999
}

// MARK: - Shadow Token'ları

extension View {
    func pzShadowCard() -> some View {
        self.shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    func pzShadowCardLifted() -> some View {
        self.shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 10)
    }

    func pzShadowProgress() -> some View {
        self.shadow(color: .pzBlue.opacity(0.60), radius: 30, x: 0, y: 16)
    }

    func pzShadowPremium() -> some View {
        self.shadow(color: .pzBlue.opacity(0.55), radius: 30, x: 0, y: 16)
    }

    func pzShadowSheet() -> some View {
        self.shadow(color: .black.opacity(0.20), radius: 40, x: 0, y: -12)
    }

    func pzShadowSegment() -> some View {
        self.shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 1)
    }

    func pzShadowSegmentIf(_ condition: Bool) -> some View {
        self.shadow(color: .black.opacity(condition ? 0.14 : 0), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Tint Opaklık Yardımcısı

extension Color {
    /// Bir rengin %10 opaklık (1A hex) overlay'ini döndürür
    func withTintOpacity() -> Color {
        self.opacity(0.10)
    }
}
