import SwiftUI

/// Themenwahl der Aussehen-Seite (Idee 73): sechs Themes für alle, ein sechstes (Lovea) nur für die zwei freigegebenen Konten, drei Erscheinungen, wirkt sofort über `EinstellungenStore`.
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

    /// Lovea sehen und wählen nur Konten, die der Server freigibt (`KontoDienst.loveaErlaubt`), nie nach dem getippten Profilnamen.
    static func verfuegbar(loveaErlaubt: Bool) -> [ThemaID] {
        ThemaID.allCases.filter { $0 != .lovea || loveaErlaubt }
    }

    /// Das Theme, das wirklich gilt: ein gespeichertes Lovea ohne Freigabe (alter Stand, Freigabe zurückgenommen, von Hand gesetzt) fällt auf Monochrom zurück.
    /// Gespeichert wird nichts um; kommt die Freigabe wieder, gilt die Wahl wieder.
    static func wirksam(_ thema: ThemaID, loveaErlaubt: Bool) -> ThemaID {
        verfuegbar(loveaErlaubt: loveaErlaubt).contains(thema) ? thema : .monochrom
    }

    /// Alle Kombinationen aus Theme und hell/dunkel: vierzehn mit Lovea, sonst zwölf.
    static func kombinationen(loveaErlaubt: Bool) -> [(thema: ThemaID, dunkel: Bool)] {
        verfuegbar(loveaErlaubt: loveaErlaubt).flatMap { t in [(thema: t, dunkel: false), (thema: t, dunkel: true)] }
    }

    static func muster(_ thema: ThemaID) -> String {
        switch thema {
        case .schlicht: "Glatt"
        case .monochrom: "Punkte"
        case .graphit: "Diagonalen"
        case .stahl: "Raster"
        case .glut: "Wellen"
        case .wald: "Höhenlinien"
        case .lovea: "Flach"
        }
    }

    static func beschreibung(_ thema: ThemaID) -> String {
        switch thema {
        case .schlicht: "Ruhig und flach, eine Farbe: Grün. Folgt dem System."
        case .monochrom: "Schwarz und Weiß, ruhig wie Apple. Folgt dem System."
        case .graphit: "Weiches Grau, am schönsten im Dunkeln."
        case .stahl: "Kühles Blau auf hellem Grund."
        case .glut: "Warmes Orange, am schönsten im Dunkeln."
        case .wald: "Gedämpftes Grün, ruhig und natürlich."
        case .lovea: "Wie in Lovea: System-Flächen, Rosé als Akzent, ohne Muster."
        }
    }
}
