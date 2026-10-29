import Foundation

// Rückfall ohne Apple Intelligence (Idee 62): derselbe Coach aus Textbausteinen und Regeln, damit jedes Gerät einen brauchbaren Coach hat.
// Der Motor ist immer verfügbar, braucht kein Netz und kein Modell und hält die Persona-Regeln von Haus aus ein (der Test
// `RegelCoachMotorTests` prüft jede Antwort mit `CoachAntwortPruefung`). Er antwortet auf den `CoachKontext`; mit der reicheren
// `CoachEingabe` (Essen, Gewicht, Wochensätze) werden die Antworten genauer. Fehlt etwas, fragt er nach, statt zu raten.

/// Worum es in einer Frage geht (Schlüsselwörter, keine Wortlisten für Gefühle: unklar bleibt unklar).
enum CoachAbsicht: String, Equatable, Sendable {
    case beschwerde, wochenrueckblick, luecken, nochEssen, gefuehl, essen, training, tagesbericht, schlaf, schritte, gewicht, gruss, danke, unbekannt

    static func erkenne(_ frage: String) -> CoachAbsicht {
        let klein = frage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        func hat(_ teile: [String]) -> Bool { teile.contains { klein.contains($0) } }
        if CoachPersona.istBeschwerde(frage) { return .beschwerde }
        if hat(["wochenrückblick", "wochenrueckblick", "rückblick"]) { return .wochenrueckblick }
        if hat(["noch nicht eingetragen", "fehlt heute", "was fehlt"]) { return .luecken }
        if hat(["esse ich noch", "soll ich noch essen", "darf ich noch essen"]) { return .nochEssen }
        if hat(["fühle ich mich", "wie geht es mir", "fühl mich"]) { return .gefuehl }
        if hat(["essen", "hunger", "kalorien", "protein", "mahlzeit"]) { return .essen }
        if hat(["training", "trainier", "gym", "workout", "übung"]) { return .training }
        if hat(["tagesbericht", "zusammenfassung", "wie war mein tag", "wie läuft mein tag"]) { return .tagesbericht }
        if hat(["schlaf", "geschlafen", "müde", "ausgeruht"]) { return .schlaf }
        if hat(["schritt", "gelaufen", "bewegt", "spazier"]) { return .schritte }
        if hat(["gewicht", "wiege", "kilo"]) { return .gewicht }
        if hat(["danke", "dankeschön"]) { return .danke }
        let woerter = klein.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if woerter.count <= 3, woerter.contains(where: { ["hallo", "hi", "hey", "moin", "servus"].contains($0) }) || klein.hasPrefix("guten ") { return .gruss }
        return .unbekannt
    }
}

/// Der Regelcoach als Motor. `eingabe` liefert die reichere Eingabe (Hauptakteur, siehe `CoachDaten`); ohne sie antwortet er nur auf dem Kontext.
struct RegelCoachMotor: CoachMotor {
    let eingabe: @Sendable @MainActor () -> CoachEingabe?

    init(eingabe: @escaping @Sendable @MainActor () -> CoachEingabe? = { nil }) { self.eingabe = eingabe }

    var name: String { "Regeln" }

    func verfuegbar() async -> Bool { true }

    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
        CoachRegelAntwort.bauen(anfrage, eingabe: await eingabe())
    }
}

/// Die Antworten des Regelcoachs, rein gerechnet.
enum CoachRegelAntwort {
    static let verstaendnis = "Heute darf es ruhig langsam gehen."

    /// Antwort auf die Frage; Daumen im Verlauf formen Länge und Ton (`CoachLernen`).
    static func bauen(_ anfrage: CoachAnfrage, eingabe e: CoachEingabe?) -> CoachAntwort {
        var antwort = grundantwort(anfrage, eingabe: e)
        let stil = CoachLernen.stil(anfrage.verlauf)
        if stil.kuerzer { antwort.text = CoachLernen.kuerzen(antwort.text, behalte: CoachPersona.schwererTag(anfrage.kontext) ? verstaendnis : nil) }
        if stil.nuechtern { antwort.text = CoachLernen.nuechtern(antwort.text) }
        return antwort
    }

    private static func grundantwort(_ anfrage: CoachAnfrage, eingabe e: CoachEingabe?) -> CoachAntwort {
        let k = anfrage.kontext
        let schwer = CoachPersona.schwererTag(k)
        switch CoachAbsicht.erkenne(anfrage.frage) {
        case .beschwerde: return beschwerde()
        case .gefuehl: return gefuehl(k, schwer: schwer)
        case .schlaf: return schlaf(k, schwer: schwer)
        case .schritte: return schritte(k, schwer: schwer)
        case .training: return training(k, e, schwer: schwer)
        case .essen: return essen(k, e, schwer: schwer)
        case .nochEssen: return nochEssen(k, e)
        case .tagesbericht: return tagesbericht(k, e, schwer: schwer)
        case .wochenrueckblick: return wochenrueckblick(e)
        case .luecken: return luecken(k, e)
        case .gewicht: return gewicht(e)
        case .gruss: return gruss()
        case .danke: return CoachAntwort(text: "Gern geschehen. Sag Bescheid, wenn du etwas wissen willst.", chips: [])
        case .unbekannt: return unbekannt()
        }
    }

    // MARK: - Bausteine

    private static func zeigMir(_ id: String, _ route: Route, _ text: String = "Zeig mir") -> CoachChip {
        CoachChip(id: id, text: text, aktion: .oeffne(route))
    }

    private static let morgenLeicht = CoachChip(id: "plan-morgen-leicht", text: "Morgen leicht", aktion: .planMorgenLeicht)

    private static func machIch(_ name: String) -> CoachChip {
        CoachChip(id: "gewohnheit-\(CoachLokal.schluessel(name))", text: "Mach ich", aktion: .gewohnheitAnlegen(name: name))
    }

    private static func punkt(_ satz: String) -> String {
        let s = satz.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let letztes = s.last else { return s }
        return ".!?".contains(letztes) ? s : s + "."
    }

    /// Setzt die Antwort zusammen: höchstens drei Aussagen (an schweren Tagen zwei plus ein verständnisvoller Satz), höchstens eine Frage.
    private static func text(_ aussagen: [String], frage: String? = nil, schwer: Bool = false) -> String {
        var teile = aussagen.map(punkt)
        if schwer { teile = Array(teile.prefix(CoachPersona.maxSaetze - 1)) + [verstaendnis] } else { teile = Array(teile.prefix(CoachPersona.maxSaetze)) }
        if let frage { teile.append(punkt(frage)) }
        return teile.joined(separator: " ")
    }

    private static func chips(_ liste: [CoachChip], schwer: Bool = false) -> [CoachChip] {
        var alle = liste
        if schwer, !alle.contains(morgenLeicht) { alle.insert(morgenLeicht, at: 0) }
        return Array(alle.prefix(2))
    }

    // MARK: - Antworten

    private static func beschwerde() -> CoachAntwort {
        CoachAntwort(text: "Das klingt unangenehm, und ich kann das von hier aus nicht beurteilen. \(CoachPersona.arztHinweis) Magst du mir sagen, seit wann das so ist?", chips: [])
    }

    private static func gefuehl(_ k: CoachKontext, schwer: Bool) -> CoachAntwort {
        if k.schlafMinuten == nil, k.bereitschaft == nil {
            return CoachAntwort(text: text(["Dazu fehlen mir noch Zahlen von dir"], frage: "Wie lange hast du heute Nacht geschlafen?"),
                                chips: [zeigMir("zeig-schlaf", .schlaf(.letzteNacht))])
        }
        let satz: String
        switch (k.schlafMinuten, k.bereitschaft) {
        case let (s?, b?): satz = "Du hast \(CoachGesundheit.dauer(minuten: s)) geschlafen und deine Bereitschaft liegt bei \(b) von 100"
        case let (s?, nil): satz = "Du hast \(CoachGesundheit.dauer(minuten: s)) geschlafen"
        case let (nil, b?): satz = "Deine Bereitschaft liegt bei \(b) von 100"
        default: satz = "Ich habe noch wenig Zahlen von dir"
        }
        let einordnung: String
        if schwer { einordnung = "Das ist ein schwerer Tag" } else if (k.bereitschaft ?? 60) >= 70 { einordnung = "Das sieht gut aus für ein Training" } else { einordnung = "Das ist solide, hör auf dein Gefühl" }
        let trainingChip = zeigMir("zeig-training", .gym(.training))
        return CoachAntwort(text: text([satz, einordnung], frage: "Passt das zu dem, wie du dich fühlst?"),
                            chips: chips([schwer ? morgenLeicht : trainingChip], schwer: schwer))
    }

    private static func schlaf(_ k: CoachKontext, schwer: Bool) -> CoachAntwort {
        guard let s = k.schlafMinuten else {
            return CoachAntwort(text: text(["Dazu fehlen mir deine Schlafdaten"], frage: "Wie lange hast du heute Nacht geschlafen?"),
                                chips: [zeigMir("zeig-schlaf", .schlaf(.letzteNacht))])
        }
        let ziel = k.ziele.schlafMinuten
        var aussagen = ["Du hast \(CoachGesundheit.dauer(minuten: s)) geschlafen, dein Ziel sind \(CoachGesundheit.dauer(minuten: ziel))"]
        var knoepfe = [zeigMir("zeig-schlaf", .schlaf(.letzteNacht))]
        if s < ziel - 30 {
            aussagen.append("Dir fehlen \(CoachGesundheit.dauer(minuten: ziel - s))")
            aussagen.append("Heute etwas früher ins Bett würde helfen")
            knoepfe.insert(machIch("Früher ins Bett"), at: 0)
        } else {
            aussagen.append("Das passt gut")
        }
        return CoachAntwort(text: text(aussagen, schwer: schwer), chips: chips(knoepfe, schwer: schwer))
    }

    private static func schritte(_ k: CoachKontext, schwer: Bool) -> CoachAntwort {
        guard let s = k.schritte else {
            return CoachAntwort(text: text(["Dazu fehlen mir deine Schritte von heute"], frage: "Hattest du dein iPhone heute dabei?"),
                                chips: [zeigMir("zeig-heute", .heute)])
        }
        let ziel = k.ziele.schritte
        var aussagen = ["Du hast heute \(CoachFormat.zahl(s)) Schritte, dein Ziel sind \(CoachFormat.zahl(ziel))"]
        var knoepfe = [zeigMir("zeig-heute", .heute)]
        if s >= ziel {
            aussagen.append("Ziel erreicht, gut gemacht")
        } else if Double(s) < Double(ziel) * 0.6 {
            aussagen.append("Ein kurzer Spaziergang bringt dich ein Stück näher")
            knoepfe.insert(machIch("Spaziergang nach dem Essen"), at: 0)
        } else {
            aussagen.append("Du bist auf einem guten Weg")
        }
        return CoachAntwort(text: text(aussagen, schwer: schwer), chips: chips(knoepfe, schwer: schwer))
    }

    private static func training(_ k: CoachKontext, _ e: CoachEingabe?, schwer: Bool) -> CoachAntwort {
        guard let letztes = k.letztesTraining else {
            return CoachAntwort(text: text(["Ich sehe noch kein Training von dir"], frage: "Wann warst du zuletzt im Gym?"),
                                chips: [zeigMir("zeig-training", .gym(.training))])
        }
        var aussagen = ["Dein letztes Training: \(letztes)"]
        if let u = e?.uebungen.first(where: { $0.vorschlag.mehrGewicht }) ?? e?.uebungen.first {
            let v = u.vorschlag
            aussagen.append(v.kg.map { "Nächstes Mal bei \(u.name): \(TrainingLogik.kgText($0)) kg × \(v.wdh)" } ?? "Nächstes Mal bei \(u.name): \(v.wdh) Wiederholungen")
        }
        if let g = e?.gruppen.first(where: { $0.faellig && $0.ziel > 0 }), Datum.wochentag(e?.heute ?? k.tag) >= 4 {
            aussagen.append("Diese Woche hast du \(CoachFormat.zahl(Int(g.saetze.rounded()))) von \(g.ziel) Sätzen für \(g.name)")
        }
        return CoachAntwort(text: text(aussagen, schwer: schwer), chips: chips([zeigMir("zeig-training", .gym(.training))], schwer: schwer))
    }

    private static func sicherheit(_ e: CoachEingabe?) -> CoachAntwort? {
        guard let e else { return nil }
        let stand = CoachRegeln.essenStand(e)
        guard stand.sehrWenig, let kcal = stand.kcalSchnitt else { return nil }
        let grenze = CoachRegeln.untergrenze(geschlecht: e.geschlecht)
        return CoachAntwort(
            text: "Im Log liegst du im Schnitt bei etwa \(CoachFormat.zahl(Int(kcal.rounded()))) kcal am Tag, unter \(CoachFormat.zahl(grenze)). "
                + "Vielleicht fehlt nur Essen im Log. Wenn du wirklich so wenig isst, \(CoachPersona.arztHinweis.lowercasedErsterBuchstabe)",
            chips: [zeigMir("zeig-essen", .essen(.heute))])
    }

    private static func essen(_ k: CoachKontext, _ e: CoachEingabe?, schwer: Bool) -> CoachAntwort {
        if let karte = sicherheit(e) { return karte }
        let ziel = "Dein Ziel sind \(CoachFormat.zahl(k.ziele.kalorien)) kcal und \(k.ziele.proteinGramm) g Protein am Tag"
        let knopf = [zeigMir("zeig-essen", .essen(.heute))]
        guard let e, let heute = e.essenKcal[e.heute], heute > 0 else {
            return CoachAntwort(text: text([ziel, "Ich sehe heute noch nichts im Log"], frage: "Was hast du schon gegessen?"), chips: knopf)
        }
        let protein = e.essenProtein[e.heute] ?? 0
        let rest = Double(k.ziele.kalorien) - heute
        let bisher = "Heute stehen \(CoachFormat.zahl(Int(heute.rounded()))) kcal und \(CoachFormat.zahl(Int(protein.rounded()))) g Protein im Log"
        let hinweis = rest > 300 ? "Es passt noch eine richtige Mahlzeit" : "Du bist fast am Ziel"
        return CoachAntwort(text: text([ziel, bisher, hinweis], schwer: schwer), chips: chips(knopf, schwer: schwer))
    }

    private static func nochEssen(_ k: CoachKontext, _ e: CoachEingabe?) -> CoachAntwort {
        if let karte = sicherheit(e) { return karte }
        let knopf = [zeigMir("zeig-essen", .essen(.heute), "Essen eintragen")]
        guard let e, let heute = e.essenKcal[e.heute], heute > 0 else {
            return CoachAntwort(text: text(["Dazu fehlt mir dein Essen von heute"], frage: "Was hast du schon gegessen?"), chips: knopf)
        }
        let ziel = k.ziele.kalorien
        let rest = Int((Double(ziel) - heute).rounded())
        let bisher = "Du bist heute bei \(CoachFormat.zahl(Int(heute.rounded()))) von \(CoachFormat.zahl(ziel)) kcal"
        guard rest > 150 else { return CoachAntwort(text: text([bisher, "Das reicht für heute"]), chips: knopf) }
        var aussagen = [bisher + ", es bleiben etwa \(CoachFormat.zahl(rest))"]
        let proteinFehlt = Int((Double(k.ziele.proteinGramm) - (e.essenProtein[e.heute] ?? 0)).rounded())
        if proteinFehlt > 10 {
            aussagen.append("Beim Protein fehlen noch \(proteinFehlt) g")
            aussagen.append("Quark, Skyr oder Eier passen gut dazu")
        }
        return CoachAntwort(text: text(aussagen), chips: knopf)
    }

    private static func tagesbericht(_ k: CoachKontext, _ e: CoachEingabe?, schwer: Bool) -> CoachAntwort {
        var aussagen: [String] = []
        if let s = k.schritte { aussagen.append("Du hast \(CoachFormat.zahl(s)) Schritte") }
        if let s = k.schlafMinuten { aussagen.append("Du hast \(CoachGesundheit.dauer(minuten: s)) geschlafen") }
        if let t = k.letztesTraining { aussagen.append("Dein letztes Training: \(t)") }
        if let heute = e?.essenKcal[e?.heute ?? ""], heute > 0 { aussagen.append("Im Log stehen \(CoachFormat.zahl(Int(heute.rounded()))) kcal") }
        guard !aussagen.isEmpty else {
            return CoachAntwort(text: text(["Für heute habe ich noch keine Zahlen von dir"], frage: "Soll ich dir zeigen, wo du etwas eintragen kannst?"),
                                chips: [zeigMir("zeig-heute", .heute)])
        }
        return CoachAntwort(text: text(aussagen, schwer: schwer), chips: chips([zeigMir("zeig-heute", .heute)], schwer: schwer))
    }

    private static func wochenrueckblick(_ e: CoachEingabe?) -> CoachAntwort {
        let knopf = [zeigMir("zeig-verlauf", .verlauf)]
        var aussagen: [String] = []
        if let e {
            let werte = (1...7).compactMap { e.schritte[Datum.addTage(e.heute, -$0)] }.filter { $0 > 0 }
            if werte.count >= 3 { aussagen.append("In den letzten 7 Tagen waren es im Schnitt \(CoachFormat.zahl(werte.reduce(0, +) / werte.count)) Schritte") }
            let saetze = e.gruppen.reduce(0.0) { $0 + $1.saetze }
            if saetze > 0 { aussagen.append("Diese Woche hast du etwa \(CoachFormat.zahl(Int(saetze.rounded()))) Sätze trainiert") }
            if let g = GewichtLogik.berechnet(e.gewicht) { aussagen.append("Dein Gewicht liegt im Schnitt bei \(GewichtText.anzeige(g))") }
        }
        guard !aussagen.isEmpty else {
            return CoachAntwort(text: text(["Für den Rückblick fehlen mir deine Wochendaten", "Im Verlauf siehst du, was schon da ist"]), chips: knopf)
        }
        return CoachAntwort(text: text(aussagen), chips: knopf)
    }

    private static func luecken(_ k: CoachKontext, _ e: CoachEingabe?) -> CoachAntwort {
        guard let e else {
            return CoachAntwort(text: text(["Das sehe ich gerade nicht", "Heute zeigt dir, was noch fehlt"]), chips: [zeigMir("zeig-heute", .heute)])
        }
        var fehlt: [String] = []
        var knoepfe: [CoachChip] = []
        if (e.essenKcal[e.heute] ?? 0) <= 0 { fehlt.append("Essen"); knoepfe.append(zeigMir("zeig-essen", .essen(.heute), "Essen eintragen")) }
        if (e.gewicht[e.heute] ?? 0) <= 0 { fehlt.append("Gewicht"); knoepfe.append(zeigMir("zeig-gewicht", .gewichtEintragen, "Gewicht eintragen")) }
        if k.schlafMinuten == nil { fehlt.append("Schlaf") }
        if k.schritte == nil { fehlt.append("Schritte") }
        guard !fehlt.isEmpty else { return CoachAntwort(text: "Heute ist alles eingetragen. Das sieht gut aus.", chips: []) }
        return CoachAntwort(text: text(["Heute fehlen noch: \(fehlt.joined(separator: ", "))", "Nichts davon ist ein Muss"]), chips: Array(knoepfe.prefix(2)))
    }

    private static func gewicht(_ e: CoachEingabe?) -> CoachAntwort {
        let knopf = [zeigMir("zeig-gewicht", .gewichtEintragen, "Gewicht eintragen")]
        guard let e, let g = GewichtLogik.berechnet(e.gewicht) else {
            return CoachAntwort(text: text(["Dazu fehlen mir Gewichtswerte von dir"], frage: "Magst du heute dein Gewicht eintragen?"), chips: knopf)
        }
        return CoachAntwort(text: text(["Dein Gewicht liegt im Schnitt der letzten 7 Tage bei \(GewichtText.anzeige(g))", "Einzelne Tage schwanken, der Schnitt zählt"]), chips: knopf)
    }

    private static func gruss() -> CoachAntwort {
        CoachAntwort(text: "Hallo! Schön, dich zu sehen. Wie geht es dir heute?",
                     chips: [CoachChip(id: "frage-gefuehl", text: CoachLokal.gefuehl, aktion: .antworten(CoachLokal.gefuehl)),
                             CoachChip(id: "frage-tagesbericht", text: "Tagesbericht", aktion: .antworten("Tagesbericht"))])
    }

    private static func unbekannt() -> CoachAntwort {
        CoachAntwort(text: "Dazu habe ich keine sicheren Zahlen. Ich kenne deinen Schlaf, deine Schritte, dein Training und dein Essen. Worum geht es dir genau?",
                     chips: [CoachChip(id: "frage-training", text: "Wie läuft mein Training?", aktion: .antworten("Wie läuft mein Training?")),
                             CoachChip(id: "frage-tagesbericht", text: "Tagesbericht", aktion: .antworten("Tagesbericht"))])
    }
}

private extension String {
    /// Erster Buchstabe klein (für Satzteile nach einem Komma).
    var lowercasedErsterBuchstabe: String {
        guard let erster = first else { return self }
        return erster.lowercased() + dropFirst()
    }
}
