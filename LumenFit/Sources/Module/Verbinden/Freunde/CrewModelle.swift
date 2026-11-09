import Foundation

/// Woran eine Herausforderung oder die Wochen-Rangliste misst. Die Namen sind die des Servers (`art`).
enum CrewMass: String, Codable, CaseIterable, Identifiable, Sendable {
    case tage, saetze, volumen, rekorde, uebung

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .tage: "Gym-Tage"
        case .saetze: "Sätze"
        case .volumen: "Volumen"
        case .rekorde: "Rekorde"
        case .uebung: "Steigerung in einer Übung"
        }
    }

    /// Hinter der Zahl: "4 Tage", "120 Sätze", "8.400 kg", "2 Rekorde", "35 ‰".
    var einheit: String {
        switch self {
        case .tage: "Tage"
        case .saetze: "Sätze"
        case .volumen: "kg"
        case .rekorde: "Rekorde"
        case .uebung: "‰"
        }
    }

    var symbol: String {
        switch self {
        case .tage: "calendar"
        case .saetze: "list.number"
        case .volumen: "scalemass"
        case .rekorde: "medal.fill"
        case .uebung: "chart.line.uptrend.xyaxis"
        }
    }

    /// Die Maße der Wochen-Rangliste (die Übung braucht einen Startwert und gehört nur zu Herausforderungen).
    nonisolated static let rangliste: [CrewMass] = [.tage, .saetze, .volumen, .rekorde]
}

enum CrewModus: String, Codable, Sendable { case gegen, gemeinsam }

/// Feste Zeichen statt Text. Ein unbekanntes Zeichen vom Server fällt beim Lesen weg.
enum CrewReaktionArt: String, Codable, CaseIterable, Sendable {
    case respekt, stark, anfeuern, stups

    var titel: String {
        switch self {
        case .respekt: "Respekt"
        case .stark: "Stark"
        case .anfeuern: "Anfeuern"
        case .stups: "Gym heute?"
        }
    }

    var symbol: String {
        switch self {
        case .respekt: "hand.thumbsup.fill"
        case .stark: "flame.fill"
        case .anfeuern: "megaphone.fill"
        case .stups: "hand.point.right.fill"
        }
    }
}

/// Eine Person in einer Herausforderung. `id` ist die Verbindungs-Id (verbunden) oder eine Teilnehmer-Id, nie eine Konto-Id.
struct CrewTeilnehmer: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var verbunden: Bool
    var ich: Bool
    var name: String
    /// "eingeladen" oder "dabei".
    var status: String
    var wert: Int
    var aktualisiert: Date?

    init(id: String, verbunden: Bool = true, ich: Bool = false, name: String, status: String = "dabei", wert: Int = 0, aktualisiert: Date? = nil) {
        self.id = id; self.verbunden = verbunden; self.ich = ich; self.name = name; self.status = status; self.wert = wert; self.aktualisiert = aktualisiert
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        verbunden = (try? c.decodeIfPresent(Bool.self, forKey: .verbunden)) ?? false
        ich = (try? c.decodeIfPresent(Bool.self, forKey: .ich)) ?? false
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? ""
        wert = (try? c.decodeIfPresent(Int.self, forKey: .wert)) ?? 0
        aktualisiert = (try? c.decodeIfPresent(Date.self, forKey: .aktualisiert)) ?? nil
    }

    var dabei: Bool { status == "dabei" }
}

struct CrewHerausforderung: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var mass: CrewMass
    var modus: CrewModus
    /// Nur gemeinsam: die Summe aller, die erreicht werden soll.
    var ziel: Int?
    /// Nur Maß Übung: der Name der Übung.
    var uebung: String?
    var start: Date
    var ende: Date
    /// "laeuft", "beendet" oder "abgebrochen".
    var status: String
    var ersteller: Bool
    /// Mein Stand: "eingeladen" oder "dabei".
    var ich: String
    var teilnehmer: [CrewTeilnehmer]

    enum CodingKeys: String, CodingKey { case id, mass = "art", modus, ziel, uebung, start, ende, status, ersteller, ich, teilnehmer }

    init(id: String, mass: CrewMass, modus: CrewModus, ziel: Int? = nil, uebung: String? = nil, start: Date, ende: Date, status: String = "laeuft",
         ersteller: Bool = false, ich: String = "dabei", teilnehmer: [CrewTeilnehmer]) {
        self.id = id; self.mass = mass; self.modus = modus; self.ziel = ziel; self.uebung = uebung; self.start = start; self.ende = ende
        self.status = status; self.ersteller = ersteller; self.ich = ich; self.teilnehmer = teilnehmer
    }

    /// Unbekannte Art oder unbekannter Modus: wirft, der Eintrag fällt in `CrewAntwort` weg.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        mass = try c.decode(CrewMass.self, forKey: .mass)
        modus = try c.decode(CrewModus.self, forKey: .modus)
        ziel = (try? c.decodeIfPresent(Int.self, forKey: .ziel)) ?? nil
        uebung = (try? c.decodeIfPresent(String.self, forKey: .uebung)) ?? nil
        start = try c.decode(Date.self, forKey: .start)
        ende = try c.decode(Date.self, forKey: .ende)
        status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "laeuft"
        ersteller = (try? c.decodeIfPresent(Bool.self, forKey: .ersteller)) ?? false
        ich = (try? c.decodeIfPresent(String.self, forKey: .ich)) ?? ""
        teilnehmer = (try? c.decodeIfPresent([CrewLesbar<CrewTeilnehmer>].self, forKey: .teilnehmer))?.compactMap(\.wert) ?? []
    }

    var eingeladen: Bool { ich == "eingeladen" }
    var dabei: Bool { ich == "dabei" }
    var abgebrochen: Bool { status == "abgebrochen" }
    var meine: CrewTeilnehmer? { teilnehmer.first(where: \.ich) }
}

struct CrewReaktion: Codable, Equatable, Identifiable, Sendable {
    var id: String
    /// Verbindungs-Id der Person, die reagiert hat.
    var von: String
    var name: String
    var art: CrewReaktionArt
    var ziel: String
    var text: String
    var zeit: Date

    init(id: String, von: String, name: String, art: CrewReaktionArt, ziel: String, text: String = "", zeit: Date) {
        self.id = id; self.von = von; self.name = name; self.art = art; self.ziel = ziel; self.text = text; self.zeit = zeit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        von = try c.decode(String.self, forKey: .von)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        art = try c.decode(CrewReaktionArt.self, forKey: .art)
        ziel = (try? c.decodeIfPresent(String.self, forKey: .ziel)) ?? ""
        text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? ""
        zeit = try c.decode(Date.self, forKey: .zeit)
    }
}

/// Eine eigene Reaktion der letzten 30 Tage (damit der Knopf weiß, dass er schon gedrückt ist).
struct CrewGesendet: Codable, Equatable, Hashable, Sendable {
    var an: String
    var art: CrewReaktionArt
    var ziel: String
}

/// Die Antwort von `GET /freunde`, auch der Datei-Cache `crew-server.json`. Jeder Eintrag einzeln gelesen: was diese App nicht versteht, fällt weg.
struct CrewAntwort: Codable, Equatable, Sendable {
    var herausforderungen: [CrewHerausforderung]
    var reaktionen: [CrewReaktion]
    var gesendet: [CrewGesendet]

    init(herausforderungen: [CrewHerausforderung] = [], reaktionen: [CrewReaktion] = [], gesendet: [CrewGesendet] = []) {
        self.herausforderungen = herausforderungen; self.reaktionen = reaktionen; self.gesendet = gesendet
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        herausforderungen = (try? c.decodeIfPresent([CrewLesbar<CrewHerausforderung>].self, forKey: .herausforderungen))?.compactMap(\.wert) ?? []
        reaktionen = (try? c.decodeIfPresent([CrewLesbar<CrewReaktion>].self, forKey: .reaktionen))?.compactMap(\.wert) ?? []
        gesendet = (try? c.decodeIfPresent([CrewLesbar<CrewGesendet>].self, forKey: .gesendet))?.compactMap(\.wert) ?? []
    }
}

/// Liest einen Listeneintrag; ein kaputter oder unbekannter wird nil statt die ganze Liste zu kippen.
struct CrewLesbar<Wert: Decodable>: Decodable {
    let wert: Wert?
    init(from decoder: Decoder) throws { wert = try? Wert(from: decoder) }
}
