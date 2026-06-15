import SwiftUI
import UIKit

/// The warm, notebook-like palette from the brief, with light/dark variants
/// that mirror styles.css. Colours resolve automatically to the active scheme.
enum Palette {
    static let bg          = dyn(light: "faf6f0", dark: "131316")
    static let surface     = dyn(light: "fffdfa", dark: "1c1c21")
    static let surface2    = dyn(light: "f3ede4", dark: "25252c")
    static let text        = dyn(light: "2a2622", dark: "ece8e3")
    static let textSoft    = dyn(light: "6f6760", dark: "9b938a")
    static let border      = dyn(light: "e7ded2", dark: "2e2e36")
    static let accent      = dyn(light: "e08a5b", dark: "e89b6e")
    static let accentSoft  = dyn(light: "f7e3d6", dark: "3a2e26")
    static let danger      = dyn(light: "c0573f", dark: "e07a63")

    private static func dyn(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: CGFloat
        if s.count == 6 {
            r = CGFloat((v & 0xFF0000) >> 16) / 255
            g = CGFloat((v & 0x00FF00) >> 8) / 255
            b = CGFloat(v & 0x0000FF) / 255
        } else {
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension View {
    /// Card surface used throughout the app.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}
