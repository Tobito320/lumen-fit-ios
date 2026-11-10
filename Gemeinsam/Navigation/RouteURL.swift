import Foundation

/// `lumenfit://`-Links für Widgets, Live Activity, Siri, Spotlight und geteilte Karten:
/// `heute` | `gym?bereich=training|plaene|fortschritt` | `essen?bereich=heute|scan|favoriten` | `schlaf?bereich=letzteNacht|verlauf|werte`
/// | `profil?bereich=uebersicht|einstellungen|aussehen|ziele|verbindungen|datensicherung|quellen|meilensteine|lumi`
/// | `verlauf` | `gewicht` | `uebung?id=...` | `freund?d=<Nutzlast, base64url>`.
/// Fehlender oder unbekannter `bereich` heißt der erste Fall. Für jede Route gilt `route(aus: url(fuer: route)) == route`; ein leerer Text zählt als fehlend.
enum RouteURL {
    nonisolated static let schema = "lumenfit"

    static func url(fuer route: Route) -> URL {
        var komponenten = URLComponents()
        komponenten.scheme = schema
        var eintraege: [URLQueryItem] = []
        switch route {
        case .heute:
            komponenten.host = "heute"
        case .gym(let bereich):
            komponenten.host = "gym"
            if bereich != .training { eintraege.append(eintrag("bereich", bereich.rawValue)) }
        case .essen(let bereich):
            komponenten.host = "essen"
            if bereich != .heute { eintraege.append(eintrag("bereich", bereich.rawValue)) }
        case .schlaf(let bereich):
            komponenten.host = "schlaf"
            if bereich != .letzteNacht { eintraege.append(eintrag("bereich", bereich.rawValue)) }
        case .profil(let bereich):
            komponenten.host = "profil"
            if bereich != .uebersicht { eintraege.append(eintrag("bereich", bereich.rawValue)) }
        case .verlauf:
            komponenten.host = "verlauf"
        case .einsichten:
            komponenten.host = "einsichten"
        case .gewichtEintragen:
            komponenten.host = "gewicht"
        case .uebung(let id):
            komponenten.host = "uebung"
            eintraege.append(eintrag("id", id))
        case .freund(let daten):
            komponenten.host = "freund"
            if let daten, !daten.isEmpty { eintraege.append(eintrag("d", daten)) }
        }
        if !eintraege.isEmpty { komponenten.percentEncodedQueryItems = eintraege }
        return komponenten.url ?? URL(filePath: "/")
    }

    /// Wert mit Prozentkodierung für alles außer A-Z, a-z, 0-9 und `-._~`: so bleiben `&`, `=`, `+` und `#` im Text und ändern den Link nicht.
    private static func eintrag(_ name: String, _ wert: String) -> URLQueryItem {
        URLQueryItem(name: name, value: wert.addingPercentEncoding(withAllowedCharacters: unreserviert) ?? "")
    }

    private static let unreserviert = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// Spotlight-Einträge tragen die `lumenfit://`-URL ihrer Route als `uniqueIdentifier`.
    static func route(ausSpotlightKennung kennung: String) -> Route? {
        URL(string: kennung).flatMap { route(aus: $0) }
    }

    static func route(aus url: URL) -> Route? {
        guard url.scheme?.lowercased() == schema,
              let komponenten = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var abfrage: [String: String] = [:]
        for eintrag in komponenten.queryItems ?? [] { abfrage[eintrag.name] = eintrag.value ?? "" }
        func leerZuNil(_ text: String?) -> String? { (text?.isEmpty ?? true) ? nil : text }
        switch (komponenten.host ?? "").lowercased() {
        case "heute", "":
            return .heute
        case "gym":
            return .gym(abfrage["bereich"].flatMap { GymBereich(rawValue: $0) } ?? .training)
        case "essen":
            return .essen(abfrage["bereich"].flatMap { EssenBereich(rawValue: $0) } ?? .heute)
        case "schlaf":
            return .schlaf(abfrage["bereich"].flatMap { SchlafBereich(rawValue: $0) } ?? .letzteNacht)
        case "profil":
            return .profil(abfrage["bereich"].flatMap { ProfilBereich(rawValue: $0) } ?? .uebersicht)
        case "verlauf":
            return .verlauf
        case "einsichten":
            return .einsichten
        case "gewicht":
            return .gewichtEintragen
        case "uebung":
            guard let id = leerZuNil(abfrage["id"]) else { return nil }
            return .uebung(id: id)
        case "freund":
            return .freund(daten: leerZuNil(abfrage["d"]))
        default:
            return nil
        }
    }
}
