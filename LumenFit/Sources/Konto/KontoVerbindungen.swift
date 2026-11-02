import Foundation
import Observation

/// Der Stand der Verbindungen zu anderen Personen, wie der Server ihn zuletzt gemeldet hat (`GET /verbindungen`). Liegt als Datei neben den Profilen
/// (`verbindungen-server.json`). `antwort == nil` heißt: der Server hat dazu noch nie etwas gesagt (dann gilt der alte Partner-Weg).
/// Jede Antwort ersetzt den Stand ganz: nichts wird zusammengeführt, eine entfernte Person ist mit dem nächsten Abgleich samt ihren Daten weg.
@MainActor @Observable
final class VerbindungenSpeicher {
    nonisolated static let dateiName = "verbindungen-server.json"

    private(set) var antwort: VerbindungenAntwort?
    @ObservationIgnored private let datei: URL

    var eintraege: [VerbindungEintrag] { antwort?.verbindungen ?? [] }
    var personen: [VerbindungEintrag] { eintraege.filter(\.aktiv) }
    /// Anfragen anderer an mich (sie haben meinen Code gescannt).
    var anfragen: [VerbindungEintrag] { eintraege.filter { $0.status == .anfrageEingehend } }
    /// Anfragen von mir, die der andere noch nicht angenommen hat.
    var wartend: [VerbindungEintrag] { eintraege.filter { $0.status == .anfrageAusgehend } }
    var lovea: VerbindungEintrag? { personen.first(where: \.lovea) }

    init(datei: URL) {
        self.datei = datei
        antwort = (try? Data(contentsOf: datei)).flatMap { try? LoveaVertrag.decoder().decode(VerbindungenAntwort.self, from: $0) }
    }

    func setze(_ neu: VerbindungenAntwort) {
        antwort = neu
        guard let daten = try? LoveaVertrag.encoder().encode(neu) else { return }
        try? FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: datei, options: .atomic)
    }

    /// Eine entfernte Person sofort lokal löschen (samt ihren Daten), bevor der Server wieder antwortet.
    func entferneLokal(_ id: String) {
        guard var a = antwort else { return }
        a.verbindungen.removeAll { $0.id == id }
        setze(a)
    }

    /// Alles weg (letztes Profil gelöscht).
    func vergiss() {
        antwort = nil
        try? FileManager.default.removeItem(at: datei)
    }
}

/// Was beim Scannen oder Annehmen eines Codes herauskommt.
enum EinladungErgebnis: Equatable, Sendable {
    case person(String)
    case fertig
    case fehler(String)
}

struct EigeneEinladung: Equatable, Sendable {
    var token: String
    var laeuftAb: Date
}

extension KontoDienst {
    // MARK: - Abgleich

    /// Holt die Verbindungen, legt Stand und Partner-Datei ab und lädt hoch, was die Verbindungen erlauben. `false`, wenn der Server den Weg nicht kennt
    /// (älterer Stand): dann läuft der alte Partner-Weg. Ein Netzfehler zählt als erledigt: der letzte Stand bleibt.
    func verbindungenAbgleichen(_ kennung: KontoKennung) async -> Bool {
        guard let r = await sendeMitKonto("/verbindungen", methode: "GET", kennung: kennung) else { return true }
        if r.status == 401 || r.status == 403 { return true }
        guard r.status == 200, let neu = try? LoveaVertrag.decoder().decode(VerbindungenAntwort.self, from: r.daten) else { return false }
        uebernimm(neu)
        if neu.teilen.isEmpty {
            hochladenVerwerfen()
        } else {
            await partnerSenden(kennung, erzwingen: true)
        }
        return true
    }

    private func uebernimm(_ neu: VerbindungenAntwort) {
        let alt = verbindungen.antwort
        verbindungen.setze(neu)
        // Die Lovea-Person liegt im bisherigen Partner-Platz. Ohne aktive Lovea-Verbindung gibt es dort nichts (die Datei von Lovea ist dann kein Ersatz).
        let datei = ordner.appendingPathComponent(Self.partnerDatei)
        if let d = verbindungen.lovea?.daten, let daten = try? LoveaVertrag.encoder().encode(d) {
            try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            try? daten.write(to: datei, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: datei)
        }
        if alt?.teilen != neu.teilen { hochladenFreigeben() }
        if alt != neu { beiVerbindungenGeaendert?() }
    }

    /// Nach einer Änderung: neu holen und weitergeben. Gibt `false` zurück, wenn der Server nicht antwortet.
    @discardableResult
    func verbindungenNeuLaden() async -> Bool {
        guard let k = registrierteKennung() else { return false }
        return await verbindungenAbgleichen(k)
    }

    // MARK: - Einladung

    /// Ein neuer Code für mich: zufälliges Token vom Server, zehn Minuten gültig, einmal nutzbar. Im Code steht nie ein Wert aus Health.
    func einladungErzeugen() async -> EigeneEinladung? {
        guard let k = await kennungBereit(), let r = await sendeMitKonto("/verbindungen/einladung", methode: "POST", kennung: k), r.status == 201 else { return nil }
        struct Antwort: Decodable { var token: String; var laeuftAb: String }
        guard let a = try? JSONDecoder().decode(Antwort.self, from: r.daten), VerbindungenLogik.istToken(a.token),
              let ende = LoveaVertrag.isoDatum(a.laeuftAb) else { return nil }
        return EigeneEinladung(token: a.token, laeuftAb: ende)
    }

    /// Wer steckt hinter dem Code? Verbraucht ihn nicht und gibt nichts frei.
    func einladungAnsehen(_ token: String) async -> EinladungErgebnis {
        await einladungSenden("/verbindungen/ansehen", token) { daten in
            struct Antwort: Decodable { var name: String }
            guard let a = try? JSONDecoder().decode(Antwort.self, from: daten) else { return EinladungErgebnis.fehler(Self.keinNetz) }
            return EinladungErgebnis.person(a.name)
        }
    }

    /// Die Anfrage an den Besitzer des Codes. Daten fließen erst, wenn er sie annimmt.
    func einladungEinloesen(_ token: String) async -> EinladungErgebnis {
        let e = await einladungSenden("/verbindungen/anfrage", token) { _ in EinladungErgebnis.fertig }
        if e == .fertig { await verbindungenNeuLaden() }
        return e
    }

    private static let keinNetz = "Das hat nicht geklappt. Prüfe die Verbindung und versuche es nochmal."

    private func einladungSenden(_ pfad: String, _ token: String, ok: (Data) -> EinladungErgebnis) async -> EinladungErgebnis {
        guard VerbindungenLogik.istToken(token) else { return .fehler("Das ist kein Code von Lumen Fit.") }
        guard let k = await kennungBereit(), let body = try? JSONSerialization.data(withJSONObject: ["token": token]),
              let r = await sendeMitKonto(pfad, methode: "POST", body: body, kennung: k) else { return .fehler(Self.keinNetz) }
        switch r.status {
        case 200, 201: return ok(r.daten)
        case 400: return .fehler("Das ist dein eigener Code.")
        case 404: return .fehler("Der Code ist abgelaufen oder schon benutzt. Bitte um einen neuen.")
        case 409: return .fehler("Ihr seid schon verbunden oder die Anfrage ist schon offen.")
        case 429: return .fehler("Zu viele Versuche. Warte eine Minute.")
        default: return .fehler(Self.keinNetz)
        }
    }

    // MARK: - Anfragen, Einstellungen, Entfernen

    func anfrageAnnehmen(_ id: String) async -> Bool { await aktion("/verbindungen/\(id)/annehmen", "POST") }
    func anfrageAblehnen(_ id: String) async -> Bool { await aktion("/verbindungen/\(id)/ablehnen", "POST") }

    /// Entfernen: auf dem Server (sofort für beide Seiten) und lokal samt den gespeicherten Daten dieser Person.
    func verbindungEntfernen(_ id: String) async -> Bool {
        guard await aktion("/verbindungen/\(id)", "DELETE", neuLaden: false) else { return false }
        let warLovea = verbindungen.lovea?.id == id
        verbindungen.entferneLokal(id)
        if warLovea { try? FileManager.default.removeItem(at: ordner.appendingPathComponent(Self.partnerDatei)) }
        beiVerbindungenGeaendert?()
        await verbindungenNeuLaden()
        return true
    }

    /// Ändert nur meine Seite: `zeigt`, `ausblenden` (Listen von Bereichsnamen), `pause`, `mitteilungen`, `favorit`, `name`.
    func verbindungAendern(_ id: String, _ felder: [String: Any]) async -> Bool {
        guard JSONSerialization.isValidJSONObject(felder), let body = try? JSONSerialization.data(withJSONObject: felder) else { return false }
        return await aktion("/verbindungen/\(id)", "PATCH", body: body)
    }

    private func aktion(_ pfad: String, _ methode: String, body: Data? = nil, neuLaden: Bool = true) async -> Bool {
        guard let k = registrierteKennung(), let r = await sendeMitKonto(pfad, methode: methode, body: body, kennung: k), r.status == 200 else { return false }
        if neuLaden { await verbindungenNeuLaden() }
        return true
    }
}
