import Foundation

/// Eine Zeile der Seite "Sets je Muskel": Sets der Woche (Mitarbeit zählt halb) und das Wochenziel aus der Befragung (0 = keins).
struct FortSetsZeile: Equatable, Identifiable, Sendable {
    let gruppe: MuskelGruppe
    let saetze: Double
    let ziel: Int
    var id: MuskelGruppe { gruppe }
    /// Balken gegen das Ziel, ohne Ziel gegen 20 (Entwurf: "Gut sind 10 bis 20").
    var anteil: Double { min(1, max(0, saetze / Double(ziel > 0 ? ziel : FortSets.gutBis))) }
    var erreicht: Bool { ziel > 0 && saetze >= Double(ziel) }
}

/// Reine Rechnung der Seite "Sets je Muskel": Zeilen je Muskelgruppe und die Stufe der Hitzekarte (0, 1 bis 4, 5 bis 9, 10 und mehr).
enum FortSets {
    static let gutBis = 20

    /// Alle Gruppen in der Reihenfolge der Ziele (Prio zuerst), ohne Aufwärmsätze.
    static func zeilen(_ sessions: [GymSession], heute: String, ziele: KoerperZiele,
                       katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [FortSetsZeile] {
        let woche = teile(sessions, heute: heute, katalog: katalog)
        let reihenfolge = ziele.reihenfolge + MuskelGruppe.allCases.filter { !ziele.reihenfolge.contains($0) }
        return reihenfolge.map { g in
            FortSetsZeile(gruppe: g, saetze: MuskelTeil.allCases.filter { $0.gruppe == g }.reduce(0.0) { $0 + (woche[$1] ?? 0) }, ziel: ziele.saetze[g] ?? 0)
        }
    }

    /// Sets der Woche je Muskelteil, ohne Aufwärmen.
    static func teile(_ sessions: [GymSession], heute: String, katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [MuskelTeil: Double] {
        MuskelLogik.wochenSaetze(SaetzeProMuskel.ohneAufwaermen(sessions), woche: heute, katalog: katalog)
    }

    /// 0 = kein Set, 1 = 1 bis 4, 2 = 5 bis 9, 3 = 10 und mehr (ein halbes Set aus Mitarbeit zählt schon als 1 bis 4).
    static func stufe(_ saetze: Double) -> Int {
        switch saetze {
        case ..<0.5: 0
        case ..<5: 1
        case ..<10: 2
        default: 3
        }
    }
}
