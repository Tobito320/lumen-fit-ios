import Foundation
import Observation

// Was der Coach lokal über die Bedienung weiß (Datei `coach.json` im Profilordner, nur auf diesem Gerät): eigener Name, gemerkte Antworten
// (Merkliste), "Heute nicht" beim Morgen-Check, die Frage, die er sich merkt, wenn er gerade nicht antworten konnte, und die Wahl der Person
// im Chat-Menü (Pause, Ton, eigenes Ziel, Morgen-Check an oder aus, "Coach hält mich an den Plan", ausgeblendeter Verlauf, abgehakte Aufgaben).
// Alle Felder sind optional beim Lesen (`decodeIfPresent`), damit neue Felder alte Dateien nie unlesbar machen.

struct CoachLokalStand: Codable, Equatable, Sendable {
    var name = ""
    /// Ids gemerkter Antworten, älteste zuerst.
    var merkliste: [String] = []
    /// Der Tag, an dem "Heute nicht" beim Morgen-Check gewählt wurde.
    var morgenUebersprungen: String?
    /// Frage, die beim letzten Mal nicht beantwortet werden konnte ("ich merke mir deine Frage").
    var wartendeFrage: String?
    /// Coach pausiert: Kachel und Karten in Heute sind aus, der Chat zeigt nur die Pause.
    var pause = false
    /// Wunschton: "", "locker", "knapp" oder "direkt" (`CoachEinstellungen.toene`).
    var ton = ""
    /// Eigenes Ziel in einem Satz; leer = keins.
    var ziel = ""
    /// Der Morgen-Check beim Öffnen am Vormittag (nur ein Schalter, es gibt keine Mitteilung).
    var morgenAn = true
    /// Training: der Coach hält mich an den Plan (neutral benannt, Standard aus).
    var disziplin = false
    /// Nachrichten bis zu diesem Zeitpunkt sind im Chat ausgeblendet (nur auf diesem Gerät).
    var ausgeblendetBis: Date?
    /// Schlüssel (`CoachLokal.schluessel`) abgehakter Aufgaben in Antworten.
    var haken: [String] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case name, merkliste, morgenUebersprungen, wartendeFrage, pause, ton, ziel, morgenAn, disziplin, ausgeblendetBis, haken
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        merkliste = (try? c.decodeIfPresent([String].self, forKey: .merkliste)) ?? []
        morgenUebersprungen = try? c.decodeIfPresent(String.self, forKey: .morgenUebersprungen)
        wartendeFrage = try? c.decodeIfPresent(String.self, forKey: .wartendeFrage)
        pause = (try? c.decodeIfPresent(Bool.self, forKey: .pause)) ?? false
        ton = (try? c.decodeIfPresent(String.self, forKey: .ton)) ?? ""
        ziel = (try? c.decodeIfPresent(String.self, forKey: .ziel)) ?? ""
        morgenAn = (try? c.decodeIfPresent(Bool.self, forKey: .morgenAn)) ?? true
        disziplin = (try? c.decodeIfPresent(Bool.self, forKey: .disziplin)) ?? false
        ausgeblendetBis = try? c.decodeIfPresent(Date.self, forKey: .ausgeblendetBis)
        haken = (try? c.decodeIfPresent([String].self, forKey: .haken)) ?? []
    }
}

@MainActor @Observable
final class CoachEinstellungen {
    nonisolated static let maxMerkliste = 50
    nonisolated static let maxHaken = 200
    nonisolated static let maxZiel = 200
    /// Die Töne des Menüs. Was nicht in der Liste steht, gilt als Standard.
    nonisolated static let toene: [(wert: String, name: String)] = [("", "Standard"), ("locker", "Locker"), ("knapp", "Knapp"), ("direkt", "Direkt")]

    @ObservationIgnored private let datei: JSONDatei<CoachLokalStand>?
    private(set) var stand = CoachLokalStand()

    /// Ohne Ordner nur im Speicher (Vorschau und Tests).
    init(ordner: URL? = nil) {
        datei = ordner.map { JSONDatei<CoachLokalStand>($0.appendingPathComponent("coach.json")) }
        if let gelesen = datei?.lade() { stand = gelesen }
    }

    var anzeigeName: String { CoachLokal.anzeigeName(stand.name) }

    func setzeName(_ text: String) { aendere { $0.name = CoachLokal.nameBereinigen(text) } }

    func istGemerkt(_ id: String) -> Bool { stand.merkliste.contains(id) }

    func merkeAntwort(_ id: String, an: Bool) {
        aendere { $0.merkliste = CoachLokal.setzen($0.merkliste, id, an: an, maximal: Self.maxMerkliste) }
    }

    func ueberspringeMorgen(tag: String) { aendere { $0.morgenUebersprungen = tag } }

    func merkeFrage(_ frage: String?) { aendere { $0.wartendeFrage = frage } }

    // MARK: - Menü des Chats

    func setzePause(_ an: Bool) { aendere { $0.pause = an } }

    /// Unbekannte Töne werden zum Standard.
    func setzeTon(_ wert: String) {
        aendere { $0.ton = Self.toene.contains { $0.wert == wert } ? wert : "" }
    }

    /// Ein Satz, getrimmt, ohne Zeilenumbruch, höchstens 200 Zeichen. Leer entfernt das Ziel.
    func setzeZiel(_ text: String) {
        aendere { $0.ziel = Self.zielBereinigen(text) }
    }

    nonisolated static func zielBereinigen(_ roh: String) -> String {
        let eins = roh.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(eins.prefix(maxZiel))
    }

    func setzeMorgen(_ an: Bool) { aendere { $0.morgenAn = an } }

    func setzeDisziplin(_ an: Bool) { aendere { $0.disziplin = an } }

    func blendeVerlaufAus(bis zeit: Date) { aendere { $0.ausgeblendetBis = zeit } }

    func istAbgehakt(_ schluessel: String) -> Bool { stand.haken.contains(schluessel) }

    func haken(_ schluessel: String, an: Bool) {
        aendere { $0.haken = CoachLokal.setzen($0.haken, schluessel, an: an, maximal: Self.maxHaken) }
    }

    private func aendere(_ f: (inout CoachLokalStand) -> Void) {
        var neu = stand
        f(&neu)
        guard neu != stand else { return }
        stand = neu
        datei?.speichere(neu)
    }
}
