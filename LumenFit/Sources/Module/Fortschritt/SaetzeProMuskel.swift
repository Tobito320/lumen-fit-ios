import Foundation

/// Eine Zeile "Sätze je Muskel gegen Ziel": die Woche in Sätzen und das Wochenziel.
struct MuskelSatzZeile: Identifiable, Equatable, Sendable {
    let gruppe: MuskelGruppe
    /// Gezählte Sätze der Woche; Mitarbeit zählt halb (`MuskelLogik.teile`).
    let saetze: Double
    let ziel: Int

    var id: MuskelGruppe { gruppe }
    /// 0 bis 1 gegen das Ziel, darüber gekappt.
    var anteil: Double { ziel > 0 ? min(1, max(0, saetze / Double(ziel))) : 0 }
    var erreicht: Bool { ziel > 0 && saetze >= Double(ziel) }

    /// "9 von 12", halbe Sätze mit Komma ("4,5 von 8").
    var text: String { String(localized: "\(VerlaufLogik.zahl(saetze)) von \(ziel)") }
}

/// Idee 32: Wochenbalken je Muskelgruppe mit Zielzahl und Wert rechts. Aufwärmsätze zählen nicht.
enum SaetzeProMuskel {
    /// Die Einheiten ohne Aufwärmsätze: ein Lauf, der nur aus Aufwärmen bestand, zählt gar nicht. Alte "fertig"-Läufe können Aufwärmsätze enthalten, neue nicht.
    static func ohneAufwaermen(_ sessions: [GymSession]) -> [GymSession] {
        sessions.map { s in
            var neu = s
            neu.laeufe = s.laeufe.map { lauf in
                var l = lauf
                let arbeit = (lauf.saetze ?? []).filter { $0.typ != "w" }
                l.saetze = arbeit.isEmpty ? nil : arbeit
                return l
            }
            return neu
        }
    }

    /// Je Gruppe in der Reihenfolge der Ziele (Prio zuerst): Sätze der Woche von `heute` gegen das Ziel. Gruppen mit Ziel 0 fehlen.
    static func zeilen(_ sessions: [GymSession], heute: String, ziele: KoerperZiele,
                       katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [MuskelSatzZeile] {
        let woche = MuskelLogik.wochenSaetze(ohneAufwaermen(sessions), woche: heute, katalog: katalog)
        return ziele.reihenfolge.compactMap { g in
            let ziel = ziele.saetze[g] ?? 0
            guard ziel > 0 else { return nil }
            let saetze = MuskelTeil.allCases.filter { $0.gruppe == g }.reduce(0.0) { $0 + (woche[$1] ?? 0) }
            return MuskelSatzZeile(gruppe: g, saetze: saetze, ziel: ziel)
        }
    }

    /// Die Aussage als Titel: "4 von 9 Muskelgruppen im Wochenziel".
    static func aussage(_ zeilen: [MuskelSatzZeile]) -> String {
        guard !zeilen.isEmpty else { return String(localized: "Noch keine Wochenziele") }
        let im = zeilen.filter(\.erreicht).count
        return String(localized: "\(im) von \(zeilen.count) Muskelgruppen im Wochenziel")
    }

    /// Die Kernzeile: die Gruppe, die am meisten fehlt, und wie viele Sätze.
    static func kernzeile(_ zeilen: [MuskelSatzZeile]) -> String {
        let summe = zeilen.reduce(0) { $0 + $1.saetze }
        guard summe > 0 else { return String(localized: "Diese Woche noch kein Satz. Tipp auf Starten, Lumi zählt mit.") }
        guard let offen = zeilen.filter({ !$0.erreicht }).max(by: { Double($0.ziel) - $0.saetze < Double($1.ziel) - $1.saetze }) else {
            return String(localized: "Alle Wochenziele sind erreicht.")
        }
        let fehlt = Double(offen.ziel) - offen.saetze
        return String(localized: "Am meisten fehlt \(offen.gruppe.name): noch \(VerlaufLogik.saetzeText(fehlt)).")
    }
}
