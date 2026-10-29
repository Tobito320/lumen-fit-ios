// Quelle: Lovea Health/Studio/StudioProfil.swift (ohne feste Studios und Personen; Datei im Profilordner statt UserDefaults)
import Foundation
import Observation

/// Studio und Trainings-Slot des Profils. `name` ist ein freies Textfeld (Vorschläge kommen aus `PrivateDaten.json`, `StudioVorgaben`).
/// `slotStart` in Minuten seit Mitternacht, nil = keine feste Uhrzeit.
struct StudioProfil: Codable, Equatable, Sendable {
    var name: String = ""
    var slotStart: Int? = nil
    var dauer: Int = 45
    var oeffnung: StudioOeffnung = .unbekannt

    init(name: String = "", slotStart: Int? = nil, dauer: Int = 45, oeffnung: StudioOeffnung = .unbekannt) {
        self.name = name
        self.slotStart = slotStart
        self.dauer = dauer
        self.oeffnung = oeffnung
    }

    /// Alle Felder `decodeIfPresent`: neue Felder machen alte Dateien nie unlesbar.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        slotStart = try c.decodeIfPresent(Int.self, forKey: .slotStart)
        dauer = try c.decodeIfPresent(Int.self, forKey: .dauer) ?? 45
        oeffnung = try c.decodeIfPresent(StudioOeffnung.self, forKey: .oeffnung) ?? .unbekannt
    }

    private enum CodingKeys: String, CodingKey { case name, slotStart, dauer, oeffnung }

    static let standard = StudioProfil()

    /// Name ohne Leerraum; leer heißt "noch kein Studio gewählt".
    var anzeigeName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hatStudio: Bool { !anzeigeName.isEmpty }
}

/// Das Studio-Profil des aktiven Profils (`studio.json` im Profilordner). Ohne Ordner nur im Speicher (Vorschau, Tests).
@MainActor @Observable
final class StudioStore {
    @ObservationIgnored private let datei: JSONDatei<StudioProfil>?
    private var gespeichert = StudioProfil.standard

    var profil: StudioProfil {
        get { gespeichert }
        set { setze(newValue) }
    }

    init(ordner: URL? = nil) {
        datei = ordner.map { JSONDatei<StudioProfil>($0.appendingPathComponent("studio.json")) }
        if let alt = datei?.lade() { gespeichert = alt }
    }

    func setze(_ neu: StudioProfil) {
        guard neu != gespeichert else { return }
        gespeichert = neu
        datei?.speichere(neu)
    }

    func aendere(_ f: (inout StudioProfil) -> Void) {
        var neu = gespeichert
        f(&neu)
        setze(neu)
    }
}

/// Ein Studio-Vorschlag aus `PrivateDaten.json`: nur Name und Öffnungszeiten, nie die Adresse.
struct StudioVorschlag: Equatable, Sendable, Identifiable {
    var name: String
    var oeffnung: StudioOeffnung
    var id: String { name }
}

/// Liest die Studio-Vorgaben aus `PrivateDaten.json` (`{version, personen:[{id, name, orte:[{name, art, ..., oeffnung?}]}]}`, SPEC 7, Annahme 17).
/// Nur Orte mit `art == "gym"` der Person, deren Name dem Profilnamen entspricht. Ohne Datei oder ohne Treffer: leer, das Studio bleibt ein Textfeld.
/// `oeffnung` ist optional: `{"rund": true}` oder `{"werktage": "08:00-22:00", "wochenende": "09:00-18:00"}`.
enum StudioVorgaben {
    private struct Datei: Decodable {
        var personen: [Person]?
    }

    private struct Person: Decodable {
        var id: String?
        var name: String?
        var orte: [Ort]?
    }

    private struct Ort: Decodable {
        var name: String?
        var art: String?
        var oeffnung: Oeffnung?
    }

    private struct Oeffnung: Decodable {
        var rund: Bool?
        var werktage: String?
        var wochenende: String?
    }

    private static func normal(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func vorschlaege(daten: Data, profilName: String) -> [StudioVorschlag] {
        guard let datei = try? JSONDecoder().decode(Datei.self, from: daten) else { return [] }
        let gesucht = normal(profilName)
        guard !gesucht.isEmpty else { return [] }
        let person = (datei.personen ?? []).first { normal($0.name) == gesucht || normal($0.id) == gesucht }
        return (person?.orte ?? []).compactMap { ort in
            guard ort.art == "gym", let name = ort.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            let o = ort.oeffnung
            let oeffnung = StudioOeffnung(rund: o?.rund ?? false,
                                          werktage: o?.werktage.flatMap(StudioOeffnung.fenster(text:)),
                                          wochenende: o?.wochenende.flatMap(StudioOeffnung.fenster(text:)))
            return StudioVorschlag(name: name, oeffnung: oeffnung)
        }
    }

    /// Aus dem App-Bundle; `PrivateDaten.json` ist in Tests und ohne Secret nicht da.
    static func vorschlaege(profilName: String, bundle: Bundle = Bundle(for: BundleAnker.self)) -> [StudioVorschlag] {
        guard let url = bundle.url(forResource: "PrivateDaten", withExtension: "json"), let daten = try? Data(contentsOf: url) else { return [] }
        return vorschlaege(daten: daten, profilName: profilName)
    }
}

/// Studio-Besuche: jede Einheit (Einchecken) ist ein Besuch, Auschecken schließt ihn (Idee 29).
enum StudioBesuche {
    struct Zaehler: Equatable, Sendable {
        var dieseWoche: Int
        var diesenMonat: Int
        var gesamt: Int
        /// Wochen in Folge mit mindestens einem Besuch (`TrainingLogik.serieWochen`).
        var serieWochen: Int
    }

    static func zaehlen(_ sessions: [GymSession], heute: String) -> Zaehler {
        let monat = String(heute.prefix(7))
        return Zaehler(dieseWoche: TrainingLogik.dieseWoche(sessions, heute: heute),
                       diesenMonat: sessions.filter { Datum.text($0.start).hasPrefix(monat) }.count,
                       gesamt: sessions.count,
                       serieWochen: TrainingLogik.serieWochen(sessions, heute: heute))
    }

    /// "3 Besuche diese Woche", "1 Besuch diese Woche".
    static func wochenText(_ z: Zaehler) -> String { "\(z.dieseWoche) \(z.dieseWoche == 1 ? "Besuch" : "Besuche") diese Woche" }
}
