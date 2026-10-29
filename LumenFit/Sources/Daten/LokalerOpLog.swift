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
        var ops: [Op] = []
        var defekt: [Data] = []
        let decoder = JSONDecoder()
        for zeile in daten.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true) {
            let roh = Data(zeile)
            decoder.userInfo[Op.zeileSchluessel] = roh   // Op schneidet `d` direkt aus den Bytes (Lovea Audit 1)
            if let op = try? decoder.decode(Op.self, from: roh) {
                if ids.insert(op.id).inserted { ops.append(op) }
            } else {
                defekt.append(roh)
            }
        }
        if !defekt.isEmpty { repariere(ops: ops, defekt: defekt) }
        return ops
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
