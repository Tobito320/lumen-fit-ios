// Quelle: Lovea Health/Koerper/KoerperView.swift (nur die Rechnung; Ansichten, Person und Punkte entfallen)
import Foundation

/// Die reine Rechnung des Fortschritt-Segments: Wochenstreifen, Ziele, nächstes Training nach Plan, Übungen einer Gruppe,
/// doppelte Progression. Kein Modell, kein Zustand. Die Rechnung der Körperkarte (Legende, Grenzteil, letztes Training)
/// steht in `ErholungsLogik.swift`.
enum KoerperLogik {
    enum Art: Sendable {
        case beine, oben
        /// Das Wort unter dem Kreis der Wochenleiste, kurz genug für sieben Spalten.
        var wort: String { self == .beine ? "Beine" : "Ober" }
        /// Für VoiceOver.
        var name: String { self == .beine ? "Beine" : "Oberkörper" }
    }

    /// Der schlechteste Teil einer Gruppe, ein Teil ohne Eintrag gilt als erholt (100). Nicht der Mittelwert: ein
    /// müder Muskel bleibt müde, auch wenn der Rest der Gruppe frisch ist.
    static func gruppenErholung(_ erholung: [MuskelTeil: Int], _ g: MuskelGruppe) -> Int {
        MuskelTeil.allCases.filter { $0.gruppe == g }.map { erholung[$0] ?? 100 }.min() ?? 100
    }

    /// "Schulter seitlich", "Brust oben", "Brust Mitte und unten", "Unterarme Beuger", aber "Quadrizeps" und
    /// "Latissimus" stehen für sich.
    static func teilName(_ t: MuskelTeil) -> String {
        // Diese vier Namen beginnen groß, sagen aber ohne ihre Gruppe nichts.
        let stumm: [MuskelTeil] = [.bUnten, .uSpeiche, .uBeuger, .uStrecker]
        let braucht = t.name.first?.isLowercase == true || stumm.contains(t)
        return braucht ? "\(t.gruppe.name) \(t.name)" : t.name
    }

    // MARK: Training als Oberkörper oder Beine

    /// Beine, wenn mehr als die Hälfte der Haupt-Teile Beine sind, sonst Oberkörper. Ohne Teile nil.
    static func art(teile: [MuskelTeil]) -> Art? {
        guard !teile.isEmpty else { return nil }
        return teile.filter { $0.gruppe == .beine }.count * 2 > teile.count ? .beine : .oben
    }

    static func haupt(_ u: Uebung) -> MuskelTeil? { MuskelLogik.teile(u).first { $0.faktor == 1 }?.teil }

    static func art(_ tag: TrainingsTag, katalog: (String) -> Uebung?) -> Art? {
        art(teile: tag.uebungen.compactMap { katalog($0.uebung).flatMap(haupt) })
    }

    /// Nach den fertigen Übungen, ohne Übungen nach dem Plan-Tag der Session.
    static func art(_ s: GymSession, plan: TrainingsPlan, katalog: (String) -> Uebung?) -> Art? {
        let teile = s.laeufe.filter(\.fertig).compactMap { katalog($0.uebung).flatMap(haupt) }
        return art(teile: teile) ?? plan.tag(id: s.tag).flatMap { art($0, katalog: katalog) }
    }

    // MARK: Ziele

    static func faellig(prio: [MuskelGruppe], ziele: KoerperZiele, woche: [MuskelTeil: Double]) -> [MuskelGruppe] {
        prio.filter { g in
            let ziel = Double(ziele.saetze[g] ?? 0)
            let gemacht = MuskelTeil.allCases.filter { $0.gruppe == g }.reduce(0.0) { $0 + (woche[$1] ?? 0) }
            return ziel > 0 && gemacht < ziel * 0.5
        }
    }

    // MARK: Nächstes Training nach Plan

    /// Der nächste Plan-Tag ab heute (heute nur, wenn noch nichts gemacht ist). Ohne Plan nil.
    static func naechstes(plan: TrainingsPlan, heute: String, heuteFertig: Bool, faellig: [MuskelGruppe],
                          katalog: (String) -> Uebung?) -> KoerperNaechstes? {
        for i in (heuteFertig ? 1 : 0)...7 {
            let datum = Datum.addTage(heute, i)
            guard let tag = TrainingLogik.tag(plan, datum: datum), !tag.uebungen.isEmpty else { continue }
            let saetze = tag.uebungen.reduce(0) { $0 + $1.saetze.count }
            let cardio = tag.uebungen.compactMap(\.minuten).reduce(0, +)
            let minuten = (saetze * 4 + cardio + 4) / 5 * 5 // shortcut: 4 min pro Satz, auf 5 gerundet; genauer mit ZeitSchaetzung (Modul gym)
            let wann = i == 0 ? "Heute" : i == 1 ? "Morgen" : TrainingLogik.wochentagName[Datum.wochentag(datum) - 1]
            var meta = ["\(wann), \(tagMonat(datum))", "\(tag.uebungen.count) \(tag.uebungen.count == 1 ? "Übung" : "Übungen")"]
            if saetze > 0 { meta.append("\(saetze) Sätze") }
            meta.append("etwa \(minuten) min")
            var chips = faellig.map(\.name)
            if chips.isEmpty {
                for g in tag.uebungen.compactMap({ katalog($0.uebung).flatMap(haupt)?.gruppe.name }) where !chips.contains(g) { chips.append(g) }
            }
            return KoerperNaechstes(titel: tag.name, meta: meta.joined(separator: " · "), chips: Array(chips.prefix(3)))
        }
        return nil
    }

    /// "2026-09-26" -> "26.9.".
    static func tagMonat(_ datum: String) -> String {
        "\(Int(datum.suffix(2)) ?? 0).\(Int(datum.dropFirst(5).prefix(2)) ?? 0)."
    }

    /// "Mo 22.9.".
    static func tagKurz(_ datum: String) -> String {
        "\(HabitLogik.wochentagKuerzel[Datum.wochentag(datum) - 1]) \(tagMonat(datum))"
    }

    // MARK: Doppelte Progression

    struct Vorschlag: Equatable, Sendable {
        let kg: Double?
        let wdh: Int
        let mehrGewicht: Bool
    }

    /// Alle Sätze am oberen Ende: +2,5 kg und zurück auf `start` Wiederholungen. Sonst gleiches Gewicht
    /// und eine Wiederholung mehr als der schwächste Satz. Ohne Gewicht (Körpergewicht) gibt es nur
    /// Wiederholungen. Leer: nil.
    // shortcut: das obere Ende ist fest 12, der Plan speichert keinen Wiederholungsbereich; pro Übung nachziehen, wenn der Plan ihn kennt.
    static func naechstesMal(_ saetze: [PlanSatz], oben: Int = 12, start: Int = 8) -> Vorschlag? {
        guard !saetze.isEmpty else { return nil }
        let kg = saetze.compactMap(\.kg).max()
        let arbeit = saetze.filter { $0.kg == kg }
        let schwach = arbeit.map(\.wdh).min() ?? 0
        if schwach >= oben { return Vorschlag(kg: kg.map { $0 + 2.5 }, wdh: kg == nil ? oben : start, mehrGewicht: true) }
        return Vorschlag(kg: kg, wdh: schwach + 1, mehrGewicht: false)
    }

    static func vorschlagText(_ v: Vorschlag, oben: Int = 12) -> String {
        guard let kg = v.kg else {
            return v.mehrGewicht ? "Alle Sätze bei \(oben). Nimm Zusatzgewicht." : "\(v.wdh) Wiederholungen. Bei \(oben) in jedem Satz: Zusatzgewicht."
        }
        if v.mehrGewicht { return "Alle Sätze bei \(oben). Nächstes Mal \(TrainingLogik.kgText(kg)) kg × \(v.wdh)." }
        return "\(TrainingLogik.kgText(kg)) kg × \(v.wdh). Bei \(oben) in jedem Satz: \(TrainingLogik.kgText(kg + 2.5)) kg."
    }

    /// 3,5 und 12.
    static func komma(_ d: Double) -> String { TrainingLogik.kgText(d) }

    /// "60 × 8", ohne Gewicht "12 Wdh".
    static func satzText(_ s: PlanSatz) -> String {
        s.kg.map { "\(TrainingLogik.kgText($0)) × \(s.wdh)" } ?? "\(s.wdh) Wdh"
    }

    // MARK: Übungen einer Gruppe

    struct VerlaufZeile: Sendable {
        let tag: String
        let saetze: String
    }

    struct UebungsZeile: Identifiable, Sendable {
        let id: String
        let name: String
        let teil: MuskelTeil
        let monat: Int
        let gesamt: Int
        /// Neueste zuerst, höchstens 3: Tag und Sätze.
        let verlauf: [VerlaufZeile]
        let vorschlag: Vorschlag?
    }

    struct GruppenDaten: Sendable {
        let monat: Int
        let gesamt: Int
        let uebungen: [UebungsZeile]
    }

    /// Fertige Übungen mit Sätzen, deren Haupt-Teil in `g` liegt. Cardio und eigene Übungen zählen nicht.
    /// "Monat" ist der Kalendermonat von `jetzt`, gezählt in Einheiten (Sessions).
    static func gruppe(_ g: MuskelGruppe, sessions: [GymSession], jetzt: Date, katalog: (String) -> Uebung?) -> GruppenDaten {
        let monatKey = Datum.text(jetzt).prefix(7)
        var nachUebung: [String: (u: Uebung, teil: MuskelTeil, laeufe: [(start: Date, saetze: [PlanSatz])])] = [:]
        var alle: Set<String> = []
        var imMonat: Set<String> = []
        for s in sessions.sorted(by: { $0.start > $1.start }) {
            for lauf in s.laeufe where lauf.fertig {
                guard let gemacht = lauf.saetze, !gemacht.isEmpty, let u = katalog(lauf.uebung),
                      let teil = haupt(u), teil.gruppe == g else { continue }
                alle.insert(s.id)
                if Datum.text(s.start).prefix(7) == monatKey { imMonat.insert(s.id) }
                nachUebung[u.id, default: (u, teil, [])].laeufe.append((s.start, gemacht))
            }
        }
        let zeilen = nachUebung.values.map { e -> UebungsZeile in
            let heuteMonat = e.laeufe.filter { Datum.text($0.start).prefix(7) == monatKey }.count
            let verlauf = e.laeufe.prefix(3).map { VerlaufZeile(tag: tagKurz(Datum.text($0.start)), saetze: $0.saetze.map(satzText).joined(separator: " · ")) }
            return UebungsZeile(id: e.u.id, name: e.u.name, teil: e.teil, monat: heuteMonat, gesamt: e.laeufe.count,
                                verlauf: verlauf, vorschlag: e.laeufe.first.flatMap { naechstesMal($0.saetze) })
        }
        return GruppenDaten(monat: imMonat.count, gesamt: alle.count, uebungen: zeilen.sorted { $0.gesamt != $1.gesamt ? $0.gesamt > $1.gesamt : $0.name < $1.name })
    }
}

/// Satzziele und Reihenfolge des Profils. `saetze` ist leer, solange es keine Ziele gibt.
struct KoerperZiele: Sendable {
    let prio: [MuskelGruppe]
    let saetze: [MuskelGruppe: Int]

    /// `wert` liest `ziel.prio.<gruppe>` (Rang 1 bis 5, 0 oder nil = keine Prio) und `ziel.saetze.<gruppe>`.
    /// Ohne Prio gilt `MuskelGruppe.standardPrio`, ohne eigenes Satzziel `MuskelLogik.standardZiel`.
    static func lesen(wert: (String) -> Int?) -> KoerperZiele {
        let raenge = MuskelGruppe.allCases.filter { (wert("ziel.prio.\($0.rawValue)") ?? 0) > 0 }
            .sorted { (wert("ziel.prio.\($0.rawValue)") ?? 0) < (wert("ziel.prio.\($1.rawValue)") ?? 0) }
        let gesetzt = MuskelGruppe.allCases.compactMap { g in wert("ziel.saetze.\(g.rawValue)").map { (g, $0) } }
        let prio = raenge.isEmpty ? MuskelGruppe.standardPrio : raenge
        let eigene = Dictionary(uniqueKeysWithValues: gesetzt)
        let saetze = Dictionary(uniqueKeysWithValues: MuskelGruppe.allCases.map {
            ($0, eigene[$0] ?? MuskelLogik.standardZiel($0, prio: prio.contains($0)))
        })
        return KoerperZiele(prio: prio, saetze: saetze)
    }

    var leer: Bool { saetze.isEmpty }

    /// Prio zuerst, dann der Rest in der Reihenfolge der Gruppen.
    var reihenfolge: [MuskelGruppe] { prio + MuskelGruppe.allCases.filter { !prio.contains($0) } }
}

struct KoerperNaechstes: Sendable {
    let titel: String
    let meta: String
    let chips: [String]
}

/// Die sieben Tage der Woche und die Bilanz. Regel für die Bilanz: "von x" sind die Plan-Tage der Woche
/// als Beine oder Oberkörper, "y" die eigenen Einheiten dieser Woche. Eine Pause ist ein vergangener Tag
/// dieser Woche ohne eigene Einheit.
struct KoerperWoche: Sendable {
    struct Tag: Sendable {
        let datum: String
        let kuerzel: String
        let nummer: Int
        let fertig: Bool
        let heute: Bool
        /// Der Tag liegt vor heute.
        let vergangen: Bool
        let geplant: KoerperLogik.Art?

        /// Was die Wochenleiste für den Tag zeigt, genau eins. Die Reihenfolge ist die Regel: gemacht
        /// schlägt alles, dann heute, dann der Plan (kommt oder verpasst), sonst Ruhetag.
        enum Anzeige: Equatable, Sendable {
            case fertig
            case heute(KoerperLogik.Art?)
            case verpasst(KoerperLogik.Art)
            case kommt(KoerperLogik.Art)
            case ruhe
        }

        var anzeige: Anzeige {
            if fertig { return .fertig }
            if heute { return .heute(geplant) }
            guard let art = geplant else { return .ruhe }
            return vergangen ? .verpasst(art) : .kommt(art)
        }

        /// Das Wort unter dem Kreis, nur für Plan-Tage, die noch offen sind (heute und kommende).
        var planWort: String? {
            switch anzeige {
            case .heute(let art): return art?.wort
            case .kommt(let art): return art.wort
            case .fertig, .verpasst, .ruhe: return nil
            }
        }

        /// VoiceOver, z. B. "Mittwoch 7., Beine geplant".
        var sprechtext: String {
            let name = TrainingLogik.wochentagName[Datum.wochentag(datum) - 1]
            let stand: String
            switch anzeige {
            case .fertig: stand = heute ? "heute, Training gemacht" : "Training gemacht"
            case .heute(let art): stand = art.map { "heute, \($0.name) geplant" } ?? "heute"
            case .verpasst(let art): stand = "\(art.name) geplant, nicht trainiert"
            case .kommt(let art): stand = "\(art.name) geplant"
            case .ruhe: stand = "kein Training"
            }
            return "\(name) \(nummer)., \(stand)"
        }
    }

    let tage: [Tag]
    let beine: Int
    let oben: Int
    let pausen: Int

    var beineGeplant: Int { tage.filter { $0.geplant == .beine }.count }
    var obenGeplant: Int { tage.filter { $0.geplant == .oben }.count }

    var bilanz: String {
        let b = max(beineGeplant, beine), o = max(obenGeplant, oben)
        guard b + o > 0 else { return "Noch kein Training geplant. Im Tab Gym legst du deinen Plan an." }
        // Eine Art ohne Plan und ohne Training (0 von 0) bleibt weg.
        let teile = [b > 0 ? "Beine \(beine) von \(b)" : nil, o > 0 ? "Oberkörper \(oben) von \(o)" : nil].compactMap { $0 }
        return (teile + ["\(pausen) \(pausen == 1 ? "Pause" : "Pausen")"]).joined(separator: " · ")
    }

    /// `montagVon`: irgendein Tag der gezeigten Woche, Standard die Woche von `heute`.
    static func bauen(sessions: [GymSession], plan: TrainingsPlan, heute: String,
                      katalog: (String) -> Uebung?, montagVon: String? = nil) -> KoerperWoche {
        let montag = Datum.montagDerWoche(montagVon ?? heute)
        let wochenPlan = WochenLogik.effektiverPlan(plan, woche: montag) // verlegt oder Testwoche
        let gemacht = Set(sessions.map { Datum.text($0.start) })
        let tage = (0..<7).map { i -> Tag in
            let datum = Datum.addTage(montag, i)
            let geplant = wochenPlan.tage.first { $0.wochentage.contains(i + 1) }.flatMap { KoerperLogik.art($0, katalog: katalog) }
            return Tag(datum: datum, kuerzel: HabitLogik.wochentagKuerzel[i], nummer: Int(datum.suffix(2)) ?? 0,
                       fertig: gemacht.contains(datum), heute: datum == heute, vergangen: datum < heute, geplant: geplant)
        }
        let eigene = sessions.filter { Datum.montagDerWoche(Datum.text($0.start)) == montag }
        let arten = eigene.map { KoerperLogik.art($0, plan: plan, katalog: katalog) }
        return KoerperWoche(tage: tage, beine: arten.filter { $0 == .beine }.count, oben: arten.filter { $0 == .oben }.count,
                            pausen: tage.filter { !$0.fertig && $0.datum < heute }.count)
    }
}
