// Quelle: Lovea Health/Coach/CoachLokal.swift
import Foundation

// Health-Coach, nur auf diesem Gerät: stabile Schlüssel, kleine Merklisten (Haken, Daumen, Gemerktes), Suche, Export
// und die Schnellfragen je nach Tageszeit. Reine Logik, nichts hier liest Modelle oder die Uhr.

enum CoachLokal {
    // MARK: - Schlüssel

    /// FNV-1a (64 Bit) über die UTF-8-Bytes, als Hex. `hashValue` ist je Start anders, dieser Wert bleibt gleich.
    static func stabilerHash(_ text: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return String(h, radix: 16)
    }

    /// Schlüssel für eine Nachricht: der Text ohne Rand. Er bleibt gleich, wenn aus dem lokalen Eintrag die Op vom
    /// Server wird (die Id wechselt dabei, der Text nicht).
    static func schluessel(_ text: String) -> String {
        stabilerHash(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Merklisten

    /// `eintrag` kommt ans Ende (an) oder fliegt raus (aus). Zu lange Listen verlieren die ältesten Einträge.
    static func setzen(_ liste: [String], _ eintrag: String, an: Bool, maximal: Int) -> [String] {
        var neu = liste.filter { $0 != eintrag }
        if an { neu.append(eintrag) }
        return Array(neu.suffix(max(maximal, 0)))
    }

    // MARK: - Fortschritt

    /// Anteil von `aktuell` an `ziel`, begrenzt auf 0 bis 1. Ohne gültiges Ziel 0.
    static func anteil(aktuell: Double, ziel: Double) -> Double {
        guard ziel > 0, aktuell.isFinite else { return 0 }
        return min(max(aktuell / ziel, 0), 1)
    }

    // MARK: - Warten

    /// Die Tippanzeige steht höchstens so lange (Sekunden); danach antwortet der Regelcoach (`CoachModell`).
    static let denkGrenze: TimeInterval = 15

    /// Zeile unter "Coach denkt nach": erst nichts, bei langer Wartezeit ein Hinweis. Die Antwort geht beim Tab-Wechsel nicht
    /// verloren, `CoachModell` hält die Anfrage.
    static func denkHinweis(sekunden: TimeInterval) -> String? {
        switch sekunden {
        case ..<8: nil
        case ..<denkGrenze: "Das dauert etwas länger. Du kannst den Tab wechseln, die Antwort bleibt hier."
        default: "Das dauert länger als sonst. Gleich antworte ich mit dem, was ich sicher weiß."
        }
    }

    // MARK: - Schnellfragen

    static let wochenrueckblick = "Mach meinen Wochenrückblick"
    static let luecken = "Was habe ich heute noch nicht eingetragen?"
    /// Idee 68: morgens fragt man nach dem Gefühl, abends nach dem Rest des Essens.
    static let gefuehl = "Wie fühle ich mich?"
    static let nochEssen = "Was esse ich noch?"

    /// Welche Fragen heute schon gestellt wurden (getrimmter Text der eigenen Nachrichten von heute).
    static func heuteGefragt(_ liste: [CoachNachricht], jetzt: Date, kalender: Calendar) -> Set<String> {
        var gefragt: Set<String> = []
        for nachricht in liste where nachricht.rolle == .nutzer && kalender.isDate(nachricht.zeit, inSameDayAs: jetzt) {
            gefragt.insert(nachricht.text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return gefragt
    }

    /// Die Schnellfragen stehen nur, solange die Person heute (Kalender, bei uns Berliner Zeit) noch nichts geschrieben
    /// hat. Ab ihrer ersten Nachricht des Tages sind sie weg, am nächsten Tag kommen sie zurück. Antworten des Coachs
    /// zählen nicht, sonst wäre der Morgengruß schon der Grund, sie zu verstecken.
    static func schnellfragenSichtbar(_ liste: [CoachNachricht], jetzt: Date, kalender: Calendar) -> Bool {
        !liste.contains { $0.rolle == .nutzer && kalender.isDate($0.zeit, inSameDayAs: jetzt) }
    }

    /// Höchstens vier Fragen: je nach Tageszeit andere Reihenfolge, am Sonntag und Montag zuerst der Wochenrückblick,
    /// abends die Frage nach Lücken im Tag. Was heute schon gefragt wurde, fällt weg, solange noch etwas übrig bleibt.
    /// `wochentag` wie bei `Calendar`: 1 = Sonntag, 2 = Montag.
    static func schnellfragen(stunde: Int, wochentag: Int, schonGefragt: Set<String>) -> [String] {
        var basis: [String]
        switch CoachText.tageszeit(stunde: stunde) {
        case .morgen: basis = [gefuehl, "Was soll ich heute essen?", "Wie läuft mein Training?", "Tagesbericht"]
        case .tag: basis = ["Tagesbericht", "Was soll ich heute essen?", "Wie läuft mein Training?"]
        case .abend: basis = [nochEssen, "Tagesbericht", luecken, "Wie läuft mein Training?"]
        case .nacht: basis = CoachRegeln.schnellfragen
        }
        if wochentag == 1 || wochentag == 2 { basis.insert(wochenrueckblick, at: 0) }
        let neu = basis.filter { !schonGefragt.contains($0) }
        return Array((neu.isEmpty ? basis : neu).prefix(4))
    }

    // MARK: - Name

    static let standardName = "Coach"
    static let maxNameZeichen = 24

    /// Der eigene Name wie ihn der Server nimmt: eine Zeile, nie `[[` oder `]]` (könnte einen Marker fälschen), keine
    /// Anführungszeichen, höchstens 24 Zeichen. Dieselbe Regel wie `nameBereinigen` in server/coach.js.
    static func nameBereinigen(_ text: String) -> String {
        var t = text
        while t.contains("[[") || t.contains("]]") {
            t = t.replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")
        }
        let ohneAnfuehrung = String(t.filter { !"\"„“”".contains($0) })
        let eineZeile = ohneAnfuehrung.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(eineZeile.prefix(maxNameZeichen)).trimmingCharacters(in: .whitespaces)
    }

    /// Was in Kopfzeile und über den Blasen steht: der eigene Name, leer = "Coach".
    static func anzeigeName(_ gespeichert: String) -> String {
        let sauber = nameBereinigen(gespeichert)
        return sauber.isEmpty ? standardName : sauber
    }

    // MARK: - Suche und Sprung

    /// Nachrichten, deren Text (ohne Marker) den Begriff enthält, ohne Rücksicht auf Groß-/Kleinschreibung und Akzente.
    static func suche(_ liste: [CoachNachricht], begriff: String) -> [CoachNachricht] {
        let gesucht = begriff.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gesucht.isEmpty else { return [] }
        return liste.filter { nachricht in
            CoachMarker.zerlegen(nachricht.text).text.range(of: gesucht, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    struct Tag: Equatable {
        let id: String
        let zeit: Date
    }

    /// Die erste Nachricht jedes Tages, neueste zuerst, höchstens `maximal`. `liste` ist nach Zeit sortiert.
    static func tage(_ liste: [CoachNachricht], kalender: Calendar, maximal: Int = 10) -> [Tag] {
        var ergebnis: [Tag] = []
        var letzte: Date?
        for nachricht in liste {
            if let letzte, kalender.isDate(letzte, inSameDayAs: nachricht.zeit) { continue }
            ergebnis.append(Tag(id: nachricht.id, zeit: nachricht.zeit))
            letzte = nachricht.zeit
        }
        return Array(ergebnis.reversed().prefix(maximal))
    }

    // MARK: - Export

    /// Der Verlauf als Text: je Nachricht `[Zeit] Name: Text`, getrennt durch eine Leerzeile. Marker fallen weg.
    static func export(_ liste: [CoachNachricht], ich: String, coach: String = standardName, zeit: (Date) -> String) -> String {
        liste.map { nachricht -> String in
            let text = nachricht.rolle == .nutzer
                ? nachricht.text.trimmingCharacters(in: .whitespacesAndNewlines)
                : CoachMarker.zerlegen(nachricht.text).text
            return "[\(zeit(nachricht.zeit))] \(nachricht.rolle == .nutzer ? ich : coach): \(text)"
        }.joined(separator: "\n\n")
    }
}
