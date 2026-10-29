import Foundation

// Daumen und Merkliste (Idee 69): Antworten bewerten; der Coach lernt daraus Länge und Ton. Gelernt wird nur aus dem sichtbaren Verlauf
// (Daumen hoch oder runter an einer Antwort), lokal, ohne Profil im Hintergrund. Reine Logik.

enum CoachLernen {
    /// Was der Verlauf über die Vorliebe der Person sagt.
    struct Stil: Equatable, Sendable {
        /// Daumen runter bei langen Antworten: kürzer antworten.
        var kuerzer = false
        /// Daumen runter bei Ausrufezeichen: nüchterner schreiben.
        var nuechtern = false

        var istLeer: Bool { !kuerzer && !nuechtern }

        /// Ein Satz fürs Modell, leer ohne Vorliebe.
        var hinweis: String {
            var teile: [String] = []
            if kuerzer { teile.append("Antworte noch kürzer, höchstens zwei Sätze.") }
            if nuechtern { teile.append("Schreibe nüchterner, ohne Ausrufezeichen.") }
            return teile.joined(separator: " ")
        }
    }

    /// Wie viele bewertete Antworten zählen (die jüngsten).
    static let fenster = 20

    static func stil(_ verlauf: [CoachNachricht]) -> Stil {
        let bewertet = verlauf.filter { $0.rolle == .coach && $0.daumen != nil }.suffix(fenster)
        let mag = bewertet.filter { $0.daumen == true }
        let magNicht = bewertet.filter { $0.daumen == false }
        guard !magNicht.isEmpty else { return Stil() }
        func woerter(_ liste: [CoachNachricht]) -> Double {
            guard !liste.isEmpty else { return 0 }
            return Double(liste.reduce(0) { $0 + CoachText.woerter($1.text) }) / Double(liste.count)
        }
        func ausrufe(_ liste: [CoachNachricht]) -> Double {
            guard !liste.isEmpty else { return 0 }
            return Double(liste.filter { $0.text.contains("!") }.count) / Double(liste.count)
        }
        var stil = Stil()
        stil.kuerzer = mag.isEmpty || woerter(magNicht) > woerter(mag)
        stil.nuechtern = ausrufe(magNicht) > ausrufe(mag)
        return stil
    }

    /// Kürzt eine Antwort auf höchstens zwei Aussagen plus die Frage. Nie, wenn der Text den Hinweis auf Ärztin oder Arzt trägt;
    /// `behalte` (der verständnisvolle Satz eines schweren Tages) fällt nie weg.
    static func kuerzen(_ text: String, behalte: String? = nil) -> String {
        let klein = text.lowercased()
        guard !klein.contains("ärztin"), !klein.contains("arzt") else { return text }
        let alle = CoachAntwortPruefung.saetze(text)
        let aussagen = alle.filter { !$0.hasSuffix("?") }
        guard aussagen.count > 2 else { return text }
        let rest = alle.filter { $0.hasSuffix("?") }
        var behalten = Array(aussagen.prefix(2))
        if let behalte, aussagen.contains(behalte), !behalten.contains(behalte) { behalten = [aussagen[0], behalte] }
        return (behalten + rest.prefix(1)).joined(separator: " ")
    }

    /// Ohne Ausrufezeichen (zu "nüchterner").
    static func nuechtern(_ text: String) -> String { text.replacingOccurrences(of: "!", with: ".") }
}
