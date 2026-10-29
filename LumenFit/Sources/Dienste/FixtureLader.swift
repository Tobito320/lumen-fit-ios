import Foundation

/// `HTTPLader` aus Dateien (Vorschau, Demo und Tests mit `-lumenFitFixtures`): die Antwort steht in einer Datei, die so heißt wie der Pfad der Anfrage
/// (`/api/v2/product/123.json` -> `api_v2_product_123.json`; ohne Endung zählt auch `api_v2_product_123.json`), irgendwo unter dem Fixture-Ordner. Ohne Datei: 404. Ohne Ordner nie Netz, immer 404.
struct FixtureLader: HTTPLader {
    let ordner: URL?

    func lade(_ anfrage: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = anfrage.url ?? URL(fileURLWithPath: "/")
        let name = url.path.split(separator: "/").joined(separator: "_")
        if let datei = finde(name) ?? finde(name + ".json"), let daten = try? Data(contentsOf: datei) { return (daten, try antwort(url, 200)) }
        return (Data(), try antwort(url, 404))
    }

    private func finde(_ name: String) -> URL? {
        guard let ordner, !name.isEmpty, let suche = FileManager.default.enumerator(at: ordner, includingPropertiesForKeys: nil) else { return nil }
        for fall in suche { if let url = fall as? URL, url.lastPathComponent == name { return url } }
        return nil
    }

    private func antwort(_ url: URL, _ status: Int) throws -> HTTPURLResponse {
        guard let antwort = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else { throw HTTPFehler.keineAntwort }
        return antwort
    }
}
