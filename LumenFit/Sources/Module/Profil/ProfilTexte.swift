import Foundation

/// Texte der Seiten Datenschutz und Quellen (Idee 78 und 79) und die Liste vor "Alles löschen". Eigene Datei, damit Tests die Pflichtworte prüfen können.
enum ProfilTexte {
    struct Abschnitt: Identifiable, Sendable {
        let titel: String
        let text: String
        var id: String { titel }
    }

    // MARK: - Datenschutz

    static let datenschutz: [Abschnitt] = [
        Abschnitt(titel: "Was gespeichert wird",
                  text: "Auf deinem iPhone: dein Name, die Spur deines Passworts (nie das Passwort selbst), deine Trainings, dein Essenstagebuch, Gewohnheiten, Ziele, Körperdaten und Einstellungen. Der Name und die Passwort-Spur liegen im Schlüsselbund, alles andere in der App."),
        Abschnitt(titel: "Was dein iPhone nie verlässt",
                  text: "Deine Gesundheitsdaten aus Health, deine Trainings, dein Essen, dein Gewicht und deine Gespräche mit dem Coach. Lumen Fit hat keinen Server, kein Konto, keine Werbung und kein Tracking. Es geht nur etwas hinaus, wenn du es selbst teilst: eine Datensicherung, eine Tabelle oder eine Wochenkarte."),
        Abschnitt(titel: "Was ins Netz geht",
                  text: "Nur das Nötige: beim Scannen oder Suchen fragt die App Open Food Facts nach dem Barcode oder deinem Suchtext, und Übungsbilder werden geladen und gemerkt. Dabei gehen nie dein Name, deine Gesundheitsdaten oder dein Training mit."),
        Abschnitt(titel: "Was Lovea sieht",
                  text: "Nichts, solange du die Verbindung nicht einschaltest. Auch dann sieht Lovea nur Zusammenfassungen, die du einzeln freigibst, nie Rohdaten."),
        Abschnitt(titel: "Passwort",
                  text: "Das Passwort schützt nur Handlungen auf diesem iPhone: Profil wechseln, Passwort ändern, Daten löschen. Es gibt keinen Anmeldebildschirm. Wer es vergisst, kann keine Rücksetzung per Mail bekommen, weil es kein Konto gibt. Mit einer Datensicherung kannst du neu anfangen."),
        Abschnitt(titel: "Alles löschen",
                  text: "Löscht dein Profil und alle Daten dieser App auf diesem iPhone, mit deinem Passwort. Daten in Health bleiben unberührt. Eine Datensicherung, die du geteilt hast, bleibt dort, wo du sie abgelegt hast."),
    ]

    // MARK: - Quellen

    struct Quelle: Identifiable, Sendable {
        let name: String
        let lizenz: String
        let text: String
        var id: String { name }
    }

    /// Namensnennung im Wortlaut der Lizenzen.
    static let quellen: [Quelle] = [
        Quelle(name: "Open Food Facts", lizenz: "ODbL",
               text: "Produktdaten von Open Food Facts, lizenziert unter der Open Database License (ODbL). Die Daten stammen von der Gemeinschaft hinter openfoodfacts.org."),
        Quelle(name: "Bundeslebensmittelschlüssel (BLS)", lizenz: "CC BY 4.0",
               text: "Nährwerte der Grundlebensmittel aus dem Bundeslebensmittelschlüssel (BLS), Max Rubner-Institut, lizenziert unter CC BY 4.0. Datenstand: Version 4.0 mit 7.140 Einträgen, in der App gespeichert und offline nutzbar."),
        Quelle(name: "Übungsbilder", lizenz: "nur geladen",
               text: "Die Bilder der Übungen werden bei Bedarf von static.exercisedb.dev geladen und auf deinem iPhone gemerkt. Sie sind nicht Teil der App."),
        Quelle(name: "Apple-Frameworks", lizenz: "Apple",
               text: "Health (HealthKit), Swift Charts, WidgetKit, ActivityKit, VisionKit, CoreBluetooth und Foundation Models von Apple. Gesundheitswerte lesen und schreiben geht nur mit deiner Zustimmung."),
    ]

    // MARK: - Alles löschen

    /// Was vor dem Löschen aufgelistet wird: Zahlen aus den Stores, nichts erfunden.
    struct Loeschzeile: Equatable, Identifiable, Sendable {
        let text: String
        var id: String { text }
    }

    static func loeschliste(einheiten: Int, essenstage: Int, meilensteine: Int, coachNachrichten: Int) -> [Loeschzeile] {
        func zeile(_ n: Int, _ einzahl: String, _ mehrzahl: String) -> Loeschzeile { Loeschzeile(text: "\(n) \(n == 1 ? einzahl : mehrzahl)") }
        return [
            zeile(einheiten, "Training", "Trainings"),
            zeile(essenstage, "Tag im Essenstagebuch", "Tage im Essenstagebuch"),
            zeile(meilensteine, "Meilenstein", "Meilensteine"),
            zeile(coachNachrichten, "Nachricht im Coach-Verlauf", "Nachrichten im Coach-Verlauf"),
            Loeschzeile(text: "Ziele, Körperdaten, Einstellungen und Gewohnheiten"),
        ]
    }
}
