import Foundation

enum OffFehler: Error, Equatable, Sendable {
    /// Rate-Limit erreicht: erst in `sekunden` wieder fragen.
    case limit(sekunden: Int)
    /// Serverfehler (HTTP 500 und mehr, auch nach einem Wiederholversuch) oder anderer unerwarteter Status.
    case server(Int)
    /// Die Adresse ließ sich nicht bauen.
    case antwort
}

/// Gleitendes Minutenfenster: höchstens `limit` Abfragen in den letzten 60 Sekunden.
struct EssenRateFenster: Sendable {
    let limit: Int
    private var zeiten: [Date] = []

    init(limit: Int) { self.limit = limit }

    /// nil = erlaubt (und gezählt), sonst die Sekunden bis wieder Platz ist.
    mutating func versuche(jetzt: Date) -> Int? {
        zeiten.removeAll { jetzt.timeIntervalSince($0) >= 60 }
        if zeiten.count >= limit, let aelteste = zeiten.min() {
            return max(1, Int((60 - jetzt.timeIntervalSince(aelteste)).rounded(.up)))
        }
        zeiten.append(jetzt)
        return nil
    }
}

/// Open Food Facts (ODbL) über den `HTTPLader`: Produkt per Barcode (höchstens 15 je Minute) und Textsuche (höchstens 10 je Minute).
/// Fragt nur auf Aufruf, lädt nie vor. Bei HTTP 500 gibt es einen Wiederholversuch, der als Abfrage zählt. Ohne Schlüssel, ohne Konto.
actor OpenFoodFactsQuelle {
    static let produktLimit = 15
    static let sucheLimit = 10

    private let lader: any HTTPLader
    private let uhr: Uhr
    private let kennung: String
    private var produktFenster = EssenRateFenster(limit: OpenFoodFactsQuelle.produktLimit)
    private var sucheFenster = EssenRateFenster(limit: OpenFoodFactsQuelle.sucheLimit)

    init(lader: any HTTPLader, uhr: @escaping Uhr = { Date() }, version: String = OpenFoodFactsQuelle.appVersion) {
        self.lader = lader
        self.uhr = uhr
        self.kennung = "LumenFit/\(version) (iOS)" // Annahme 26: weder Mail noch Repo-Adresse (das Repo ist privat)
    }

    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }

    /// nil = unbekannter Barcode (HTTP 404 oder `status: 0`).
    func produkt(_ roh: String) async throws -> Lebensmittel? {
        let code = BarcodeLogik.normal(roh)
        guard !code.isEmpty, var teile = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json") else { throw OffFehler.antwort }
        teile.queryItems = [URLQueryItem(name: "fields", value: ErnaehrungLogik.offFelder)]
        guard let url = teile.url else { throw OffFehler.antwort }
        let (daten, status) = try await hole(url, suche: false)
        if status == 404 { return nil }
        guard status == 200 else { throw OffFehler.server(status) }
        return ErnaehrungLogik.offProdukt(daten).map(Self.alsOff)
    }

    func suche(_ text: String) async throws -> [Lebensmittel] {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, var teile = URLComponents(string: "https://search.openfoodfacts.org/search") else { return [] }
        teile.queryItems = [URLQueryItem(name: "q", value: q), URLQueryItem(name: "page_size", value: "20"),
                            URLQueryItem(name: "langs", value: "de"),
                            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments")]
        guard let url = teile.url else { throw OffFehler.antwort }
        let (daten, status) = try await hole(url, suche: true)
        guard status == 200 else { throw OffFehler.server(status) }
        return ErnaehrungLogik.offSuche(daten).map(Self.alsOff)
    }

    private static func alsOff(_ l: Lebensmittel) -> Lebensmittel {
        var neu = l
        neu.quelle = "off"
        return neu
    }

    private func hole(_ url: URL, suche: Bool) async throws -> (Data, Int) {
        for versuch in 0..<2 {
            try erlaube(suche: suche)
            var anfrage = URLRequest(url: url)
            anfrage.setValue(kennung, forHTTPHeaderField: "User-Agent")
            anfrage.timeoutInterval = 15
            let (daten, antwort) = try await lader.lade(anfrage)
            if antwort.statusCode == 500, versuch == 0 { continue }
            if antwort.statusCode == 429 { throw OffFehler.limit(sekunden: 60) }
            return (daten, antwort.statusCode)
        }
        throw OffFehler.server(500)
    }

    private func erlaube(suche: Bool) throws {
        let jetzt = uhr()
        let warten = suche ? sucheFenster.versuche(jetzt: jetzt) : produktFenster.versuche(jetzt: jetzt)
        if let warten { throw OffFehler.limit(sekunden: warten) }
    }
}
