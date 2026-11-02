import Foundation

/// Was die App dem Server über die Nutzung meldet, aber nur nach einem "Ja" (Datenschutz): Zähler, welche Bereiche (Tabs, Seiten) und Funktionen benutzt wurden,
/// dazu Gruppen (`NutzungArt`) wie erster Griff am Tag, Wege, Abbrüche, Fehlerarten. Je Tag, an das Konto gebunden, also nicht anonym.
/// Nie Gesundheitswerte, nie Inhalte, nie Texte, Namen oder Kennungen aus den Daten. Die Namen sind feste Wörter dieser App (`NutzungName`, `NutzungNamen.swift`).
struct NutzungZaehler: Codable, Equatable, Sendable {
    var bereiche: [String: Int] = [:]
    var funktionen: [String: Int] = [:]
    /// Alle weiteren Zähler: Art (`NutzungArt.rawValue`) → Name → Anzahl.
    var mehr: [String: [String: Int]] = [:]
    var leer: Bool { bereiche.isEmpty && funktionen.isEmpty && mehr.values.allSatisfy(\.isEmpty) }

    init() {}

    private enum CodingKeys: String, CodingKey { case bereiche, funktionen, mehr }

    /// Alte Dateien (`nutzung-offen.json` vor den Gruppen) haben `mehr` nicht.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bereiche = (try? c.decodeIfPresent([String: Int].self, forKey: .bereiche)) ?? [:]
        funktionen = (try? c.decodeIfPresent([String: Int].self, forKey: .funktionen)) ?? [:]
        mehr = (try? c.decodeIfPresent([String: [String: Int]].self, forKey: .mehr)) ?? [:]
    }
}

/// Körper von `POST /nutzung`. Alles außer `tag`, `bereiche`, `funktionen` ist optional, damit ältere Server und Apps weiter zusammenpassen.
struct NutzungMeldung: Codable, Equatable, Sendable {
    var tag: String
    var bereiche: [String: Int]
    var funktionen: [String: Int]
    var gruppen: [String: [String: Int]]?
    var ios: String?
    var geraet: String?
}

/// Der Stand der noch nicht gesendeten Zähler. Rein und ohne Datei testbar.
struct NutzungStand: Codable, Equatable, Sendable {
    /// So viele verschiedene Namen je Tag und Art nimmt der Server an.
    nonisolated static let maxNamen = 60
    nonisolated static let maxAnzahl = 9999
    /// Ältere offene Tage nimmt der Server nicht mehr an (3 Tage); so lange wird höchstens aufgehoben.
    nonisolated static let maxTage = 4

    var tage: [String: NutzungZaehler] = [:]
    /// Der Tag, an dem "erster Tab" und "erste Funktion des Tages" schon gezählt sind (der Tag selbst verschwindet nach dem Senden, dieser Merker nicht).
    var ersterTabTag: String?
    var ersteFunktionTag: String?
    /// Begonnene, nicht beendete Abläufe (Ablauf → letzte Stufe). Ein Rest aus einer früheren Sitzung zählt beim nächsten Start als Abbruch.
    var offen: [String: String] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey { case tage, ersterTabTag, ersteFunktionTag, offen }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tage = (try? c.decodeIfPresent([String: NutzungZaehler].self, forKey: .tage)) ?? [:]
        ersterTabTag = (try? c.decodeIfPresent(String.self, forKey: .ersterTabTag)) ?? nil
        ersteFunktionTag = (try? c.decodeIfPresent(String.self, forKey: .ersteFunktionTag)) ?? nil
        offen = (try? c.decodeIfPresent([String: String].self, forKey: .offen)) ?? [:]
    }

    /// Form des Servers: Kleinbuchstabe am Anfang, dann Buchstaben, Ziffern, `_` und `.`, höchstens 40 Zeichen.
    nonisolated static func gueltig(_ name: String) -> Bool {
        guard let erster = name.unicodeScalars.first, name.count <= 40, ("a"..."z").contains(erster) else { return false }
        return name.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "_" || $0 == "." }
    }

    /// Wege heißen "von>nach", beide Teile in der Form eines Namens.
    nonisolated static func gueltig(_ name: String, art: NutzungArt) -> Bool {
        guard art == .weg else { return gueltig(name) }
        let teile = name.split(separator: ">", omittingEmptySubsequences: false)
        return teile.count == 2 && teile.allSatisfy { gueltig(String($0)) }
    }

    mutating func zaehleBereich(_ name: String, tag: String) { zaehle(name, tag: tag, art: \.bereiche) }
    mutating func zaehleFunktion(_ name: String, tag: String) { zaehle(name, tag: tag, art: \.funktionen) }

    private mutating func zaehle(_ name: String, tag: String, art: WritableKeyPath<NutzungZaehler, [String: Int]>) {
        guard Self.gueltig(name) else { return }
        var z = tage[tag] ?? NutzungZaehler()
        if z[keyPath: art][name] == nil, z[keyPath: art].count >= Self.maxNamen { return }
        z[keyPath: art][name] = min(Self.maxAnzahl, (z[keyPath: art][name] ?? 0) + 1)
        tage[tag] = z
        kuerze()
    }

    /// Zählt in einer Gruppe (`NutzungArt`). Ungültige Namen und Namen über der Grenze der Art fallen weg.
    mutating func zaehleMehr(_ art: NutzungArt, _ name: String, tag: String, anzahl: Int = 1) {
        guard Self.gueltig(name, art: art), anzahl > 0 else { return }
        var z = tage[tag] ?? NutzungZaehler()
        var gruppe = z.mehr[art.rawValue] ?? [:]
        if gruppe[name] == nil, gruppe.count >= art.maxNamen { return }
        gruppe[name] = min(Self.maxAnzahl, (gruppe[name] ?? 0) + anzahl)
        z.mehr[art.rawValue] = gruppe
        tage[tag] = z
        kuerze()
    }

    /// Der Stand der Einstellungen ist ein Zustand, kein Zähler: der neue ersetzt den alten dieses Tages.
    mutating func setzeStand(_ namen: [String], tag: String) {
        let gut = Set(namen.filter { Self.gueltig($0) }).sorted().prefix(NutzungArt.stand.maxNamen)
        var z = tage[tag] ?? NutzungZaehler()
        z.mehr[NutzungArt.stand.rawValue] = gut.isEmpty ? nil : Dictionary(uniqueKeysWithValues: gut.map { ($0, 1) })
        tage[tag] = z
        kuerze()
    }

    /// Merkt den Tag als aktiv, ohne etwas zu zählen (der Start selbst ist ein aktiver Tag).
    mutating func aktiv(tag: String) {
        if tage[tag] == nil { tage[tag] = NutzungZaehler() }
        kuerze()
    }

    private mutating func kuerze() {
        guard tage.count > Self.maxTage else { return }
        for alt in tage.keys.sorted().dropLast(Self.maxTage) { tage[alt] = nil }
    }

    /// Welche Tage jetzt gesendet werden: ältere Tage mit Inhalt, und heute einmal je Start (auch leer: das ist der aktive Tag).
    /// `zwischendurch`: heute auch außerhalb des Starts, wenn es etwas zu melden gibt (beim Wechsel in den Hintergrund, damit Fehler nicht erst beim übernächsten Start ankommen).
    func faellig(heute: String, ersterInSitzung: Bool, zwischendurch: Bool = false) -> [(String, NutzungZaehler)] {
        var aus = tage.filter { $0.key != heute && !$0.value.leer }
        if ersterInSitzung { aus[heute] = tage[heute] ?? NutzungZaehler() }
        else if zwischendurch, let h = tage[heute], !h.leer { aus[heute] = h }
        return aus.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// Nach dem Senden: die Zähler des Tages sind weg (der Server hat sie addiert).
    mutating func abgeschickt(tag: String) { tage[tag] = nil }
}

/// Die Namen, die die App meldet. Feste Wörter aus Routen und Ereignissen, nie Inhalte (eine Übungs-Kennung wird nicht gemeldet).
enum NutzungName {
    /// Funktionen, bei denen die Zeit vom Öffnen der App bis zum ersten Mal gemessen wird.
    nonisolated static let zielFunktionen: Set<String> = ["training", "satz", "mahlzeit"]

    nonisolated static func tab(_ tab: LumenFitTab) -> String { "tab.\(tab.rawValue)" }

    nonisolated static func seite(_ route: Route) -> String {
        switch route {
        case .heute: "seite.heute"
        case .gym(let b): "seite.gym.\(b.rawValue)"
        case .essen(let b): "seite.essen.\(b.rawValue)"
        case .schlaf(let b): "seite.schlaf.\(b.rawValue)"
        case .coach: "seite.coach"
        case .profil(let b): "seite.profil.\(b.rawValue)"
        case .verlauf: "seite.verlauf"
        case .gewichtEintragen: "seite.gewichtEintragen"
        case .uebung: "seite.uebung"
        case .freund: "blatt.freund"
        }
    }

    /// Blätter über den Tabs (Profil, Freunde).
    nonisolated static func blatt(_ route: Route) -> String {
        switch route {
        case .profil: "blatt.profil"
        case .freund: "blatt.freund"
        default: seite(route)
        }
    }

    nonisolated static func funktion(_ ereignis: Ereignis) -> String? {
        switch ereignis {
        case .trainingGestartet: "training"
        case .satzFertig: "satz"
        case .mahlzeitGespeichert: "mahlzeit"
        case .gewichtGespeichert: "gewicht"
        case .habitGeaendert: "habit"
        case .meilensteinErreicht: "meilenstein"
        default: nil
        }
    }
}

/// Hält den Stand im Speicher und in `nutzung-offen.json` (nur Zähler und feste Namen). Zählen ist billig: die Datei wird höchstens alle 15 Sekunden geschrieben
/// und beim Wechsel in den Hintergrund. Ohne Zustimmung (`an == false`, der Standard) wird nichts gezählt, nichts gesendet und Offenes sofort verworfen.
@MainActor
final class NutzungSpeicher {
    nonisolated static let datei = "nutzung-offen.json"
    nonisolated static let schreibPause: TimeInterval = 15

    private(set) var stand: NutzungStand
    /// Nur nach einem "Ja" an. Aus (nie gefragt, Nein, Schalter im Datenschutz): nichts wird gezählt, Offenes wird verworfen, nichts geht raus.
    var an = false {
        didSet { if !an { verwerfe() } }
    }
    private let ablage: URL
    private let uhr: Uhr
    private var sitzung: Date?
    private var letzter: String?
    private var zielErreicht: Set<String> = []
    private var gesehenInSitzung: Set<String> = []
    private var restGeprueft = false
    private var startGemessen = false
    private var letzteSicherung: Date?

    init(ordner: URL, uhr: @escaping Uhr) {
        ablage = ordner.appendingPathComponent(Self.datei)
        self.uhr = uhr
        stand = (try? Data(contentsOf: ablage)).flatMap { try? JSONDecoder().decode(NutzungStand.self, from: $0) } ?? NutzungStand()
    }

    private var heute: String { Datum.text(uhr()) }

    // MARK: Zählen

    func bereich(_ name: String) {
        guard an else { return }
        if sitzung == nil { vordergrund() }
        let tag = heute
        stand.zaehleBereich(name, tag: tag)
        if let von = letzter, von != name { stand.zaehleMehr(.weg, "\(von)>\(name)", tag: tag) }
        letzter = name
        if name.hasPrefix("tab."), stand.ersterTabTag != tag { stand.ersterTabTag = tag; stand.zaehleMehr(.erster, name, tag: tag) }
        sichere()
    }

    func funktion(_ name: String) {
        guard an else { return }
        if sitzung == nil { vordergrund() }
        let tag = heute
        stand.zaehleFunktion(name, tag: tag)
        if stand.ersteFunktionTag != tag { stand.ersteFunktionTag = tag; stand.zaehleMehr(.erster, "fn.\(name)", tag: tag) }
        if let beginn = sitzung, NutzungName.zielFunktionen.contains(name), zielErreicht.insert(name).inserted {
            stand.zaehleMehr(.ziel, "\(name).\(NutzungMass.ziel(uhr().timeIntervalSince(beginn)))", tag: tag)
        }
        sichere()
    }

    /// Die App kommt nach vorn: ein Start, die Tageszeit, und Reste unbeendeter Abläufe einer früheren Sitzung zählen als Abbruch.
    func vordergrund() {
        guard an, sitzung == nil else { return }
        let jetzt = uhr()
        let tag = heute
        sitzung = jetzt
        letzter = "start"
        zielErreicht = []
        if !restGeprueft {
            restGeprueft = true
            for (ablauf, stufe) in stand.offen { stand.zaehleMehr(.abbruch, "\(ablauf).\(stufe)", tag: tag) }
            stand.offen = [:]
        }
        stand.zaehleMehr(.start, "anzahl", tag: tag)
        stand.zaehleMehr(.start, "block_\(NutzungMass.block(jetzt))", tag: tag)
        sichere()
    }

    /// Die App geht in den Hintergrund: Dauer der Sitzung als Bereich, letzter Bereich als Absprung, Datei schreiben.
    func hintergrund() {
        guard an else { return }
        if let beginn = sitzung {
            let tag = heute
            stand.zaehleMehr(.dauer, NutzungMass.dauer(uhr().timeIntervalSince(beginn)), tag: tag)
            if let l = letzter, l != "start" { stand.zaehleMehr(.absprung, l, tag: tag) }
        }
        sitzung = nil
        letzter = nil
        sichere(sofort: true)
    }

    /// Der Stand der Einstellungen (Theme, Bereiche, Band, Einheit, Haptik) als Zustand dieses Tages, nur als feste Namen.
    func einstellungen(_ e: Einstellungen) {
        guard an else { return }
        var namen = ["theme_\(e.thema.rawValue)", e.bandAktiv ? "band_an" : "band_aus", "einheit_\(e.gewichtsEinheit.rawValue)"]
        for bereich in AppBereich.allCases where e.zeigt(bereich) { namen.append("bereich_\(bereich.rawValue)") }
        if !e.haptik { namen.append("haptik_aus") }
        stand.setzeStand(namen, tag: heute)
        sichere()
    }

    func fehler(_ art: NutzungFehler, anzahl: Int = 1) {
        guard an else { return }
        stand.zaehleMehr(.fehler, art.rawValue, tag: heute, anzahl: anzahl)
        sichere()
    }

    /// Ein Aufruf des Lumen-Servers: Dauer als Bereich, bei Fehlschlag (kein Netz, nicht 2xx) zusätzlich Status. Nicht gemessene Wege (`/nutzung`) ergeben nichts.
    func route(methode: String?, pfad: String?, status: Int?, dauer: TimeInterval) {
        guard an, let name = NutzungRoute.name(methode: methode, pfad: pfad) else { return }
        let tag = heute
        stand.zaehleMehr(.tempo, "\(name).\(NutzungMass.tempo(dauer))", tag: tag)
        if let status, (200..<300).contains(status) { sichere(); return }
        stand.zaehleMehr(.route, "\(name).\(NutzungRoute.status(status))", tag: tag)
        sichere()
    }

    /// Startzeit bis zur ersten Ansicht, einmal je Prozess.
    func startdauer(_ sekunden: TimeInterval) {
        guard an, !startGemessen else { return }
        startGemessen = true
        stand.zaehleMehr(.tempo, "start.\(NutzungMass.tempo(sekunden))", tag: heute)
        sichere()
    }

    func gesehen(_ eintrag: NutzungEintrag) {
        guard an, gesehenInSitzung.insert(eintrag.rawValue).inserted else { return }
        stand.zaehleMehr(.gesehen, eintrag.rawValue, tag: heute)
        sichere()
    }

    func getippt(_ eintrag: NutzungEintrag) {
        guard an else { return }
        stand.zaehleMehr(.getippt, eintrag.rawValue, tag: heute)
        sichere()
    }

    // MARK: Abläufe

    /// Ein Ablauf beginnt oder kommt in eine neue Stufe.
    func ablauf(_ ablauf: NutzungAblauf, stufe: String) {
        guard an, ablauf.stufen.contains(stufe) else { return }
        if stand.offen[ablauf.rawValue] == nil { stand.zaehleMehr(.begonnen, ablauf.rawValue, tag: heute) }
        stand.offen[ablauf.rawValue] = stufe
        sichere()
    }

    func ablaufFertig(_ ablauf: NutzungAblauf) {
        guard an, stand.offen[ablauf.rawValue] != nil else { return }
        stand.offen[ablauf.rawValue] = nil
        stand.zaehleMehr(.fertig, ablauf.rawValue, tag: heute)
        sichere()
    }

    /// Die Ansicht des Ablaufs verschwindet: war er nicht fertig, zählt die letzte Stufe als Abbruch.
    func ablaufEnde(_ ablauf: NutzungAblauf) {
        guard an, let stufe = stand.offen[ablauf.rawValue] else { return }
        stand.offen[ablauf.rawValue] = nil
        stand.zaehleMehr(.abbruch, "\(ablauf.rawValue).\(stufe)", tag: heute)
        sichere()
    }

    // MARK: Senden

    func faellig(heute: String, ersterInSitzung: Bool, zwischendurch: Bool = false) -> [(String, NutzungZaehler)] {
        guard an else { return [] }
        return stand.faellig(heute: heute, ersterInSitzung: ersterInSitzung, zwischendurch: zwischendurch)
    }

    func abgeschickt(tag: String) { stand.abgeschickt(tag: tag); sichere(sofort: true) }

    // MARK: Ablage

    private func verwerfe() {
        guard stand != NutzungStand() else { return }
        stand = NutzungStand()
        sitzung = nil
        letzter = nil
        sichere(sofort: true)
    }

    private func sichere(sofort: Bool = false) {
        let jetzt = uhr()
        if !sofort, let l = letzteSicherung, jetzt.timeIntervalSince(l) >= 0, jetzt.timeIntervalSince(l) < Self.schreibPause { return }
        letzteSicherung = jetzt
        guard let daten = try? JSONEncoder().encode(stand) else { return }
        try? FileManager.default.createDirectory(at: ablage.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: ablage, options: .atomic)
    }
}
