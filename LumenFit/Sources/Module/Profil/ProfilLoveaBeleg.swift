import Foundation

/// Je Op-Art die Zahlen eines Import-Laufs. Nur Zahlen und der feste Grund-Text aus `ProfilLoveaArten`, nie Inhalte oder Gesundheitswerte.
struct ProfilLoveaArtBeleg: Codable, Equatable, Sendable {
    var geholt = 0
    var uebernommen = 0
    var roh = 0
    var ausgeschlossen = 0
    var unbekannt = 0
    /// Soll geschrieben werden (übernommen und roh, ohne unlesbare Zeit).
    var geplant = 0
    /// Davon nach dem Schreiben per Kennung im lokalen Speicher wiedergefunden.
    var wiedergefunden = 0
    /// Bewusst nicht geschrieben, weil lokal schon eine neuere "letzte gewinnt"-Op da war.
    var uebersprungen = 0
    var zeitKaputt = 0
    var grund: String?
}

/// Der Beleg nach einem Lauf (`POST /lovea/import-beleg`, `typ: "beleg"`). Der Import gilt nur als erledigt, wenn `vollstaendig` stimmt.
struct ProfilLoveaBeleg: Codable, Equatable, Sendable {
    var typ = "beleg"
    var zeit: String
    var vollstaendig = false
    /// Höchste gelesene `seq` in Lovea.
    var seqMax: Int
    var unlesbar: Int
    var neu: Int
    var schonDa: Int
    var uebersprungen: Int
    var arten: [String: ProfilLoveaArtBeleg]

    /// Der Server nimmt nur Namen in dieser Form (kleiner Anfangsbuchstabe, Buchstaben, Ziffern, `_`, `.`, höchstens 60) und höchstens 150 Arten.
    static func gueltigeArt(_ name: String) -> Bool {
        guard let erster = name.unicodeScalars.first, ("a"..."z").contains(erster), name.count <= 60 else { return false }
        return name.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "_" || $0 == "." }
    }

    static func baue(_ e: ProfilLoveaErgebnis, zeit: Date) -> ProfilLoveaBeleg {
        let a = e.abdeckung
        var arten: [String: ProfilLoveaArtBeleg] = [:]
        // Namen, die der Server nicht annähme, laufen in einem Sammelpunkt zusammen (und machen den Beleg nicht ungültig).
        func name(_ art: String) -> String { gueltigeArt(art) ? art : "andere.art" }
        for (art, n) in a.geholt { arten[name(art), default: .init()].geholt += n }
        for (art, n) in a.uebernommen { arten[name(art), default: .init()].uebernommen += n }
        for (art, n) in a.roh { arten[name(art), default: .init()].roh += n }
        for (art, n) in a.unbekannt { arten[name(art), default: .init()].unbekannt += n }
        for (art, n) in a.zeitKaputt { arten[name(art), default: .init()].zeitKaputt += n }
        for (grund, jeArt) in a.ausgeschlossen {
            for (art, n) in jeArt {
                arten[name(art), default: .init()].ausgeschlossen += n
                arten[name(art), default: .init()].grund = grund
            }
        }
        for (art, n) in e.geplant { arten[name(art), default: .init()].geplant += n }
        for (art, n) in e.wiedergefunden { arten[name(art), default: .init()].wiedergefunden += n }
        for (art, n) in e.uebersprungenArt { arten[name(art), default: .init()].uebersprungen += n }
        var beleg = ProfilLoveaBeleg(zeit: ISO8601DateFormatter().string(from: zeit), seqMax: a.hoechsteSeq, unlesbar: a.unlesbar,
                                     neu: e.neu, schonDa: e.schonDa, uebersprungen: e.uebersprungen, arten: arten)
        beleg.vollstaendig = beleg.pruefeVollstaendig()
        return beleg
    }

    /// Vollständig heißt: nichts Unbekanntes, nichts Unlesbares, keine kaputte Zeit, und jede geplante Op steht nach dem Schreiben wirklich im Speicher.
    func pruefeVollstaendig() -> Bool {
        guard unlesbar == 0, arten.count <= 150 else { return false }
        return arten.values.allSatisfy { a in
            a.unbekannt == 0 && a.zeitKaputt == 0
                && a.geplant == a.uebernommen + a.roh
                && a.wiedergefunden + a.uebersprungen == a.geplant
                && a.geholt == a.uebernommen + a.roh + a.ausgeschlossen + a.unbekannt
        }
    }
}

/// Meldung nach einem Fehlschlag (`typ: "fehler"`): Fehlerart, Zeitpunkt, bis wohin geladen war. Dazu die stillen Gründe, bei denen der Lauf gar nicht erst startet.
struct ProfilLoveaFehlerBeleg: Codable, Equatable, Sendable {
    var typ = "fehler"
    var zeit: String
    var fehler: String
    var geladen: Int
    var bisSeq: Int

    init(zeit: Date, fehler: String, geladen: Int = 0, bisSeq: Int = 0) {
        self.zeit = ISO8601DateFormatter().string(from: zeit)
        self.fehler = fehler
        self.geladen = geladen
        self.bisSeq = bisSeq
    }
}

extension ProfilLoveaFehler {
    /// Fester Name für den Server (Liste dort: `BELEG_FEHLER`).
    var belegName: String {
        switch self {
        case .nichtErlaubt: "nicht_erlaubt"
        case .profilNichtLeer: "profil_nicht_leer"
        case .netz: "netz"
        case .abgelehnt: "abgelehnt"
        case .server: "server"
        case .antwortKaputt: "antwort_kaputt"
        case .speichern: "speichern"
        }
    }
}
