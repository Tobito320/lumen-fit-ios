import Foundation

// Coach mit echtem Modell am Lumen-Server (`POST /ki/coach`, Muster wie die Foto-KI): der OpenAI-Schlüssel liegt nur am Server, die App kennt ihn nie.
// Aus, bis der Server den Schalter `kiCoachErlaubt` für das Konto setzt (ohne Build änderbar) und dort das Secret `OPENAI_API_KEY` liegt.
// Gesendet wird eine Zusammenfassung (Tageswerte, Essen, Gewicht, Schritte und Schlaf der letzten 14 Tage, Ziele, Merkzettel, das bisherige Gespräch),
// nie Rohdaten oder Bilder. Fehler und Fristen gibt der Motor weiter; die Auswahl (`CoachWahlMotor`) erfindet daraus keine Antwort.

struct CoachServerMotor: CoachMotor {
    let zugang: any EssenKiZugang
    let lader: any HTTPLader
    let freigabe: EssenKiFreigabe
    let eingabe: @Sendable @MainActor () -> CoachEingabe?
    /// Letzter sicherer Stand der Freigabe: ein Funkloch beim Start schaltet das echte Modell nicht ab (sonst käme für Minuten der Rückfall).
    var merkSchluessel = CoachServerMotor.standardSchluessel
    static let standardSchluessel = "lumenfit.coach.serverErlaubt"

    var name: String { "Server" }

    func verfuegbar() async -> Bool {
        await freigabe.pruefen()
        let geprueft = await freigabe.geprueft
        if geprueft {
            let sicher = await freigabe.erlaubt
            UserDefaults.standard.set(sicher, forKey: merkSchluessel)
        }
        return UserDefaults.standard.bool(forKey: merkSchluessel)
    }

    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
        guard let verbindung = zugang.verbindung() else { throw CoachMotorFehler.nichtBereit }
        let roh = await eingabe()
        var request = URLRequest(url: verbindung.server.appendingPathComponent("ki/coach"))
        request.httpMethod = "POST"
        request.timeoutInterval = 14
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, wert) in verbindung.kopfzeilen { request.setValue(wert, forHTTPHeaderField: name) }
        request.httpBody = try Self.koerper(anfrage, eingabe: roh)
        let ergebnis: (Data, HTTPURLResponse)
        do {
            ergebnis = try await lader.lade(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CoachMotorFehler.nichtBereit
        }
        guard ergebnis.1.statusCode == 200 else { throw CoachMotorFehler.nichtBereit }
        let huelle = try JSONDecoder().decode(ServerAntwortHuelle.self, from: ergebnis.0)
        return try CoachModellUebersetzer.antwort(text: huelle.text, chips: (huelle.knoepfe ?? []).map { CoachRohChip(text: $0.text, art: $0.art, ziel: $0.ziel) })
    }

    // MARK: - Anfrage (rein, testbar)

    struct ServerVerlaufZeile: Encodable, Equatable { let rolle: String; let text: String }
    struct ServerEssenTag: Encodable, Equatable { let tag: String; let kcal: Int; let protein: Int }
    struct ServerGewichtTag: Encodable, Equatable { let tag: String; let kg: Double }
    struct ServerSchrittTag: Encodable, Equatable { let tag: String; let n: Int }
    struct ServerSchlafTag: Encodable, Equatable { let tag: String; let minuten: Int }
    struct ServerZiele: Encodable, Equatable { let schritte: Int; let kalorien: Int; let proteinGramm: Int; let schlafMinuten: Int; let gymTageProWoche: Int }
    struct ServerKontext: Encodable, Equatable {
        var tag: String
        var schlafMinuten: Int?
        var bereitschaft: Int?
        var schritte: Int?
        var letztesTraining: String?
        var stimmung: String
        var ziele: ServerZiele
        var merkzettel: [String]
        var essen: [ServerEssenTag]
        var gewicht: [ServerGewichtTag]
        var schritteTage: [ServerSchrittTag]
        var schlafTage: [ServerSchlafTag]
        var ton: String
        var ziel: String
        var disziplin: Bool
    }
    struct ServerAnfrage: Encodable, Equatable {
        var frage: String
        var verlauf: [ServerVerlaufZeile]
        var kontext: ServerKontext
    }

    private struct ServerKnopf: Decodable { let text: String; let art: String; let ziel: String }
    private struct ServerAntwortHuelle: Decodable { let text: String; let knoepfe: [ServerKnopf]? }

    /// Die Tage, die mitgehen: die letzten 14, neueste zuerst.
    static let tage = 14

    static func anfrageBauen(_ a: CoachAnfrage, eingabe e: CoachEingabe?) -> ServerAnfrage {
        let k = a.kontext
        let ab = Datum.addTage(e?.heute ?? k.tag, -tage)
        func neueste<W>(_ werte: [String: W]) -> [(tag: String, wert: W)] {
            werte.filter { $0.key >= ab }.sorted { $0.key > $1.key }.prefix(tage).map { (tag: $0.key, wert: $0.value) }
        }
        let essen = neueste(e?.essenKcal ?? [:]).map { ServerEssenTag(tag: $0.tag, kcal: Int($0.wert.rounded()), protein: Int((e?.essenProtein[$0.tag] ?? 0).rounded())) }
        let gewicht = neueste(e?.gewicht ?? [:]).map { ServerGewichtTag(tag: $0.tag, kg: Double($0.wert) / 10) }
        let schritte = neueste(e?.schritte ?? [:]).map { ServerSchrittTag(tag: $0.tag, n: $0.wert) }
        let schlaf = neueste(e?.schlaf ?? [:]).map { ServerSchlafTag(tag: $0.tag, minuten: $0.wert) }
        let z = k.ziele
        let verlauf = a.verlauf.suffix(12).map { ServerVerlaufZeile(rolle: $0.rolle == .nutzer ? "du" : "coach", text: String(CoachMarker.zerlegen($0.text).text.prefix(400))) }
        let kontext = ServerKontext(
            tag: k.tag, schlafMinuten: k.schlafMinuten, bereitschaft: k.bereitschaft, schritte: k.schritte, letztesTraining: k.letztesTraining,
            stimmung: k.stimmung.rawValue,
            ziele: ServerZiele(schritte: z.schritte, kalorien: z.kalorien, proteinGramm: z.proteinGramm, schlafMinuten: z.schlafMinuten, gymTageProWoche: z.gymTageProWoche),
            merkzettel: Array(k.merkzettel.suffix(10)), essen: essen, gewicht: gewicht, schritteTage: schritte, schlafTage: schlaf,
            ton: a.ton, ziel: a.ziel, disziplin: a.disziplin)
        return ServerAnfrage(frage: a.frage, verlauf: verlauf, kontext: kontext)
    }

    static func koerper(_ a: CoachAnfrage, eingabe e: CoachEingabe?) throws -> Data {
        try JSONEncoder().encode(anfrageBauen(a, eingabe: e))
    }
}
