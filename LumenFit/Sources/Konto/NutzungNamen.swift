import Foundation

// Die festen Wörter der Nutzungsmeldung. Jeder Name, den die App sendet, kommt aus einem dieser Typen oder aus `NutzungName`; es gibt keinen Weg für Freitext.
// Die Gegenliste liegt im Server (`server/nutzung-namen.js`); `NutzungVertragTests` prüft, dass beide übereinstimmen. Neuer Name hier = dort eintragen.

/// Die Gruppen der Meldung (Schlüssel im Körper von `POST /nutzung`, Feld `gruppen`).
enum NutzungArt: String, CaseIterable, Sendable {
    case start, dauer, erster, weg, absprung, ziel, begonnen, fertig, abbruch, gesehen, getippt, stand, fehler, route, tempo

    /// So viele verschiedene Namen je Tag und Art nimmt der Server an.
    nonisolated var maxNamen: Int {
        switch self {
        case .route: 160
        case .weg: 120
        case .tempo: 80
        default: 60
        }
    }
}

/// Fehlerarten als feste Namen, nie ein Fehlertext, nie ein Stack.
enum NutzungFehler: String, CaseIterable, Sendable {
    case speichern
    case absturz
    case haenger
    case healthNichtVerfuegbar = "health_nicht_verfuegbar"
    case bandVerbindung = "band_verbindung"
    case bandNichtGefunden = "band_nicht_gefunden"
    case coachAntwort = "coach_antwort"
    case coachVersteht = "coach_versteht"
}

/// Abläufe mit mehreren Stufen: begonnen, beendet oder in einer Stufe abgebrochen (QR-Verbinden, Studio-Suche, Essen eintragen).
enum NutzungAblauf: String, CaseIterable, Sendable {
    case qr, studio, essen

    nonisolated var stufen: [String] {
        switch self {
        case .qr: ["scannen", "pruefen", "frage", "sendet", "wartet", "fehler"]
        case .studio: ["tippen"]
        case .essen: ["offen", "scan", "foto"]
        }
    }
}

/// Einträge (Zeilen, Karten), von denen gezählt wird, ob sie gesehen und ob sie angetippt wurden.
enum NutzungEintrag: String, CaseIterable, Sendable {
    case profilKollegen = "profil_kollegen"
    case profilKonto = "profil_konto"
    case profilAussehen = "profil_aussehen"
    case profilZiele = "profil_ziele"
    case profilHealth = "profil_health"
    case profilMeilensteine = "profil_meilensteine"
    case profilGeraete = "profil_geraete"
    case profilFreunde = "profil_freunde"
    case profilDaten = "profil_daten"
    case profilUeber = "profil_ueber"
}

/// Welche Aufrufe des Lumen-Servers gemessen werden, unter festem Namen. Alles andere (auch `/nutzung` selbst) wird nicht gemessen.
enum NutzungRoute {
    nonisolated static func name(methode: String?, pfad: String?) -> String? {
        guard let pfad else { return nil }
        switch pfad {
        case "/konto": return "konto"
        case "/config": return "config"
        case "/lovea/freigabe": return "freigabe"
        case "/lovea/agent/ops": return "lovea_ops"
        case "/lovea/import-erledigt": return "import_erledigt"
        case "/lovea/import-beleg": return "import_beleg"
        case "/partner": return methode == "PUT" ? "partner_put" : "partner_get"
        case "/ki/foto": return "ki_foto"
        case "/ki/coach": return "ki_coach"
        default: return pfad.hasPrefix("/verbindungen") ? "verbindungen" : nil
        }
    }

    /// Status als fester Name; nil (kein Netz) wird "netz".
    nonisolated static func status(_ code: Int?) -> String {
        guard let code else { return "netz" }
        if [400, 401, 403, 404, 409, 413, 429, 500, 502, 503].contains(code) { return "s\(code)" }
        return code >= 500 ? "s5xx" : "s4xx"
    }
}

/// Dauern und Tageszeit als grobe Bereiche, nie als genauer Wert.
enum NutzungMass {
    nonisolated static func block(_ zeit: Date) -> String {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        switch kalender.component(.hour, from: zeit) {
        case 5..<11: return "morgen"
        case 11..<14: return "mittag"
        case 14..<18: return "nachmittag"
        case 18..<23: return "abend"
        default: return "nacht"
        }
    }

    nonisolated static func dauer(_ sekunden: TimeInterval) -> String {
        switch sekunden {
        case ..<60: "lt1m"
        case ..<300: "m1_5"
        case ..<900: "m5_15"
        case ..<1800: "m15_30"
        default: "gt30m"
        }
    }

    nonisolated static func ziel(_ sekunden: TimeInterval) -> String {
        switch sekunden {
        case ..<10: "lt10s"
        case ..<30: "lt30s"
        case ..<60: "lt1m"
        case ..<180: "lt3m"
        default: "gt3m"
        }
    }

    nonisolated static func tempo(_ sekunden: TimeInterval) -> String {
        switch sekunden {
        case ..<1: "lt1s"
        case ..<3: "lt3s"
        default: "gt3s"
        }
    }

    nonisolated static func sekunden(_ dauer: Duration) -> TimeInterval {
        let teile = dauer.components
        return TimeInterval(teile.seconds) + TimeInterval(teile.attoseconds) / 1e18
    }
}

/// App-, iOS- und Gerätetyp für die Fehlerzahlen: nur grobe Form ("26.1", "iPhone17,1"), kein Name des Geräts. Auf dem Simulator fällt der Gerätetyp weg.
enum NutzungGeraet {
    nonisolated static var ios: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }

    nonisolated static var typ: String? {
        var info = utsname()
        uname(&info)
        let name = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
        return name.hasPrefix("iPhone") || name.hasPrefix("iPad") ? name : nil
    }
}

/// Der Beginn des Prozesses (Zeitpunkt des ersten Zugriffs, `LumenFitApp.init`), für die Startzeit bis zur ersten Ansicht.
enum NutzungStart {
    nonisolated static let beginn = ContinuousClock.now
}
