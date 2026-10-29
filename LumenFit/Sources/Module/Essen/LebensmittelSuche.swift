import Foundation
import Observation

/// Zustand der Online-Suche, die nur auf "Suchen" läuft.
enum EssenOnlineZustand: Equatable, Sendable {
    case ruhig
    case laedt
    case fertig(treffer: Int)
    case limit(sekunden: Int)
    case offline
    case fehler
}

/// Suche für Textfeld und Barcode: BLS lokal zuerst (ohne Netz), danach Open Food Facts, aber nur auf eine Nutzeraktion hin.
/// Ein unbekannter Barcode endet in `BarcodeErgebnis.unbekannt` und führt die Ansicht zur Eingabe von Hand. Der letzte Barcode-Treffer
/// wird gemerkt, ein zweiter Scan desselben Codes fragt nicht noch einmal nach.
@MainActor @Observable
final class LebensmittelSuche {
    @ObservationIgnored private let index: LebensmittelIndex
    @ObservationIgnored private let off: OpenFoodFactsQuelle
    @ObservationIgnored private let speicher: @MainActor (String) -> Lebensmittel?
    @ObservationIgnored private(set) var letzterTreffer: (code: String, lebensmittel: Lebensmittel)?

    private(set) var stand = SuchStand()
    private(set) var text = ""
    private(set) var online: EssenOnlineZustand = .ruhig

    /// `speicher` findet einen Barcode in Tagebuch, Zuletzt und Eigenen (`EssenStore.offline(barcode:)`).
    init(index: LebensmittelIndex, off: OpenFoodFactsQuelle, speicher: @escaping @MainActor (String) -> Lebensmittel?) {
        self.index = index
        self.off = off
        self.speicher = speicher
    }

    /// Jede Eingabe im Textfeld: nur lokal (Favoriten, Zuletzt, Eigene vorne, dann BLS), nie Netz.
    func eingabe(_ neu: String, vorne: [Lebensmittel]) {
        text = neu
        online = .ruhig
        var treffer = index.suchen(neu, vorne: vorne, anzahl: 50)
        // Der BLS schreibt "Hafer Flocken" in zwei Wörtern: ein langes Wort wird an jeder Stelle geteilt, echte Treffer stehen dann vorn.
        var gesehen = Set<String>()
        var geteilt: [Lebensmittel] = []
        for variante in Self.teilungen(neu) {
            let anfang = LebensmittelBasis.normal(variante)
            // Nur Namen, die mit der Teilung beginnen: "haf erflocken" darf nicht über das Wortende eines Plätzchens treffen.
            for l in index.suchen(variante, vorne: [], anzahl: 10) where LebensmittelBasis.schluessel(l).hasPrefix(anfang) && gesehen.insert(l.id).inserted {
                geteilt.append(l)
            }
        }
        if !geteilt.isEmpty {
            let ids = Set(geteilt.map(\.id))
            treffer = Array((geteilt + treffer.filter { !ids.contains($0.id) }).prefix(50))
        }
        stand = SuchStand(nummer: stand.nummer + 1, lokal: treffer, server: [], sichtbar: treffer)
    }

    /// Ein einzelnes Wort ab 7 Zeichen an jeder Stelle in zwei Wörter geteilt ("haferflocken" -> "hafer flocken"); sonst leer.
    nonisolated static func teilungen(_ text: String) -> [String] {
        let zeichen = Array(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard zeichen.count >= 7, !zeichen.contains(" ") else { return [] }
        return (3...(zeichen.count - 3)).map { String(zeichen[..<$0]) + " " + String(zeichen[$0...]) }
    }

    /// Nur auf "Suchen": Open Food Facts. Treffer kommen hinten dran, nichts springt; eine Antwort zu einer überholten Eingabe wird verworfen.
    func onlineSuchen() async {
        let anfrage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard anfrage.count >= 2 else { return }
        let nummer = stand.nummer
        online = .laedt
        do {
            let antwort = try await off.suche(anfrage)
            guard nummer == stand.nummer else { return }
            stand = SuchZusammenfuehrung.server(stand, antwort: antwort, nummer: nummer)
            online = .fertig(treffer: antwort.count)
        } catch let fehler as OffFehler {
            guard nummer == stand.nummer else { return }
            switch fehler {
            case .limit(let sekunden): online = .limit(sekunden: sekunden)
            case .server, .antwort: online = .fehler
            }
        } catch {
            guard nummer == stand.nummer else { return }
            online = .offline
        }
    }

    /// Barcode aus Kamera oder Eingabe: Speicher, dann Open Food Facts.
    func barcode(_ roh: String) async -> BarcodeErgebnis {
        let code = BarcodeLogik.normal(roh)
        if let gemerkt = letzterTreffer, gemerkt.code == code { return .gefunden(gemerkt.lebensmittel) }
        let speicher = speicher
        let off = off
        let quellen = BarcodeQuellen(lokal: { code in await speicher(code) }, offLive: { code in try await off.produkt(code) })
        let ergebnis = await BarcodeKette.suchen(code, quellen)
        if case .gefunden(let l) = ergebnis { letzterTreffer = (code, l) }
        return ergebnis
    }

    /// Ein Treffer, der nicht aus dem Barcode kam (Auswahl in der Liste), wird ebenfalls gemerkt, wenn er einen Barcode hat.
    func merke(_ l: Lebensmittel) {
        if let code = l.barcode { letzterTreffer = (BarcodeLogik.normal(code), l) }
    }
}
