// Quelle: Lovea Health/Ernaehrung/EssenServer.swift (der Weg zum Server ist neu: Lumen-Server mit Konto-Kopfzeilen über den HTTPLader)
import Foundation

enum EssenServerFehler: Error, Equatable, Sendable {
    /// Kein Server in der Konfiguration, Gerät nicht angemeldet, oder der Server lehnt das Konto ab (401, 403).
    case keinZugang
    /// Kein Netz, Zeitüberschreitung oder eine Antwort, die nicht zu lesen ist.
    case netz
    /// Unerwarteter Status.
    case server(Int)
}

/// Produktdatenbank des Lumen-Servers (Open Food Facts DACH): `GET /essen/suche?q=&n=` und `GET /essen/barcode/<code>`.
/// Gleiche Kopfzeilen wie `/ki/foto`. Fragt nur auf Aufruf; die Entprellung liegt bei `LebensmittelSuche`.
struct EssenServerQuelle: Sendable {
    let zugang: any EssenKiZugang
    let lader: any HTTPLader

    nonisolated static let trefferZahl = 30

    private struct Produkt: Decodable {
        let code: String
        let name: String
        let marke: String?
        let menge: String?
        let portion_g: Double?
        let portion_name: String?
        let pro100: Naehrwerte
    }

    /// Ein kaputter Treffer (zum Beispiel ohne `kcal`) lässt die anderen stehen.
    private struct Versuch: Decodable {
        let produkt: Produkt?
        init(from decoder: Decoder) throws { produkt = try? Produkt(from: decoder) }
    }

    private struct SucheAntwort: Decodable { let treffer: [Versuch] }
    private struct BarcodeAntwort: Decodable { let produkt: Produkt? }

    func suche(_ text: String) async throws -> [Lebensmittel] {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let (daten, status) = try await hole("essen/suche", [URLQueryItem(name: "q", value: q), URLQueryItem(name: "n", value: String(Self.trefferZahl))])
        guard status == 200 else { throw EssenServerFehler.server(status) }
        guard let antwort = try? JSONDecoder().decode(SucheAntwort.self, from: daten) else { throw EssenServerFehler.netz }
        return antwort.treffer.compactMap { $0.produkt.map(Self.lebensmittel) }
    }

    /// nil = der Server kennt den Code nicht (404).
    func produkt(_ roh: String) async throws -> Lebensmittel? {
        let code = BarcodeLogik.normal(roh)
        guard !code.isEmpty else { return nil }
        let (daten, status) = try await hole("essen/barcode/\(code)", [])
        if status == 404 { return nil }
        guard status == 200 else { throw EssenServerFehler.server(status) }
        guard let antwort = try? JSONDecoder().decode(BarcodeAntwort.self, from: daten) else { throw EssenServerFehler.netz }
        return antwort.produkt.map(Self.lebensmittel)
    }

    private func hole(_ pfad: String, _ query: [URLQueryItem]) async throws -> (Data, Int) {
        guard let verbindung = zugang.verbindung() else { throw EssenServerFehler.keinZugang }
        guard var teile = URLComponents(url: verbindung.server.appendingPathComponent(pfad), resolvingAgainstBaseURL: false) else { throw EssenServerFehler.netz }
        if !query.isEmpty { teile.queryItems = query }
        guard let url = teile.url else { throw EssenServerFehler.netz }
        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = 6
        for (name, wert) in verbindung.kopfzeilen { anfrage.setValue(wert, forHTTPHeaderField: name) }
        let antwort: (Data, HTTPURLResponse)
        do {
            antwort = try await lader.lade(anfrage)
        } catch is CancellationError {
            throw CancellationError()
        } catch let fehler as URLError where fehler.code == .cancelled {
            throw CancellationError()
        } catch {
            throw EssenServerFehler.netz
        }
        if antwort.1.statusCode == 401 || antwort.1.statusCode == 403 { throw EssenServerFehler.keinZugang }
        return (antwort.0, antwort.1.statusCode)
    }

    /// Dieselbe Abbildung wie in Lovea (id `off-<code>`), dazu die Packung aus `menge` ("250 g", "1,5 l").
    private static func lebensmittel(_ p: Produkt) -> Lebensmittel {
        let pack = packung(p.menge)
        let marke = p.marke?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Lebensmittel(id: "off-\(p.code)", name: p.name, marke: marke?.isEmpty == true ? nil : marke, barcode: p.code,
                            fluessig: pack?.fluessig ?? false, pro100: p.pro100, portionMenge: p.portion_g,
                            portionName: p.portion_g == nil ? nil : p.portion_name.flatMap(ErnaehrungLogik.portionsName),
                            packungMenge: pack?.menge, quelle: "off")
    }

    /// "250 g" -> 250, "1,5 l" -> 1500 (flüssig), "500 ml" -> 500 (flüssig). Alles andere: nil.
    static func packung(_ text: String?) -> (menge: Double, fluessig: Bool)? {
        guard let text else { return nil }
        let t = text.lowercased().trimmingCharacters(in: .whitespaces)
        let zahl = String(t.prefix { $0.isNumber || $0 == "," || $0 == "." })
        let einheit = t.dropFirst(zahl.count).trimmingCharacters(in: .whitespaces)
        guard let wert = Double(zahl.replacingOccurrences(of: ",", with: ".")), wert > 0 else { return nil }
        switch einheit {
        case "g": return (wert, false)
        case "kg": return (wert * 1000, false)
        case "ml": return (wert, true)
        case "cl": return (wert * 10, true)
        case "l": return (wert * 1000, true)
        default: return nil
        }
    }
}
