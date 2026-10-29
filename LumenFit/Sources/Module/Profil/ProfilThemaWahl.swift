import SwiftUI

/// Themenwahl der Aussehen-Seite (Idee 73): fünf Themes, drei Erscheinungen, wirkt sofort über `EinstellungenStore`.
enum ProfilThemaWahl {
    /// Diese zwei Themes sind für Dunkel gedacht: beim ersten Aktivieren schaltet die Erscheinung von System auf Dunkel.
    static let dunkelVorwahl: Set<ThemaID> = [.graphit, .glut]

    /// Die Einstellungen nach dem Antippen einer Theme-Karte. Graphit und Glut wählen beim Aktivieren einmalig Dunkel vor, aber nur,
    /// wenn die Erscheinung noch auf System steht (wer Hell oder Dunkel selbst gewählt hat, behält es); danach ändert der Nutzer frei.
    static func waehle(_ thema: ThemaID, aktuell: Einstellungen) -> Einstellungen {
        var neu = aktuell
        neu.thema = thema
        if thema != aktuell.thema, dunkelVorwahl.contains(thema), aktuell.erscheinung == .system { neu.erscheinung = .dunkel }
        return neu
    }

    static func istDunkel(_ erscheinung: Erscheinung, systemDunkel: Bool) -> Bool {
        switch erscheinung {
        case .system: systemDunkel
        case .hell: false
        case .dunkel: true
        }
    }

    /// Alle zehn Kombinationen aus Theme und hell/dunkel.
    static let kombinationen: [(thema: ThemaID, dunkel: Bool)] = ThemaID.allCases.flatMap { t in [(thema: t, dunkel: false), (thema: t, dunkel: true)] }

    static func muster(_ thema: ThemaID) -> String {
        switch thema {
        case .monochrom: "Punkte"
        case .graphit: "Diagonalen"
        case .stahl: "Raster"
        case .glut: "Wellen"
        case .wald: "Höhenlinien"
        }
    }

    static func beschreibung(_ thema: ThemaID) -> String {
        switch thema {
        case .monochrom: "Schwarz und Weiß, ruhig wie Apple. Folgt dem System."
        case .graphit: "Weiches Grau, am schönsten im Dunkeln."
        case .stahl: "Kühles Blau auf hellem Grund."
        case .glut: "Warmes Orange, am schönsten im Dunkeln."
        case .wald: "Gedämpftes Grün, ruhig und natürlich."
        }
    }
}

/// Mini-Vorschau einer Theme-Karte: Grundfläche, Karte, Akzent und das Muster des Themes in der aktuellen Erscheinung.
struct ProfilThemaVorschau: View {
    let thema: ThemaID
    let dunkel: Bool
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        let palette = LumenFarben.palette(thema: thema, dunkel: dunkel, kontrastHoch: kontrast == .increased)
        ZStack(alignment: .bottomLeading) {
            palette.grund
            MusterFlaeche(thema: thema, ort: .kopf)
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Capsule().fill(palette.akzent).frame(width: 36, height: 8)
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(palette.flaeche).frame(height: 22)
                    .overlay(alignment: .leading) { Capsule().fill(palette.text2).frame(width: 40, height: 4).padding(.leading, Abstand.s) }
            }
            .padding(Abstand.s)
        }
        .environment(\.palette, palette)
        .environment(\.colorScheme, dunkel ? .dark : .light)
        .frame(height: 76)
        .clipShape(.rect(cornerRadius: Rundung.klein, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Rundung.klein, style: .continuous).stroke(palette.rand, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
