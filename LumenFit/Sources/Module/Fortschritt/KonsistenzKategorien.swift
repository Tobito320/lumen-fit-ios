// Quelle: Lovea Health/Verlauf/KonsistenzKategorien.swift
import Foundation

/// Eigene Kategorien für das Konsistenz-Raster: Name + Farbe, je Profil.
/// Ein Plantag gehört zu höchstens einer Kategorie; ohne eigene Wahl entscheidet sein Name.
struct KonsistenzKategorie: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    /// "RRGGBB"
    var farbe: String
}

struct KonsistenzEinstellung: Codable, Equatable, Sendable {
    var kategorien: [KonsistenzKategorie]
    /// Plantag-id -> Kategorie-id; "" = bewusst keine Kategorie. Fehlt der Plantag, gilt die Vorbelegung nach Name.
    var zuordnung: [String: String] = [:]

    static let standard = KonsistenzEinstellung(kategorien: KonsistenzKategorienLogik.standardKategorien)
}

/// Was eine Zelle zeigt: neutral (Training ohne Kategorie), eine Kategorie oder zwei (geteilte Zelle).
enum KonsistenzFuellung: Equatable, Sendable {
    case neutral
    case eine(String)
    case zwei(String, String)
}

/// Rein: Kategorie je Plantag, Füllung je Tag. Die Karte zeichnet nur.
enum KonsistenzKategorienLogik {
    static let schluessel = "konsistenz.kategorien"

    static let standardKategorien: [KonsistenzKategorie] = [
        KonsistenzKategorie(id: "unterkoerper", name: "Unterkörper", farbe: "34C3A0"),
        KonsistenzKategorie(id: "oberkoerper", name: "Oberkörper", farbe: "F0609E"),
        KonsistenzKategorie(id: "ruecken", name: "Rücken", farbe: "5B8DEF"),
        KonsistenzKategorie(id: "brust", name: "Brust", farbe: "F5A524"),
        KonsistenzKategorie(id: "cardio", name: "Cardio", farbe: "A66CFF"),
    ]

    /// Farben für neue Kategorien, der Reihe nach.
    static let palette = ["34C3A0", "F0609E", "5B8DEF", "F5A524", "A66CFF", "4CC9F0", "EF6F5B", "9BD14B"]

    /// Stichwörter im Plantag-Namen (klein, ohne Umlaut) -> Standard-Kategorie. Reihenfolge zählt: "Upper Body" ist Oberkörper, nicht Rücken.
    private static let stichwoerter: [(kategorie: String, woerter: [String])] = [
        ("unterkoerper", ["unterk", "legs", "leg ", "bein", "lower", "quad"]),
        ("oberkoerper", ["oberk", "upper"]),
        ("ruecken", ["ruecken", "rücken", "back", "pull"]),
        ("brust", ["brust", "chest", "push"]),
        ("cardio", ["cardio", "lauf", "run", "ausdauer", "hiit"]),
    ]

    /// Vorbelegung aus dem Plantag-Namen; nil, wenn nichts passt oder die Kategorie gelöscht ist.
    static func vorbelegt(name: String?, in kategorien: [KonsistenzKategorie]) -> String? {
        guard let name else { return nil }
        let text = name.lowercased() + " "
        for eintrag in stichwoerter where eintrag.woerter.contains(where: { text.contains($0) }) {
            return kategorien.contains { $0.id == eintrag.kategorie } ? eintrag.kategorie : nil
        }
        return nil
    }

    /// Kategorie eines Plantags: eigene Wahl (auch "keine") vor Vorbelegung. Eine gelöschte Kategorie zählt als keine.
    static func kategorie(tagId: String?, name: String?, einstellung e: KonsistenzEinstellung) -> String? {
        if let tagId, let wahl = e.zuordnung[tagId] {
            return e.kategorien.contains { $0.id == wahl } ? wahl : nil
        }
        return vorbelegt(name: name, in: e.kategorien)
    }

    /// Füllung je Tag (`yyyy-MM-dd`): Kategorien der Einheiten in Startreihenfolge, doppelte weg, mehr als zwei zeigen die ersten zwei.
    static func fuellungen(_ sessions: [GymSession], einstellung e: KonsistenzEinstellung, tagName: (String?) -> String?) -> [String: KonsistenzFuellung] {
        var je: [String: [String]] = [:]
        for s in sessions.sorted(by: { $0.start < $1.start }) {
            let tag = Datum.text(s.start)
            var liste = je[tag, default: []]
            if let k = kategorie(tagId: s.tag, name: tagName(s.tag), einstellung: e), !liste.contains(k) { liste.append(k) }
            je[tag] = liste
        }
        return je.mapValues { liste in
            switch liste.count {
            case 0: .neutral
            case 1: .eine(liste[0])
            default: .zwei(liste[0], liste[1])
            }
        }
    }

    /// Neue Kategorie mit der nächsten freien Palettenfarbe.
    static func neu(in e: KonsistenzEinstellung, name: String = "Neu") -> KonsistenzKategorie {
        let benutzt = Set(e.kategorien.map(\.farbe))
        let farbe = palette.first { !benutzt.contains($0) } ?? palette[e.kategorien.count % palette.count]
        return KonsistenzKategorie(id: UUID().uuidString, name: name, farbe: farbe)
    }

    // MARK: - Speichern (JSON-Text in `einstellung.setzen`, je Profil)

    static func lesen(_ text: String) -> KonsistenzEinstellung {
        guard !text.isEmpty, let e = try? JSONDecoder().decode(KonsistenzEinstellung.self, from: Data(text.utf8)) else { return .standard }
        return e
    }

    static func text(_ e: KonsistenzEinstellung) -> String {
        guard let daten = try? JSONEncoder().encode(e) else { return "" }
        return String(decoding: daten, as: UTF8.self)
    }
}
