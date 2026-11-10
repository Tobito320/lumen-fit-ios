// Quelle: Lovea Health/Verlauf/VerlaufView.swift (nur VerlaufLogik; Ansichten und VerlaufZiel entfallen)
import Foundation

/// Numbers of the Verlauf tab: finished strength runs to counts per muscle group and per exercise.
/// Pure, no state. Sets per group are the sum over its parts (`MuskelLogik.teile`), like the Körper tab.
enum VerlaufLogik {
    /// One finished strength run with its sets. `tag` is `yyyy-MM-dd` of the session start.
    struct Lauf: Equatable {
        let session: String
        let tag: String
        let uebung: Uebung
        let saetze: [PlanSatz]
    }

    struct Zaehler: Equatable {
        var sessions: Set<String> = []
        var saetze = 0.0
        var einheiten: Int { sessions.count }

        mutating func zaehlen(_ session: String, _ n: Double) {
            sessions.insert(session)
            saetze += n
        }
    }

    struct Zeitraeume: Equatable {
        var woche = Zaehler()
        var monat = Zaehler()
        var gesamt = Zaehler()

        mutating func zaehlen(_ l: Lauf, saetze n: Double, heute: String, montag: String) {
            gesamt.zaehlen(l.session, n)
            if l.tag.prefix(7) == heute.prefix(7) { monat.zaehlen(l.session, n) }
            if Datum.montagDerWoche(l.tag) == montag { woche.zaehlen(l.session, n) }
        }
    }

    struct Tageseintrag: Equatable, Identifiable {
        let tag: String
        /// "60 × 8 · 65 × 8"
        let text: String
        var id: String { tag }
    }

    struct UebungsVerlauf: Equatable, Identifiable {
        let uebung: Uebung
        var monat = 0
        var gesamt = 0
        /// Newest first, one entry per day.
        var tage: [Tageseintrag] = []
        var e1rm: Double?
        var id: String { uebung.id }
    }

    /// A day of this week with training that gives the groups no set (`ohneSaetze`).
    struct TagOhneSaetze: Equatable, Identifiable {
        enum Art: Equatable {
            /// Only the Gym tick, no unit (also set by old "Schreib, was war" entries).
            case nurHaken
            /// A unit without a counted set: nothing ticked, or only warm-ups.
            case keinSatz
            /// Ticked sets, but only own exercises: they have no muscle group.
            case eigeneUebung
        }

        let tag: String
        let art: Art
        var id: String { tag }
    }

    private static let deutsch = Locale(identifier: "de_DE")

    /// Finished runs with sets, oldest first. Cardio, own exercises (not in the catalog) and runs
    /// ticked without sets give nothing.
    static func laeufe(_ sessions: [GymSession], katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [Lauf] {
        sessions.sorted { $0.start < $1.start }.flatMap { s in
            s.laeufe.compactMap { l in
                guard l.fertig, let n = l.saetze, !n.isEmpty, let u = katalog(l.uebung), !u.istCardio else { return nil }
                return Lauf(session: s.id, tag: Datum.text(s.start), uebung: u, saetze: n)
            }
        }
    }

    /// Days of the week of `heute` (Mo to So) with training but no counted set: only the Gym tick
    /// (`GymTageLogik.nurAbgehakt`), or a unit whose runs `laeufe` drops (nothing ticked, only warm-ups,
    /// own exercises). Same rule as the tiles, so hint and number cannot disagree. A unit that still
    /// runs (`TrainingLogik.laufend`) and finished Cardio are fine. Oldest first.
    static func ohneSaetze(_ sessions: [GymSession], gym: [String: Int], heute: String, jetzt: Date,
                           katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [TagOhneSaetze] {
        let montag = Datum.montagDerWoche(heute)
        let sonntag = Datum.addTage(montag, 6)
        var arten: [String: TagOhneSaetze.Art] = [:]
        for tag in GymTageLogik.nurAbgehakt(sessions: sessions, gym: gym) { arten[tag] = .nurHaken }
        for (tag, einheiten) in Dictionary(grouping: sessions, by: { Datum.text($0.start) }) {
            let laeuft = einheiten.contains { TrainingLogik.laufend($0, jetzt: jetzt) }
            let cardio = einheiten.contains { s in s.laeufe.contains { l in l.fertig && katalog(l.uebung)?.istCardio == true } }
            if laeuft || cardio || !laeufe(einheiten, katalog: katalog).isEmpty { continue }
            let eigene = einheiten.contains { s in s.laeufe.contains { l in l.fertig && !(l.saetze ?? []).isEmpty } }
            arten[tag] = eigene ? .eigeneUebung : .keinSatz
        }
        return arten.filter { $0.key >= montag && $0.key <= sonntag }
            .map { TagOhneSaetze(tag: $0.key, art: $0.value) }
            .sorted { $0.tag < $1.tag }
    }

    /// The line under the day in the hint.
    static func grund(_ art: TagOhneSaetze.Art) -> String {
        switch art {
        case .nurHaken: String(localized: "Gym abgehakt, keine Einheit gespeichert.")
        case .keinSatz: String(localized: "Kein Satz abgehakt. Aufwärmsätze zählen nicht.")
        case .eigeneUebung: String(localized: "Nur eigene Übungen. Sie haben keine Muskelgruppe.")
        }
    }

    /// Week (Mo to So), month and total per group. Groups without a run are missing.
    static func gruppen(_ laeufe: [Lauf], heute: String) -> [MuskelGruppe: Zeitraeume] {
        let montag = Datum.montagDerWoche(heute)
        var ergebnis: [MuskelGruppe: Zeitraeume] = [:]
        for l in laeufe {
            var proGruppe: [MuskelGruppe: Double] = [:]
            for (teil, faktor) in MuskelLogik.teile(l.uebung) { proGruppe[teil.gruppe, default: 0] += faktor * Double(l.saetze.count) }
            for (g, n) in proGruppe { ergebnis[g, default: Zeitraeume()].zaehlen(l, saetze: n, heute: heute, montag: montag) }
        }
        return ergebnis
    }

    static func uebung(_ u: Uebung, _ laeufe: [Lauf], heute: String) -> UebungsVerlauf {
        var v = UebungsVerlauf(uebung: u)
        var sessions = Set<String>(), imMonat = Set<String>()
        var proTag: [(tag: String, saetze: [PlanSatz])] = []
        for l in laeufe where l.uebung.id == u.id {
            sessions.insert(l.session)
            if l.tag.prefix(7) == heute.prefix(7) { imMonat.insert(l.session) }
            if let i = proTag.firstIndex(where: { $0.tag == l.tag }) {
                proTag[i].saetze += l.saetze
            } else {
                proTag.append((tag: l.tag, saetze: l.saetze))
            }
            if let best = l.saetze.compactMap(e1rm).max() { v.e1rm = max(v.e1rm ?? 0, best) }
        }
        v.gesamt = sessions.count
        v.monat = imMonat.count
        v.tage = proTag.sorted { $0.tag > $1.tag }.map { Tageseintrag(tag: $0.tag, text: $0.saetze.map(satzText).joined(separator: " · ")) }
        return v
    }

    /// Exercises that load the group (direct or helping), most done first.
    static func uebungen(_ gruppe: MuskelGruppe, _ laeufe: [Lauf], heute: String) -> [UebungsVerlauf] {
        var gesehen = Set<String>()
        var liste: [Uebung] = []
        for l in laeufe where MuskelLogik.teile(l.uebung).contains(where: { $0.teil.gruppe == gruppe }) {
            if gesehen.insert(l.uebung.id).inserted { liste.append(l.uebung) }
        }
        return liste.map { uebung($0, laeufe, heute: heute) }.sorted {
            $0.gesamt != $1.gesamt ? $0.gesamt > $1.gesamt : $0.uebung.name < $1.uebung.name
        }
    }

    /// Epley: kg × (1 + Wdh / 30); one rep is the weight itself. Sets without weight give nil.
    static func e1rm(_ s: PlanSatz) -> Double? {
        guard let kg = s.kg, kg > 0, s.wdh > 0 else { return nil }
        return s.wdh == 1 ? kg : kg * (1 + Double(s.wdh) / 30)
    }

    /// "62,5 × 8", or "8 Wdh" without weight.
    static func satzText(_ s: PlanSatz) -> String {
        guard let kg = s.kg, kg > 0 else { return String(localized: "\(s.wdh) Wdh") }
        return "\(zahl(kg)) × \(s.wdh)"
    }

    /// "12", "4,5".
    static func zahl(_ d: Double) -> String {
        d.formatted(.number.precision(.fractionLength(0...1)).locale(deutsch))
    }

    static func saetzeText(_ d: Double) -> String { "\(zahl(d)) \(d == 1 ? String(localized: "Satz") : String(localized: "Sätze"))" }

    /// "3× · 9 Sätze"
    static func kurz(_ z: Zaehler) -> String { "\(z.einheiten)× · \(saetzeText(z.saetze))" }
}
