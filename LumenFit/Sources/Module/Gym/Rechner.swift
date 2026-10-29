import Foundation

/// Scheibenrechner (Idee 25): welche Scheiben pro Seite auf die Stange. Stange 20 kg, Scheiben 25 bis 1,25 kg.
enum ScheibenRechner {
    nonisolated static let stange = 20.0
    nonisolated static let scheiben: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    struct Ergebnis: Equatable, Sendable {
        /// Scheiben pro Seite, schwerste zuerst.
        var proSeite: [Double]
        /// Tatsächlich erreichtes Gesamtgewicht mit diesen Scheiben.
        var erreicht: Double
        /// Gewünscht, aber mit den Scheiben nicht genau machbar (kleiner Rest).
        var rest: Double
        /// Das Ziel liegt unter der Stange.
        var unterStange: Bool
    }

    static func berechne(kg: Double, stange: Double = ScheibenRechner.stange, verfuegbar: [Double] = ScheibenRechner.scheiben) -> Ergebnis {
        guard kg >= stange else { return Ergebnis(proSeite: [], erreicht: stange, rest: 0, unterStange: kg < stange - 0.001) }
        var rest = (kg - stange) / 2
        var liste: [Double] = []
        for g in verfuegbar.sorted(by: >) {
            while rest >= g - 0.001 {
                liste.append(g)
                rest -= g
            }
        }
        let erreicht = stange + 2 * liste.reduce(0, +)
        return Ergebnis(proSeite: liste, erreicht: erreicht, rest: max(0, (kg - erreicht) * 100).rounded() / 100, unterStange: false)
    }

    /// Zahl mit bis zu zwei Nachkommastellen: 1,25 bleibt 1,25 (`TrainingLogik.kgText` rundet auf eine).
    static func zahl(_ wert: Double) -> String {
        wert.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "de_DE")))
    }

    /// "2 × 25, 10" oder "ohne Scheiben".
    static func text(_ e: Ergebnis) -> String {
        guard !e.proSeite.isEmpty else { return "ohne Scheiben" }
        var gruppen: [(Double, Int)] = []
        for s in e.proSeite {
            if let i = gruppen.firstIndex(where: { $0.0 == s }) { gruppen[i].1 += 1 } else { gruppen.append((s, 1)) }
        }
        return gruppen.map { $0.1 > 1 ? "\($0.1) × \(zahl($0.0))" : zahl($0.0) }.joined(separator: ", ")
    }
}

/// Aufwärmrechner (Idee 25): Aufwärmsätze in Prozent vom Arbeitsgewicht, auf 2,5 kg gerundet, nie unter 2,5 kg.
enum AufwaermRechner {
    struct Stufe: Equatable, Sendable {
        var prozent: Int
        var wdh: Int
    }

    /// 40 % × 10, 60 % × 5, 80 % × 3.
    nonisolated static let standard: [Stufe] = [Stufe(prozent: 40, wdh: 10), Stufe(prozent: 60, wdh: 5), Stufe(prozent: 80, wdh: 3)]

    static func saetze(arbeit: Double, stufen: [Stufe] = AufwaermRechner.standard) -> [PlanSatz] {
        guard arbeit > 0 else { return [] }
        return stufen.map { s in
            PlanSatz(wdh: s.wdh, kg: max(2.5, (arbeit * Double(s.prozent) / 100 / 2.5).rounded() * 2.5), failure: false, typ: "w")
        }
    }

    /// Fügt die Aufwärmsätze vor den ersten Arbeitssatz ein; schon vorhandene, noch offene Aufwärmsätze werden ersetzt; ist einer abgehakt, bleibt alles wie es ist.
    static func einfuegen(in saetze: [PlanSatz], arbeit: Double, stufen: [Stufe] = AufwaermRechner.standard) -> [PlanSatz] {
        let warm = Self.saetze(arbeit: arbeit, stufen: stufen)
        guard !warm.isEmpty, !saetze.contains(where: { $0.typ == "w" && $0.ok == true }) else { return saetze }
        return warm + saetze.filter { $0.typ != "w" }
    }

    /// "40 % × 10: 25 kg".
    static func zeile(_ satz: PlanSatz, prozent: Int) -> String {
        "\(prozent) % × \(satz.wdh): \(TrainingLogik.kgText(satz.kg ?? 0)) kg"
    }
}
