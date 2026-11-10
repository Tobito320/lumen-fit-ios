// Quelle: Lovea Health/Studio/GymOeffnung.swift (ohne die fest verdrahteten Studios: Zeiten sind Daten, die der Mensch einträgt)
import Foundation

/// Öffnungsfenster eines Tages in Minuten seit Mitternacht. `bis == nil`: bis Mitternacht offen oder Ende unbekannt.
struct Oeffnungsfenster: Equatable, Sendable {
    let von: Int
    let bis: Int?
}

/// Ein geplanter Slot oder ein Einchecken, das nicht ins Öffnungsfenster passt.
struct OeffnungsWarnung: Equatable, Sendable {
    enum Grund: Equatable, Sendable { case vorOeffnung(von: Int), nachSchluss(bis: Int) }
    let wochentag: Int
    let grund: Grund
}

/// Die Öffnungszeiten eines Studios, vom Menschen eingetragen (oder aus `PrivateDaten.json` vorgeschlagen). Ohne Angabe gilt das
/// Studio als immer offen: es gibt dann nie eine Warnung. Alle Zeiten sind Minuten seit Mitternacht.
struct StudioOeffnung: Codable, Equatable, Sendable {
    struct Fenster: Codable, Equatable, Sendable {
        var von: Int
        var bis: Int
    }

    /// 24 Stunden, 7 Tage.
    var rund = false
    /// Montag bis Freitag; nil = unbekannt.
    var werktage: Fenster?
    /// Samstag und Sonntag; nil = unbekannt.
    var wochenende: Fenster?

    init(rund: Bool = false, werktage: Fenster? = nil, wochenende: Fenster? = nil) {
        self.rund = rund
        self.werktage = werktage
        self.wochenende = wochenende
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rund = try c.decodeIfPresent(Bool.self, forKey: .rund) ?? false
        werktage = try c.decodeIfPresent(Fenster.self, forKey: .werktage)
        wochenende = try c.decodeIfPresent(Fenster.self, forKey: .wochenende)
    }

    private enum CodingKeys: String, CodingKey { case rund, werktage, wochenende }

    static let unbekannt = StudioOeffnung()

    /// Ob überhaupt Zeiten bekannt sind.
    var bekannt: Bool { rund || werktage != nil || wochenende != nil }

    /// "08:00-22:00" als Fenster; nil bei kaputtem Text.
    static func fenster(text: String) -> Fenster? {
        let teile = text.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard teile.count == 2, let von = Datum.minuten(teile[0]), let bis = Datum.minuten(teile[1]), bis > von else { return nil }
        return Fenster(von: von, bis: bis)
    }
}

/// Öffnungszeiten als Daten, dazu die reine Prüflogik. Wochentag 1 = Mo … 7 = So (`Datum.wochentag`).
enum GymOeffnung {
    static func fenster(_ o: StudioOeffnung, wochentag: Int) -> Oeffnungsfenster {
        if o.rund { return Oeffnungsfenster(von: 0, bis: nil) }
        let f = wochentag >= 6 ? o.wochenende : o.werktage
        return f.map { Oeffnungsfenster(von: $0.von, bis: $0.bis) } ?? Oeffnungsfenster(von: 0, bis: nil)
    }

    /// `minute` = Minuten seit Mitternacht. Beginn zählt als offen, Ende nicht.
    static func istOffen(_ o: StudioOeffnung, wochentag: Int, minute: Int) -> Bool {
        let f = fenster(o, wochentag: wochentag)
        return minute >= f.von && (f.bis.map { minute < $0 } ?? true)
    }

    /// Slot von `start` bis `start + dauer`: ganz im Fenster ist ok, auch bündig an Anfang und Ende.
    static func warnung(_ o: StudioOeffnung, wochentag: Int, start: Int, dauer: Int) -> OeffnungsWarnung? {
        let f = fenster(o, wochentag: wochentag)
        if start < f.von { return OeffnungsWarnung(wochentag: wochentag, grund: .vorOeffnung(von: f.von)) }
        if let bis = f.bis, start + dauer > bis { return OeffnungsWarnung(wochentag: wochentag, grund: .nachSchluss(bis: bis)) }
        return nil
    }

    /// Eine Warnung je Trainingstag der Woche, der nicht passt, nach Wochentag sortiert. Ohne Zeiten oder ohne feste Uhrzeit leer.
    static func warnungen(_ o: StudioOeffnung, wochentage: [Int], start: Int?, dauer: Int) -> [OeffnungsWarnung] {
        guard let start else { return [] }
        return Set(wochentage).filter { (1...7).contains($0) }.sorted()
            .compactMap { warnung(o, wochentag: $0, start: start, dauer: dauer) }
    }

    /// "Mo, Di: öffnet erst um 08:00": gleiche Gründe zusammengefasst, nach erstem Wochentag sortiert.
    static func zeilen(_ warnungen: [OeffnungsWarnung]) -> [String] {
        var gruppen: [(grund: OeffnungsWarnung.Grund, tage: [Int])] = []
        for w in warnungen {
            if let i = gruppen.firstIndex(where: { $0.grund == w.grund }) { gruppen[i].tage.append(w.wochentag) } else { gruppen.append((w.grund, [w.wochentag])) }
        }
        return gruppen.map { g in
            let tage = TrainingLogik.wochentageText(g.tage)
            switch g.grund {
            case .vorOeffnung(let von): return String(localized: "\(tage): öffnet erst um \(Datum.uhrzeit(minuten: von))")
            case .nachSchluss(let bis): return String(localized: "\(tage): schließt um \(Datum.uhrzeit(minuten: bis))")
            }
        }
    }

    /// Hinweis beim Einchecken: das Studio hat jetzt zu. nil, wenn offen oder nichts bekannt ist.
    static func hinweis(_ o: StudioOeffnung, jetzt: Date) -> String? {
        guard o.bekannt else { return nil }
        let tag = Datum.wochentag(Datum.text(jetzt))
        let minute = Datum.minuten(Datum.uhrzeit(jetzt)) ?? 0
        guard !istOffen(o, wochentag: tag, minute: minute) else { return nil }
        let f = fenster(o, wochentag: tag)
        if minute < f.von { return String(localized: "Das Studio öffnet erst um \(Datum.uhrzeit(minuten: f.von)).") }
        return String(localized: "Das Studio hat seit \(Datum.uhrzeit(minuten: f.bis ?? 0)) zu.")
    }

    /// Eine Zeile für die Studio-Karte: "24/7 geöffnet", "Mo–Fr 08:00–22:00, Sa/So 09:00–18:00", "Zeiten unbekannt".
    static func kurztext(_ o: StudioOeffnung) -> String {
        if o.rund { return String(localized: "24/7 geöffnet") }
        var teile: [String] = []
        if let w = o.werktage { teile.append(String(localized: "Mo–Fr \(Datum.uhrzeit(minuten: w.von))–\(Datum.uhrzeit(minuten: w.bis))")) }
        if let w = o.wochenende { teile.append(String(localized: "Sa/So \(Datum.uhrzeit(minuten: w.von))–\(Datum.uhrzeit(minuten: w.bis))")) }
        return teile.isEmpty ? String(localized: "Zeiten unbekannt") : teile.joined(separator: ", ")
    }
}
