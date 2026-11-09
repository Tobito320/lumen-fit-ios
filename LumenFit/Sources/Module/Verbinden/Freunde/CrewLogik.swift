import Foundation

/// Die Werte einer Woche. nil heißt: die Person teilt das nicht (nie als 0 anzeigen).
struct CrewWoche: Equatable, Sendable {
    var tage: Int?
    var saetze: Int?
    var volumen: Int?
    var rekorde: Int?

    func wert(_ mass: CrewMass) -> Int? {
        switch mass {
        case .tage: tage
        case .saetze: saetze
        case .volumen: volumen
        case .rekorde: rekorde
        case .uebung: nil
        }
    }
}

/// Eine Zeile der Wochen-Rangliste. Gleicher Wert, gleicher Rang.
struct CrewRang: Identifiable, Equatable, Sendable {
    nonisolated static let eigeneId = "ich"
    var id: String
    var name: String
    var wert: Int
    var rang: Int
    var ich: Bool
}

enum CrewStand: Equatable, Sendable {
    case fuehrt, gleich, hinten, gewonnen, verloren, abgebrochen
    /// Gemeinsames Ziel: wie viel Prozent alle zusammen geschafft haben (auch über 100).
    case gemeinsam(prozent: Int)
}

/// Ein eigener Wert für `PUT /freunde/werte`.
struct CrewWertMeldung: Codable, Equatable, Sendable {
    var id: String
    var wert: Int
}

/// Beste Übung du gegen eine Person: geschätztes 1RM in kg.
struct CrewVergleich: Identifiable, Equatable, Sendable {
    var uebung: String
    var ich: Double
    var person: Double
    var id: String { uebung }
}

/// Der beste Satz der Crew für eine Übung ("Schlag meinen Satz").
struct CrewBestwert: Equatable, Sendable {
    var name: String
    var kg: Double
    var wdh: Int
}

/// Ein Rekord der Pinnwand mit der Verbindung, von der er kommt (für den Respekt-Knopf).
struct CrewPinnwandEintrag: Identifiable, Equatable, Sendable {
    var person: String
    var rekord: PinnwandRekord
    var id: String { "\(person)-\(rekord.tag)-\(rekord.uebung)" }
}

/// Reine Regeln der Crew (Herausforderungen, Rangliste, Reaktionen). Ohne Netz und Oberfläche testbar.
enum CrewLogik {
    nonisolated static let zielLaenge = 80

    // MARK: Crew

    /// Aktive, nicht pausierte Verbindungen, jede Kennung und die Lovea-Person nur einmal.
    static func crew(_ eintraege: [VerbindungEintrag]) -> [VerbindungEintrag] {
        var gesehen: Set<String> = []
        var loveaDa = false
        return eintraege.filter { e in
            guard e.aktiv, !e.ich.pause else { return false }
            if e.lovea { guard !loveaDa else { return false }; loveaDa = true }
            return gesehen.insert(e.id).inserted
        }
    }

    static func name(_ e: VerbindungEintrag) -> String {
        e.anzeigeName.isEmpty ? (e.daten?.profilName ?? "") : e.anzeigeName
    }

    /// Reagieren geht nur an aktive, nicht pausierte Verbindungen, die mir Gym zeigen (der Server prüft dasselbe).
    static func darfReagieren(_ e: VerbindungEintrag) -> Bool {
        e.aktiv && !e.ich.pause && (e.sichtbareBereiche.contains(.gym) || e.daten?.freigaben.contains(.gym) == true)
    }

    private static func mitSaetzen(_ d: ZusammenfassungDatei?) -> [PartnerEinheit]? {
        guard let d, d.freigaben.contains(.gym), d.freigaben.contains(.verlauf) else { return nil }
        return d.heute.verlauf?.einheiten ?? []
    }

    // MARK: Übungen und Sätze

    /// Name ohne Klammerzusatz, wie ihn die Pinnwand zeigt.
    static func anzeige(_ name: String) -> String {
        name.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Gleiche Übung bei gleichem Namen ohne Klammerzusatz, ohne Groß/Klein (wie `GymRekordPinnwandLogik`).
    static func normal(_ name: String) -> String { anzeige(name).lowercased() }

    static func uebungsName(_ l: UebungsLauf) -> String { l.name ?? UebungsKatalog.nachId[l.uebung]?.name ?? "Übung" }

    /// Die gezählten Sätze eines Laufs ohne Aufwärmen: im laufenden Training die abgehakten Zeilen, sonst die gespeicherten.
    static func saetze(_ l: UebungsLauf) -> [PlanSatz] {
        l.stand.map { $0.filter(\.zaehlt) } ?? (l.saetze ?? []).filter { $0.typ != "w" }
    }

    private static func e1rm(_ saetze: [PlanSatz]) -> Double? {
        saetze.filter { $0.typ != "d" }.compactMap(RekordLogik.e1rm).max()
    }

    /// Je Übung (normalisiert) das beste geschätzte 1RM einer Einheit.
    private static func bestJeUebung(_ s: GymSession) -> [String: (anzeige: String, e1rm: Double)] {
        var best: [String: (anzeige: String, e1rm: Double)] = [:]
        for l in s.laeufe {
            guard let e = e1rm(saetze(l)) else { continue }
            let name = uebungsName(l)
            let key = normal(name)
            if e > best[key]?.e1rm ?? 0 { best[key] = (anzeige(name), e) }
        }
        return best
    }

    // MARK: Werte

    /// Mein Wert eines Maßes für Einheiten mit Start in `von ..< bis`.
    static func wert(_ mass: CrewMass, sessions: [GymSession], von: Date, bis: Date, uebung: String? = nil) -> Int {
        let drin = sessions.filter { $0.start >= von && $0.start < bis }
        switch mass {
        case .tage:
            return Set(drin.map { Datum.text($0.start) }).count
        case .saetze:
            return drin.reduce(0) { $0 + $1.laeufe.reduce(0) { $0 + saetze($1).count } }
        case .volumen:
            let kg = drin.flatMap(\.laeufe).flatMap(saetze).reduce(0.0) { $0 + ($1.kg ?? 0) * Double($1.wdh) }
            return Int(kg.rounded())
        case .rekorde:
            return rekordZahl(sessions, von: von, bis: bis)
        case .uebung:
            return uebung.map { promille(normal($0), sessions: sessions, von: von, bis: bis) } ?? 0
        }
    }

    /// In wie vielen Übungen im Zeitraum ein geschätztes 1RM über allem davor lag (`RekordLogik.e1rm`). Das erste Mal ist kein Rekord.
    private static func rekordZahl(_ sessions: [GymSession], von: Date, bis: Date) -> Int {
        var bisher: [String: Double] = [:]
        var rekorde: Set<String> = []
        for s in sessions.sorted(by: { $0.start < $1.start }) where s.start < bis {
            for (key, b) in bestJeUebung(s) {
                if s.start >= von, let alt = bisher[key], b.e1rm > alt { rekorde.insert(key) }
                bisher[key] = max(bisher[key] ?? 0, b.e1rm)
            }
        }
        return rekorde.count
    }

    /// Steigerung des besten e1RM im Zeitraum in Promille gegen den besten Wert vor dem Start; ohne Wert davor gegen die erste Einheit im Zeitraum.
    /// Nie negativ (schwächer ist 0).
    private static func promille(_ key: String, sessions: [GymSession], von: Date, bis: Date) -> Int {
        let werte = sessions.sorted { $0.start < $1.start }.filter { $0.start < bis }.compactMap { s -> (Date, Double)? in
            bestJeUebung(s)[key].map { (s.start, $0.e1rm) }
        }
        let davor = werte.filter { $0.0 < von }.map(\.1).max()
        let drin = werte.filter { $0.0 >= von }.map(\.1)
        guard let best = drin.max(), let basis = davor ?? drin.first, basis > 0 else { return 0 }
        return max(0, Int(((best / basis - 1) * 1000).rounded()))
    }

    /// Montag 00:00 dieser Woche bis Montag 00:00 der nächsten (Berlin).
    static func wochenZeitraum(jetzt: Date) -> (von: Date, bis: Date) {
        let montag = Datum.wochenstart(Datum.text(jetzt))
        return (Datum.datum(montag), Datum.datum(Datum.addTage(montag, 7)))
    }

    static func woche(sessions: [GymSession], jetzt: Date) -> CrewWoche {
        let z = wochenZeitraum(jetzt: jetzt)
        func w(_ m: CrewMass) -> Int { wert(m, sessions: sessions, von: z.von, bis: z.bis) }
        return CrewWoche(tage: w(.tage), saetze: w(.saetze), volumen: w(.volumen), rekorde: w(.rekorde))
    }

    /// Die Woche einer Person aus ihrer Zusammenfassung. Tage nur mit Freigabe gym, Sätze, Volumen und Rekorde nur mit gym und verlauf.
    /// Werte aus einer älteren Woche zählen nicht. Ohne Daten nil.
    static func woche(_ datei: ZusammenfassungDatei?, jetzt: Date) -> CrewWoche? {
        guard let datei else { return nil }
        let heute = Datum.text(jetzt)
        let montag = Datum.wochenstart(heute)
        var w = CrewWoche()
        if datei.freigaben.contains(.gym) {
            if let tage = datei.heute.gymTage {
                w.tage = Set(tage.filter { $0 >= montag && $0 <= heute }).count
            } else if let zahl = datei.heute.gymTageWoche {
                w.tage = datei.heute.tag >= montag ? zahl : 0
            }
        }
        if let einheiten = mitSaetzen(datei) {
            let diese = einheiten.filter { $0.tag >= montag && $0.tag <= heute }
            w.saetze = diese.reduce(0) { $0 + $1.uebungen.flatMap(\.saetze).filter { $0.typ != "w" }.count }
            w.volumen = Int(diese.reduce(0.0) { $0 + GymPartnerLogik.volumen($1) }.rounded())
            w.rekorde = GymRekordPinnwandLogik.rekorde(datei, jetzt: jetzt).filter { $0.tag >= montag }.count
        }
        return w
    }

    /// "8.400 kg", "1 Tag", "12 Sätze", "35 ‰".
    static func wertText(_ wert: Int, _ mass: CrewMass) -> String {
        let zahl = wert.formatted(.number.locale(Locale(identifier: "de_DE")))
        guard wert == 1 else { return "\(zahl) \(mass.einheit)" }
        switch mass {
        case .tage: return "1 Tag"
        case .saetze: return "1 Satz"
        case .rekorde: return "1 Rekord"
        case .volumen, .uebung: return "\(zahl) \(mass.einheit)"
        }
    }

    // MARK: Rangliste

    static func rangliste(_ mass: CrewMass, ich: CrewWoche, eintraege: [VerbindungEintrag], jetzt: Date) -> [CrewRang] {
        var zeilen: [CrewRang] = []
        if let w = ich.wert(mass) { zeilen.append(CrewRang(id: CrewRang.eigeneId, name: "Du", wert: w, rang: 0, ich: true)) }
        for e in crew(eintraege) {
            guard let w = woche(e.daten, jetzt: jetzt)?.wert(mass) else { continue }
            zeilen.append(CrewRang(id: e.id, name: name(e), wert: w, rang: 0, ich: false))
        }
        return raenge(zeilen)
    }

    /// Absteigend nach Wert; gleicher Wert gleicher Rang (1, 1, 3), bei Gleichstand du zuerst, dann nach Name.
    static func raenge(_ zeilen: [CrewRang]) -> [CrewRang] {
        let sortiert = zeilen.sorted { a, b in
            if a.wert != b.wert { return a.wert > b.wert }
            if a.ich != b.ich { return a.ich }
            return a.name.lowercased() < b.name.lowercased()
        }
        return sortiert.enumerated().map { i, z in
            var neu = z
            neu.rang = (sortiert.firstIndex { $0.wert == z.wert } ?? i) + 1
            return neu
        }
    }

    // MARK: Herausforderungen

    static func eigenerWert(_ h: CrewHerausforderung, sessions: [GymSession]) -> Int {
        wert(h.mass, sessions: sessions, von: h.start, bis: h.ende, uebung: h.uebung)
    }

    static func vorbei(_ h: CrewHerausforderung, jetzt: Date) -> Bool { h.status == "beendet" || jetzt >= h.ende }

    /// Was diese App melden soll: nur wo ich dabei bin, nicht abgebrochen, bis Ende + 24 h, und nur geänderte Werte (höchstens 20).
    static func zuMelden(_ antwort: CrewAntwort, sessions: [GymSession], jetzt: Date) -> [CrewWertMeldung] {
        let liste = antwort.herausforderungen.compactMap { h -> CrewWertMeldung? in
            guard istId(h.id), h.dabei, !h.abgebrochen, jetzt <= h.ende.addingTimeInterval(86_400) else { return nil }
            let w = eigenerWert(h, sessions: sessions)
            return w == h.meine?.wert ? nil : CrewWertMeldung(id: h.id, wert: min(max(w, 0), 1_000_000_000))
        }
        return Array(liste.prefix(20))
    }

    /// Eine Id des Servers: 32 Hex-Zeichen. Eine andere würde den ganzen `PUT /freunde/werte` kippen (400).
    static func istId(_ text: String) -> Bool {
        text.utf8.count == 32 && text.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) || ($0 >= 65 && $0 <= 70) }
    }

    static func stand(_ h: CrewHerausforderung, jetzt: Date) -> CrewStand {
        if h.abgebrochen { return .abgebrochen }
        let dabei = h.teilnehmer.filter(\.dabei)
        if h.modus == .gemeinsam {
            let summe = dabei.reduce(0) { $0 + $1.wert }
            guard let ziel = h.ziel, ziel > 0 else { return .gemeinsam(prozent: 0) }
            return .gemeinsam(prozent: Int((Double(summe) * 100 / Double(ziel)).rounded(.down)))
        }
        let meins = h.meine?.wert ?? 0
        let andere = dabei.filter { !$0.ich }.map(\.wert).max() ?? 0
        let fertig = vorbei(h, jetzt: jetzt)
        if meins > andere { return fertig ? .gewonnen : .fuehrt }
        if meins < andere { return fertig ? .verloren : .hinten }
        return .gleich
    }

    static func text(_ s: CrewStand) -> String {
        switch s {
        case .fuehrt: "du führst"
        case .gleich: "Gleichstand"
        case .hinten: "du liegst hinten"
        case .gewonnen: "gewonnen"
        case .verloren: "verloren"
        case .abgebrochen: "abgebrochen"
        case .gemeinsam(let p): "\(p) % geschafft"
        }
    }

    /// "Duell", "Gruppe" oder "Gemeinsam". Ein Duell hat genau zwei Personen (Eingeladene zählen mit).
    static func art(_ h: CrewHerausforderung) -> String {
        h.modus == .gemeinsam ? "Gemeinsam" : h.teilnehmer.count <= 2 ? "Duell" : "Gruppe"
    }

    /// "Duell: Sätze", "Gemeinsam: Volumen", "Gruppe: Kniebeuge".
    static func titel(_ h: CrewHerausforderung) -> String {
        "\(art(h)): \(h.mass == .uebung ? (h.uebung ?? h.mass.titel) : h.mass.titel)"
    }

    /// "noch 3 Tage", "noch 1 Tag", "endet heute", "beendet".
    static func restText(_ h: CrewHerausforderung, jetzt: Date) -> String {
        guard !vorbei(h, jetzt: jetzt) else { return "beendet" }
        let tage = Int((h.ende.timeIntervalSince(jetzt) / 86_400).rounded(.down))
        return tage < 1 ? "endet heute" : tage == 1 ? "noch 1 Tag" : "noch \(tage) Tage"
    }

    /// Ende "bis Sonntag": Sonntag 23:59:59 (Berlin); liegt das weniger als eine Stunde vor `jetzt`, der Sonntag der nächsten Woche.
    static func endeBisSonntag(jetzt: Date) -> Date {
        let naechsterMontag = Datum.addTage(Datum.wochenstart(Datum.text(jetzt)), 7)
        let ende = Datum.datum(naechsterMontag).addingTimeInterval(-1)
        return ende.timeIntervalSince(jetzt) >= 3600 ? ende : Datum.datum(Datum.addTage(naechsterMontag, 7)).addingTimeInterval(-1)
    }

    /// Vorschlag für ein gemeinsames Ziel: Summe der Wochenwerte aller × Wochen, gerundet (ab 1.000 auf 100, ab 100 auf 10), mindestens 1.
    static func zielVorschlag(wochenwerte: [Int?], tage: Int) -> Int {
        let roh = Double(wochenwerte.compactMap { $0 }.reduce(0, +)) * Double(max(1, tage)) / 7
        let schritt: Double = roh >= 1000 ? 100 : roh >= 100 ? 10 : 1
        return max(1, Int((roh / schritt).rounded() * schritt))
    }

    // MARK: Reaktionen

    /// Höchstens 80 UTF-16-Zeichen (so zählt der Server).
    static func begrenzt(_ text: String, auf laenge: Int = zielLaenge) -> String {
        var t = text
        while t.utf16.count > laenge { t.removeLast() }
        return t
    }

    static func zielRekord(tag: String, uebung: String) -> String { begrenzt("rekord:\(tag):\(normal(uebung))") }
    static func zielEinheit(tag: String) -> String { "einheit:\(tag)" }
    static func zielLive(tag: String) -> String { "live:\(tag)" }
    static func zielStups(tag: String) -> String { "stups:\(tag)" }

    /// Reaktionen nach `seit`, neueste zuerst; ohne Zeitpunkt alle.
    static func neue(_ reaktionen: [CrewReaktion], seit: Date?) -> [CrewReaktion] {
        reaktionen.filter { r in seit.map { r.zeit > $0 } ?? true }.sorted { $0.zeit > $1.zeit }
    }

    static func reaktionText(_ r: CrewReaktion) -> String {
        let worauf = r.text.isEmpty ? "" : " · \(r.text)"
        switch r.art {
        case .respekt: return "\(r.name) gibt dir Respekt\(worauf)"
        case .stark: return "\(r.name) findet dein Training stark\(worauf)"
        case .anfeuern: return "\(r.name) feuert dich an\(worauf)"
        case .stups: return "\(r.name) fragt: Gym heute?"
        }
    }

    // MARK: Pinnwand, Trainings, Vergleich, Bestwert

    /// Wie `GymRekordPinnwandLogik.pinnwand`, aber mit der Verbindung je Rekord.
    static func pinnwand(eintraege: [VerbindungEintrag], jetzt: Date) -> [CrewPinnwandEintrag] {
        var gesehen: Set<String> = []
        let alle = eintraege.filter { $0.aktiv && !$0.ich.pause && gesehen.insert($0.id).inserted }.flatMap { e -> [CrewPinnwandEintrag] in
            guard let d = e.daten else { return [] }
            return GymRekordPinnwandLogik.rekorde(d, name: e.anzeigeName.isEmpty ? d.profilName : e.anzeigeName, jetzt: jetzt)
                .map { CrewPinnwandEintrag(person: e.id, rekord: $0) }
        }
        let sortiert = alle.sorted { a, b in
            a.rekord.tag != b.rekord.tag ? a.rekord.tag > b.rekord.tag : (a.rekord.name, a.rekord.uebung) < (b.rekord.name, b.rekord.uebung)
        }
        return Array(sortiert.prefix(GymRekordPinnwandLogik.zeilenMax))
    }


    /// Gemeinsame Übungen: bestes geschätztes 1RM aus meinen Einheiten gegen das aus den Einheiten der Person. Nach Name sortiert.
    static func vergleich(sessions: [GymSession], datei: ZusammenfassungDatei?) -> [CrewVergleich] {
        guard let einheiten = mitSaetzen(datei) else { return [] }
        var meine: [String: (anzeige: String, e1rm: Double)] = [:]
        for s in sessions {
            for (key, b) in bestJeUebung(s) where b.e1rm > meine[key]?.e1rm ?? 0 { meine[key] = b }
        }
        var ihre: [String: Double] = [:]
        for u in einheiten.flatMap(\.uebungen) {
            guard let e = e1rm(u.saetze.map(GymPartnerLogik.satz)) else { continue }
            ihre[normal(u.name)] = max(ihre[normal(u.name)] ?? 0, e)
        }
        return meine.compactMap { key, m in ihre[key].map { CrewVergleich(uebung: m.anzeige, ich: m.e1rm, person: $0) } }
            .sorted { $0.uebung.lowercased() < $1.uebung.lowercased() }
    }

    /// Der Satz mit dem höchsten geschätzten 1RM der Crew für diese Übung; nur von Personen, die gym und verlauf teilen. Sonst nil.
    static func bestwert(uebung: String, eintraege: [VerbindungEintrag]) -> CrewBestwert? {
        let key = normal(uebung)
        var best: (e1rm: Double, wert: CrewBestwert)?
        for e in crew(eintraege) {
            for u in (mitSaetzen(e.daten) ?? []).flatMap(\.uebungen) where normal(u.name) == key {
                for s in u.saetze where s.typ != "w" && s.typ != "d" {
                    guard let kg = s.kg, let wert = RekordLogik.e1rm(GymPartnerLogik.satz(s)), wert > best?.e1rm ?? 0 else { continue }
                    best = (wert, CrewBestwert(name: name(e), kg: Double(kg) / 10, wdh: s.wdh))
                }
            }
        }
        return best?.wert
    }

    /// "Crew-Bestwert: Beispiel Freund A 80 kg × 8"
    static func bestwertText(_ b: CrewBestwert) -> String {
        "Bestwert bei Freunden: \(b.name) \(TrainingLogik.kgText(b.kg)) kg × \(b.wdh)"
    }

    // MARK: Einstieg

    /// Die Zeile unter "Crew" im Gym-Tab: "2 im Gym · Duell: du führst · 1 neu"; ohne alles ein Satz, was man hier tun kann.
    static func einstiegText(imGym: Int, herausforderung: String?, neu: Int, personen: Int) -> String {
        var teile: [String] = []
        if imGym > 0 { teile.append("\(imGym) im Gym") }
        if let herausforderung { teile.append(herausforderung) }
        if neu > 0 { teile.append("\(neu) neu") }
        if !teile.isEmpty { return teile.joined(separator: " · ") }
        return personen == 0 ? "Freunde einladen und herausfordern" : "Herausfordern, vergleichen, anfeuern"
    }

    /// Die wichtigste laufende Herausforderung für den Einstieg: "Duell: du führst".
    static func einstiegStand(_ antwort: CrewAntwort?, jetzt: Date) -> String? {
        guard let h = antwort?.herausforderungen.first(where: { $0.dabei && !$0.abgebrochen && !vorbei($0, jetzt: jetzt) }) else { return nil }
        return "\(art(h)): \(text(stand(h, jetzt: jetzt)))"
    }
}
