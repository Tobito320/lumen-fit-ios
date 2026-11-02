import Foundation

/// Was die App dem Server über die Nutzung meldet: nur Zähler, welche Bereiche (Tabs, Seiten) und Funktionen benutzt wurden, je Tag.
/// Nie Gesundheitswerte, nie Inhalte, nie Texte, Namen oder Kennungen aus den Daten. Die Namen sind feste Wörter dieser App (`NutzungName`).
struct NutzungZaehler: Codable, Equatable, Sendable {
    var bereiche: [String: Int] = [:]
    var funktionen: [String: Int] = [:]
    var leer: Bool { bereiche.isEmpty && funktionen.isEmpty }
}

/// Körper von `POST /nutzung`.
struct NutzungMeldung: Codable, Equatable, Sendable {
    var tag: String
    var bereiche: [String: Int]
    var funktionen: [String: Int]
}

/// Der Stand der noch nicht gesendeten Zähler. Rein und ohne Datei testbar.
struct NutzungStand: Codable, Equatable, Sendable {
    /// So viele verschiedene Namen je Tag und Art nimmt der Server an.
    nonisolated static let maxNamen = 60
    nonisolated static let maxAnzahl = 9999
    /// Ältere offene Tage nimmt der Server nicht mehr an (3 Tage); so lange wird höchstens aufgehoben.
    nonisolated static let maxTage = 4

    var tage: [String: NutzungZaehler] = [:]

    /// Form des Servers: Kleinbuchstabe am Anfang, dann Buchstaben, Ziffern, `_` und `.`, höchstens 40 Zeichen.
    nonisolated static func gueltig(_ name: String) -> Bool {
        guard let erster = name.unicodeScalars.first, name.count <= 40, ("a"..."z").contains(erster) else { return false }
        return name.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "_" || $0 == "." }
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
    func faellig(heute: String, ersterInSitzung: Bool) -> [(String, NutzungZaehler)] {
        var aus = tage.filter { $0.key != heute && !$0.value.leer }
        if ersterInSitzung { aus[heute] = tage[heute] ?? NutzungZaehler() }
        return aus.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// Nach dem Senden: die Zähler des Tages sind weg (der Server hat sie addiert).
    mutating func abgeschickt(tag: String) { tage[tag] = nil }
}

/// Die Namen, die die App meldet. Feste Wörter aus Routen und Ereignissen, nie Inhalte (eine Übungs-Kennung wird nicht gemeldet).
enum NutzungName {
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

/// Hält den Stand im Speicher und in `nutzung-offen.json` (nur Zähler). Zählen ist billig: eine kleine Datei, nur bei einer Änderung.
@MainActor
final class NutzungSpeicher {
    nonisolated static let datei = "nutzung-offen.json"

    private(set) var stand: NutzungStand
    /// Aus (Schalter im Datenschutz): nichts wird gezählt, Offenes wird verworfen, nichts geht raus.
    var an = true {
        didSet { if !an, oldValue { stand = NutzungStand(); sichere() } }
    }
    private let ablage: URL
    private let uhr: Uhr

    init(ordner: URL, uhr: @escaping Uhr) {
        ablage = ordner.appendingPathComponent(Self.datei)
        self.uhr = uhr
        stand = (try? Data(contentsOf: ablage)).flatMap { try? JSONDecoder().decode(NutzungStand.self, from: $0) } ?? NutzungStand()
    }

    func bereich(_ name: String) { guard an else { return }; stand.zaehleBereich(name, tag: Datum.text(uhr())); sichere() }
    func funktion(_ name: String) { guard an else { return }; stand.zaehleFunktion(name, tag: Datum.text(uhr())); sichere() }
    func faellig(heute: String, ersterInSitzung: Bool) -> [(String, NutzungZaehler)] { stand.faellig(heute: heute, ersterInSitzung: ersterInSitzung) }
    func abgeschickt(tag: String) { stand.abgeschickt(tag: tag); sichere() }

    private func sichere() {
        guard let daten = try? JSONEncoder().encode(stand) else { return }
        try? FileManager.default.createDirectory(at: ablage.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: ablage, options: .atomic)
    }
}
