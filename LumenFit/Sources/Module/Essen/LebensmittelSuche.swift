import Foundation
import Observation

/// Zustand der Server-Suche, die beim Tippen mitläuft. Lokale Treffer bleiben in jedem Zustand stehen.
enum EssenOnlineZustand: Equatable, Sendable {
    case ruhig
    case laedt
    case fertig(treffer: Int)
    /// Kein Netz.
    case offline
    /// Der Server antwortet nicht, lehnt das Konto ab oder das Gerät ist nicht angemeldet.
    case fehler
}

/// Suche für Textfeld und Barcode. Beim Tippen: BLS lokal sofort (`eingabe`), danach die Produktdatenbank des Lumen-Servers (`serverSuchen`,
/// ab 2 Zeichen, entprellt). Ein unbekannter Barcode endet in `BarcodeErgebnis.unbekannt` und führt die Ansicht zur Eingabe von Hand. Barcode:
/// Speicher, Server, dann Open Food Facts als Rückfall. Der letzte Barcode-Treffer wird gemerkt, ein zweiter Scan desselben Codes fragt nicht noch einmal nach.
@MainActor @Observable
final class LebensmittelSuche {
    @ObservationIgnored private let index: LebensmittelIndex
    @ObservationIgnored private let off: OpenFoodFactsQuelle
    @ObservationIgnored private let server: EssenServerQuelle?
    @ObservationIgnored private let speicher: @MainActor (String) -> Lebensmittel?
    @ObservationIgnored private(set) var letzterTreffer: (code: String, lebensmittel: Lebensmittel)?
    /// Ergebnis des Nachladens je Barcode (auch "nichts" und Fehler), damit jeder Code in einer Sitzung höchstens einmal bei Open Food Facts gefragt wird.
    @ObservationIgnored private var nachgeladen: [String: Lebensmittel?] = [:]
    @ObservationIgnored private var nachladenLaeuft: Set<String> = []

    private(set) var stand = SuchStand()
    private(set) var text = ""
    private(set) var online: EssenOnlineZustand = .ruhig

    /// Pause nach dem letzten Tastendruck, bevor der Server gefragt wird.
    nonisolated static let serverPause: Duration = .milliseconds(250)

    /// `speicher` findet einen Barcode in Tagebuch, Zuletzt und Eigenen (`EssenStore.offline(barcode:)`). Ohne `server` bleibt es bei BLS und Open Food Facts für Barcodes.
    init(index: LebensmittelIndex, off: OpenFoodFactsQuelle, server: EssenServerQuelle? = nil, speicher: @escaping @MainActor (String) -> Lebensmittel?) {
        self.index = index
        self.off = off
        self.server = server
        self.speicher = speicher
    }

    /// Jede Eingabe im Textfeld: nur lokal (Favoriten, Zuletzt, Eigene vorne, dann BLS), sofort und ohne Netz.
    func eingabe(_ neu: String, vorne: [Lebensmittel]) {
        text = neu
        online = .ruhig
        var treffer = Self.grundlebensmittelZuerst(index.suchen(neu, vorne: vorne, anzahl: 2000), text: neu, vorne: vorne)
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

    /// Reihenfolge für ein einzelnes Suchwort (höchstens 50): Favoriten, Zuletzt und Eigene zuerst, dann Namen, die mit genau diesem Wort beginnen
    /// ("Apfel roh" vor "Apfelmus"), dann bis zu acht Namen, in denen das Wort der Kopf einer Zusammensetzung ist ("Ei" findet "Hühnerei roh"), dann der Rest.
    nonisolated static func grundlebensmittelZuerst(_ treffer: [Lebensmittel], text: String, vorne: [Lebensmittel]) -> [Lebensmittel] {
        let wort = LebensmittelBasis.normal(text)
        guard !wort.isEmpty, !wort.contains(" ") else { return Array(treffer.prefix(50)) }
        let eigene = Set(vorne.map(\.id))
        let basis = treffer.filter { !eigene.contains($0.id) }
        func woerter(_ l: Lebensmittel) -> [Substring] { LebensmittelBasis.schluessel(l).split(separator: " ") }
        let genau = basis.filter { woerter($0).first.map { $0 == wort } ?? false }
        let kopf = Array(basis.filter { l in
            let w = woerter(l)
            return w.contains { $0.hasSuffix(wort) } && !w.contains { $0.hasPrefix(wort) }
        }.prefix(8))
        let belegt = Set((genau + kopf).map(\.id))
        return Array((treffer.filter { eigene.contains($0.id) } + genau + kopf + basis.filter { !belegt.contains($0.id) }).prefix(50))
    }

    /// Ein einzelnes Wort ab 7 Zeichen an jeder Stelle in zwei Wörter geteilt ("haferflocken" -> "hafer flocken"); sonst leer.
    nonisolated static func teilungen(_ text: String) -> [String] {
        let zeichen = Array(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard zeichen.count >= 7, !zeichen.contains(" ") else { return [] }
        return (3...(zeichen.count - 3)).map { String(zeichen[..<$0]) + " " + String(zeichen[$0...]) }
    }

    /// Nach `eingabe`: die Server-Treffer kommen hinten dran, nichts springt. Wartet `pause` (neue Eingabe oder Abbruch der Task verwirft die Anfrage),
    /// fragt nur ab 2 Zeichen; eine Antwort zu einer überholten Eingabe wird verworfen.
    func serverSuchen(pause: Duration = LebensmittelSuche.serverPause) async {
        let anfrage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let server, anfrage.count >= 2 else { return }
        let nummer = stand.nummer
        try? await Task.sleep(for: pause)
        guard !Task.isCancelled, nummer == stand.nummer else { return }
        online = .laedt
        do {
            let antwort = try await server.suche(anfrage)
            guard !Task.isCancelled, nummer == stand.nummer else { return }
            stand = SuchZusammenfuehrung.server(stand, antwort: antwort, nummer: nummer)
            online = .fertig(treffer: antwort.count)
        } catch is CancellationError {
            return
        } catch let fehler as EssenServerFehler {
            guard nummer == stand.nummer else { return }
            online = fehler == .netz ? .offline : .fehler
        } catch {
            guard nummer == stand.nummer else { return }
            online = .fehler
        }
    }

    /// Barcode aus Kamera oder Eingabe: Speicher, Server (bei 404 oder Fehler weiter), dann Open Food Facts.
    func barcode(_ roh: String) async -> BarcodeErgebnis {
        let code = BarcodeLogik.normal(roh)
        if let gemerkt = letzterTreffer, gemerkt.code == code { return .gefunden(gemerkt.lebensmittel) }
        let speicher = speicher
        let off = off
        let server = server
        let quellen = BarcodeQuellen(lokal: { code in await speicher(code) }, offLive: { code in
            if let treffer = try? await server?.produkt(code) { return treffer }
            return try await off.produkt(code)
        })
        let ergebnis = await BarcodeKette.suchen(code, quellen)
        if case .gefunden(let l) = ergebnis { letzterTreffer = (code, l) }
        return ergebnis
    }

    /// Einmal pro Barcode: das Produkt direkt bei Open Food Facts, für Zutaten und Siegel der Ampel (der Speicher kennt sie oft nicht).
    /// Fehler, Limit und unbekannte Codes bleiben leise: nil. Schreibt nichts in den Speicher, kein Wiederholen.
    func zutatenNachladen(_ roh: String) async -> Lebensmittel? {
        let code = BarcodeLogik.normal(roh)
        guard !code.isEmpty else { return nil }
        if let bekannt = nachgeladen[code] { return bekannt }
        guard nachladenLaeuft.insert(code).inserted else { return nil }
        defer { nachladenLaeuft.remove(code) }
        let antwort: Lebensmittel? = try? await off.produkt(code)
        nachgeladen[code] = .some(antwort)
        return antwort
    }

    /// Ein Treffer, der nicht aus dem Barcode kam (Auswahl in der Liste), wird ebenfalls gemerkt, wenn er einen Barcode hat.
    func merke(_ l: Lebensmittel) {
        if let code = l.barcode { letzterTreffer = (BarcodeLogik.normal(code), l) }
    }
}
