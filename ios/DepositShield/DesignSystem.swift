import SwiftUI
import UIKit

/// "Ledger" — the Deposit Shield design language, ported 1:1 from the web
/// app's palette (deep ink navy, warm paper, verified-emerald, brass accent,
/// clay for warnings) with an editorial serif display and a monospaced
/// hash/timestamp motif.
enum DS {
    // Ink (dark surfaces)
    static let ink      = Color(hex: 0x0B1220)
    static let ink700   = Color(hex: 0x1A2740)
    static let ink800   = Color(hex: 0x131B2E)

    // Paper (light surfaces)
    static let paper     = Color(hex: 0xFAF7F2)
    static let paperDim  = Color(hex: 0xF1EBE0)

    // Verified emerald
    static let emerald     = Color(hex: 0x0E9F6E)
    static let emeraldDark = Color(hex: 0x0B7D57)
    static let emerald50   = Color(hex: 0xE6F6F0)

    // Brass accent
    static let brass      = Color(hex: 0xB08D4C)
    static let brassLight = Color(hex: 0xD3B876)
    static let brass50    = Color(hex: 0xF7F1E3)

    // Clay (used sparingly — warnings, disputes)
    static let clay   = Color(hex: 0xC4553B)
    static let clay50 = Color(hex: 0xFBEAE6)

    // Ink-on-paper ink shades
    static let paperInkFaint = ink.opacity(0.55)
    static let hairline      = brass.opacity(0.28)

    /// Editorial serif display (stand-in for Fraunces on the web).
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let f = Font.system(size: size, weight: weight, design: .serif)
        return italic ? f.italic() : f
    }

    /// Monospaced hash/timestamp motif (stand-in for JetBrains Mono).
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
