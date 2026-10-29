// Quelle: Lovea Health/Coach/CoachGedaechtnis.swift
import Foundation
import Observation

// Health-Coach, Gedächtnis: kurze Einträge, die der Coach sich merken darf (Ziele, Verletzungen, Vorlieben) und die die Person selbst pflegt.
// Gespeichert wird im `CoachStore.merkzettel` (Ops `fit.coach.merke`, nur auf diesem Gerät, sichtbar und löschbar). Reine Regeln stehen in
// `CoachGedaechtnisRegeln`. Anders als in Lovea gibt es keine Ids und keinen Server: der Text ist der Schlüssel.
//
// Akku: kein Timer, kein Netz.

/// Reine Regeln ohne Isolation (der Marker-Parser ruft sie auf): Text, Grenzen, Merkwunsch aus einer Frage.
enum CoachGedaechtnisRegeln {
    static let maxEintraege = 40
    static let minLaenge = 3
    static let maxLaenge = 200

    /// Getrimmt, 3 bis 200 Zeichen, ohne `[[`, `]]` und Zeilenumbruch. Sonst `nil`.
    static func sauber(_ roh: String) -> String? {
        let text = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (minLaenge...maxLaenge).contains(text.count), !text.contains("[["), !text.contains("]]"),
              !text.contains(where: \.isNewline) else { return nil }
        return text
    }

    /// Eingabe von Hand: Zeilenumbrüche werden zu Leerzeichen, dann gilt `sauber`.
    static func einzeilig(_ roh: String) -> String? {
        sauber(roh.split(whereSeparator: \.isNewline).joined(separator: " "))
    }

    static func gleich(_ a: String, _ b: String) -> Bool { a.lowercased() == b.lowercased() }

    /// Der Text für einen neuen Eintrag, oder `nil`: ungültig, schon da (Groß/klein egal) oder die 40 sind voll.
    /// Der älteste Eintrag wird nie stillschweigend gelöscht, ein neuer fällt lieber weg.
    static func hinzufuegen(_ roh: String, bestehend: [String]) -> String? {
        guard bestehend.count < maxEintraege, let text = einzeilig(roh), !bestehend.contains(where: { gleich($0, text) }) else { return nil }
        return text
    }

    /// Der neue Text eines Eintrags, oder `nil`: ungültig oder ein anderer Eintrag hat ihn schon.
    static func aendern(_ roh: String, andere: [String]) -> String? {
        guard let text = einzeilig(roh), !andere.contains(where: { gleich($0, text) }) else { return nil }
        return text
    }

    private static let merkAnfaenge = ["bitte merk dir", "merk dir", "merke dir", "vergiss nicht"]
    private static let zielAnfaenge = ["mein ziel ist", "mein ziel:", "mein ziel"]

    /// Was der Coach aus einer Frage von selbst merkt: nur bei klarem Wunsch ("Merk dir, dass ...") oder Ziel ("Mein Ziel ist ...").
    /// Beschwerden und Vermutungen merkt er nie von allein. `nil`, wenn nichts zu merken ist.
    static func merkWunsch(in frage: String) -> String? {
        let text = frage.trimmingCharacters(in: .whitespacesAndNewlines)
        let klein = text.lowercased()
        for anfang in merkAnfaenge where klein.hasPrefix(anfang) {
            var rest = String(text.dropFirst(anfang.count)).trimmingCharacters(in: CharacterSet(charactersIn: " ,:;-").union(.whitespacesAndNewlines))
            if rest.lowercased().hasPrefix("dass ") { rest = String(rest.dropFirst(5)) }
            return einzeilig(rest)
        }
        for anfang in zielAnfaenge where klein.hasPrefix(anfang) {
            let rest = String(text.dropFirst(anfang.count)).trimmingCharacters(in: CharacterSet(charactersIn: " ,:;-").union(.whitespacesAndNewlines))
            guard !rest.isEmpty, let eintrag = einzeilig("Ziel: " + rest) else { return nil }
            return eintrag
        }
        return nil
    }
}

/// Der Merkzettel des Coachs: dünne Schicht über `CoachStore` mit den Regeln. Neueste Einträge zuerst.
@MainActor @Observable
final class CoachGedaechtnis {
    static let maxEintraege = CoachGedaechtnisRegeln.maxEintraege
    static let maxLaenge = CoachGedaechtnisRegeln.maxLaenge

    @ObservationIgnored private let store: CoachStore

    init(store: CoachStore) { self.store = store }

    /// Die Einträge, neueste zuerst.
    var eintraege: [String] { store.merkzettel.reversed() }

    /// Neuer Eintrag, wie er jetzt gespeichert ist. `nil`: ungültiger Text, schon da oder die 40 sind voll.
    @discardableResult
    func hinzufuegen(_ text: String) -> String? {
        guard let sauber = CoachGedaechtnisRegeln.hinzufuegen(text, bestehend: store.merkzettel) else { return nil }
        store.merke(sauber)
        return sauber
    }

    /// Neuer Text für einen Eintrag. Unbekannter Eintrag, ungültiger oder doppelter Text: nichts passiert.
    @discardableResult
    func aendern(_ alt: String, zu neu: String) -> Bool {
        guard store.merkzettel.contains(alt),
              let sauber = CoachGedaechtnisRegeln.aendern(neu, andere: store.merkzettel.filter { $0 != alt }), sauber != alt else { return false }
        store.vergiss(alt)
        store.merke(sauber)
        return true
    }

    func loeschen(_ text: String) { store.vergiss(text) }

    /// Rückgängig nach `loeschen`.
    func wiederherstellen(_ text: String) { _ = hinzufuegen(text) }

    /// Merkt, was die Frage ausdrücklich verlangt (`merkWunsch`). Gibt den gemerkten Text zurück oder `nil`.
    @discardableResult
    func merkeAusFrage(_ frage: String) -> String? {
        guard let wunsch = CoachGedaechtnisRegeln.merkWunsch(in: frage) else { return nil }
        return hinzufuegen(wunsch)
    }
}
