import SwiftUI
import UIKit

enum Theme {
    // Fondos verde pastel (natural, luxury) — con soporte modo oscuro
    // Fondo un poco más profundo + superficies casi-blancas para que los cards
    // se separen del fondo (antes surfaceLight vs background = 1.10, ahora 1.29).
    static let background = dyn(light: 0xCFE4C0, dark: 0x0A1A0A)
    static let backgroundElevated = dyn(light: 0xF7FBF3, dark: 0x13251A)
    static let surface = dyn(light: 0xEDF3E5, dark: 0x172A1D)
    static let surfaceLight = dyn(light: 0xF7FBF3, dark: 0x1A2E1F)

    // Verde oscuro luxury (bosque) — fijo (brand color, se ve bien en ambos)
    static let headerDark = Color(hex: 0x1A2E1A)
    static let headerDeep = Color(hex: 0x1B3B1B)
    static let deepGreen = dyn(light: 0x1B3B1B, dark: 0xA3D08C)
    static let darkGreen = Color(hex: 0x234023)

    // Texto — se invierten en dark
    static let ink = dyn(light: 0x0A1A0A, dark: 0xEDF3E5)
    static let inkSoft = dyn(light: 0x2E3E2E, dark: 0xB8CAB8)
    static let inkMuted = dyn(light: 0x4E5E4E, dark: 0x8A9A8A)
    static let hairline = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.12)
        : UIColor(white: 0.1, alpha: 0.15) })

    private static func dyn(light: Int, dark: Int) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    // Acentos
    static let primary = deepGreen                     // Verde bosque profundo
    static let primaryDark = Color(hex: 0x0E2A0E)
    static let primaryDeep = Color(hex: 0x081A08)

    static let accent = Color(hex: 0x4A7A4A)          // Verde medio para chips/iconos
    static let secondary = Color(hex: 0x86A886)       // Verde salvia

    static let sun = Color(hex: 0xE3B85A)
    static let coral = Color(hex: 0xE0805F)
    static let heart = Color(hex: 0xD64545)
    static let cyan = Color(hex: 0x6BB89F)             // Verde-cyan suave

    // Semantic
    static let success = Color(hex: 0x4A7A4A)
    static let warning = Color(hex: 0xE3B85A)
    static let danger = heart
    static let info = Color(hex: 0x5A8DAA)

    static let systemBlue = info
    static let systemGreen = success
    static let systemRed = heart
    static let systemOrange = coral
    static let systemYellow = sun
    static let systemPurple = Color(hex: 0x9E7BB0)
    static let systemIndigo = info

    // Legacy panda
    static let panda50 = Color(hex: 0xE8F0DE)
    static let panda100 = Color(hex: 0xD5E5C6)
    static let panda500 = primary
    static let panda600 = primaryDark
    static let panda700 = primaryDeep

    // Soft backgrounds pastel
    static let softPrimary = Color(hex: 0xBFD8AC)      // Verde suave para inputs/chips
    static let softCyan = Color(hex: 0xCFE5D5)
    static let softSuccess = Color(hex: 0xCFE5C6)
    static let softWarning = Color(hex: 0xF5E3B8)
    static let softDanger = Color(hex: 0xF5D0D0)
    static let softPurple = Color(hex: 0xE0D5E8)

    // Gradientes (verde oscuro para hero)
    static let heroPrimary = LinearGradient(
        colors: [Color(hex: 0x234023), Color(hex: 0x1B3B1B)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let heroDeep = LinearGradient(
        colors: [Color(hex: 0x081A08), Color(hex: 0x1B3B1B)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let heroCyan = LinearGradient(
        colors: [Color(hex: 0x6BB89F), Color(hex: 0x4A7A4A)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let heroSunset = LinearGradient(
        colors: [Color(hex: 0xE0805F), Color(hex: 0xE3B85A)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let headerGradient = LinearGradient(
        colors: [background, backgroundElevated],
        startPoint: .top, endPoint: .bottom)

    static let primaryGradient = heroPrimary

    static func applyGlobalAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: UIColor(ink)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(ink)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(primary)

        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255.0,
            green: CGFloat((hex >> 8) & 0xff) / 255.0,
            blue: CGFloat(hex & 0xff) / 255.0,
            alpha: alpha
        )
    }
}
