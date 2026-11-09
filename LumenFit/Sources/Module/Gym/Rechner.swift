// Quelle: Lovea Health/Workout.swift (Aufwärmrechner, ausgelagert)
import Foundation

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
