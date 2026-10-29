import Foundation

/// Supersätze (Idee 28): `PlanUebung.supersatz == true` koppelt eine Übung mit der nächsten im Tag. Beide Übungen wechseln sich
/// satzweise ab, die Pause kommt nur einmal je Runde. Cardio zählt nie als Paar; eine Kette ergibt Paare von vorn (A+B, C allein).
enum SupersatzLogik {
    /// Die Blöcke eines Tages als Indizes: Einzelübungen und Paare.
    static func bloecke(_ uebungen: [PlanUebung]) -> [[Int]] {
        var aus: [[Int]] = []
        var i = 0
        while i < uebungen.count {
            if uebungen[i].supersatz == true, !uebungen[i].istCardio, i + 1 < uebungen.count, !uebungen[i + 1].istCardio {
                aus.append([i, i + 1])
                i += 2
            } else {
                aus.append([i])
                i += 1
            }
        }
        return aus
    }

    /// Der Block, zu dem die Übung an `index` gehört.
    static func paar(_ index: Int, in uebungen: [PlanUebung]) -> [Int] {
        bloecke(uebungen).first { $0.contains(index) } ?? [index]
    }

    /// Koppelt Übung `i` mit der nächsten (oder löst die Kopplung). Die letzte Übung und Cardio lassen sich nicht koppeln.
    static func koppeln(_ uebungen: [PlanUebung], _ i: Int, an: Bool) -> [PlanUebung] {
        guard uebungen.indices.contains(i) else { return uebungen }
        var neu = uebungen
        let moeglich = i + 1 < uebungen.count && !uebungen[i].istCardio && !uebungen[i + 1].istCardio
        neu[i].supersatz = an && moeglich ? true : nil
        return neu
    }

    /// Der nächste offene Satz mit Supersätzen: in einem Paar kommt die Übung mit weniger Haken dran (bei Gleichstand die erste),
    /// sonst wie `WorkoutLogik.dran`. nil = alles fertig.
    static func dran(_ liste: [WorkoutUebung]) -> (uebung: Int, satz: Int)? {
        for block in bloecke(liste.map(\.planUebung)) {
            let offen = block.filter { !liste[$0].fertig && !liste[$0].ausgelassen }
            guard let erste = offen.min(by: { (liste[$0].fertigZahl, $0) < (liste[$1].fertigZahl, $1) }) else { continue }
            let u = liste[erste]
            if u.planUebung.istCardio { return (erste, 0) }
            if let j = u.saetze.firstIndex(where: { $0.ok != true }) { return (erste, j) }
        }
        return nil
    }
}
