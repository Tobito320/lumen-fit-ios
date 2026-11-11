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
