import Foundation

/// Netz hinter einem Port: Module bekommen ihn aus `AppUmgebung.http`, Tests einen `SkriptLader`.
protocol HTTPLader: Sendable {
    func lade(_ anfrage: URLRequest) async throws -> (Data, HTTPURLResponse)
}

enum HTTPFehler: Error, Equatable, Sendable { case keineAntwort }

/// Der echte Lader über `URLSession`.
struct URLSessionLader: HTTPLader {
    func lade(_ anfrage: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        guard let http = antwort as? HTTPURLResponse else { throw HTTPFehler.keineAntwort }
        return (daten, http)
    }
}
