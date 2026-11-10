import Foundation

/// Ein Rekord auf der Seite "Geschafft": Übung und ihr bester Satz heute.
struct GeschafftRekord: Equatable, Sendable {
    let uebung: String
    let text: String
}

/// Was die Seite "Geschafft" zeigt (Entwurf `geschafft`): Kacheln, Rekorde, trainierte Muskeln, Lumi.
struct GeschafftStand: Equatable, Sendable {
    let titel: String
    let datum: Date
    let sekunden: TimeInterval
    let saetze: Int
    let volumen: Double
    let rekorde: [GeschafftRekord]
    /// Hauptmuskeln aller Übungen mit mindestens einem abgehakten Satz.
    let muskeln: Set<MuskelTeil>

    var stimmung: LumiStimmung { rekorde.isEmpty ? .ziel : .stolz }
}

/// Rechnet die Seite aus dem gespeicherten Training: die Sitzung ist nach `beende()` schon leer, das Training im Store bleibt.
enum GeschafftLogik {
    /// Das zuletzt beendete Training (die Seite kommt direkt nach dem Beenden).
    static func letzte(_ sessions: [GymSession]) -> GymSession? {
        sessions.filter { $0.ende != nil }.max { $0.start < $1.start }
    }

    static func stand(_ s: GymSession, tag: TrainingsTag?, alle: [GymSession], katalog: (PlanUebung) -> Uebung?, jetzt: Date) -> GeschafftStand {
        let frueher = alle.filter { $0.id != s.id && $0.start < s.start }
        let liste = WorkoutLogik.uebungen(s, tag: tag, frueher: frueher)
        var rekorde: [GeschafftRekord] = []
        var muskeln: Set<MuskelTeil> = []
        for u in liste {
            let saetze = u.saetze.filter(\.zaehlt)
            guard u.fertigZahl > 0 else { continue }
            if let teil = katalog(u.planUebung).flatMap(KoerperLogik.haupt) { muskeln.insert(teil) }
            let tage = RekordLogik.tage(katalogId: u.planUebung.uebung, planId: u.id, in: frueher)
            guard !RekordLogik.neue(saetze, gegen: tage).isEmpty,
                  let bester = saetze.max(by: { (RekordLogik.e1rm($0) ?? Double($0.wdh)) < (RekordLogik.e1rm($1) ?? Double($1.wdh)) }) else { continue }
            rekorde.append(GeschafftRekord(uebung: u.planUebung.anzeigeName, text: WorkoutLogik.satzText(bester)))
        }
        let titel = tag.map { $0.name.isEmpty ? String(localized: "Training") : $0.name } ?? String(localized: "Freies Training")
        return GeschafftStand(titel: titel, datum: s.start, sekunden: (s.ende ?? jetzt).timeIntervalSince(s.start),
                              saetze: WorkoutLogik.saetzeZahl(liste), volumen: WorkoutLogik.volumen(liste),
                              rekorde: rekorde, muskeln: muskeln)
    }
}
