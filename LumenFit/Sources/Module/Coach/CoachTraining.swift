import Foundation

// Health-Coach kennt das Training (Idee 66): aus den Einheiten wird der Kontext des Coachs, ohne dass die Person etwas kopiert: das letzte
// Training als eine Zeile, die Rekorde der letzten Wochen, die Wochensätze je Muskelgruppe und die Vorschläge fürs nächste Mal.
// Reine Logik: Einheiten, Plan und Zeit kommen von außen. Der Katalog ist ein Parameter, damit Tests ohne Bundle laufen.
//
// Nicht aus Lovea übernommen: `CoachTraining` steuerte dort das laufende Training per Marker (Satz eintragen, Übung tauschen). Das braucht
// `WorkoutLogik` des Moduls gym; in Lumen Fit führen Chips nur Handlungen des Coachs aus (`CoachTracking`).

enum CoachTraining {
    typealias Katalog = (String) -> Uebung?

    // MARK: - Letztes Training

    /// "Push, gestern, 52 Minuten, 14 Sätze": die jüngste Einheit mit mindestens einem Arbeitssatz. `nil` ohne Einheit.
    static func letztesTraining(_ sessions: [GymSession], plan: TrainingsPlan, jetzt: Date) -> String? {
        let mitSaetzen = sessions.filter { saetze($0) > 0 }
        guard let letzte = mitSaetzen.max(by: { $0.start < $1.start }) else { return nil }
        let name = plan.tag(id: letzte.tag)?.name ?? "Training"
        var teile = [name, wann(letzte.start, jetzt: jetzt)]
        if let ende = letzte.ende {
            let minuten = Int((ende.timeIntervalSince(letzte.start) / 60).rounded())
            if minuten > 0 { teile.append("\(minuten) Minuten") }
        }
        teile.append("\(saetze(letzte)) Sätze")
        return teile.joined(separator: ", ")
    }

    /// Arbeitssätze einer Einheit (ohne Aufwärmsätze) in den abgeschlossenen Übungen.
    static func saetze(_ session: GymSession) -> Int {
        session.laeufe.reduce(0) { summe, lauf in
            summe + (lauf.saetze ?? []).filter { $0.typ != "w" }.count
        }
    }

    static func wann(_ start: Date, jetzt: Date) -> String {
        let tage = Datum.tageZwischen(Datum.text(start), Datum.text(jetzt))
        switch tage {
        case ..<1: return "heute"
        case 1: return "gestern"
        default: return "vor \(tage) Tagen"
        }
    }

    // MARK: - Rekorde

    struct Rekord: Equatable, Sendable {
        let uebung: String
        let kg: Double
        let wdh: Int
        let tag: String

        var text: String { "\(uebung) \(TrainingLogik.kgText(kg)) kg × \(wdh)" }
    }

    /// Die besten Sätze je Übung (geschätztes Einerwiederholungsmaximum nach Epley), die in den letzten `tage` Tagen aufgestellt wurden,
    /// neueste zuerst, höchstens `maximal`. Ein Rekord zählt nur, wenn davor schon trainiert wurde (der allererste Satz ist keiner).
    static func rekorde(_ sessions: [GymSession], heute: String, tage: Int = 14, maximal: Int = 3, katalog: Katalog = { UebungsKatalog.nachId[$0] }) -> [Rekord] {
        var bester: [String: (wert: Double, rekord: Rekord, vorher: Bool)] = [:]
        for session in sessions.sorted(by: { $0.start < $1.start }) {
            for lauf in session.laeufe {
                for satz in lauf.saetze ?? [] where satz.typ != "w" && satz.wdh > 0 {
                    guard let kg = satz.kg, kg > 0 else { continue }
                    let wert = kg * (1 + Double(satz.wdh) / 30)
                    let name = katalog(lauf.uebung)?.name ?? lauf.name ?? lauf.uebung
                    let hatteSchon = bester[lauf.uebung] != nil
                    if wert > (bester[lauf.uebung]?.wert ?? 0) {
                        bester[lauf.uebung] = (wert, Rekord(uebung: name, kg: kg, wdh: satz.wdh, tag: Datum.text(session.start)), hatteSchon)
                    }
                }
            }
        }
        return bester.values
            .filter { $0.vorher && Datum.tageZwischen($0.rekord.tag, heute) <= tage }
            .map(\.rekord)
            .sorted { ($0.tag, $0.uebung) > ($1.tag, $1.uebung) }
            .prefix(maximal).map { $0 }
    }

    // MARK: - Wochensätze

    /// Je Muskelgruppe die Sätze dieser Woche (höchster Teil der Gruppe) gegen das Wochenziel. Nur Gruppen, die in den letzten 28 Tagen
    /// trainiert wurden: wer Arme nie trainiert, bekommt keine Mahnung dafür.
    static func gruppen(_ sessions: [GymSession], heute: String, katalog: Katalog = { UebungsKatalog.nachId[$0] }) -> [CoachGruppe] {
        let woche = MuskelLogik.wochenSaetze(sessions, woche: heute, katalog: katalog)
        let ab = Datum.addTage(heute, -28)
        let frisch = sessions.filter { Datum.text($0.start) >= ab }
        var trainiert: Set<MuskelGruppe> = []
        for session in frisch {
            for teil in MuskelLogik.wochenSaetze([session], woche: Datum.text(session.start), katalog: katalog).keys { trainiert.insert(teil.gruppe) }
        }
        return MuskelGruppe.allCases.filter { trainiert.contains($0) }.map { gruppe in
            let saetze = woche.filter { $0.key.gruppe == gruppe }.map(\.value).max() ?? 0
            let ziel = MuskelLogik.standardZiel(gruppe, prio: MuskelGruppe.standardPrio.contains(gruppe))
            return CoachGruppe(name: gruppe.name, saetze: saetze, ziel: ziel, faellig: saetze < Double(ziel) / 2)
        }
    }

    // MARK: - Fürs nächste Mal

    /// Die Übungen der jüngsten Einheit mit Vorschlag fürs nächste Mal (doppelte Progression), höchstens fünf.
    static func uebungen(_ sessions: [GymSession], katalog: Katalog = { UebungsKatalog.nachId[$0] }) -> [CoachUebung] {
        guard let letzte = sessions.filter({ saetze($0) > 0 }).max(by: { $0.start < $1.start }) else { return [] }
        var liste: [CoachUebung] = []
        for lauf in letzte.laeufe {
            let arbeit = (lauf.saetze ?? []).filter { $0.typ != "w" }
            guard let vorschlag = CoachSteigerung.naechstesMal(arbeit) else { continue }
            if katalog(lauf.uebung)?.istCardio == true { continue }
            let name = katalog(lauf.uebung)?.name ?? lauf.name ?? lauf.uebung
            liste.append(CoachUebung(name: name, vorschlag: vorschlag))
        }
        return Array(liste.reversed().prefix(5))
    }
}
