import Foundation

/// Einziger Schalter für Lovea-Verbindung und Import (Ahmeds Vorgabe 29.10.: nur für die zwei freigegebenen Konten, niemand anders).
/// Vorerst ist nur Demo erlaubt; der Server mit Freigabe je Konto ersetzt diese eine Funktion.
enum LoveaFreigabe {
    static func erlaubt(konto: ProfilID?, demo: Bool) -> Bool { demo }

    /// Start mit `-lumenFitDemo`.
    static var demoAktiv: Bool { ProcessInfo.processInfo.arguments.contains("-lumenFitDemo") }
}

struct ProfilLoveaPerson: Equatable, Identifiable, Sendable {
    /// Wert des Headers `X-Lovea-Person` (steht nur in der privaten Datei, nie im Code).
    var kennung: String
    var anzeige: String
    var id: String { kennung }
}

/// Server, Schlüssel und Personen aus dem Block `lovea` der `PrivateDaten.json` (gitignored, Secret `PRIVATE_DATEN_JSON`):
/// `{"lovea": {"server": "https://…", "schluessel": "…", "personen": [{"kennung": "…", "anzeige": "…"}]}}`.
// shortcut: der Schlüssel liegt im Bundle jeder Installation, nur `LoveaFreigabe` sperrt; der Server soll ihn später je Konto ausgeben.
struct ProfilLoveaZugang: Sendable, CustomStringConvertible {
    var server: URL
    var schluessel: String
    var personen: [ProfilLoveaPerson]

    /// Nie Server oder Schlüssel in Logs oder Fehlertexte.
    var description: String { "ProfilLoveaZugang(\(personen.count) Personen)" }

    static func lade(bundle: Bundle = .main) -> ProfilLoveaZugang? {
        guard let url = bundle.url(forResource: "PrivateDaten", withExtension: "json"), let daten = try? Data(contentsOf: url) else { return nil }
        return lies(daten)
    }

    static func lies(_ daten: Data) -> ProfilLoveaZugang? {
        struct Datei: Decodable {
            struct Block: Decodable {
                struct P: Decodable { var kennung: String; var anzeige: String }
                var server: String
                var schluessel: String
                var personen: [P]
            }
            var lovea: Block?
        }
        guard let block = (try? JSONDecoder().decode(Datei.self, from: daten))?.lovea, let server = URL(string: block.server),
              !block.schluessel.isEmpty, !block.personen.isEmpty else { return nil }
        return ProfilLoveaZugang(server: server, schluessel: block.schluessel,
                                 personen: block.personen.map { ProfilLoveaPerson(kennung: $0.kennung, anzeige: $0.anzeige) })
    }
}

/// Fehler des Imports. Die Texte sind fest: nie die Netz-Fehlermeldung durchreichen (sie enthält die Adresse).
enum ProfilLoveaFehler: Error, Equatable, Sendable {
    case nichtErlaubt
    case profilNichtLeer
    case netz
    case abgelehnt
    case server(Int)
    case antwortKaputt
    case speichern

    var titel: String {
        switch self {
        case .nichtErlaubt: "Nicht freigegeben"
        case .profilNichtLeer: "Das Profil hat schon Einträge"
        case .netz: "Keine Verbindung zu Lovea"
        case .abgelehnt: "Lovea hat den Zugang abgelehnt"
        case .server: "Lovea antwortet nicht richtig"
        case .antwortKaputt: "Die Antwort von Lovea ist unlesbar"
        case .speichern: "Konnte nicht speichern"
        }
    }

    var hilfe: String {
        switch self {
        case .nichtErlaubt: "Für dieses Profil ist der Import aus Lovea nicht freigegeben."
        case .profilNichtLeer: "Bestätige den Import, dann wird Neues dazugelegt und Gleiches übersprungen."
        case .netz: "Prüfe dein Netz und versuch es nochmal. Es wurde noch nichts übernommen."
        case .abgelehnt: "Der Schlüssel passt nicht oder die Person ist unbekannt. Es wurde noch nichts übernommen."
        case .server: "Lovea hat einen Fehler gemeldet. Versuch es später nochmal. Es wurde noch nichts übernommen."
        case .antwortKaputt: "Die Daten kamen in einer Form an, die Lumen Fit nicht versteht. Es wurde noch nichts übernommen."
        case .speichern: "Ist auf dem iPhone der Speicher voll? Gib Platz frei und versuch es nochmal. Schon Übernommenes bleibt, nichts wird doppelt."
        }
    }

    /// Netz, Server und Speicher gehen nach dem Beheben von vorn; alles andere ändert ein erneuter Versuch nicht.
    var wiederholbar: Bool {
        switch self {
        case .netz, .server, .speichern: true
        case .nichtErlaubt, .profilNichtLeer, .abgelehnt, .antwortKaputt: false
        }
    }
}

/// Eine Op, wie Lovea sie liefert (`GET /agent/ops`, mit `seq`). `zeit` bleibt Text bis zum Planen.
struct ProfilLoveaOp: Sendable {
    var seq: Int
    var id: String
    var art: String
    var zeit: String
    var d: Data
}

struct ProfilLoveaAbzug: Sendable {
    /// Aufsteigend nach `seq`, also in Originalreihenfolge.
    var ops: [ProfilLoveaOp] = []
    /// Einträge ohne Kennung, Art, `seq` oder Zeit.
    var unlesbar = 0
}

struct ProfilLoveaAbdeckung: Equatable, Sendable {
    var uebernommen: [String: Int] = [:]
    var roh: [String: Int] = [:]
    /// Grund → Art → Anzahl.
    var ausgeschlossen: [String: [String: Int]] = [:]
    var unbekannt: [String: Int] = [:]
    var unlesbar = 0

    var ausgeschlossenGesamt: Int { ausgeschlossen.values.reduce(0) { $0 + $1.values.reduce(0, +) } }
}

struct ProfilLoveaPlan: Sendable {
    /// Zu schreibende Ops (übernommen und roh behalten) in Originalreihenfolge.
    var ops: [Op]
    var abdeckung: ProfilLoveaAbdeckung
}

struct ProfilLoveaErgebnis: Equatable, Sendable {
    var neu: Int
    var schonDa: Int
    /// Einträge, die eine ältere Fassung einer "letzte gewinnt"-Art waren (nur bei nicht leerem Profil).
    var uebersprungen: Int
    var trainings: Int
    var essenstage: Int
    var abdeckung: ProfilLoveaAbdeckung
}

enum ProfilLoveaImport {
    static let seitenGroesse = 200

    // MARK: - Holen (nur lesen)

    static func anfrage(zugang: ProfilLoveaZugang, kennung: String, seit: Int) -> URLRequest? {
        guard var teile = URLComponents(url: zugang.server, resolvingAgainstBaseURL: false) else { return nil }
        let pfad = teile.path.hasSuffix("/") ? String(teile.path.dropLast()) : teile.path
        teile.path = pfad + "/agent/ops"
        teile.queryItems = [
            URLQueryItem(name: "von", value: kennung), URLQueryItem(name: "seit", value: String(seit)),
            URLQueryItem(name: "limit", value: String(seitenGroesse)), URLQueryItem(name: "aufsteigend", value: "1"),
            // Ohne `voll=1` kürzt der Server große Rümpfe (Pläne, Essen) zu einer Vorschau.
            URLQueryItem(name: "voll", value: "1"),
        ]
        guard let url = teile.url else { return nil }
        var anfrage = URLRequest(url: url)
        anfrage.httpMethod = "GET"
        anfrage.timeoutInterval = 30
        anfrage.setValue(zugang.schluessel, forHTTPHeaderField: "X-Lovea-Key")
        anfrage.setValue(kennung, forHTTPHeaderField: "X-Lovea-Person")
        return anfrage
    }

    private struct SeiteRoh: Decodable {
        struct Eintrag: Decodable {
            var seq: Int?
            var id: String?
            var art: String?
            var zeit: String?
            var d: JSONValue?
        }
        var ops: [Eintrag]
        var mehr: Bool?
    }

    /// Lädt alle Ops einer Person, Seite für Seite. Erst wenn alles da ist, wird geschrieben (Aufrufer): bei einem Netzfehler bleibt das Profil unberührt.
    static func hole(zugang: ProfilLoveaZugang, kennung: String, lader: any HTTPLader,
                     fortschritt: @MainActor (Int) -> Void = { _ in }) async throws -> ProfilLoveaAbzug {
        var abzug = ProfilLoveaAbzug()
        var seit = 0
        let enc = JSONEncoder()
        while true {
            guard let anfrage = anfrage(zugang: zugang, kennung: kennung, seit: seit) else { throw ProfilLoveaFehler.antwortKaputt }
            let antwort: (Data, HTTPURLResponse)
            do { antwort = try await lader.lade(anfrage) } catch { throw ProfilLoveaFehler.netz }
            switch antwort.1.statusCode {
            case 200: break
            case 401, 403: throw ProfilLoveaFehler.abgelehnt
            default: throw ProfilLoveaFehler.server(antwort.1.statusCode)
            }
            guard let seite = try? JSONDecoder().decode(SeiteRoh.self, from: antwort.0) else { throw ProfilLoveaFehler.antwortKaputt }
            var hoechste = seit
            for e in seite.ops {
                if let s = e.seq { hoechste = max(hoechste, s) }
                guard let s = e.seq, let id = e.id, !id.isEmpty, let art = e.art, let zeit = e.zeit else { abzug.unlesbar += 1; continue }
                abzug.ops.append(ProfilLoveaOp(seq: s, id: id, art: art, zeit: zeit, d: (try? enc.encode(e.d ?? .object([:]))) ?? Data("{}".utf8)))
            }
            await fortschritt(abzug.ops.count)
            guard seite.mehr == true else { break }
            guard hoechste > seit else { throw ProfilLoveaFehler.antwortKaputt }   // kein Fortschritt: nie endlos fragen
            seit = hoechste
        }
        abzug.ops.sort { $0.seq < $1.seq }
        return abzug
    }

    // MARK: - Planen (rein)

    /// Teilt den Abzug nach der Tabelle in zu schreibende Ops und Abdeckung. `von` wird das Zielprofil.
    static func plane(_ abzug: ProfilLoveaAbzug, fuer profil: ProfilID) -> ProfilLoveaPlan {
        let mitBruch = ISO8601DateFormatter()
        mitBruch.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let ohneBruch = ISO8601DateFormatter()
        var abdeckung = ProfilLoveaAbdeckung()
        abdeckung.unlesbar = abzug.unlesbar
        var ops: [Op] = []
        for roh in abzug.ops {
            switch ProfilLoveaArten.behandlung(art: roh.art, d: roh.d) {
            case .ausschliessen(let grund):
                abdeckung.ausgeschlossen[grund, default: [:]][roh.art, default: 0] += 1
                continue
            case .unbekannt:
                abdeckung.unbekannt[roh.art, default: 0] += 1
                continue
            case .uebernehmen: abdeckung.uebernommen[roh.art, default: 0] += 1
            case .rohBehalten: abdeckung.roh[roh.art, default: 0] += 1
            }
            guard let zeit = mitBruch.date(from: roh.zeit) ?? ohneBruch.date(from: roh.zeit) else {
                abdeckung.unlesbar += 1
                continue
            }
            ops.append(Op(id: roh.id, art: roh.art, von: profil, zeit: zeit, d: roh.d))
        }
        return ProfilLoveaPlan(ops: ops, abdeckung: abdeckung)
    }

    // MARK: - Einspielen

    /// Schreibt in Originalreihenfolge. Doppelte Kennungen (auch ein zweiter Import) werden übersprungen. In einem nicht leeren Profil gewinnt bei
    /// "letzte gewinnt"-Arten das Neuere (Annahme 30), wie beim Einspielen einer Sicherung.
    @MainActor
    static func spieleEin(_ plan: ProfilLoveaPlan, in daten: DatenSatz, fortschritt: (Int, Int) -> Void = { _, _ in }) async throws -> ProfilLoveaErgebnis {
        let vorher = ProfilSicherungLogik.alleOps(daten)
        let leer = vorher.isEmpty
        var bekannt = Set(vorher.map(\.id))
        var neuste: [String: Date] = [:]
        for op in vorher where ProfilSicherungLogik.letzteGewinnt.contains(op.art) { neuste[op.art] = max(neuste[op.art] ?? .distantPast, op.zeit) }

        var ergebnis = ProfilLoveaErgebnis(neu: 0, schonDa: 0, uebersprungen: 0, trainings: 0, essenstage: 0, abdeckung: plan.abdeckung)
        for (i, op) in plan.ops.enumerated() {
            guard bekannt.insert(op.id).inserted else { ergebnis.schonDa += 1; continue }
            if !leer, ProfilSicherungLogik.letzteGewinnt.contains(op.art), let juengste = neuste[op.art], op.zeit < juengste {
                ergebnis.uebersprungen += 1
                continue
            }
            daten.raum.einreihen(op)
            ergebnis.neu += 1
            if i % 200 == 199 { fortschritt(i + 1, plan.ops.count); await Task.yield() }
        }
        fortschritt(plan.ops.count, plan.ops.count)
        // `einreihen` meldet einen vollen Speicher nur als Ereignis: hier zählen wir nach, was wirklich in der Datei steht.
        guard ProfilSicherungLogik.alleOps(daten).count == vorher.count + ergebnis.neu else { throw ProfilLoveaFehler.speichern }
        ergebnis.trainings = daten.training.sessions.count
        ergebnis.essenstage = daten.essen.tage.count
        return ergebnis
    }

    /// Ganzer Ablauf: Freigabe, Leer-Prüfung, holen, planen, einspielen. Das Profil bleibt bei jedem Fehler vor dem Einspielen unberührt.
    @MainActor
    static func fuehreAus(zugang: ProfilLoveaZugang, person: ProfilLoveaPerson, in daten: DatenSatz, lader: any HTTPLader, demo: Bool,
                          bestaetigt: Bool, fortschritt: @MainActor (String) -> Void = { _ in }) async throws -> ProfilLoveaErgebnis {
        guard LoveaFreigabe.erlaubt(konto: daten.profil, demo: demo) else { throw ProfilLoveaFehler.nichtErlaubt }
        if ProfilSicherungLogik.hatDaten(daten), !bestaetigt { throw ProfilLoveaFehler.profilNichtLeer }
        let abzug = try await hole(zugang: zugang, kennung: person.kennung, lader: lader) { n in fortschritt("\(n) Einträge geladen") }
        let plan = plane(abzug, fuer: daten.profil)
        return try await spieleEin(plan, in: daten) { fertig, gesamt in fortschritt("\(fertig) von \(gesamt) gespeichert") }
    }
}
