import Foundation

/// Die Daten für die Ansichten des Partners (Plan, Verlauf, Tagebuch, Körperwerte) aus den eigenen Stores, als Zusammenfassung ohne Rohdaten:
/// Übungsnamen statt Sätze, Namen und Kalorien statt Mengen und Fotos, Messwerte in Zehnteln. Der Bauer (`ZusammenfassungBauer`) gibt davon nur frei,
/// was die Freigaben erlauben. Die Rechnung ist rein und ohne Stores testbar; nur `sammle` liest die Stores.
enum PartnerAnsichtsDaten {
    struct Werte: Sendable, Equatable {
        var plan: PartnerPlan?
        var verlauf: PartnerVerlauf?
        var tagebuch: [PartnerTagebuchTag] = []
        var tagebuchZiele: PartnerMakros?
        var koerper: [String: [PartnerMesspunkt]] = [:]
    }

    nonisolated static let planTage = 14
    nonisolated static let uebungenJeTag = 20
    nonisolated static let trainingsMax = 10
    nonisolated static let tageMax = 400
    nonisolated static let einheitenMax = 30
    nonisolated static let uebungenJeEinheit = 15
    nonisolated static let saetzeJeUebung = 12
    nonisolated static let tagebuchTage = 7
    nonisolated static let eintraegeJeTag = 30
    nonisolated static let messpunkteJeArt = 90

    @MainActor
    static func sammle(daten: DatenSatz, freigaben: Set<FreigabeArt>, jetzt: Date) -> Werte {
        let heute = Datum.text(jetzt)
        var w = Werte()
        if freigaben.contains(.plan) { w.plan = plan(daten.training.plan) }
        if freigaben.contains(.verlauf) { w.verlauf = verlauf(sessions: daten.training.sessions, plan: daten.training.plan, laufende: daten.training.laufende(jetzt: jetzt), heute: heute, mitSaetzen: freigaben.contains(.gym)) }
        if freigaben.contains(.tagebuch) {
            w.tagebuch = tagebuch(heute: heute) { daten.essen.eintraege($0) }
            let ziele = daten.essen.ernaehrungsZiele(tag: heute)
            w.tagebuchZiele = PartnerMakros(kcal: ziele.kcal, protein: ziele.protein, kohlenhydrate: ziele.kohlenhydrate, fett: ziele.fett)
        }
        if freigaben.contains(.koerper) {
            var werte: [MessArt: [String: Int]] = [:]
            for art in MessArt.allCases { werte[art] = daten.essen.massReihe(art) }
            w.koerper = koerper(werte)
        }
        return w
    }

    // MARK: Rechnung

    static func kurz(_ text: String, _ laenge: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(laenge))
    }

    private static func gerundet(_ x: Double) -> Int { x.isFinite ? max(0, Int(x.rounded())) : 0 }

    /// Namen, Wochentage und Übungsnamen. Ein Plan ohne Tage gibt es nicht (nil).
    static func plan(_ p: TrainingsPlan) -> PartnerPlan? {
        let tage = p.tage.prefix(planTage).map { t in
            PartnerPlanTag(name: kurz(t.name, 40), wochentage: Set(t.wochentage.filter { (1...7).contains($0) }).sorted(),
                           uebungen: t.uebungen.prefix(uebungenJeTag).map { PartnerPlanUebung(name: kurz($0.anzeigeName, 40), saetze: $0.saetze.count) })
        }
        guard !tage.isEmpty else { return nil }
        let ruhe = Set((p.ruhetage ?? []).filter { (1...7).contains($0) }).sorted()
        let name = p.splitName.map { kurz($0, 40) }
        return PartnerPlan(name: name?.isEmpty == false ? name : nil, tage: Array(tage), ruhetage: ruhe.isEmpty ? nil : ruhe)
    }

    /// "Im Gym" (laufende Einheit) und die letzten Einheiten mit Daten. Immer eine Antwort: ohne Training leere Liste, damit die Ansicht "noch kein Training" sagt.
    static func verlauf(sessions: [GymSession], plan: TrainingsPlan, laufende: GymSession?, heute: String, mitSaetzen: Bool = false) -> PartnerVerlauf {
        let neueste = sessions.sorted { $0.start > $1.start }
        let trainings = neueste.filter { GymTageLogik.hatDaten($0) }.prefix(trainingsMax).map { s in
            let name = plan.tag(id: s.tag).map { kurz($0.name, 40) }
            return PartnerTrainingKurz(
                tag: Datum.text(s.start), name: name?.isEmpty == false ? name : nil, minuten: s.ende.map { max(0, Int($0.timeIntervalSince(s.start) / 60)) },
                saetze: s.laeufe.reduce(0) { $0 + ($1.saetze?.count ?? 0) },
                uebungen: s.laeufe.filter { ($0.saetze?.isEmpty == false) || $0.fertig }.count, kcal: s.kcal)
        }
        var v = PartnerVerlauf(trainings: Array(trainings), woche: TrainingLogik.dieseWoche(sessions, heute: heute),
                               serieWochen: TrainingLogik.serieWochen(sessions, heute: heute), gesamt: sessions.count)
        if mitSaetzen {
            let mitDaten = neueste.filter { GymTageLogik.hatDaten($0) }
            v.tage = Array(Set(mitDaten.map { Datum.text($0.start) }).sorted(by: >).prefix(tageMax))
            v.einheiten = mitDaten.prefix(einheitenMax).map { einheit($0, plan: plan) }
        }
        if let laufende {
            v.imGym = true
            v.imGymSeit = laufende.start
            let name = plan.tag(id: laufende.tag).map { kurz($0.name, 40) }
            v.imGymName = name?.isEmpty == false ? name : nil
        }
        return v
    }

    /// Eine Einheit zum Nachlesen: je Übung die abgehakten Sätze (ohne Cardio), Gewicht in Zehnteln. Übungen ohne Sätze fallen weg.
    static func einheit(_ s: GymSession, plan: TrainingsPlan) -> PartnerEinheit {
        let name = plan.tag(id: s.tag).map { kurz($0.name, 40) }
        let uebungen = s.laeufe.compactMap { l -> PartnerUebungKurz? in
            let zeilen = l.stand.map { $0.filter { $0.ok == true } } ?? l.saetze ?? []
            let saetze = zeilen.prefix(saetzeJeUebung).map { z in
                PartnerSatzKurz(wdh: max(0, z.wdh), kg: z.kg.map { gerundet($0 * 10) },
                                typ: z.typ == "w" || z.typ == "d" ? z.typ : z.failure ? "f" : nil)
            }
            guard !saetze.isEmpty else { return nil }
            let n = kurz(l.name ?? UebungsKatalog.nachId[l.uebung]?.name ?? "Übung", 40)
            return PartnerUebungKurz(name: n.isEmpty ? "Übung" : n, saetze: Array(saetze))
        }
        return PartnerEinheit(tag: Datum.text(s.start), name: name?.isEmpty == false ? name : nil,
                              minuten: s.ende.map { max(0, Int($0.timeIntervalSince(s.start) / 60)) }, kcal: s.kcal,
                              uebungen: Array(uebungen.prefix(uebungenJeEinheit)))
    }

    /// Die letzten sieben Tage (neuester zuerst), nur Tage mit Einträgen: Summe, Makros, Name und Kalorien jedes Eintrags. Keine Fotos, keine Mengen.
    static func tagebuch(heute: String, eintraege: (String) -> [EssenEintrag]) -> [PartnerTagebuchTag] {
        (0..<tagebuchTage).compactMap { i -> PartnerTagebuchTag? in
            let tag = Datum.addTage(heute, -i)
            let liste = eintraege(tag).filter { $0.geloescht != true }
            guard !liste.isEmpty else { return nil }
            let summe = ErnaehrungLogik.summe(liste)
            return PartnerTagebuchTag(
                tag: tag, kcal: gerundet(summe.kcal), protein: gerundet(summe.protein), kohlenhydrate: gerundet(summe.kohlenhydrate), fett: gerundet(summe.fett),
                mahlzeiten: liste.prefix(eintraegeJeTag).map {
                    PartnerMahlzeitKurz(mahlzeit: $0.mahlzeit.rawValue, name: kurz($0.lebensmittel.name, 60), kcal: gerundet($0.naehrwerte.kcal))
                })
        }
    }

    /// Je Messart die letzten Punkte, älteste zuerst; Arten ohne Wert fehlen.
    static func koerper(_ werte: [MessArt: [String: Int]]) -> [String: [PartnerMesspunkt]] {
        var aus: [String: [PartnerMesspunkt]] = [:]
        for (art, tage) in werte {
            let punkte = MessLogik.punkte(tage).suffix(messpunkteJeArt).map { PartnerMesspunkt(tag: $0.tag, zehntel: $0.zehntel) }
            if !punkte.isEmpty { aus[art.rawValue] = punkte }
        }
        return aus
    }
}
