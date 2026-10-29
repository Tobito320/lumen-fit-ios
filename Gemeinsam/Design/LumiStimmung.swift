import SwiftUI

extension LumiStimmung {
    /// Für den Satz neben Lumi und für VoiceOver ("Lumi ist müde").
    var beschreibung: String {
        switch self {
        case .bereit: "Lumi ist bereit"
        case .muede: "Lumi ist müde"
        case .stolz: "Lumi ist stolz"
        case .schlaeft: "Lumi schläft"
        case .denkt: "Lumi denkt nach"
        }
    }

    /// Farben des Körpers (Mitte nach Rand), Hof, Füße, Arme, Kontur und Gesichtsfarbe: Stand v10, fest in Hell und Dunkel.
    struct Farbsatz: Sendable {
        let verlauf: [UInt32]       // vier Stufen bei 0, 0,45, 0,85 und 1
        let hof: UInt32
        let fuss: UInt32
        let arm: UInt32
        let kontur: UInt32
        let gesicht: UInt32
    }

    var farbsatz: Farbsatz {
        switch self {
        case .bereit, .denkt:
            Farbsatz(verlauf: [0xFFF8D6, 0xFFD95A, 0xFFAE1F, 0xF07E00], hof: 0xFFD95A, fuss: 0xF07E00, arm: 0xFFAE1F, kontur: 0xF07E00, gesicht: 0x3A2200)
        case .muede, .schlaeft:
            Farbsatz(verlauf: [0xE4E8FF, 0xA9B4FF, 0x6E74F0, 0x4B47C9], hof: 0xA9B4FF, fuss: 0x4B47C9, arm: 0x6E74F0, kontur: 0x4B47C9, gesicht: 0x2B2552)
        case .stolz:
            Farbsatz(verlauf: [0xFFE7A8, 0xFF9A4A, 0xFA4A5E, 0xC81E4A], hof: 0xFF9A4A, fuss: 0xC81E4A, arm: 0xFA4A5E, kontur: 0xC81E4A, gesicht: 0x3D0716)
        }
    }
}
