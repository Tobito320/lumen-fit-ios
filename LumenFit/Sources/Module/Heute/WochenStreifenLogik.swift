import Foundation

/// Ein Tag des Wochenstreifens (Idee 20): Montag bis Sonntag, je Tag drei kleine Bögen mit denselben Bereichen wie die Ringplatte.
struct HeuteWochenTag: Equatable, Sendable, Identifiable {
    var tag: String
    var kuerzel: String
    var istHeute: Bool
    var zukunft: Bool
    /// 0 bis 1 je Bereich; Tage in der Zukunft haben 0.
    var schritte: Double
    var gym: Double
    var schlaf: Double
    var id: String { tag }

    /// Mittel der drei Bereiche, für die Reihenfolge "beste Tage" und die Beschreibung.
    var gesamt: Double { (schritte + gym + schlaf) / 3 }

    func anteil(_ bereich: Datenbereich) -> Double {
        switch bereich {
        case .bewegen: schritte
        case .trainieren: gym
        case .erholen: schlaf
        }
    }
}

enum WochenStreifenLogik {
    /// Die sieben Tage der Woche von `heute`. Schritte und Schlaf gegen ihr Ziel (bei Überschuss 1), Gym als 1 an einem Tag mit Einheit oder Haken.
    static func woche(heute: String, schritte: [String: Int], schlafMinuten: [String: Int], gymTage: Set<String>,
                      schritteZiel: Int, schlafZiel: Int) -> [HeuteWochenTag] {
        HabitLogik.wochenTage(heute: heute).enumerated().map { index, tag in
            let zukunft = tag > heute
            func anteil(_ ist: Int?, _ ziel: Int) -> Double {
                guard !zukunft, let ist, ziel > 0 else { return 0 }
                return min(1, max(0, Double(ist) / Double(ziel)))
            }
            return HeuteWochenTag(tag: tag, kuerzel: HabitLogik.wochentagKuerzel[index], istHeute: tag == heute, zukunft: zukunft,
                             schritte: anteil(schritte[tag], schritteZiel), gym: !zukunft && gymTage.contains(tag) ? 1 : 0,
                             schlaf: anteil(schlafMinuten[tag], schlafZiel))
        }
    }

    /// Tage der Woche von `heute` bis heute mit Gym (Einheit oder Haken), für den Gym-Bogen.
    static func gymTageDerWoche(heute: String, sessions: [GymSession], haken: [String: Int]) -> Set<String> {
        let woche = Set(HabitLogik.wochenTage(heute: heute).filter { $0 <= heute })
        var tage = Set(sessions.map { Datum.text($0.start) })
        for (tag, wert) in haken where wert > 0 { tage.insert(tag) }
        return tage.intersection(woche)
    }

    /// Alle Tage mit Gym aus Einheiten und Haken (nicht nur die laufende Woche).
    static func gymTage(sessions: [GymSession], haken: [String: Int]) -> Set<String> {
        var tage = Set(sessions.map { Datum.text($0.start) })
        for (tag, wert) in haken where wert > 0 { tage.insert(tag) }
        return tage
    }

    /// "Montag: Schritte 80 %, Gym ja, Schlaf 95 %" für VoiceOver.
    static func beschreibung(_ t: HeuteWochenTag, bereiche: Einstellungen = Einstellungen()) -> String {
        if t.zukunft { return "\(Datum.anzeige(t.tag)): noch nicht dran" }
        let prozent = { (x: Double) in "\(Int((x * 100).rounded())) %" }
        var teile = ["Schritte \(prozent(t.schritte))"]
        if bereiche.gymAn { teile.append("Gym \(t.gym > 0 ? "ja" : "nein")") }
        if bereiche.schlafAn { teile.append("Schlaf \(prozent(t.schlaf))") }
        return "\(Datum.anzeige(t.tag)): " + teile.joined(separator: ", ")
    }
}
