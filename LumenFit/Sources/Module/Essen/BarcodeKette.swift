// Quelle: Lovea Health/Ernaehrung/BarcodeKette.swift
import Foundation

enum BarcodeLogik {
    /// Nur Ziffern; UPC-A (12) bekommt eine führende 0 (so führt Open Food Facts sie).
    static func normal(_ roh: String) -> String {
        let z = roh.filter(\.isNumber)
        return z.count == 12 ? "0" + z : z
    }

    /// Text im Suchfeld sieht wie ein getippter oder eingefügter Barcode aus: nur Ziffern, plausible Länge
    /// (EAN-8, UPC-A oder EAN-13). Alles andere bleibt normale Textsuche.
    static func istBarcodeEingabe(_ text: String) -> Bool {
        guard text.allSatisfy(\.isNumber) else { return false }
        return [8, 12, 13].contains(text.count)
    }
}

enum BarcodeErgebnis: Equatable, Sendable {
    case gefunden(Lebensmittel)
    /// Kein Treffer in Speicher und Open Food Facts: der Nutzer gibt die Werte von Hand ein.
    case unbekannt(String)
    /// Kein Netz.
    case offline(String)
    /// Open Food Facts erlaubt nur 15 Abfragen je Minute; `sekunden` bis zur nächsten freien.
    case limit(String, sekunden: Int)
    /// Open Food Facts antwortet gerade nicht (Serverfehler).
    case fehler(String)
}

/// Die zwei Quellen der Kette. Die Quellen `server` (eigener Server) und `name` (Open EAN Database) aus Lovea gibt es hier nicht.
struct BarcodeQuellen: Sendable {
    var lokal: @Sendable (String) async -> Lebensmittel?
    var offLive: @Sendable (String) async throws -> Lebensmittel?
}

/// Speicher (Tagebuch, Zuletzt, Eigene) -> Open Food Facts. Open Food Facts wird nur auf eine Nutzeraktion hin gefragt.
enum BarcodeKette {
    static func suchen(_ roh: String, _ q: BarcodeQuellen) async -> BarcodeErgebnis {
        let code = BarcodeLogik.normal(roh)
        if let l = await q.lokal(code) { return .gefunden(l) }
        do {
            if let l = try await q.offLive(code) { return .gefunden(l) }
            return .unbekannt(code)
        } catch let fehler as OffFehler {
            switch fehler {
            case .limit(let sekunden): return .limit(code, sekunden: sekunden)
            case .server, .antwort: return .fehler(code)
            }
        } catch {
            return .offline(code)
        }
    }
}
