import SwiftUI

/// Ein Theme, hell und dunkel nach Erscheinung (Auftrag 09.11.: "Ein theme. Dark/white. Kein wählbarer Theme."). Die `ThemaID`-Fälle bleiben, weil
/// alte Dateien und Snapshots sie tragen; sie wirken nicht mehr.
enum ProfilThemaWahl {
    static func istDunkel(_ erscheinung: Erscheinung, systemDunkel: Bool) -> Bool {
        switch erscheinung {
        case .system: systemDunkel
        case .hell: false
        case .dunkel: true
        }
    }

    /// Das Theme, das wirklich gilt: immer Schlicht, was auch gespeichert ist (Gespeichert wird nichts umgeschrieben).
    static func wirksam(_ thema: ThemaID, loveaErlaubt: Bool) -> ThemaID { .schlicht }
}
