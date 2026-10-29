import Foundation

// Morgen-Check (Idee 67): beim ersten Öffnen des Coach-Tabs am Morgen eine Frage, Antwort 1 bis 5. Die Antwort färbt Lumis Stimmung (Op
// `fit.lumi.stimmung`, das Modul heute liest sie) und den Vorschlag des Coachs. Nie als Mitteilung: er erscheint nur, wenn die Person den
// Tab öffnet. Reine Logik, Zeit und Stand kommen von außen.

enum CoachMorgenCheck {
    static let frage = "Wie fühlst du dich heute früh?"

    struct Stufe: Equatable, Sendable {
        let wert: Int
        let name: String
        let symbol: String
    }

    /// 1 = schwer ... 5 = top. Der Text steht an jeder Stufe, nicht nur eine Zahl.
    static let stufen: [Stufe] = [
        Stufe(wert: 1, name: "Schwer", symbol: "cloud.rain"),
        Stufe(wert: 2, name: "Müde", symbol: "moon.zzz"),
        Stufe(wert: 3, name: "Okay", symbol: "minus.circle"),
        Stufe(wert: 4, name: "Gut", symbol: "sun.min"),
        Stufe(wert: 5, name: "Top", symbol: "sun.max"),
    ]

    /// Der Morgen: 5 bis 11 Uhr (wie `CoachText.tageszeit`).
    static func istMorgen(stunde: Int) -> Bool { CoachText.tageszeit(stunde: stunde) == .morgen }

    /// Erscheint nur am Morgen, solange für heute weder eine Antwort noch ein "Heute nicht" vorliegt.
    static func faellig(stunde: Int, tag: String, stimmungen: [StimmungsEintrag], uebersprungen: String?) -> Bool {
        istMorgen(stunde: stunde) && !stimmungen.contains { $0.tag == tag } && uebersprungen != tag
    }

    /// Lumis Stimmung zur Antwort: schwer und müde zeigen Lumi müde, okay und gut bereit, top stolz.
    static func stimmung(fuer wert: Int) -> LumiStimmung {
        switch wert {
        case ...2: .muede
        case 3, 4: .bereit
        default: .stolz
        }
    }

    /// Der Eintrag für die Op; Werte außerhalb von 1 bis 5 werden begrenzt.
    static func eintrag(tag: String, wert: Int) -> StimmungsEintrag {
        let w = min(max(wert, 1), 5)
        return StimmungsEintrag(tag: tag, wert: w, stimmung: stimmung(fuer: w))
    }

    /// Die Antwort des Coachs auf den Morgen-Check: kurz, ohne Druck, mit einem Vorschlag als Chip. Der Plan-Vorschlag folgt der Zahl:
    /// schwer und müde bieten leichteres Training an, gut und top zeigen das Training.
    static func antwort(wert: Int, kontext: CoachKontext) -> CoachAntwort {
        let w = min(max(wert, 1), 5)
        let schlaf = kontext.schlafMinuten.map { " Du hast \(CoachGesundheit.dauer(minuten: $0)) geschlafen." } ?? ""
        switch w {
        case 1:
            return CoachAntwort(text: "Das klingt nach einem schweren Morgen, und das ist okay.\(schlaf) Heute zählt nur, was dir guttut.",
                                chips: [CoachChip(id: "plan-morgen-leicht", text: "Morgen leicht", aktion: .planMorgenLeicht)])
        case 2:
            return CoachAntwort(text: "Müde Tage gibt es, du brauchst dich heute nicht zu beweisen.\(schlaf) Wir nehmen es heute locker.",
                                chips: [CoachChip(id: "plan-morgen-leicht", text: "Morgen leicht", aktion: .planMorgenLeicht)])
        case 3:
            return CoachAntwort(text: "Okay ist ein guter Start.\(schlaf) Magst du schauen, was heute ansteht?",
                                chips: [CoachChip(id: "zeig-heute", text: "Zeig mir", aktion: .oeffne(.heute))])
        case 4:
            return CoachAntwort(text: "Schön, dass du dich gut fühlst.\(schlaf) Ein Training heute passt dazu.",
                                chips: [CoachChip(id: "zeig-training", text: "Zeig mir", aktion: .oeffne(.gym(.training)))])
        default:
            return CoachAntwort(text: "Top, das freut mich für dich.\(schlaf) Nutze die Energie, wenn du magst.",
                                chips: [CoachChip(id: "zeig-training", text: "Zeig mir", aktion: .oeffne(.gym(.training)))])
        }
    }
}
