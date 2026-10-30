// Quelle: Lovea Zyklus/ZyklusModell.swift
import Foundation

enum ZyklusBlutung: String, Codable, CaseIterable, Hashable, Sendable {
    case schmierblutung, leicht, mittel, stark
}

enum ZyklusSymptom: String, Codable, CaseIterable, Hashable, Sendable {
    case kopfschmerzen, kraempfe, rueckenschmerzen, brustspannen, uebelkeit
    case blaehbauch, akne, muedigkeit, heisshunger, schwindel, verstopfung, durchfall
}

enum ZyklusStimmung: String, Codable, CaseIterable, Hashable, Sendable {
    case froehlich, ruhig, energiegeladen, empfindlich, gereizt, traurig, aengstlich, gestresst
}

enum ZyklusAusfluss: String, Codable, CaseIterable, Hashable, Sendable {
    case keiner, klebrig, cremig, waessrig, eiweissartig
}

enum ZyklusTest: String, Codable, CaseIterable, Hashable, Sendable {
    case negativ, positiv
}

enum ZyklusSex: String, Codable, CaseIterable, Hashable, Sendable {
    case geschuetzt, ungeschuetzt
}

enum ZyklusModus: String, Codable, CaseIterable, Hashable, Sendable {
    case zyklus, schwanger, kinderwunsch, pille
}

enum ZyklusPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case periode, follikel, fruchtbar, eisprung, luteal
}

/// Ein Tag im Zyklus-Tagebuch. `id` ist das Datum als `yyyy-MM-dd` (siehe `Datum.kalender`).
struct ZyklusTag: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var blutung: ZyklusBlutung?
    var symptome: Set<ZyklusSymptom>
    var stimmung: Set<ZyklusStimmung>
    var ausfluss: ZyklusAusfluss?
    var temperatur: Double?
    var eisprungTest: ZyklusTest?
    var schwangerschaftsTest: ZyklusTest?
    var sex: ZyklusSex?
    var pille: Bool?
    var wasserMl: Int?
    var schlafMin: Int?
    var gewicht: Double?
    var notiz: String?

    init(id: String,
         blutung: ZyklusBlutung? = nil,
         symptome: Set<ZyklusSymptom> = [],
         stimmung: Set<ZyklusStimmung> = [],
         ausfluss: ZyklusAusfluss? = nil,
         temperatur: Double? = nil,
         eisprungTest: ZyklusTest? = nil,
         schwangerschaftsTest: ZyklusTest? = nil,
         sex: ZyklusSex? = nil,
         pille: Bool? = nil,
         wasserMl: Int? = nil,
         schlafMin: Int? = nil,
         gewicht: Double? = nil,
         notiz: String? = nil) {
        self.id = id
        self.blutung = blutung
        self.symptome = symptome
        self.stimmung = stimmung
        self.ausfluss = ausfluss
        self.temperatur = temperatur
        self.eisprungTest = eisprungTest
        self.schwangerschaftsTest = schwangerschaftsTest
        self.sex = sex
        self.pille = pille
        self.wasserMl = wasserMl
        self.schlafMin = schlafMin
        self.gewicht = gewicht
        self.notiz = notiz
    }

    /// Nichts eingetragen: der Speicher darf den Tag dann entfernen.
    var istLeer: Bool {
        blutung == nil && symptome.isEmpty && stimmung.isEmpty && ausfluss == nil
            && temperatur == nil && eisprungTest == nil && schwangerschaftsTest == nil
            && sex == nil && pille == nil && wasserMl == nil && schlafMin == nil
            && gewicht == nil && (notiz ?? "").isEmpty
    }
}

struct ZyklusEinstellung: Codable, Hashable, Sendable {
    var zyklusLaenge: Int = 28
    var periodenLaenge: Int = 5
    var modus: ZyklusModus = .zyklus
}

/// Nachsichtig lesen: fehlende Felder sind leer, unbekannte Auswahlwerte aus einer neueren Version werden übersprungen (eine alte Datei bleibt lesbar).
extension ZyklusTag {
    private enum CodingKeys: String, CodingKey {
        case id, blutung, symptome, stimmung, ausfluss, temperatur, eisprungTest, schwangerschaftsTest, sex, pille, wasserMl, schlafMin, gewicht, notiz
    }

    private static func auswahl<W: RawRepresentable>(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys, _ typ: W.Type) -> W? where W.RawValue == String {
        (try? c.decodeIfPresent(String.self, forKey: k)).flatMap { $0 }.flatMap(W.init(rawValue:))
    }

    private static func menge<W: RawRepresentable & Hashable>(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys, _ typ: W.Type) -> Set<W> where W.RawValue == String {
        let roh = (try? c.decodeIfPresent([String].self, forKey: k)) ?? nil
        return Set((roh ?? []).compactMap(W.init(rawValue:)))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id),
                  blutung: Self.auswahl(c, .blutung, ZyklusBlutung.self),
                  symptome: Self.menge(c, .symptome, ZyklusSymptom.self),
                  stimmung: Self.menge(c, .stimmung, ZyklusStimmung.self),
                  ausfluss: Self.auswahl(c, .ausfluss, ZyklusAusfluss.self),
                  temperatur: try c.decodeIfPresent(Double.self, forKey: .temperatur),
                  eisprungTest: Self.auswahl(c, .eisprungTest, ZyklusTest.self),
                  schwangerschaftsTest: Self.auswahl(c, .schwangerschaftsTest, ZyklusTest.self),
                  sex: Self.auswahl(c, .sex, ZyklusSex.self),
                  pille: try c.decodeIfPresent(Bool.self, forKey: .pille),
                  wasserMl: try c.decodeIfPresent(Int.self, forKey: .wasserMl),
                  schlafMin: try c.decodeIfPresent(Int.self, forKey: .schlafMin),
                  gewicht: try c.decodeIfPresent(Double.self, forKey: .gewicht),
                  notiz: try c.decodeIfPresent(String.self, forKey: .notiz))
    }
}

extension ZyklusEinstellung {
    private enum CodingKeys: String, CodingKey { case zyklusLaenge, periodenLaenge, modus }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(zyklusLaenge: try c.decodeIfPresent(Int.self, forKey: .zyklusLaenge) ?? 28,
                  periodenLaenge: try c.decodeIfPresent(Int.self, forKey: .periodenLaenge) ?? 5,
                  modus: (try? c.decodeIfPresent(String.self, forKey: .modus)).flatMap { $0 }.flatMap(ZyklusModus.init(rawValue:)) ?? .zyklus)
    }
}
