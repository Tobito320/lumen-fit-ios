import Foundation

// Health-Coach, Prüfung (Idee 63, 70): jede Antwort eines Motors wird gegen die Persona-Regeln geprüft, bevor sie im Chat steht.
// Verstößt sie, antwortet stattdessen der Regelmotor (`CoachWahl`). Reine Logik.

enum CoachAntwortPruefung {
    enum Verstoss: String, Equatable, Sendable {
        case leer, zuLang, zuVieleSaetze, zuVieleFragen, satzZuLang
        case sieAnrede, alsKI, diagnose, belehrend, druckAmSchwerenTag, emoji
        /// Frage mit Beschwerden, Antwort ohne Hinweis auf Ärztin oder Arzt.
        case arztFehlt
        /// Daten fehlen, die Antwort fragt nicht nach (sie rät).
        case rueckfrageFehlt
    }

    /// Zerlegt in Sätze: Ende bei `.`, `!` oder `?`, gefolgt von Leerraum oder Textende. Zahlen wie "8.200" und "7,5" trennen nicht.
    static func saetze(_ text: String) -> [String] {
        var ergebnis: [String] = []
        var aktuell = ""
        let zeichen = Array(text)
        for (i, c) in zeichen.enumerated() {
            aktuell.append(c)
            guard c == "." || c == "!" || c == "?" else { continue }
            let danachLeer = i + 1 >= zeichen.count || zeichen[i + 1].isWhitespace
            if danachLeer {
                let satz = aktuell.trimmingCharacters(in: .whitespacesAndNewlines)
                if !satz.isEmpty { ergebnis.append(satz) }
                aktuell = ""
            }
        }
        let rest = aktuell.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { ergebnis.append(rest) }
        return ergebnis
    }

    static func fragen(_ text: String) -> [String] { saetze(text).filter { $0.hasSuffix("?") } }

    /// Alle Verstöße, leer = gut. `frage` und `kontext` bestimmen, ob Arzthinweis und Rückfrage nötig sind.
    static func pruefe(_ text: String, frage: String, kontext: CoachKontext) -> [Verstoss] {
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else { return [.leer] }
        var fehler: [Verstoss] = []
        let klein = sauber.lowercased()
        let alle = saetze(sauber)
        let nurFragen = alle.filter { $0.hasSuffix("?") }
        let aussagen = alle.count - nurFragen.count

        if sauber.count > CoachPersona.maxZeichen { fehler.append(.zuLang) }
        if aussagen > CoachPersona.maxSaetze { fehler.append(.zuVieleSaetze) }
        if nurFragen.count > CoachPersona.maxFragen { fehler.append(.zuVieleFragen) }
        if alle.contains(where: { $0.split(whereSeparator: \.isWhitespace).count > CoachPersona.maxWoerterProSatz }) { fehler.append(.satzZuLang) }
        if hatSieAnrede(sauber) { fehler.append(.sieAnrede) }
        if CoachPersona.alsKI.contains(where: { klein.contains($0) }) { fehler.append(.alsKI) }
        if CoachPersona.diagnosen.contains(where: { klein.contains($0) }) { fehler.append(.diagnose) }
        if CoachPersona.belehrend.contains(where: { klein.contains($0) }) { fehler.append(.belehrend) }
        if CoachPersona.schwererTag(kontext), CoachPersona.druck.contains(where: { klein.contains($0) }) { fehler.append(.druckAmSchwerenTag) }
        if sauber.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) { fehler.append(.emoji) }
        if CoachPersona.istBeschwerde(frage), !klein.contains("ärztin"), !klein.contains("arzt") { fehler.append(.arztFehlt) }
        if !CoachPersona.fehlendeDaten(frage: frage, kontext: kontext).isEmpty, nurFragen.isEmpty { fehler.append(.rueckfrageFehlt) }
        return fehler
    }

    static func ist(_ text: String, frage: String, kontext: CoachKontext) -> Bool {
        pruefe(text, frage: frage, kontext: kontext).isEmpty
    }

    /// "Sie", "Ihnen", "Ihr" und "Ihre" mitten im Satz oder als Anrede. Ein "Sie" am Satzanfang zählt nur mit "Ihnen" oder "Ihr" im Text.
    static func hatSieAnrede(_ text: String) -> Bool {
        let woerter = text.split { !$0.isLetter }.map(String.init)
        for (i, wort) in woerter.enumerated() {
            if ["Ihnen", "Ihr", "Ihre", "Ihren", "Ihrem", "Ihrer", "Ihres"].contains(wort) { return true }
            if wort == "Sie", i > 0 { return true }
        }
        return false
    }
}
