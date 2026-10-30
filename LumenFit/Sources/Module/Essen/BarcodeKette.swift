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
    /// Der Code ist unbekannt, aber eine Namensquelle kennt den Namen: ähnliche Produkte zur Auswahl ("Meintest du ...?").
    case vorschlaege(name: String, [Lebensmittel], code: String)
}

/// Die Quellen der Kette. Der eigene Server aus Lovea fehlt hier. `name` und `namensSuche` (Lovea: Open EAN Database) sind optional und
/// stehen in Lumen auf `nil`, solange es keine Namensquelle gibt; dann endet ein unbekannter Code wie bisher in `unbekannt`.
struct BarcodeQuellen: Sendable {
    var lokal: @Sendable (String) async -> Lebensmittel?
    var offLive: @Sendable (String) async throws -> Lebensmittel?
    /// Name (und Marke) zu einem Code, der in keiner Quelle Nährwerte hat.
    var name: (@Sendable (String) async throws -> (name: String, marke: String?)?)? = nil
    /// Ähnliche Produkte zu einem Namen.
    var namensSuche: (@Sendable (String) async -> [Lebensmittel])? = nil
}

/// Speicher (Tagebuch, Zuletzt, Eigene) -> Open Food Facts. Open Food Facts wird nur auf eine Nutzeraktion hin gefragt.
enum BarcodeKette {
    static func suchen(_ roh: String, _ q: BarcodeQuellen) async -> BarcodeErgebnis {
        let code = BarcodeLogik.normal(roh)
        if let l = await q.lokal(code) { return .gefunden(l) }
        do {
            if let l = try await q.offLive(code) { return .gefunden(l) }
            return await vorschlaege(code, q) ?? .unbekannt(code)
        } catch let fehler as OffFehler {
            switch fehler {
            case .limit(let sekunden): return .limit(code, sekunden: sekunden)
            case .server, .antwort: return .fehler(code)
            }
        } catch {
            return .offline(code)
        }
    }

    /// Nur mit Namensquelle: ein Name, dazu ähnliche Produkte. Fehler der Namensquelle zählen als "keine Vorschläge".
    private static func vorschlaege(_ code: String, _ q: BarcodeQuellen) async -> BarcodeErgebnis? {
        guard let nameQuelle = q.name, let suche = q.namensSuche,
              let n = (try? await nameQuelle(code)) ?? nil else { return nil }
        let text = [n.marke, n.name].compactMap { $0 }.joined(separator: " ")
        let liste = await suche(text)
        return liste.isEmpty ? nil : .vorschlaege(name: n.name, liste, code: code)
    }
}
