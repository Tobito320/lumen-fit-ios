import Foundation

/// Der 12-Wochen-Ausblick einer Hauptübung: Vergangenheit (schwerster Satz je Woche ab der ersten Woche mit Wert) und die Projektion bis Woche 12.
struct FortAusblick: Equatable, Identifiable, Sendable {
    var uebungId: String
    var name: String
    /// Zwölf Werte in kg, Woche 1 zuerst.
    var punkte: [Double]
    /// Index der laufenden Woche ("Heute") in `punkte`; davor gemessen, danach geplant.
    var heute: Int
    /// Schritt alle zwei Wochen in kg.
    var schritt: Double
    var id: String { uebungId }
    /// "Woche 8" in der Zeile des Tabs.
    var woche: Int { heute + 1 }
}

/// Reine Rechnung des Ausblicks (Entwurf "12-Wochen-Ausblick"): Lücken übernehmen den letzten Wert; danach alle zwei Wochen ein Schritt,
/// 2,5 kg (unter 20 kg nur 1 kg), der erste gleich in der nächsten Woche. Ein Plan, kein Versprechen.
enum FortAusblickLogik {
    static let wochen = 12

    static func ausblick(_ z: GewichtZeile) -> FortAusblick? {
        guard let erste = z.wochen.firstIndex(where: { $0 != nil }) else { return nil }
        var vergangen: [Double] = []
        var letzter = 0.0
        for w in z.wochen[erste...] {
            if let w { letzter = w }
            vergangen.append(letzter)
        }
        let schritt = letzter < 20 ? 1.0 : 2.5
        let zukunft = (0..<max(0, wochen - vergangen.count)).map { i in letzter + schritt * Double((i + 2) / 2) }
        return FortAusblick(uebungId: z.uebungId, name: z.name, punkte: vergangen + zukunft, heute: vergangen.count - 1, schritt: schritt)
    }

    /// Die ersten drei Hauptübungen (Reihenfolge des Plans) mit Ausblick.
    static func hauptuebungen(_ zeilen: [GewichtZeile]) -> [FortAusblick] {
        Array(zeilen.compactMap(ausblick).prefix(3))
    }
}
