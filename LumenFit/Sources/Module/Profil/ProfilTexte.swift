import Foundation

/// Texte der Seiten Datenschutz und Quellen (Idee 78 und 79) und die Liste vor "Alles löschen". Eigene Datei, damit Tests die Pflichtworte prüfen können.
enum ProfilTexte {
    struct Abschnitt: Identifiable, Sendable {
        let titel: String
        let text: String
        var id: String { titel }
    }

    // MARK: - Datenschutz

    static func datenschutz() -> [Abschnitt] { [
        Abschnitt(titel: String(localized: "Was gespeichert wird"),
                  text: String(localized: "Auf deinem iPhone: dein Name, die Spur deines Passworts (nie das Passwort selbst), deine Trainings, dein Essenstagebuch, Gewohnheiten, Ziele, Körperdaten und Einstellungen. Der Name und die Passwort-Spur liegen im Schlüsselbund, alles andere in der App.")),
        Abschnitt(titel: String(localized: "Was dein iPhone nie verlässt"),
                  text: String(localized: "Deine Gesundheitsdaten aus Health, deine Trainings, dein Essen, dein Gewicht. Lumen Fit hat keinen Server für deine Daten, kein Konto mit Anmeldung, keine Werbung und kein Tracking. Es geht nur etwas hinaus, wenn du es selbst teilst: eine Datensicherung, eine Tabelle, eine Wochenkarte, die Zusammenfassung, die du deinem Partner einzeln freigibst, oder ein Essensfoto für die Schätzung, wenn du ihr zugestimmt hast.")),
        Abschnitt(titel: String(localized: "Was ins Netz geht"),
                  text: String(localized: "Nur das Nötige: beim Scannen oder Suchen fragt die App Open Food Facts nach dem Barcode oder deinem Suchtext, und Übungsbilder werden geladen und gemerkt. Beim Eintragen deines Studios geht dein Suchtext an Apple Karten, dazu deine ungefähre Position, wenn du den Standort erlaubst (nur während der Suche, ohne Erlaubnis suchst du ohne Entfernung). Gespeichert wird nur der Name des Studios, nie ein Standort. Dabei gehen nie dein Name, deine Gesundheitsdaten oder dein Training mit.")),
        Abschnitt(titel: String(localized: "Was an den Lumen-Server geht"),
                  text: String(localized: "Eine zufällige Kennung dieses iPhones, dein Profilname und die App-Version. Daran erkennt der Server dein Gerät, damit Einstellungen wie die Namensregel ohne Update geändert werden können. Nur wenn du Ja sagst, kommt eine Nutzungsmeldung dazu. Sie besteht aus kleinen Zählern und festen Namen, hängt an deinem Konto und ist deshalb nicht anonym. Sie zeigt, welchen Tab und welche Funktion du am Tag zuerst öffnest und zu welcher Tageszeit, wie lange eine Sitzung ungefähr dauert, welche Wege du in der App gehst, wo ein Ablauf (zum Beispiel das Verbinden per QR-Code) abbricht, welche Einstellungen gewählt sind, welche Fehler aufgetreten sind (nur die Art, zum Beispiel Absturz oder Speichern fehlgeschlagen), wie schnell der Server antwortet, dazu App-Version, iOS-Version und Gerätetyp. Kein Gesundheitswert, kein Gewicht, kein Essen, kein Schlaf, kein Training, kein Text, kein Name, kein Studio, kein Standort, keine Verbindung und kein Fehlertext geht dorthin. Sagst du Nein oder gar nichts, geht nichts davon raus. Die Meldungen werden nach 90 Tagen gelöscht. Mit dem Schalter „Nutzung melden“ unten auf dieser Seite änderst du deine Antwort jederzeit; Aus stoppt das Senden sofort und verwirft, was noch nicht gesendet ist. Die Kennung, der Profilname und die App-Version gehen trotzdem hin, damit Einstellungen ankommen.")),
        Abschnitt(titel: String(localized: "Was dein Partner sieht"),
                  text: String(localized: "Nichts, solange du keine Datenart freigibst. Ist dein Konto mit einem Partner verbunden, sieht er nur die Zusammenfassungen (Schritte, Gym-Tage, Schlaf, Kalorien), die du einzeln freigibst, nie Rohdaten. Sie laufen über den Lumen-Server und, solange Lovea den Weg noch nutzt, zusätzlich über eine Datei auf diesem iPhone.")),
        Abschnitt(titel: String(localized: "Passwort"),
                  text: String(localized: "Das Passwort schützt nur Handlungen auf diesem iPhone: Profil wechseln, Passwort ändern, Daten löschen. Es gibt keinen Anmeldebildschirm. Wer es vergisst, bekommt keine Rücksetzung per Mail, weil es kein Konto mit Anmeldung gibt. Beim Wechseln und beim Löschen steht dafür „Passwort vergessen?“: Das Profil und seine Daten werden nach zwei Bestätigungen gelöscht, und du fängst neu an (mit einer Datensicherung wieder mit deinen Daten).")),
        Abschnitt(titel: String(localized: "Essen per Foto schätzen"),
                  text: String(localized: "Nur wenn du vorher im Foto-Blatt auf „Erlauben“ tippst: Dann gehen das Foto (verkleinert, ohne Ort und Aufnahmezeit), die Mahlzeit und dein Hinweis über den Lumen-Server an OpenAI in den USA zur Auswertung. Der Lumen-Server speichert weder Foto noch Antwort, er zählt nur die Fotos am Tag. OpenAI bekommt die Anfrage mit der Einstellung, die Antwort nicht zu speichern. Ohne Zustimmung geht kein Foto raus. Zurücknehmen kannst du sie jederzeit im Foto-Blatt über das Hand-Symbol.")),
        Abschnitt(titel: String(localized: "Konto löschen"),
                  text: String(localized: "Unter Konto ganz unten: löscht zuerst alles zu deinem Konto auf dem Lumen-Server (Kennung, Einstellungen, Verbindungen, Freigaben, Herausforderungen, Reaktionen, Nutzungs- und Foto-Zähler) und danach alle Profile von Lumen Fit auf diesem iPhone. Ohne Netz wird nichts gelöscht. Daten in Health bleiben unberührt.")),
        Abschnitt(titel: String(localized: "Alles löschen"),
                  text: String(localized: "Löscht dein Profil und alle Daten dieser App auf diesem iPhone, mit deinem Passwort. Beim letzten Profil gehen auch die Dateien für Lovea, der Stand der Widgets und die Spuren des Bands weg. Daten in Health bleiben unberührt. Eine Datensicherung, die du geteilt hast, bleibt dort, wo du sie abgelegt hast.")),
    ] }

    // MARK: - Frage nach der Nutzungsmeldung

    /// Die Frage im ersten Start, für Bestandskonten einmal und im Datenschutz-Bereich: gleiche Worte an allen Stellen, zwei gleichwertige Antworten.
    enum NutzungFrage {
        static let titel = String(localized: "Hilfst du uns, Lumen Fit besser zu machen?")
        static let einleitung = String(localized: "Wenn du Ja sagst, meldet die App dem Lumen-Server kleine Zähler zur Nutzung. So finden wir Fehler schneller und sehen, was niemand braucht.")
        static let gezaehlt = String(localized: "Das wird gezählt: welchen Tab und welche Funktion du am Tag zuerst öffnest, zu welcher Tageszeit, wie lange eine Sitzung ungefähr dauert, welche Wege du gehst, wo ein Ablauf abbricht, welche Einstellungen gewählt sind, Fehlerarten wie Absturz und wie schnell der Server antwortet.")
        static let nie = String(localized: "Das wird nie gesendet: Gesundheitswerte, Gewicht, Essen, Schlaf, Trainings, Texte, Namen, Studios, Standort, Verbindungen und Fehlertexte.")
        static let konto = String(localized: "Die Zähler hängen an der zufälligen Kennung dieses iPhones und deinem Profilnamen. Sie sind nicht anonym.")
        static let aus = String(localized: "Du kannst jederzeit unter Profil, Über Lumen Fit, Datenschutz ausschalten. Die App funktioniert bei Nein genauso, auch mit Health.")
        static let ja = String(localized: "Ja, helfen")
        static let nein = String(localized: "Nein")
        static let schalter = String(localized: "Nutzung melden")
        static let schalterFuss = String(localized: "Hängt an deinem Konto, nicht anonym. Aus stoppt das Senden sofort und verwirft, was noch nicht gesendet ist.")
    }

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
               text: String(localized: "Produktdaten von Open Food Facts, lizenziert unter der Open Database License (ODbL). Die Daten stammen von der Gemeinschaft hinter openfoodfacts.org.")),
        Quelle(name: "Bundeslebensmittelschlüssel (BLS)", lizenz: "CC BY 4.0",
               text: String(localized: "Nährwerte der Grundlebensmittel aus dem Bundeslebensmittelschlüssel (BLS), Max Rubner-Institut, lizenziert unter CC BY 4.0. Datenstand: Version 4.0 mit 7.140 Einträgen, in der App gespeichert und offline nutzbar.")),
        Quelle(name: String(localized: "Übungsbilder"), lizenz: String(localized: "nur geladen"),
               text: String(localized: "Die Bilder der Übungen werden bei Bedarf von static.exercisedb.dev geladen und auf deinem iPhone gemerkt. Sie sind nicht Teil der App.")),
        Quelle(name: String(localized: "Apple-Frameworks"), lizenz: "Apple",
               text: String(localized: "Health (HealthKit), Swift Charts, WidgetKit, ActivityKit, VisionKit, CoreBluetooth und Foundation Models von Apple. Gesundheitswerte lesen und schreiben geht nur mit deiner Zustimmung.")),
    ]

    // MARK: - Passwort vergessen

    static func zuruecksetzenTitel(name: String) -> String { String(localized: "\(name) zurücksetzen?") }
    static let zuruecksetzenText = String(localized: "Ohne Passwort kommst du nicht an dieses Profil. Lumen Fit hat keinen Server für Passwörter und kann dir nichts per Mail schicken. Du kannst das Profil löschen und neu anfangen.")
    static let zuruecksetzenWarnung = String(localized: "Das Profil und alle seine Daten auf diesem iPhone werden gelöscht: Trainings, Essen, Gewicht, Meilensteine. Daten in Health bleiben. Das lässt sich nicht rückgängig machen.")
    static func zuruecksetzenFrage(name: String) -> String { String(localized: "\(name) endgültig löschen?") }
    static let ladeProblemLesefehler = String(localized: "Die Profile konnten gerade nicht gelesen werden. Nichts ist gelöscht. Versuch es gleich nochmal, zum Beispiel nach dem Entsperren des iPhones.")
    static let ladeProblemKaputt = String(localized: "Der gespeicherte Eintrag deiner Profile ist beschädigt. Nichts wurde überschrieben. Du kannst ihn verwerfen und neu anfangen; eine Kopie bleibt auf diesem iPhone.")

    // MARK: - Alles löschen

    /// Was vor dem Löschen aufgelistet wird: Zahlen aus den Stores, nichts erfunden.
    struct Loeschzeile: Equatable, Identifiable, Sendable {
        let text: String
        var id: String { text }
    }

    static func loeschliste(einheiten: Int, essenstage: Int, meilensteine: Int) -> [Loeschzeile] {
        func zeile(_ n: Int, _ einzahl: String, _ mehrzahl: String) -> Loeschzeile { Loeschzeile(text: "\(n) \(n == 1 ? einzahl : mehrzahl)") }
        return [
            zeile(einheiten, String(localized: "Training"), String(localized: "Trainings")),
            zeile(essenstage, String(localized: "Tag im Essenstagebuch"), String(localized: "Tage im Essenstagebuch")),
            zeile(meilensteine, String(localized: "Meilenstein"), String(localized: "Meilensteine")),
        ] + [
            Loeschzeile(text: String(localized: "Ziele, Körperdaten, Einstellungen und Gewohnheiten")),
        ]
    }
}
