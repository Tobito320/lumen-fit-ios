import Foundation

/// Kleine reine Hilfen, die aus dem Gesundheitsstand und dem Datensatz die Eingaben für Bereit-Score, Gewicht und Hinweise bauen.
enum HeuteQuellen {
    /// Der neueste Vitalwert von heute oder gestern und die Werte davor (neueste zuerst, bis 60) als Vergleich.
    /// Ein Wert von vorgestern oder älter gilt nicht als "heute": dann fehlt der Teil, statt mit einem alten Wert zu rechnen.
    static func vital(_ werte: [VitalMesswert], heute: String) -> (aktuell: Double?, basis: [Double]) {
        let gestern = Datum.addTage(heute, -1)
        let sortiert = werte.filter { $0.tag <= heute && $0.wert.isFinite }.sorted { $0.tag > $1.tag }
        guard let neuester = sortiert.first, neuester.tag >= gestern else { return (nil, []) }
        let basis = sortiert.dropFirst().filter { $0.tag < neuester.tag }.prefix(60).map(\.wert)
        return (neuester.wert, Array(basis))
    }

    /// Gezählte (fertige) Sätze je Tag.
    static func saetzeProTag(_ sessions: [GymSession]) -> [String: Int] {
        var je: [String: Int] = [:]
        for s in sessions {
            let n = s.laeufe.filter { $0.fertig }.reduce(0) { $0 + ($1.saetze?.count ?? 0) }
            je[Datum.text(s.start), default: 0] += n
        }
        return je
    }

    /// Tageslast ab gestern, neuester zuerst, 31 Tage: aktive kcal plus `BereitScore.satzKcal` je Gym-Satz. nil = für den Tag weder Health noch Gym.
    static func tageslast(heute: String, tage: [String: TagesWerte], saetze: [String: Int]) -> [Double?] {
        (1...31).map { i -> Double? in
            let tag = Datum.addTage(heute, -i)
            let n = saetze[tag] ?? 0
            guard tage[tag] != nil || n > 0 else { return nil }
            return (tage[tag]?.aktiveKcal ?? 0) + BereitScore.satzKcal * Double(n)
        }
    }

    /// Gewicht je Tag in Zehntel-kg: Health, darüber das von Hand Eingetragene (der Haken `gewicht` gewinnt am selben Tag).
    static func gewichtWerte(health: [GewichtsMesswert], manuell: [String: Int]) -> [String: Int] {
        var werte: [String: Int] = [:]
        for g in health where g.kg.isFinite && g.kg > 0 { werte[g.tag] = Int((g.kg * 10).rounded()) }
        for (tag, zehntel) in manuell where zehntel > 0 { werte[tag] = zehntel }
        return werte
    }

    /// Das Eingabe-Gewicht in Zehntel-kg; ein Zahlenrad steht in 0,1-kg-Schritten (30,0 bis 249,9 kg, `Koerpermasse`).
    static let gewichtBereich = Koerpermasse.gewichtZehntel

    /// "1.234" mit deutschem Tausenderpunkt.
    static func zahl(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }
}
