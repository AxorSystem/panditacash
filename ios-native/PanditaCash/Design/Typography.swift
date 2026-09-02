import SwiftUI

// Tipografía real-estate: sans-serif limpia, weights medios, no rounded

enum PType {
    static func display(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func heading(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func bodyBold(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static func number(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .default).monospacedDigit()
    }
    static func mono(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

extension Text {
    func inkColor(_ opacity: Double = 1.0) -> Text {
        self.foregroundColor(Theme.ink.opacity(opacity))
    }
}
