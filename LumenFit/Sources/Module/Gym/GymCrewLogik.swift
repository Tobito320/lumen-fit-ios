import Foundation

enum CrewZustand: Int, Sendable {
    case imGym, heuteDa, geplant, noch, veraltet, pausiert

    /// Reihenfolge in der Liste: im Gym, heute da, geplant, der Rest.
    fileprivate var rang: Int { min(rawValue, CrewZustand.noch.rawValue) }
}

/// Eine Person in der Crew-Liste des Gym-Tabs.
struct CrewZeile: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var status: String
    var zustand: CrewZustand
    /// Nur wenn die Person gerade trainiert und ihre Sätze freigibt (`GymMitlaufLogik`).
    var mitlauf: MitlaufSatz?
}

enum GymCrewLogik {
    /// So viele Personen stehen im Tab, der Rest als "+ n".
    static let sichtbar = 6

    /// Die Zeilen für `datum`: nur aktive Verbindungen mit Daten und mindestens einer Freigabe aus gym, verlauf, plan (pausierte immer, als "pausiert").
    /// Die Lovea-Person und jede Kennung nur einmal. Sortiert: im Gym, heute da, geplant, Rest (gleicher Rang bleibt in der Reihenfolge der Liste).
    static func zeilen(eintraege: [VerbindungEintrag], datum: String, heute: String, jetzt: Date) -> [CrewZeile] {
        var gesehen: Set<String> = []
        var loveaDa = false
        var zeilen: [CrewZeile] = []
        for e in eintraege where e.aktiv {
            if e.lovea { guard !loveaDa else { continue }; loveaDa = true }
            guard gesehen.insert(e.id).inserted, let z = zeile(e, datum: datum, heute: heute, jetzt: jetzt) else { continue }
            zeilen.append(z)
        }
        return zeilen.enumerated().sorted { ($0.element.zustand.rang, $0.offset) < ($1.element.zustand.rang, $1.offset) }.map(\.element)
    }

    private static func zeile(_ e: VerbindungEintrag, datum: String, heute: String, jetzt: Date) -> CrewZeile? {
        let name = e.anzeigeName.isEmpty ? (e.daten?.profilName ?? "") : e.anzeigeName
        if e.ich.pause { return CrewZeile(id: e.id, name: name, status: String(localized: "pausiert"), zustand: .pausiert) }
        guard let d = e.daten, d.freigaben.contains(where: { [.gym, .verlauf, .plan].contains($0) }) else { return nil }
        let tage = Int(jetzt.timeIntervalSince(d.geschrieben) / 86_400)
        if jetzt.timeIntervalSince(d.geschrieben) > LoveaVertrag.frist {
            return CrewZeile(id: e.id, name: name, status: String(localized: "zuletzt vor \(tage) Tagen"), zustand: .veraltet)
        }
        let status = GymPartnerLogik.status(d, datum: datum, heute: heute, jetzt: jetzt)
        let zustand: CrewZustand = switch status {
        case "gerade im Gym": .imGym
        case _ where status.hasPrefix("geplant"): .geplant
        case "noch nicht", "nicht im Gym", "nicht freigegeben", "Ruhetag": .noch
        default: .heuteDa
        }
        return CrewZeile(id: e.id, name: name, status: status, zustand: zustand, mitlauf: zustand == .imGym ? GymMitlaufLogik.letzterSatz(d, jetzt: jetzt) : nil)
    }
}
