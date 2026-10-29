import Foundation

// Coach auf dem Gerät (Idee 61): Apples Sprachmodell (Foundation Models) antwortet auf Deutsch ohne Server; Gesundheitsdaten verlassen das
// iPhone nie. Alle Aufrufe von FoundationModels stehen in dieser Datei (unten, hinter `#if canImport(FoundationModels)`), damit ein Fehler
// dort den Rest nicht verdeckt. Alles darüber ist reine Logik ohne Framework und läuft in Tests:
// Prompt aus dem `CoachKontext`, Nachladen für die Werkzeuge, Übersetzung der Chips des Modells in `CoachChip`.
//
// Typnamen und Aufrufe geprüft gegen developer.apple.com/documentation/foundationmodels (SystemLanguageModel.availability, supportsLocale,
// LanguageModelSession(model:tools:instructions:), respond(generating:options:prompt:), Tool, @Generable, @Guide).

enum CoachMotorFehler: Error, Equatable, Sendable {
    /// Das Modell ist nicht bereit (kein Apple Intelligence, falsche Sprache, noch nicht geladen).
    case nichtBereit
    /// Die Antwort war leer oder nicht brauchbar.
    case leer
    /// Das Modell hat nicht innerhalb der Frist geantwortet (die Tippanzeige steht höchstens 15 Sekunden).
    case zeitUeberschritten
}

// MARK: - Nachladen für die Werkzeuge

/// Was das Modell bei Bedarf nachlädt (letztes Training, Rekorde, Schlaf, Essen): lokal gelesen, nie gesendet. Jede Funktion bekommt die Zahl der
/// Einträge oder Tage (1 bis 7) und liefert eine kurze deutsche Zeile je Eintrag.
struct CoachNachladen: Sendable {
    var training: @Sendable @MainActor (Int) -> String
    var rekorde: @Sendable @MainActor (Int) -> String
    var schlaf: @Sendable @MainActor (Int) -> String
    var essen: @Sendable @MainActor (Int) -> String

    static let leer = CoachNachladen(training: { _ in "" }, rekorde: { _ in "" }, schlaf: { _ in "" }, essen: { _ in "" })

    /// Liest aus den Stores des aktiven Profils zum Zeitpunkt des Aufrufs (ein Profilwechsel mitten im Gespräch bleibt richtig).
    @MainActor
    static func live(_ umgebung: AppUmgebung) -> CoachNachladen {
        CoachNachladen(
            training: { n in
                guard let daten = umgebung.daten else { return "" }
                let jetzt = umgebung.uhr()
                let liste = daten.training.sessions.prefix(max(n, 1)).compactMap { CoachTraining.letztesTraining([$0], plan: daten.training.plan, jetzt: jetzt) }
                return liste.isEmpty ? "Noch kein Training eingetragen." : liste.joined(separator: "\n")
            },
            rekorde: { n in
                guard let daten = umgebung.daten else { return "" }
                let liste = CoachTraining.rekorde(daten.training.sessions, heute: Datum.text(umgebung.uhr()), maximal: max(n, 1)).map(\.text)
                return liste.isEmpty ? "Keine neuen Rekorde in den letzten 14 Tagen." : liste.joined(separator: "\n")
            },
            schlaf: { n in
                let heute = Datum.text(umgebung.uhr())
                let zeilen = (0..<max(n, 1)).compactMap { zurueck -> String? in
                    let tag = Datum.addTage(heute, -zurueck)
                    return umgebung.gesundheit.naechte[tag].map { "\(tag): \(CoachGesundheit.dauer(minuten: $0.schlafMinuten))" }
                }
                return zeilen.isEmpty ? "Keine Schlafdaten." : zeilen.joined(separator: "\n")
            },
            essen: { n in
                guard let daten = umgebung.daten else { return "" }
                let heute = Datum.text(umgebung.uhr())
                let zeilen = (0..<max(n, 1)).compactMap { zurueck -> String? in
                    let tag = Datum.addTage(heute, -zurueck)
                    let summe = daten.essen.summe(tag)
                    guard summe.kcal > 0 else { return nil }
                    return "\(tag): \(CoachFormat.zahl(Int(summe.kcal.rounded()))) kcal, \(CoachFormat.zahl(Int(summe.protein.rounded()))) g Protein"
                }
                return zeilen.isEmpty ? "Nichts im Essens-Log." : zeilen.joined(separator: "\n")
            })
    }
}

// MARK: - Prompt

enum CoachModellPrompt {
    /// Wie viele Nachrichten des Verlaufs mitgehen (der Kontext des Modells ist klein).
    static let verlaufNachrichten = 6
    static let maxZeichenJeNachricht = 300

    /// Der Kontext mit den echten Zahlen, die Vorliebe aus den Daumen, das bisherige Gespräch und die Frage. Fehlendes steht als "unbekannt",
    /// damit das Modell nachfragt statt zu raten.
    static func bauen(_ anfrage: CoachAnfrage) -> String {
        let k = anfrage.kontext
        var zeilen: [String] = []
        zeilen.append("Heute: \(k.tag)")
        zeilen.append("Schlaf heute Nacht: \(k.schlafMinuten.map { CoachGesundheit.dauer(minuten: $0) } ?? "unbekannt")")
        zeilen.append("Bereitschaft: \(k.bereitschaft.map { "\($0) von 100" } ?? "unbekannt")")
        zeilen.append("Schritte heute: \(k.schritte.map { CoachFormat.zahl($0) } ?? "unbekannt")")
        zeilen.append("Letztes Training: \(k.letztesTraining ?? "unbekannt")")
        zeilen.append("Stimmung heute: \(k.stimmung.rawValue)\(CoachPersona.schwererTag(k) ? " (schwerer Tag)" : "")")
        let z = k.ziele
        zeilen.append("Ziele: \(CoachFormat.zahl(z.schritte)) Schritte, \(CoachFormat.zahl(z.kalorien)) kcal, \(z.proteinGramm) g Protein, "
                      + "\(CoachGesundheit.dauer(minuten: z.schlafMinuten)) Schlaf, \(z.gymTageProWoche) Gym-Tage pro Woche")
        if !k.merkzettel.isEmpty { zeilen.append("Merkzettel der Person:\n" + k.merkzettel.suffix(10).map { "- \($0)" }.joined(separator: "\n")) }
        let hinweis = CoachLernen.stil(anfrage.verlauf).hinweis
        if !hinweis.isEmpty { zeilen.append("Vorliebe der Person: \(hinweis)") }
        let bisher = anfrage.verlauf.suffix(verlaufNachrichten).map { n -> String in
            let text = String(CoachMarker.zerlegen(n.text).text.prefix(maxZeichenJeNachricht))
            return "\(n.rolle == .nutzer ? "Person" : "Coach"): \(text)"
        }
        if !bisher.isEmpty { zeilen.append("Bisheriges Gespräch:\n" + bisher.joined(separator: "\n")) }
        zeilen.append("Fehlt dir eine Zahl, nutze ein Werkzeug. Steht sie auch dort nicht, frage kurz nach, statt zu raten.")
        zeilen.append("Frage der Person: \(anfrage.frage)")
        return zeilen.joined(separator: "\n")
    }
}

// MARK: - Übersetzung der Chips

/// Ein Knopf, wie das Modell ihn liefert: Text, Art und Ziel als Zeichenketten.
struct CoachRohChip: Equatable, Sendable {
    var text: String
    var art: String
    var ziel: String
}

enum CoachModellUebersetzer {
    /// Seiten, zu denen "zeig_mir" springen darf (Schlüssel wie `CoachMarker.Ziel`, dazu "heute").
    static func route(fuer ziel: String) -> Route? {
        let klein = ziel.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if klein == "heute" { return .heute }
        return CoachMarker.Ziel(rawValue: klein)?.route
    }

    /// Nur Knöpfe mit gültiger Art und gültigem Ziel, höchstens zwei; alles andere fällt still weg.
    static func chips(_ roh: [CoachRohChip]) -> [CoachChip] {
        var liste: [CoachChip] = []
        for r in roh {
            let text = String(r.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
            guard !text.isEmpty else { continue }
            switch r.art {
            case "mach_ich":
                let name = r.ziel.trimmingCharacters(in: .whitespacesAndNewlines)
                guard (2...CoachMarker.maxGewohnheitName).contains(name.count), !name.contains(where: \.isNewline) else { continue }
                liste.append(CoachChip(id: "gewohnheit-\(CoachLokal.schluessel(name))", text: text, aktion: .gewohnheitAnlegen(name: name)))
            case "morgen_leicht":
                liste.append(CoachChip(id: "plan-morgen-leicht", text: text, aktion: .planMorgenLeicht))
            case "zeig_mir":
                guard let route = route(fuer: r.ziel) else { continue }
                liste.append(CoachChip(id: "gehe-\(CoachLokal.schluessel(r.ziel.lowercased()))", text: text, aktion: .oeffne(route)))
            default:
                continue
            }
        }
        var gesehen: Set<String> = []
        return Array(liste.filter { gesehen.insert($0.id).inserted }.prefix(2))
    }

    /// Text ohne Marker und Leerraum plus die Chips (die des Modells zuerst, dann die aus Markern), höchstens zwei. Leerer Text ist ein Fehler.
    static func antwort(text: String, chips roh: [CoachRohChip]) throws -> CoachAntwort {
        let zerlegt = CoachMarker.zerlegen(text)
        guard !zerlegt.text.isEmpty else { throw CoachMotorFehler.leer }
        let eigene = chips(roh)
        let ausMarkern = zerlegt.chips.filter { marker in !eigene.contains { $0.id == marker.id } }
        return CoachAntwort(text: zerlegt.text, chips: Array((eigene + ausMarkern).prefix(2)))
    }
}

// MARK: - Foundation Models (die einzige Stelle, die das Framework anfasst)

#if canImport(FoundationModels)
import FoundationModels

@Generable(description: "Ein Knopf unter der Antwort, der eine Handlung auslöst")
struct CoachModellChip {
    @Guide(description: "Kurzer Knopftext auf Deutsch, höchstens drei Wörter")
    var text: String
    @Guide(description: "Art der Handlung", .anyOf(["mach_ich", "morgen_leicht", "zeig_mir"]))
    var art: String
    @Guide(description: "Bei mach_ich der Name der neuen Gewohnheit, bei zeig_mir die Seite: heute, training, essen, schlaf, verlauf oder gewicht. Sonst leer")
    var ziel: String
}

@Generable(description: "Die Antwort des Coachs an die Person")
struct CoachModellAntwort {
    @Guide(description: "Höchstens drei kurze Sätze plus höchstens eine Frage, Deutsch, per du, mit echten Zahlen aus dem Kontext")
    var text: String
    @Guide(description: "Null bis zwei Knöpfe mit einer Handlung, nur wenn sie wirklich helfen", .maximumCount(2))
    var knoepfe: [CoachModellChip]
}

@Generable(description: "Wie weit zurück nachgeladen wird")
struct CoachNachladenArgumente {
    @Guide(description: "Anzahl der Einträge oder Tage, 1 bis 7", .range(1...7))
    var anzahl: Int
}

struct CoachTrainingTool: Tool {
    typealias Arguments = CoachNachladenArgumente
    let name = "letztesTraining"
    let description = "Liefert die letzten Trainings der Person mit Zeitpunkt, Dauer und Zahl der Sätze."
    let quelle: CoachNachladen

    func call(arguments: CoachNachladenArgumente) async throws -> String { await quelle.training(arguments.anzahl) }
}

struct CoachRekordeTool: Tool {
    typealias Arguments = CoachNachladenArgumente
    let name = "rekorde"
    let description = "Liefert die neuesten persönlichen Rekorde der Person mit Übung, Gewicht und Wiederholungen."
    let quelle: CoachNachladen

    func call(arguments: CoachNachladenArgumente) async throws -> String { await quelle.rekorde(arguments.anzahl) }
}

struct CoachSchlafTool: Tool {
    typealias Arguments = CoachNachladenArgumente
    let name = "schlaf"
    let description = "Liefert die Schlafdauer der letzten Nächte der Person."
    let quelle: CoachNachladen

    func call(arguments: CoachNachladenArgumente) async throws -> String { await quelle.schlaf(arguments.anzahl) }
}

struct CoachEssenTool: Tool {
    typealias Arguments = CoachNachladenArgumente
    let name = "essen"
    let description = "Liefert Kalorien und Protein aus dem Essens-Log der letzten Tage."
    let quelle: CoachNachladen

    func call(arguments: CoachNachladenArgumente) async throws -> String { await quelle.essen(arguments.anzahl) }
}

#endif

/// Der Coach mit Apples Modell auf dem Gerät. Eine neue Sitzung je Frage: das bisherige Gespräch geht im Prompt mit, deshalb gibt es beim
/// Wechsel zwischen den Motoren keinen Verlust. Ohne das Framework (andere Plattform) ist er nie verfügbar, damit alles andere trotzdem baut.
struct ModellCoachMotor: CoachMotor {
    let nachladen: CoachNachladen

    init(nachladen: CoachNachladen = .leer) { self.nachladen = nachladen }

    var name: String { "Apple Intelligence" }

    func verfuegbar() async -> Bool { Self.modellBereit() }

    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
        guard Self.modellBereit() else { throw CoachMotorFehler.nichtBereit }
        let roh = try await frageModell(anfrage)
        return try CoachModellUebersetzer.antwort(text: roh.text, chips: roh.chips)
    }

    /// Der Rohtext und die Knöpfe des Modells.
    private struct Roh {
        var text: String
        var chips: [CoachRohChip]
    }

    #if canImport(FoundationModels)
    /// Verfügbar und Deutsch unterstützt.
    static func modellBereit() -> Bool {
        let modell = SystemLanguageModel.default
        guard case .available = modell.availability else { return false }
        return modell.supportsLocale(Locale(identifier: "de_DE"))
    }

    private func frageModell(_ anfrage: CoachAnfrage) async throws -> Roh {
        let werkzeuge: [any Tool] = [CoachTrainingTool(quelle: nachladen), CoachRekordeTool(quelle: nachladen),
                                     CoachSchlafTool(quelle: nachladen), CoachEssenTool(quelle: nachladen)]
        let sitzung = LanguageModelSession(model: SystemLanguageModel.default, tools: werkzeuge, instructions: CoachPersona.anweisung)
        let ergebnis = try await sitzung.respond(to: CoachModellPrompt.bauen(anfrage), generating: CoachModellAntwort.self,
                                                 options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 300))
        let antwort = ergebnis.content
        return Roh(text: antwort.text, chips: antwort.knoepfe.map { CoachRohChip(text: $0.text, art: $0.art, ziel: $0.ziel) })
    }
    #else
    static func modellBereit() -> Bool { false }

    private func frageModell(_ anfrage: CoachAnfrage) async throws -> Roh { throw CoachMotorFehler.nichtBereit }
    #endif
}
