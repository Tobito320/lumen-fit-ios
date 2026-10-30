// Quelle: Lovea Health/Ernaehrung/EssenAuftrag.swift
import Foundation

/// Eine Foto-Analyse, die im Hintergrund läuft oder fertig auf die Entscheidung wartet. Hier steht nur der Zustand;
/// das Foto liegt als eigene Datei daneben (`EssenKiAuftragStore`). Jedes Feld außer den ersten vier darf in einer alten Datei fehlen.
struct EssenKiAuftrag: Codable, Equatable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case laeuft, fertig, fehler
        /// Die App wurde beendet, während es lief. Das Foto ist noch da, "Nochmal" geht.
        case unterbrochen
    }

    let id: UUID
    let erstellt: Date
    let mahlzeit: Mahlzeit
    /// Tag, an dem das Essen eingetragen wird (`yyyy-MM-dd`).
    let datum: String
    var hinweis = ""
    var status = Status.laeuft
    /// Wann der aktuelle Lauf gestartet ist (für die Schritte in der Ladeanzeige).
    var gestartet = Date()
    var analyse: EssenKiAnalyse?
    var fehler: EssenKiAnzeige?
    /// Neu schätzen ist schiefgegangen oder unterbrochen worden: die alte Schätzung gilt weiter.
    var neuFehler: String?
    /// Netz war weg: beim nächsten Öffnen der App einmal von selbst wiederholen.
    var autoNochmal = false
    /// Die automatische Wiederholung ist schon verbraucht (jedes Foto zählt gegen das Tageslimit).
    var wiederholt = false

    init(id: UUID, erstellt: Date, mahlzeit: Mahlzeit, datum: String, gestartet: Date) {
        self.id = id
        self.erstellt = erstellt
        self.mahlzeit = mahlzeit
        self.datum = datum
        self.gestartet = gestartet
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        erstellt = try c.decode(Date.self, forKey: .erstellt)
        mahlzeit = try c.decode(Mahlzeit.self, forKey: .mahlzeit)
        datum = try c.decode(String.self, forKey: .datum)
        hinweis = try c.decodeIfPresent(String.self, forKey: .hinweis) ?? ""
        status = try c.decodeIfPresent(Status.self, forKey: .status) ?? .laeuft
        gestartet = try c.decodeIfPresent(Date.self, forKey: .gestartet) ?? erstellt
        analyse = try c.decodeIfPresent(EssenKiAnalyse.self, forKey: .analyse)
        fehler = try c.decodeIfPresent(EssenKiAnzeige.self, forKey: .fehler)
        neuFehler = try c.decodeIfPresent(String.self, forKey: .neuFehler)
        autoNochmal = try c.decodeIfPresent(Bool.self, forKey: .autoNochmal) ?? false
        wiederholt = try c.decodeIfPresent(Bool.self, forKey: .wiederholt) ?? false
    }
}

/// Reine Logik zu `EssenKiAuftrag`: Statuswechsel, Unterbrechung, Speicherformat. Ohne Datei, Netz und Views,
/// damit die Tests nichts Echtes anfassen.
enum EssenKiAuftragLogik {
    nonisolated static let unterbrochen = EssenKiAnzeige(
        titel: "Unterbrochen", text: "Die Analyse wurde unterbrochen. Das Foto ist noch da.",
        symbol: "arrow.clockwise", nochmal: true, neuesFoto: false)

    static func neu(mahlzeit: Mahlzeit, datum: String, id: UUID = UUID(), jetzt: Date = Date()) -> EssenKiAuftrag {
        EssenKiAuftrag(id: id, erstellt: jetzt, mahlzeit: mahlzeit, datum: datum, gestartet: jetzt)
    }

    static func ergebnis(_ a: EssenKiAuftrag, _ analyse: EssenKiAnalyse) -> EssenKiAuftrag {
        var n = a
        n.status = .fertig
        n.analyse = analyse
        n.fehler = nil
        n.neuFehler = nil
        n.autoNochmal = false
        return n
    }

    /// Mit Schätzung (Neu schätzen schiefgegangen) bleibt sie stehen; ohne wird es ein Fehler. Nur ein
    /// Netzfehler ohne frühere Wiederholung merkt sich die automatische Wiederholung.
    static func fehlgeschlagen(_ a: EssenKiAuftrag, anzeige: EssenKiAnzeige, netz: Bool) -> EssenKiAuftrag {
        var n = a
        n.autoNochmal = false
        if a.analyse != nil {
            n.status = .fertig
            n.neuFehler = anzeige.text
        } else {
            n.status = .fehler
            n.fehler = anzeige
            n.autoNochmal = netz && !a.wiederholt
        }
        return n
    }

    static func fehlgeschlagen(_ a: EssenKiAuftrag, _ fehler: EssenKiFehler) -> EssenKiAuftrag {
        fehlgeschlagen(a, anzeige: EssenKiFotoLogik.anzeige(fehler), netz: fehler == .netz)
    }

    /// Neuer Lauf mit demselben Foto. `hinweis` nur bei einer Rückfrage; `automatisch` verbraucht die Wiederholung.
    static func neuStart(_ a: EssenKiAuftrag, hinweis: String? = nil, automatisch: Bool = false, jetzt: Date = Date()) -> EssenKiAuftrag {
        var n = a
        n.status = .laeuft
        n.gestartet = jetzt
        n.fehler = nil
        n.neuFehler = nil
        n.autoNochmal = false
        if let hinweis { n.hinweis = hinweis }
        if automatisch { n.wiederholt = true }
        return n
    }

    /// Abbrechen, solange es läuft: mit früherer Schätzung zurück zu ihr, sonst ist nichts mehr da (`nil`).
    static func abgebrochen(_ a: EssenKiAuftrag) -> EssenKiAuftrag? {
        guard a.analyse != nil else { return nil }
        var n = a
        n.status = .fertig
        n.neuFehler = nil
        return n
    }

    /// Nach einem Neustart der App läuft nichts mehr. Was lief, ist "unterbrochen" (Foto bleibt), außer
    /// es war ein Neu schätzen: dann gilt die alte Schätzung weiter. Nichts geht still verloren.
    static func nachNeustart(_ liste: [EssenKiAuftrag]) -> [EssenKiAuftrag] {
        liste.map { a in
            guard a.status == .laeuft else { return a }
            var n = a
            if a.analyse != nil {
                n.status = .fertig
                n.neuFehler = "Neu schätzen wurde unterbrochen."
            } else {
                n.status = .unterbrochen
            }
            return n
        }
    }

    /// Was bei Fehler und Unterbrechung gezeigt wird.
    static func anzeige(_ a: EssenKiAuftrag) -> EssenKiAnzeige? {
        switch a.status {
        case .fehler: return a.fehler ?? EssenKiFotoLogik.fotoUnlesbar
        case .unterbrochen: return Self.unterbrochen
        case .laeuft, .fertig: return nil
        }
    }

    static func anzahlFertig(_ liste: [EssenKiAuftrag]) -> Int { liste.filter { $0.status == .fertig }.count }

    /// Ladeanzeige: 0 Bild wird gesendet, 1 Essen wird erkannt, 2 Kalorien werden geschätzt. Nach Zeit, nicht
    /// nach echtem Fortschritt (der Server meldet keinen).
    nonisolated static let schrittGrenzen: [TimeInterval] = [2, 6]

    static func schritt(seit: Date, jetzt: Date = Date()) -> Int {
        let s = jetzt.timeIntervalSince(seit)
        return schrittGrenzen.filter { s >= $0 }.count
    }

    static func kodieren(_ liste: [EssenKiAuftrag]) -> Data? { try? JSONEncoder().encode(liste) }

    /// `nil` = Datei nicht lesbar. Dann darf niemand die Datei mit einer leeren Liste überschreiben.
    static func lesen(_ daten: Data) -> [EssenKiAuftrag]? { try? JSONDecoder().decode([EssenKiAuftrag].self, from: daten) }
}
