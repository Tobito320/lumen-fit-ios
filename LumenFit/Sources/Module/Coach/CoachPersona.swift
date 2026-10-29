import Foundation

// Health-Coach, Persona (Idee 63, 70): wie der Coach spricht und was er nie sagt. Die Regeln stehen hier einmal und gelten für beide Motoren:
// das Modell bekommt sie als Anweisung (`anweisung`), `CoachAntwortPruefung` prüft jede Antwort gegen dieselben Listen, der Regelmotor
// hält sie von Haus aus ein. Reine Logik, nichts hier liest Modelle oder die Uhr.

enum CoachPersona {
    /// Höchstens drei Aussagesätze und höchstens eine Frage.
    static let maxSaetze = 3
    static let maxFragen = 1
    /// Ein kurzer Satz hat höchstens so viele Wörter.
    static let maxWoerterProSatz = 25
    static let maxZeichen = 480

    /// Text bei nicht bereitem Modell oder Fehler: ruhig, mit Lumi, nie ein rohes Fehlerwort.
    static let fehlerText = "Gerade nicht erreichbar, ich merke mir deine Frage."

    static let arztHinweis = "Sprich dazu bitte mit deiner Ärztin oder deinem Arzt."

    // MARK: - Listen (klein geschrieben verglichen)

    static let alsKI = ["als ki", "als künstliche intelligenz", "als sprachmodell", "als ai", "ich bin eine ki", "ich bin ein sprachmodell",
                        "ich bin nur ein programm", "as an ai", "language model"]

    /// Diagnosen und Krankheitsnamen stellt der Coach nie, auch nicht als Vermutung.
    static let diagnosen = ["diagnose", "du leidest", "du hast vermutlich", "du hast wahrscheinlich", "du hast sicher eine", "bandscheibenvorfall",
                            "meniskusriss", "sehnenscheidenentzündung", "tennisarm", "depression", "burnout", "burn-out", "diabetes", "bluthochdruck",
                            "essstörung", "magersucht", "bulimie", "herzinfarkt", "arthrose", "muskelfaserriss", "zerrung", "entzündung", "infektion"]

    /// Belehrung und Vorwurf: nie.
    static let belehrend = ["du musst", "du solltest", "du hättest", "man sollte", "reiß dich", "reiss dich", "faul", "ausrede", "versagt",
                            "schon wieder", "kein wunder"]

    /// An schweren Tagen kein Druck.
    static let druck = ["durchbeißen", "durchziehen", "härter", "streng dich", "gib alles", "kein ausruhen", "trotzdem trainieren", "kein grund"]

    /// Anzeichen für Beschwerden in einer Frage: dann gehört der Hinweis auf Ärztin oder Arzt in die Antwort.
    static let beschwerden = ["schmerz", "tut weh", "tut mir weh", "weh ", "stechen", "kribbeln", "taub", "schwindel", "brustschmerz", "atemnot",
                              "ohnmacht", "verletzt", "verletzung", "geschwollen", "blut", "herzrasen", "übel", "erbrechen"]

    /// Wörter, die auf Du-Form hindeuten (für Tests und die Prüfung der Anrede).
    static let duWoerter = ["du", "dir", "dich", "dein", "deine", "deinen", "deinem", "deiner", "deines"]

    // MARK: - Anweisung fürs Modell

    /// Die Anweisung der Sitzung (Deutsch). Der Kontext mit den echten Zahlen kommt je Frage im Prompt.
    static let anweisung = """
    Du bist der Coach in der App Lumen Fit und sprichst wie ein guter Freund mit der Person, die dich fragt.
    Schreibe Deutsch, per du, ruhig und warm. Antworte mit höchstens drei kurzen Sätzen plus höchstens einer Frage.
    Nenne echte Zahlen aus dem Kontext statt Floskeln. Erfinde nie Zahlen: fehlt etwas, sage das kurz und frage nach.
    Sage nie, dass du eine KI oder ein Sprachmodell bist. Stelle nie Diagnosen und nenne keine Krankheiten.
    Bei Schmerzen, Schwindel oder anderen Beschwerden sage freundlich, dass die Person das mit ihrer Ärztin oder ihrem Arzt klären soll.
    An schweren Tagen (wenig Schlaf, niedrige Bereitschaft, müde Stimmung) bist du verständnisvoll, machst keinen Druck und belehrst nie.
    Keine Vorwürfe, keine Befehle wie "du musst", keine Emojis. Merke dir nichts selbst; nutze nur den Merkzettel aus dem Kontext.
    Schlage höchstens zwei Handlungen als Knopf vor: "mach_ich" (neue Gewohnheit), "morgen_leicht" (morgiges Training leichter) oder "zeig_mir" (Seite öffnen).
    """

    // MARK: - Lage

    /// Ein schwerer Tag: wenig Schlaf (unter 6 Stunden), niedrige Bereitschaft (unter 40) oder müde Stimmung.
    static func schwererTag(_ kontext: CoachKontext) -> Bool {
        if let schlaf = kontext.schlafMinuten, schlaf < 360 { return true }
        if let bereitschaft = kontext.bereitschaft, bereitschaft < 40 { return true }
        return kontext.stimmung == .muede
    }

    static func istBeschwerde(_ frage: String) -> Bool {
        let klein = frage.lowercased() + " "
        return beschwerden.contains { klein.contains($0) }
    }

    /// Welche Daten eine Frage braucht, die im Kontext fehlen (Namen für die Rückfrage). Leer: alles da.
    static func fehlendeDaten(frage: String, kontext: CoachKontext) -> [FehlendeDaten] {
        let klein = frage.lowercased()
        var fehlt: [FehlendeDaten] = []
        let schlafFrage = klein.contains("schlaf") || klein.contains("geschlafen") || klein.contains("müde")
        let gefuehlFrage = klein.contains("fühle ich mich") && kontext.bereitschaft == nil
        if schlafFrage || gefuehlFrage, kontext.schlafMinuten == nil { fehlt.append(.schlaf) }
        if klein.contains("schritt") || klein.contains("gelaufen") || klein.contains("bewegt"), kontext.schritte == nil { fehlt.append(.schritte) }
        if klein.contains("training") || klein.contains("trainiert") || klein.contains("gym"), kontext.letztesTraining == nil { fehlt.append(.training) }
        return fehlt
    }

    enum FehlendeDaten: String, Equatable, Sendable { case schlaf, schritte, training }
}
