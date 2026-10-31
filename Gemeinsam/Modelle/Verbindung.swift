import Foundation

/// Was der Nutzer seinem Partner zeigt. Jede Art ist einzeln und standardmäßig aus. `plan`, `verlauf`, `tagebuch` und `koerper` gehören zu den Ansichten des Partners
/// (Trainingsplan, Statuszeile und Verlauf, Tagebuch, Körperwerte); `schritte`, `gym`, `schlaf` und `essen` zu den Zeilen der Partner-Karte.
enum FreigabeArt: String, Codable, CaseIterable, Sendable { case schritte, gym, schlaf, essen, plan, verlauf, tagebuch, koerper, stimmung, gewohnheiten }
enum PartnerBereich: Sendable { case heute, schlaf, essen, gym }
enum PartnerEreignisArt: String, Codable, Sendable { case gymStart, gymEnde, ziel, rekord, schlafGut }
enum BandMuster: String, Codable, Sendable { case kurz, lang, doppelt, ruf, pauseEnde }

struct TagesZusammenfassung: Codable, Equatable, Sendable {
    var tag: String
    var schritte: Int?
    var gymTageWoche: Int?
    var schlafMinuten: Int?
    var kcal: Int?
    // Erweiterung (Gleichstand Health): alles optional, eine ältere Datei bleibt lesbar. Jedes Feld gehört zu genau einer Freigabe.
    /// Schrittziel (Freigabe schritte).
    var schritteZiel: Int?
    /// Schritte je Tag (`yyyy-MM-dd`) der laufenden Woche (Freigabe schritte).
    var schritteWoche: [String: Int]?
    /// Tage der laufenden Woche mit Gym (Freigabe gym) und das Wochenziel.
    var gymTage: [String]?
    var gymZiel: Int?
    /// Schlaf je Aufwachtag der laufenden Woche in Minuten und das Ziel (Freigabe schlaf).
    var schlafWoche: [String: Int]?
    var schlafZiel: Int?
    /// Energie-Rat von heute: "hoch", "mittel" oder "niedrig" (Freigabe schlaf), dazu der Gym-Satz (zusätzlich Freigabe gym).
    var energieStufe: String?
    var energieGym: String?
    /// Kennungen eingebauter Gewohnheiten, die heute erledigt sind ("gym" mit Freigabe gym, "wasser" mit Freigabe essen).
    var habitsFertig: [String]?
    /// Phase und Tag des Zyklus in kurzen Hinweisen. Nur wenn die Person es in den Zyklus-Einstellungen erlaubt (kein Teil von `FreigabeArt`).
    var zyklus: ZyklusZusammenfassung?
    /// Trainingsplan: Name, Wochentage, Übungsnamen (Freigabe plan).
    var plan: PartnerPlan?
    /// Statuszeile "im Gym" und die letzten Trainings als Zusammenfassung, ohne Sätze und Gewichte (Freigabe verlauf).
    var verlauf: PartnerVerlauf?
    /// Tagebuch der letzten sieben Tage: Tageswerte, Makros, Namen der Einträge, keine Fotos (Freigabe tagebuch) und die Tagesziele dazu (ebenfalls tagebuch).
    var tagebuch: [PartnerTagebuchTag]?
    var tagebuchZiele: PartnerMakros?
    /// Messreihen je `MessArt.rawValue` in Zehnteln, Gewicht eingeschlossen (Freigabe koerper).
    var koerper: [String: [PartnerMesspunkt]]?
    /// Morgen-Check von heute (1 schwer bis 5 top) und der Verlauf der Woche je Tag (Freigabe stimmung).
    var stimmung: Int?
    var stimmungWoche: [String: Int]?
    /// Alle Gewohnheiten mit Serie und Quote (Freigabe gewohnheiten).
    var gewohnheiten: [GewohnheitStand]?

    init(tag: String, schritte: Int? = nil, gymTageWoche: Int? = nil, schlafMinuten: Int? = nil, kcal: Int? = nil) {
        self.tag = tag; self.schritte = schritte; self.gymTageWoche = gymTageWoche
        self.schlafMinuten = schlafMinuten; self.kcal = kcal
    }
}

/// Eine Gewohnheit für den Vergleich: Serie (Tage oder Wochen in Folge, je nach Art), Quote der letzten 30 Tage in Prozent und ob sie heute erledigt ist.
struct GewohnheitStand: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var symbol: String
    var serie: Int
    var quote: Int
    var heute: Bool
}

/// Ein Tag des Plans: Name, Wochentage (1 = Montag bis 7 = Sonntag) und die Übungen.
struct PartnerPlanTag: Codable, Equatable, Hashable, Sendable {
    var name: String
    var wochentage: [Int]
    var uebungen: [PartnerPlanUebung]
}

struct PartnerPlanUebung: Codable, Equatable, Hashable, Sendable {
    var name: String
    var saetze: Int
}

struct PartnerPlan: Codable, Equatable, Sendable {
    var name: String?
    var tage: [PartnerPlanTag]
    var ruhetage: [Int]?
}

/// Eine Einheit als Zusammenfassung: Tag, Name des Plantags, Dauer, Zahl der Sätze und Übungen.
struct PartnerTrainingKurz: Codable, Equatable, Hashable, Sendable {
    var tag: String
    var name: String?
    var minuten: Int?
    var saetze: Int
    var uebungen: Int
    var kcal: Int?
}

struct PartnerVerlauf: Codable, Equatable, Sendable {
    /// Läuft gerade ein Training? Dann seit wann und welcher Tag des Plans.
    var imGym: Bool?
    var imGymSeit: Date?
    var imGymName: String?
    /// Neueste zuerst, höchstens zehn.
    var trainings: [PartnerTrainingKurz]
    var woche: Int?
    var serieWochen: Int?
    var gesamt: Int?
}

/// Kalorien und Makros in ganzen Zahlen (für einen Tag oder als Tagesziel).
struct PartnerMakros: Codable, Equatable, Hashable, Sendable {
    var kcal: Int
    var protein: Int
    var kohlenhydrate: Int
    var fett: Int
}

/// Ein Eintrag im Tagebuch: nur Name und Kalorien, `mahlzeit` ist `Mahlzeit.rawValue`.
struct PartnerMahlzeitKurz: Codable, Equatable, Hashable, Sendable {
    var mahlzeit: String
    var name: String
    var kcal: Int
}

struct PartnerTagebuchTag: Codable, Equatable, Hashable, Sendable {
    var tag: String
    var kcal: Int
    var protein: Int
    var kohlenhydrate: Int
    var fett: Int
    var mahlzeiten: [PartnerMahlzeitKurz]

    var summe: PartnerMakros { PartnerMakros(kcal: kcal, protein: protein, kohlenhydrate: kohlenhydrate, fett: fett) }
}

/// Ein Messwert in Zehnteln (784 = 78,4 kg), `tag` ist `yyyy-MM-dd`.
struct PartnerMesspunkt: Codable, Equatable, Hashable, Sendable {
    var tag: String
    var zehntel: Int
}

struct PartnerEreignis: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var art: PartnerEreignisArt
    var zeit: Date
    var text: String
}

/// Form von `zusammenfassung.json` (Lumen Fit schreibt) und `partner.json` (Lovea schreibt).
struct ZusammenfassungDatei: Codable, Equatable, Sendable {
    var version: Int
    var geschrieben: Date
    var profilName: String
    var freigaben: [FreigabeArt]
    var heute: TagesZusammenfassung
    var ereignisse: [PartnerEreignis]

    enum CodingKeys: String, CodingKey { case version, geschrieben, profilName, freigaben, heute, ereignisse }
}

/// Eine Freigabe-Art, die diese Version nicht kennt (eine neuere App hat sie geschrieben), liest sich als `nil` und fällt weg, statt die ganze Datei zu kippen.
private struct FreigabeArtLesen: Decodable {
    let art: FreigabeArt?

    init(from decoder: Decoder) throws {
        art = FreigabeArt(rawValue: try decoder.singleValueContainer().decode(String.self))
    }
}

extension ZusammenfassungDatei {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        geschrieben = try c.decode(Date.self, forKey: .geschrieben)
        profilName = try c.decode(String.self, forKey: .profilName)
        freigaben = try c.decode([FreigabeArtLesen].self, forKey: .freigaben).compactMap(\.art)
        heute = try c.decode(TagesZusammenfassung.self, forKey: .heute)
        ereignisse = try c.decode([PartnerEreignis].self, forKey: .ereignisse)
    }
}

struct BandWunsch: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var muster: BandMuster
    var zeit: Date
    var von: String
}

struct BandStatusDatei: Codable, Equatable, Sendable {
    var version: Int
    var geschrieben: Date
    var verbunden: Bool
    var akkuProzent: Int?
    var name: String?
    /// Zusatzfelder für Lumen Alarm (alle optional, Lovea ignoriert sie): Bluetooth am iPhone an, Band lädt, wann das Band zuletzt verbunden war,
    /// Vibrationsstärke der Quelle "Wunsch" (1 bis 3) und die Band-Schritte von heute.
    var bluetoothAn: Bool?
    var laedt: Bool?
    var zuletztGesehen: Date?
    var staerke: Int?
    var schritteHeute: Int?

    enum CodingKeys: String, CodingKey { case version, geschrieben, verbunden, akkuProzent, name, bluetoothAn, laedt, zuletztGesehen, staerke, schritteHeute }
}

extension BandStatusDatei {
    /// Tolerant: ein falsch getyptes Zusatzfeld ist nil, die Datei bleibt lesbar.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        geschrieben = try c.decode(Date.self, forKey: .geschrieben)
        verbunden = try c.decode(Bool.self, forKey: .verbunden)
        akkuProzent = (try? c.decodeIfPresent(Int.self, forKey: .akkuProzent)) ?? nil
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil
        bluetoothAn = (try? c.decodeIfPresent(Bool.self, forKey: .bluetoothAn)) ?? nil
        laedt = (try? c.decodeIfPresent(Bool.self, forKey: .laedt)) ?? nil
        zuletztGesehen = (try? c.decodeIfPresent(Date.self, forKey: .zuletztGesehen)) ?? nil
        staerke = (try? c.decodeIfPresent(Int.self, forKey: .staerke)) ?? nil
        schritteHeute = (try? c.decodeIfPresent(Int.self, forKey: .schritteHeute)) ?? nil
    }
}

enum PartnerStand: Equatable, Sendable {
    case nichtVerbunden
    case verbunden(ZusammenfassungDatei)
    case veraltet(ZusammenfassungDatei)
    case unbekannteVersion
}

struct FreundKarte: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var woche: String
    var schritte: Int
    var gymTage: Int
    var schlafSchnittMinuten: Int?
    var erstellt: Date
    var respekt: Bool
}
