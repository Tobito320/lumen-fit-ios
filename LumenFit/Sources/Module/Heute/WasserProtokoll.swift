import Foundation

/// Wann wie viel getrunken wurde: aus den `habit.setzen`-Ops der Wasser-Gewohnheit eines Tages. Nur Erhöhungen zählen; Zurücknehmen löscht den Eintrag nicht,
/// sondern senkt den Stand, den die nächste Erhöhung dann wieder aufholt.
struct WasserEintrag: Identifiable, Equatable, Sendable {
    let zeit: Date
    let glaeser: Int
    var id: Date { zeit }
}

enum WasserProtokoll {
    static func eintraege(ops: [Op], profil: ProfilID, tag: String) -> [WasserEintrag] {
        let folge = ops.filter { $0.art == "habit.setzen" && $0.von == profil }
            .compactMap { op in op.daten(HabitSetzenD.self).map { (op.zeit, $0) } }
            .filter { $0.1.art == Habit.wasser.id && $0.1.datum == tag }
            .sorted { $0.0 < $1.0 }
        var stand = 0
        var liste: [WasserEintrag] = []
        for (zeit, d) in folge {
            if d.wert > stand { liste.append(WasserEintrag(zeit: zeit, glaeser: d.wert - stand)) }
            stand = d.wert
        }
        return liste
    }

    /// "14:32 · +1 Glas".
    static func text(_ e: WasserEintrag) -> String {
        "\(Datum.uhrzeit(e.zeit)) · +\(e.glaeser) \(e.glaeser == 1 ? "Glas" : "Gläser")"
    }
}
