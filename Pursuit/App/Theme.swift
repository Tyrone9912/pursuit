import SwiftUI
import AppKit

extension Color {
    /// A dynamic color that resolves per-appearance, mirroring the CSS
    /// custom-property pairs (light / `prefers-color-scheme: dark`) in the design spec.
    init(light: NSColor, dark: NSColor) {
        self.init(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Design tokens ported from the Pursuit design spec's `:root` CSS custom properties.
enum Theme {
    static let pageBackground = Color(light: NSColor(hex: 0xEEF0F5), dark: NSColor(hex: 0x0C0E11))
    static let pageText       = Color(light: NSColor(hex: 0x3A3F4A), dark: NSColor(hex: 0x8891A0))
    static let background     = Color(light: NSColor(hex: 0xF5F7FA), dark: NSColor(hex: 0x131519))
    static let sidebar        = Color(light: NSColor(hex: 0xE8ECF2), dark: NSColor(hex: 0x0F1215))
    static let surface        = Color(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x1C2028))
    static let surface2       = Color(light: NSColor(hex: 0xF2F4F8), dark: NSColor(hex: 0x242830))

    static let border       = Color(light: NSColor(hex: 0x000000, alpha: 0.08), dark: NSColor(hex: 0xFFFFFF, alpha: 0.065))
    static let borderStrong = Color(light: NSColor(hex: 0x000000, alpha: 0.13), dark: NSColor(hex: 0xFFFFFF, alpha: 0.11))

    static let text1 = Color(light: NSColor(hex: 0x1A1D24), dark: NSColor(hex: 0xE5E9F0))
    static let text2 = Color(light: NSColor(hex: 0x5A6170), dark: NSColor(hex: 0x7E8898))
    static let text3 = Color(light: NSColor(hex: 0x9AA2B0), dark: NSColor(hex: 0x4A5260))

    static let accent       = Color(light: NSColor(hex: 0x235C47), dark: NSColor(hex: 0x3D9272))
    static let accentMid    = Color(light: NSColor(hex: 0x2D7A5E), dark: NSColor(hex: 0x4AAA87))
    static let accentBg     = Color(light: NSColor(hex: 0x235C47, alpha: 0.09), dark: NSColor(hex: 0x3D9272, alpha: 0.12))
    static let accentBorder = Color(light: NSColor(hex: 0x235C47, alpha: 0.22), dark: NSColor(hex: 0x3D9272, alpha: 0.28))
    static let accentText   = Color(light: NSColor(hex: 0x1A4635), dark: NSColor(hex: 0x6ECBA8))

    static let green = Color(light: NSColor(hex: 0x27AE60), dark: NSColor(hex: 0x2ECC71))
    static let amber = Color(light: NSColor(hex: 0xE67E22), dark: NSColor(hex: 0xF39C12))
    static let blue  = Color(light: NSColor(hex: 0x2980B9), dark: NSColor(hex: 0x3498DB))
    static let red   = Color(light: NSColor(hex: 0xE74C3C), dark: NSColor(hex: 0xE74C3C))

    static let chrome        = Color(light: NSColor(hex: 0xD6DAE3), dark: NSColor(hex: 0x232830))
    static let toolbar       = Color(light: NSColor(hex: 0xEBEEF3), dark: NSColor(hex: 0x171B21))
    static let tabActiveBg   = Color(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x1C2028))

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 7
        static let lg: CGFloat = 10
    }

    enum Font {
        static func label(_ size: CGFloat = 10.5, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
    }
}
