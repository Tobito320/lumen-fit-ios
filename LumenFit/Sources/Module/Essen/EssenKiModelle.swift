// Quelle: Lovea Health/Essen/EssenModelle.swift (EssenAnalyse, EssenKomponente, EssenVersteckt) und Essen/EssenClient.swift (KiFehler)
import Foundation

/// Fehlerarten der Foto-Schätzung. Die Namen sind die Fehlerarten des Servers (`ki-foto.js`).
enum EssenKiFehler: Error, Equatable, Sendable {
    case nichtEingerichtet
    case tageslimit
    case guthaben
    case zuVieleAnfragen
    case bildZuGross
    case netz
    case ungueltig
    case unbekannt
}

/// Eine erkannte Zutat zum Bearbeiten. Die Nährwerte stehen pro 100 g, damit sich beim Ändern der Gramm alles ohne neuen Aufruf neu rechnet.
struct EssenKiKomponente: Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var gramm: Double
    var kcalPro100: Double
    var proteinPro100: Double
    var kohlenhydratePro100: Double
    var fettPro100: Double
    /// "hoch", "mittel" oder "niedrig" (wie sicher sich die KI bei dieser Zutat ist).
    var sicherheit: String

    var kcal: Int { Int((gramm * kcalPro100 / 100).rounded()) }
}

/// Nicht Sichtbares, aber sehr wahrscheinlich Enthaltenes (Bratöl, Soße, Dressing).
struct EssenKiVersteckt: Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var gramm: Double
    var kcal: Int
}

/// Antwort von `POST /ki/foto`. Gespeichert wird sie im Auftrag; fehlt in einer alten Datei ein Feld, gilt ein Standardwert.
struct EssenKiAnalyse: Codable, Equatable, Sendable {
    struct Komponente: Codable, Equatable, Sendable {
        var name: String
        var gramm: Double
        var kcalPro100: Double
        var proteinPro100: Double
        var kohlenhydratePro100: Double
        var fettPro100: Double
        var sicherheit: String

        enum CodingKeys: String, CodingKey {
            case name, gramm, sicherheit
            case kcalPro100 = "kcal_pro_100g"
            case proteinPro100 = "protein_pro_100g"
            case kohlenhydratePro100 = "kohlenhydrate_pro_100g"
            case fettPro100 = "fett_pro_100g"
        }

        init(name: String, gramm: Double, kcalPro100: Double, proteinPro100: Double, kohlenhydratePro100: Double, fettPro100: Double, sicherheit: String) {
            self.name = name
            self.gramm = gramm
            self.kcalPro100 = kcalPro100
            self.proteinPro100 = proteinPro100
            self.kohlenhydratePro100 = kohlenhydratePro100
            self.fettPro100 = fettPro100
            self.sicherheit = sicherheit
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            gramm = try c.decodeIfPresent(Double.self, forKey: .gramm) ?? 0
            kcalPro100 = try c.decodeIfPresent(Double.self, forKey: .kcalPro100) ?? 0
            proteinPro100 = try c.decodeIfPresent(Double.self, forKey: .proteinPro100) ?? 0
            kohlenhydratePro100 = try c.decodeIfPresent(Double.self, forKey: .kohlenhydratePro100) ?? 0
            fettPro100 = try c.decodeIfPresent(Double.self, forKey: .fettPro100) ?? 0
            sicherheit = try c.decodeIfPresent(String.self, forKey: .sicherheit) ?? "mittel"
        }
    }

    struct Versteckt: Codable, Equatable, Sendable {
        var name: String
        var gramm: Double
        var kcal: Int
    }

    struct Gesamt: Codable, Equatable, Sendable {
        var kcal: Int
        var kcalMin: Int
        var kcalMax: Int

        enum CodingKeys: String, CodingKey {
            case kcal
            case kcalMin = "kcal_min"
            case kcalMax = "kcal_max"
        }

        init(kcal: Int, kcalMin: Int, kcalMax: Int) {
            self.kcal = kcal
            self.kcalMin = kcalMin
            self.kcalMax = kcalMax
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kcal = try c.decodeIfPresent(Int.self, forKey: .kcal) ?? 0
            kcalMin = try c.decodeIfPresent(Int.self, forKey: .kcalMin) ?? 0
            kcalMax = try c.decodeIfPresent(Int.self, forKey: .kcalMax) ?? 0
        }
    }

    var istEssen: Bool
    var items: [Komponente]
    var versteckt: [Versteckt]
    var gesamt: Gesamt
    var frage: String?
    var bemerkung: String
    /// Fotos, die heute noch übrig sind (der Server zählt mit).
    var rest: Int?

    enum CodingKeys: String, CodingKey {
        case items, versteckt, gesamt, frage, bemerkung, rest
        case istEssen = "ist_essen"
    }

    init(istEssen: Bool, items: [Komponente], versteckt: [Versteckt] = [], gesamt: Gesamt, frage: String? = nil, bemerkung: String = "", rest: Int? = nil) {
        self.istEssen = istEssen
        self.items = items
        self.versteckt = versteckt
        self.gesamt = gesamt
        self.frage = frage
        self.bemerkung = bemerkung
        self.rest = rest
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        istEssen = try c.decodeIfPresent(Bool.self, forKey: .istEssen) ?? false
        items = try c.decodeIfPresent([Komponente].self, forKey: .items) ?? []
        versteckt = try c.decodeIfPresent([Versteckt].self, forKey: .versteckt) ?? []
        gesamt = try c.decodeIfPresent(Gesamt.self, forKey: .gesamt) ?? Gesamt(kcal: 0, kcalMin: 0, kcalMax: 0)
        frage = try c.decodeIfPresent(String.self, forKey: .frage)
        bemerkung = try c.decodeIfPresent(String.self, forKey: .bemerkung) ?? ""
        rest = try c.decodeIfPresent(Int.self, forKey: .rest)
    }

    var komponenten: [EssenKiKomponente] {
        items.map {
            EssenKiKomponente(name: $0.name, gramm: $0.gramm, kcalPro100: $0.kcalPro100, proteinPro100: $0.proteinPro100,
                              kohlenhydratePro100: $0.kohlenhydratePro100, fettPro100: $0.fettPro100, sicherheit: $0.sicherheit)
        }
    }

    var versteckteListe: [EssenKiVersteckt] {
        versteckt.map { EssenKiVersteckt(name: $0.name, gramm: $0.gramm, kcal: $0.kcal) }
    }
}
