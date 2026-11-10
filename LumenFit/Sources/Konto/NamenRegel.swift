import Foundation

/// Die eine Regel für Profilnamen (Vorgabe 29.10.): getrimmt, 2 bis 20 Zeichen, nur Buchstaben (auch Umlaute), Leerzeichen, Bindestrich und Apostroph;
/// Anfang und Ende sind Buchstaben, zwei Trennzeichen stehen nie nebeneinander. Keine Ziffern, Sonderzeichen oder Emojis. Mehrere Leerzeichen werden eines.
/// Sie gilt für neue Eingaben (Anlegen, Ändern); ein schon gespeicherter Name wird nie nachträglich geprüft, damit kein Profil unlesbar wird.
/// Dazu die Sperre: der Name lässt sich erst nach `nameAendernTage` Tagen wieder ändern (Server-Einstellung).
enum NamenRegel {
    nonisolated static let minLaenge = 2
    nonisolated static let maxLaenge = 20

    enum Fehler: Error, Equatable, Sendable { case leer, zuKurz, zuLang, zeichen }

    /// Der saubere Name oder der Grund. Länge zählt Zeichen wie die Person sie sieht (nicht Bytes).
    static func pruefe(_ roh: String) -> Result<String, Fehler> {
        let sauber = roh.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").joined(separator: " ")
        guard !sauber.isEmpty else { return .failure(.leer) }
        let zeichen = Array(sauber)
        guard zeichen.allSatisfy(erlaubt), zeichen.first?.isLetter == true, zeichen.last?.isLetter == true else { return .failure(.zeichen) }
        for i in zeichen.indices.dropFirst() where !zeichen[i].isLetter && !zeichen[i - 1].isLetter { return .failure(.zeichen) }
        guard zeichen.count >= minLaenge else { return .failure(.zuKurz) }
        guard zeichen.count <= maxLaenge else { return .failure(.zuLang) }
        return .success(sauber)
    }

    private static func erlaubt(_ z: Character) -> Bool { z.isLetter || z == " " || z == "-" || z == "'" || z == "\u{2019}" }

    static func text(_ fehler: Fehler) -> String {
        switch fehler {
        case .leer: String(localized: "Wie soll Lumi dich nennen?")
        case .zuKurz: String(localized: "Der Name braucht mindestens \(minLaenge) Buchstaben.")
        case .zuLang: String(localized: "Der Name darf höchstens \(maxLaenge) Zeichen lang sein.")
        case .zeichen: String(localized: "Erlaubt sind Buchstaben, Leerzeichen, Bindestrich und Apostroph. Keine Ziffern, Sonderzeichen oder Emojis.")
        }
    }

    /// Ab diesem Tag (0 Uhr) ist die nächste Änderung erlaubt; nil, wenn sie jetzt erlaubt ist.
    /// Ein Datum in der Zukunft (verstellte Uhr) zählt nicht, sonst bliebe der Name jahrelang gesperrt.
    // shortcut: die Sperre rechnet mit der Geräteuhr und lässt sich damit umgehen; der Name ist nur Anzeige, Ausbau wäre ein Zähler am Server.
    static func freiAb(letzteAenderung: Date?, tage: Int, jetzt: Date, kalender: Calendar = .current) -> Date? {
        guard tage > 0, let letzte = letzteAenderung, letzte <= jetzt,
              let spaeter = kalender.date(byAdding: .day, value: tage, to: letzte) else { return nil }
        let frei = kalender.startOfDay(for: spaeter)
        return frei > jetzt ? frei : nil
    }
}
