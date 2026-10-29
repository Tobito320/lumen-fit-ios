import Foundation

/// Eine Codable-Datei auf der Platte: atomar schreiben, defekte Datei sichern statt verlieren.
/// Datumswerte als Sekunden seit 1970 (verlustfrei, auch für Widgets lesbar).
struct JSONDatei<Wert: Codable & Sendable>: Sendable {
    let url: URL

    init(_ url: URL) {
        self.url = url
    }

    /// nil, wenn die Datei fehlt. Ist sie defekt, wird sie als `<name>.defekt` gesichert und nil geliefert (der Store startet leer).
    func lade() -> Wert? {
        guard let daten = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        if let wert = try? decoder.decode(Wert.self, from: daten) { return wert }
        sichereDefekte()
        return nil
    }

    /// Schreibt atomar (erst temporär, dann ersetzen). Gibt false zurück, wenn es nicht ging (zum Beispiel kein Platz).
    @discardableResult
    func speichere(_ wert: Wert) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        guard let daten = try? encoder.encode(wert) else { return false }
        let ordner = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return (try? daten.write(to: url, options: .atomic)) != nil
    }

    func loesche() {
        try? FileManager.default.removeItem(at: url)
    }

    private func sichereDefekte() {
        let ziel = url.appendingPathExtension("defekt")
        try? FileManager.default.removeItem(at: ziel)
        try? FileManager.default.moveItem(at: url, to: ziel)
    }
}
