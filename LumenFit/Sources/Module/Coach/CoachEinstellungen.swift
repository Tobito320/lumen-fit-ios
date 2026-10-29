import Foundation
import Observation

// Was der Coach lokal über die Bedienung weiß (Datei `coach.json` im Profilordner, nur auf diesem Gerät): eigener Name, gemerkte Antworten
// (Merkliste), "Heute nicht" beim Morgen-Check und die Frage, die er sich merkt, wenn er gerade nicht antworten konnte.
// Alle Felder sind optional beim Lesen (`decodeIfPresent`), damit neue Felder alte Dateien nie unlesbar machen.

struct CoachLokalStand: Codable, Equatable, Sendable {
    var name = ""
    /// Ids gemerkter Antworten, älteste zuerst.
    var merkliste: [String] = []
    /// Der Tag, an dem "Heute nicht" beim Morgen-Check gewählt wurde.
    var morgenUebersprungen: String?
    /// Frage, die beim letzten Mal nicht beantwortet werden konnte ("ich merke mir deine Frage").
    var wartendeFrage: String?

    init() {}

    private enum CodingKeys: String, CodingKey { case name, merkliste, morgenUebersprungen, wartendeFrage }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        merkliste = (try? c.decodeIfPresent([String].self, forKey: .merkliste)) ?? []
        morgenUebersprungen = try? c.decodeIfPresent(String.self, forKey: .morgenUebersprungen)
        wartendeFrage = try? c.decodeIfPresent(String.self, forKey: .wartendeFrage)
    }
}

@MainActor @Observable
final class CoachEinstellungen {
    static let maxMerkliste = 50

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

    private func aendere(_ f: (inout CoachLokalStand) -> Void) {
        var neu = stand
        f(&neu)
        guard neu != stand else { return }
        stand = neu
        datei?.speichere(neu)
    }
}
