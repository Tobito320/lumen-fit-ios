import Foundation

// Wecker und Erinnerungen per Coach-Marker, übernommen aus Loveas `CoachWecker.swift` (W-026) und der Prüfung `weckerPlusPruefen` des Lovea-Servers.
// Der Coach schreibt am Ende einer Antwort eine der Formen:
//   [[wecker: neu | HH:MM | Wiederholung | Name]]            Name optional
//   [[wecker: aendern | Id | HH:MM | Wiederholung | Name]]   ohne Name bleibt er
//   [[wecker: an | Id]]  [[wecker: aus | Id]]                 Id haupt = der Hauptwecker
//   [[wecker: loeschen | Id]]
//   [[erinnern: neu | HH:MM | Wiederholung | Text]]           dieselben fünf, Text statt Name (Pflicht bei neu)
// Wiederholung: einmalig, taeglich, werktags, wochenende, Wochentage `mo,di,...`, bei Erinnerungen auch ein Datum JJJJ-MM-TT.
// Lumen Fit stellt keinen Wecker selbst: ein bestätigter Befehl wird ein Auftrag in `wecker-auftraege.json`, Lumen Alarm führt ihn aus
// (`AlarmWeckerDienst`). Anders als bei Lovea prüft hier die App, was dort der Server prüft: Ids nur aus dem Stand von Lumen Alarm, Namenlänge, Minute, Datum.

extension WeckerBefehl {
    nonisolated static let haupt = "haupt"
    nonisolated static let maxName = 30
    nonisolated static let maxText = 60

    private nonisolated static let codes = ["mo", "di", "mi", "do", "fr", "sa", "so"]

    private struct Wann {
        var tage: [Int]
        var datum: String?
    }

    // MARK: - Lesen (Form)

    /// Marker `wecker` oder `erinnern` mit den Feldern hinter dem Doppelpunkt (schon an `|` getrennt und gekürzt). nil: gilt nicht, es geschieht nichts.
    /// Geprüft ist nur die Form; ob die Ids existieren, prüft `geprueft`.
    nonisolated static func aus(_ name: String, _ teile: [String]) -> WeckerBefehl? {
        guard let verb = teile.first?.lowercased() else { return nil }
        let wecker = name == "wecker"
        let f = Array(teile.dropFirst())
        switch verb {
        case "an", "aus":
            guard f.count == 1, let id = kennung(f[0]) else { return nil }
            return wecker ? .weckerSchalter(id: id, an: verb == "an") : .erinnerungSchalter(id: id, an: verb == "an")
        case "loeschen":
            guard f.count == 1, let id = kennung(f[0]) else { return nil }
            return wecker ? .weckerLoeschen(id: id) : .erinnerungLoeschen(id: id)
        case "neu":
            guard f.count >= 2, let minute = uhrMinute(f[0]), let wann = wiederholung(f[1], datum: !wecker) else { return nil }
            let rest = einzeilig(f.dropFirst(2), max: wecker ? maxName : maxText)
            if wecker { return .weckerNeu(minute: minute, tage: wann.tage, name: rest) }
            return rest.isEmpty ? nil : .erinnerungNeu(minute: minute, tage: wann.tage, datum: wann.datum, text: rest)
        case "aendern":
            guard f.count >= 3, let id = kennung(f[0]), let minute = uhrMinute(f[1]), let wann = wiederholung(f[2], datum: !wecker) else { return nil }
            let rest = einzeilig(f.dropFirst(3), max: wecker ? maxName : maxText)
            let neu: String? = rest.isEmpty ? nil : rest
            return wecker ? .weckerAendern(id: id, minute: minute, tage: wann.tage, name: neu)
                : .erinnerungAendern(id: id, minute: minute, tage: wann.tage, datum: wann.datum, text: neu)
        default:
            return nil
        }
    }

    /// `H:MM` oder `HH:MM` als Minuten seit Mitternacht; Minuten immer zweistellig.
    nonisolated static func uhrMinute(_ text: String) -> Int? {
        let teile = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard teile.count == 2, (1...2).contains(teile[0].count), teile[1].count == 2,
              teile.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let h = Int(teile[0]), let m = Int(teile[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }

    private nonisolated static func kennung(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        return (1...64).contains(t.count) && !t.contains(where: \.isNewline) ? t : nil
    }

    /// Name oder Text als eine Zeile: ohne `|` und eckige Doppelklammern, Umbrüche zu Leerzeichen, auf `max` Zeichen gekürzt.
    nonisolated static func einzeilig(_ felder: ArraySlice<String>, max: Int) -> String {
        let roh = felder.joined(separator: " ").replacingOccurrences(of: "|", with: " ")
            .replacingOccurrences(of: "[[", with: " ").replacingOccurrences(of: "]]", with: " ")
        let eine = roh.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(eine.prefix(max)).trimmingCharacters(in: .whitespaces)
    }

    private nonisolated static func wiederholung(_ text: String, datum erlaubt: Bool) -> Wann? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        switch t {
        case "einmalig": return Wann(tage: [], datum: nil)
        case "taeglich", "täglich": return Wann(tage: Array(1...7), datum: nil)
        case "werktags": return Wann(tage: Array(1...5), datum: nil)
        case "wochenende": return Wann(tage: [6, 7], datum: nil)
        default: break
        }
        if erlaubt, SchlafNachtLogik.gueltigerTag(t) { return Wann(tage: [], datum: t) }
        let nummern = t.split(separator: ",", omittingEmptySubsequences: false).map { codes.firstIndex(of: $0.trimmingCharacters(in: .whitespaces)) }
        guard !nummern.isEmpty, !nummern.contains(nil) else { return nil }
        return Wann(tage: Array(Set(nummern.compactMap { $0 }.map { $0 + 1 })).sorted(), datum: nil)
    }

    /// Die Wochentage im Wort des Markers: einmalig (keine), taeglich, werktags, wochenende oder `mo,mi`.
    nonisolated static func wort(tage: [Int]) -> String {
        let menge = Set(tage.filter { (1...7).contains($0) })
        if menge.isEmpty { return "einmalig" }
        if menge.count == 7 { return "taeglich" }
        if menge == Set([1, 2, 3, 4, 5]) { return "werktags" }
        if menge == Set([6, 7]) { return "wochenende" }
        return menge.sorted().map { codes[$0 - 1] }.joined(separator: ",")
    }

    // MARK: - Prüfen gegen den Stand von Lumen Alarm

    /// Der Befehl mit den Ids, wie der Stand sie schreibt, oder nil, wenn er nicht gilt: unbekannte Id (Ids nur aus den Listen, beim Wecker auch `haupt`
    /// für an und aus), ein Datum, das schon vorbei ist (heute nur mit einer Uhrzeit, die noch kommt). `heute` ist "JJJJ-MM-TT", `jetztMinute` Minuten seit Mitternacht.
    nonisolated func geprueft(gegen stand: WeckerStandDatei, heute: String, jetztMinute: Int) -> WeckerBefehl? {
        func weckerId(_ id: String) -> String? { stand.wecker.first { $0.id.lowercased() == id.lowercased() }?.id }
        func erinnerungId(_ id: String) -> String? { stand.erinnerungen.first { $0.id.lowercased() == id.lowercased() }?.id }
        func datumOk(_ datum: String?, _ minute: Int) -> Bool {
            guard let datum else { return true }
            return datum > heute || (datum == heute && minute > jetztMinute)
        }
        switch self {
        case .weckerNeu:
            return self
        case .weckerAendern(let id, let minute, let tage, let name):
            return weckerId(id).map { .weckerAendern(id: $0, minute: minute, tage: tage, name: name) }
        case .weckerSchalter(let id, let an):
            if id.lowercased() == Self.haupt { return stand.haupt == nil ? nil : .weckerSchalter(id: Self.haupt, an: an) }
            return weckerId(id).map { .weckerSchalter(id: $0, an: an) }
        case .weckerLoeschen(let id):
            return weckerId(id).map { .weckerLoeschen(id: $0) }
        case .erinnerungNeu(let minute, _, let datum, _):
            return datumOk(datum, minute) ? self : nil
        case .erinnerungAendern(let id, let minute, let tage, let datum, let text):
            guard datumOk(datum, minute) else { return nil }
            return erinnerungId(id).map { .erinnerungAendern(id: $0, minute: minute, tage: tage, datum: datum, text: text) }
        case .erinnerungSchalter(let id, let an):
            return erinnerungId(id).map { .erinnerungSchalter(id: $0, an: an) }
        case .erinnerungLoeschen(let id):
            return erinnerungId(id).map { .erinnerungLoeschen(id: $0) }
        }
    }

    // MARK: - Anzeige

    /// Der Hauptwecker oder ein Wecker im Stand: die Zeile beim Namen nennen, nicht bei der Id.
    nonisolated func zeile(stand: WeckerStandDatei?) -> String {
        func weckerName(_ id: String) -> String {
            if id.lowercased() == Self.haupt { return "Hauptwecker" }
            let w = stand?.wecker.first { $0.id == id }
            return "Wecker \(w.map { Datum.uhrzeit(minuten: $0.minute) } ?? "")\(w?.name.map { " (\($0))" } ?? "")".trimmingCharacters(in: .whitespaces)
        }
        func erinnerungName(_ id: String) -> String {
            let e = stand?.erinnerungen.first { $0.id == id }
            return "Erinnerung \(e.map { "\(Datum.uhrzeit(minuten: $0.minute)) \($0.text)" } ?? "")".trimmingCharacters(in: .whitespaces)
        }
        func wann(_ minute: Int, _ tage: [Int], _ datum: String?) -> String {
            "\(Datum.uhrzeit(minuten: minute)), \(datum ?? Self.wort(tage: tage))"
        }
        switch self {
        case .weckerNeu(let minute, let tage, let name):
            return "Wecker \(wann(minute, tage, nil))\(name.isEmpty ? "" : ": \(name)")"
        case .weckerAendern(let id, let minute, let tage, let name):
            return "\(weckerName(id)) ändern auf \(wann(minute, tage, nil))\(name.map { ": \($0)" } ?? "")"
        case .weckerSchalter(let id, let an):
            return "\(weckerName(id)) \(an ? "einschalten" : "ausschalten")"
        case .weckerLoeschen(let id):
            return "\(weckerName(id)) löschen"
        case .erinnerungNeu(let minute, let tage, let datum, let text):
            return "Erinnerung \(wann(minute, tage, datum)): \(text)"
        case .erinnerungAendern(let id, let minute, let tage, let datum, let text):
            return "\(erinnerungName(id)) ändern auf \(wann(minute, tage, datum))\(text.map { ": \($0)" } ?? "")"
        case .erinnerungSchalter(let id, let an):
            return "\(erinnerungName(id)) \(an ? "einschalten" : "ausschalten")"
        case .erinnerungLoeschen(let id):
            return "\(erinnerungName(id)) löschen"
        }
    }
}
