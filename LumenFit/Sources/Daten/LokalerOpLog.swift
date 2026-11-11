import Foundation

/// Was `LokalerOpLog.fuegeAn` getan hat: `doppelt` ist kein Fehler (die Op ist schon da), `fehlgeschlagen` heißt: nichts steht in der Datei
/// (Speicher voll, Dateirechte) und die Person muss es erfahren.
enum OpAnhang: Equatable, Sendable { case angehaengt, doppelt, fehlgeschlagen }

/// Der lokale Log eines Profils: eine Zeile JSON je `Op` in `ops.jsonl`, nur anhängen (SPEC 5.3).
/// Doppelte `id` werden übersprungen. Eine kaputte Zeile (meist die letzte, nach einem Abbruch beim Schreiben) wird übersprungen
/// und samt Text in `<datei>.defekt` gesichert; die Datei wird danach ohne sie neu geschrieben, damit Anhängen wieder auf einer sauberen Zeile beginnt.
struct LokalerOpLog: Sendable {
    let datei: URL
    private(set) var ids: Set<String> = []

    init(datei: URL) { self.datei = datei }

    /// Liest alle Ops (in Dateireihenfolge) und merkt sich ihre Ids.
    mutating func lade() -> [Op] {
        ids = []
        guard let daten = try? Data(contentsOf: datei), !daten.isEmpty else { return [] }
        let zeilen = daten.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        var ops: [Op] = []
        var defekt: [Data] = []
        for (i, op) in Self.dekodiere(zeilen).enumerated() {
            if let op {
                if ids.insert(op.id).inserted { ops.append(op) }
            } else {
                defekt.append(Data(zeilen[i]))
            }
        }
        if !defekt.isEmpty { repariere(ops: ops, defekt: defekt) }
        return ops
    }

    /// Dekodiert jede Zeile für sich (nil = kaputt), in Dateireihenfolge. Ab ein paar hundert Zeilen auf allen Kernen:
    /// der Start wartet auf diesen Schritt (Startzeit 11.11.2026: 7500 Ops brauchten im Simulator 580 ms bis zum ersten Bild).
    static func dekodiere(_ zeilen: [Data]) -> [Op?] {
        let n = zeilen.count
        let teile = min(ProcessInfo.processInfo.activeProcessorCount, 8)
        guard n >= 512, teile > 1 else {
            let decoder = JSONDecoder()
            return zeilen.map { eine($0, decoder) }
        }
        let ablage = OpAblage(anzahl: n)
        defer { ablage.frei() }
        DispatchQueue.concurrentPerform(iterations: teile) { t in
            let decoder = JSONDecoder()
            var i = t
            while i < n {
                ablage.puffer[i] = eine(zeilen[i], decoder)
                i += teile
            }
        }
        return Array(ablage.puffer)
    }

    private static func eine(_ zeile: Data, _ decoder: JSONDecoder) -> Op? {
        if let op = OpSchnellLeser.op(zeile) { return op }
        let roh = Data(zeile)
        decoder.userInfo[Op.zeileSchluessel] = roh   // Op schneidet `d` direkt aus den Bytes (Lovea Audit 1)
        return try? decoder.decode(Op.self, from: roh)
    }

    /// Hängt eine Op an, mit Ergebnis: angehängt, doppelte `id` (nichts geschrieben, kein Fehler) oder Schreiben fehlgeschlagen.
    @discardableResult
    mutating func fuegeAn(_ op: Op) -> OpAnhang {
        guard !ids.contains(op.id) else { return .doppelt }
        guard var zeile = try? JSONEncoder().encode(op) else { return .fehlgeschlagen }
        zeile.append(UInt8(ascii: "\n"))
        try? FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: datei.path) {
            guard (try? zeile.write(to: datei, options: .atomic)) != nil else { return .fehlgeschlagen }
        } else {
            guard let handle = try? FileHandle(forUpdating: datei) else { return .fehlgeschlagen }   // Lesen des letzten Bytes braucht Lese- und Schreibrecht
            defer { try? handle.close() }
            do {
                // Endet die Datei nicht auf einem Zeilenumbruch (Abbruch mitten im Schreiben), zuerst einen setzen.
                let ende = try handle.seekToEnd()
                if ende > 0 {
                    try handle.seek(toOffset: ende - 1)
                    if try handle.read(upToCount: 1) != Data([UInt8(ascii: "\n")]) { try handle.write(contentsOf: Data([UInt8(ascii: "\n")])) }
                }
                try handle.seekToEnd()
                try handle.write(contentsOf: zeile)
            } catch { return .fehlgeschlagen }
        }
        ids.insert(op.id)
        return .angehaengt
    }

    /// Wie `fuegeAn`, nur als Bool: true, wenn angehängt (doppelt und fehlgeschlagen sind beide false).
    @discardableResult
    mutating func haengeAn(_ op: Op) -> Bool { fuegeAn(op) == .angehaengt }

    private func repariere(ops: [Op], defekt: [Data]) {
        let sicherung = datei.appendingPathExtension("defekt")
        var text = (try? Data(contentsOf: sicherung)) ?? Data()
        for zeile in defekt { text.append(zeile); text.append(UInt8(ascii: "\n")) }
        guard (try? text.write(to: sicherung, options: .atomic)) != nil else { return }
        let encoder = JSONEncoder()
        var neu = Data()
        for op in ops { if let z = try? encoder.encode(op) { neu.append(z); neu.append(UInt8(ascii: "\n")) } }
        try? neu.write(to: datei, options: .atomic)
    }
}

/// Ergebnisplätze für `dekodiere`: jeder Kern schreibt nur seine eigenen Indizes, deshalb ohne Sperre.
private final class OpAblage: @unchecked Sendable {
    let puffer: UnsafeMutableBufferPointer<Op?>
    init(anzahl: Int) {
        puffer = .allocate(capacity: anzahl)
        puffer.initialize(repeating: nil)
    }
    func frei() {
        _ = puffer.deinitialize()
        puffer.deallocate()
    }
}

/// Schneller Weg für eine Zeile aus `ops.jsonl`: liest `id`, `art`, `von`, `zeit` als einfache Strings und schneidet `d` roh heraus, ohne JSONDecoder
/// und ohne ISO8601DateFormatter (der Start las 7500 Ops in 250 ms, fast alles im Decoder, Startzeit 11.11.2026). Alles Ungewöhnliche (Escape in
/// einem der vier Felder, fehlendes Feld, abgeschnittene Zeile, anderes Datumsformat) gibt nil; dann dekodiert der JSONDecoder wie vorher.
// shortcut: `d` wird nur auf Klammern und Strings geprüft, nicht voll validiert; ein kaputtes, aber ausgeglichenes `d` bleibt im Log statt in `.defekt`,
// die Faltung überspringt es (daten() gibt nil). Volle Prüfung nur, falls je so eine Zeile auftaucht.
enum OpSchnellLeser {
    static func op(_ zeile: Data) -> Op? {
        zeile.withUnsafeBytes { roh -> Op? in
            let b = roh.bindMemory(to: UInt8.self)
            var leser = Leser(b: b)
            return leser.op()
        }
    }

    private struct Leser {
        let b: UnsafeBufferPointer<UInt8>
        var i = 0

        init(b: UnsafeBufferPointer<UInt8>) { self.b = b }

        private static let anf = UInt8(ascii: "\""), rueck = UInt8(ascii: "\\")

        mutating func leer() {
            while i < b.count, b[i] == 0x20 || b[i] == 0x09 || b[i] == 0x0A || b[i] == 0x0D { i += 1 }
        }

        /// Ein String ohne Escape: der Bereich zwischen den Anführungszeichen, nil bei Escape oder Zeilenende.
        mutating func einfacherString() -> Range<Int>? {
            guard i < b.count, b[i] == Self.anf else { return nil }
            let start = i + 1
            var j = start
            while j < b.count, b[j] != Self.anf {
                if b[j] == Self.rueck { return nil }
                j += 1
            }
            guard j < b.count else { return nil }
            i = j + 1
            return start..<j
        }

        /// Hinter das schließende Anführungszeichen des Strings, der bei `i` beginnt.
        mutating func stringUeberspringen() -> Bool {
            i += 1
            while i < b.count, b[i] != Self.anf { i += b[i] == Self.rueck ? 2 : 1 }
            guard i < b.count else { return false }
            i += 1
            return true
        }

        /// Überspringt einen beliebigen Wert; false, wenn die Zeile vorher endet.
        mutating func ueberspringe() -> Bool {
            guard i < b.count else { return false }
            let c = b[i]
            if c == Self.anf { return stringUeberspringen() }
            if c == UInt8(ascii: "{") || c == UInt8(ascii: "[") {
                var tiefe = 0
                while i < b.count {
                    let x = b[i]
                    if x == Self.anf {
                        guard stringUeberspringen() else { return false }
                        continue
                    }
                    if x == UInt8(ascii: "{") || x == UInt8(ascii: "[") {
                        tiefe += 1
                    } else if x == UInt8(ascii: "}") || x == UInt8(ascii: "]") {
                        tiefe -= 1
                        if tiefe == 0 { i += 1; return true }
                    }
                    i += 1
                }
                return false
            }
            // Zahl, true, false, null
            let start = i
            while i < b.count, b[i] != UInt8(ascii: ","), b[i] != UInt8(ascii: "}"), b[i] != UInt8(ascii: "]"),
                  b[i] != 0x20, b[i] != 0x09, b[i] != 0x0A, b[i] != 0x0D { i += 1 }
            return i > start
        }

        func gleich(_ r: Range<Int>, _ text: StaticString) -> Bool {
            text.withUTF8Buffer { t in
                guard r.count == t.count else { return false }
                for k in 0..<t.count where b[r.lowerBound + k] != t[k] { return false }
                return true
            }
        }

        func text(_ r: Range<Int>) -> String { String(decoding: UnsafeBufferPointer(rebasing: b[r]), as: UTF8.self) }

        mutating func op() -> Op? {
            var id: Range<Int>?, art: Range<Int>?, von: Range<Int>?, zeit: Range<Int>?, d: Range<Int>?
            leer()
            guard i < b.count, b[i] == UInt8(ascii: "{") else { return nil }
            i += 1
            leer()
            while true {
                guard let schluessel = einfacherString() else { return nil }
                leer()
                guard i < b.count, b[i] == UInt8(ascii: ":") else { return nil }
                i += 1
                leer()
                if gleich(schluessel, "d") {
                    let start = i
                    guard ueberspringe() else { return nil }
                    d = start..<i
                } else if gleich(schluessel, "id") { guard let r = einfacherString() else { return nil }; id = r
                } else if gleich(schluessel, "art") { guard let r = einfacherString() else { return nil }; art = r
                } else if gleich(schluessel, "von") { guard let r = einfacherString() else { return nil }; von = r
                } else if gleich(schluessel, "zeit") { guard let r = einfacherString() else { return nil }; zeit = r
                } else {
                    guard ueberspringe() else { return nil }
                }
                leer()
                guard i < b.count else { return nil }
                if b[i] == UInt8(ascii: ",") { i += 1; leer(); continue }
                guard b[i] == UInt8(ascii: "}") else { return nil }
                i += 1
                break
            }
            leer()
            guard i == b.count, let id, let art, let von, let zeit, let d, !d.isEmpty,
                  let datum = OpSchnellLeser.datum(UnsafeBufferPointer(rebasing: b[zeit])) else { return nil }
            return Op(id: text(id), art: text(art), von: ProfilID(rawValue: text(von)), zeit: datum, d: Data(buffer: UnsafeBufferPointer(rebasing: b[d])))
        }
    }

    /// `YYYY-MM-DDTHH:MM:SS[.f...](Z|±HH:MM)`, wie `Op` es schreibt; sonst nil.
    static func datum(_ t: UnsafeBufferPointer<UInt8>) -> Date? {
        func zahl(_ von: Int, _ laenge: Int) -> Int? {
            guard von + laenge <= t.count else { return nil }
            var w = 0
            for k in von..<(von + laenge) {
                let c = t[k]
                guard c >= 0x30, c <= 0x39 else { return nil }
                w = w * 10 + Int(c - 0x30)
            }
            return w
        }
        guard t.count >= 20, t[4] == UInt8(ascii: "-"), t[7] == UInt8(ascii: "-"), t[10] == UInt8(ascii: "T"), t[13] == UInt8(ascii: ":"), t[16] == UInt8(ascii: ":"),
              let jahr = zahl(0, 4), let monat = zahl(5, 2), let tag = zahl(8, 2), let stunde = zahl(11, 2), let minute = zahl(14, 2), let sekunde = zahl(17, 2),
              (1...12).contains(monat), (1...31).contains(tag), stunde < 24, minute < 60, sekunde < 61 else { return nil }
        var i = 19
        var bruch = 0.0
        if t[i] == UInt8(ascii: ".") {
            i += 1
            var faktor = 0.1
            let start = i
            while i < t.count, t[i] >= 0x30, t[i] <= 0x39 { bruch += Double(t[i] - 0x30) * faktor; faktor /= 10; i += 1 }
            guard i > start else { return nil }
        }
        guard i < t.count else { return nil }
        var versatz = 0
        if t[i] == UInt8(ascii: "Z") {
            i += 1
        } else if t[i] == UInt8(ascii: "+") || t[i] == UInt8(ascii: "-") {
            guard i + 6 == t.count, t[i + 3] == UInt8(ascii: ":"), let h = zahl(i + 1, 2), let m = zahl(i + 4, 2) else { return nil }
            versatz = (h * 3600 + m * 60) * (t[i] == UInt8(ascii: "-") ? -1 : 1)
            i += 6
        } else {
            return nil
        }
        guard i == t.count else { return nil }
        // Tage seit 1970 aus dem Kalenderdatum (Howard Hinnant, days_from_civil)
        let y = monat <= 2 ? jahr - 1 : jahr
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (monat + (monat > 2 ? -3 : 9)) + 2) / 5 + tag - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let tage = era * 146_097 + doe - 719_468
        let sekunden = tage * 86_400 + stunde * 3600 + minute * 60 + sekunde - versatz
        return Date(timeIntervalSince1970: TimeInterval(sekunden) + bruch)
    }
}
