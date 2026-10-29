// Quelle: Lovea Health/Coach/CoachMarker.swift
import Foundation

// Health-Coach, Marker: eine Antwort darf am Ende bis zu vier Zeilen der Form `[[name: a | b]]` tragen. Das Sprachmodell liefert Chips
// strukturiert; die Marker sind der zweite Weg (Textbausteine, ältere Verläufe) und der Schutz, dass nie ein halber Marker im Chat steht.
// Alles Unbekannte oder Kaputte verschwindet still. Marker für Wecker, Erinnerung und Kalender gibt es in Lumen Fit nicht: sie fallen
// wie jeder unbekannte Marker weg. Reine Logik.
//
// Übernommen: `weiter` (Folgefragen) und `gehe` (Sprung). Neu für Lumen Fit: `gewohnheit`, `plan` und `merke` (die Handlungen der Chips).

enum CoachMarker {
    /// Seiten, zu denen `[[gehe: ...]]` springen darf.
    enum Ziel: String, Equatable, Sendable {
        case schritte, training, gewicht, verlauf, schlaf, essen

        var standardText: String {
            switch self {
            case .schritte: "Schritte öffnen"
            case .training: "Training öffnen"
            case .gewicht: "Gewicht öffnen"
            case .verlauf: "Verlauf öffnen"
            case .schlaf: "Schlaf öffnen"
            case .essen: "Essen öffnen"
            }
        }

        var route: Route {
            switch self {
            case .schritte: .heute
            case .training: .gym(.training)
            case .gewicht: .gewichtEintragen
            case .verlauf: .verlauf
            case .schlaf: .schlaf(.letzteNacht)
            case .essen: .essen(.heute)
            }
        }
    }

    enum Art: Equatable, Sendable {
        case weiter([String])
        case gehe(ziel: Ziel, beschriftung: String)
        /// `[[gewohnheit: Name]]`: der Chip "Mach ich" legt eine Gewohnheit an.
        case gewohnheit(name: String)
        /// `[[plan: morgen leicht]]`: der Chip "Morgen leicht".
        case planMorgenLeicht
        /// `[[merke: Text]]`: ein Eintrag für den Merkzettel (`CoachGedaechtnisRegeln.sauber`).
        case merke(String)
    }

    struct Zerlegt: Equatable, Sendable {
        let text: String
        let marker: [Art]
    }

    static let maxMarker = 4
    static let maxGewohnheitName = 40

    /// Trennt die Marker vom Text. Der Text kommt ohne Marker und ohne Leerraum am Ende zurück.
    static func zerlegen(_ roh: String) -> Zerlegt {
        var text = ""
        var marker: [Art] = []
        var rest = Substring(roh)
        while let start = rest.range(of: "[[") {
            text.append(contentsOf: rest[rest.startIndex..<start.lowerBound])
            let danach = rest[start.upperBound...]
            guard let ende = danach.range(of: "]]") else {
                // Antwort mitten im Marker abgeschnitten: nur wegwerfen, wenn es nach Marker aussieht.
                if !klingtNachMarker(danach) { text.append(contentsOf: rest[start.lowerBound...]) }
                rest = rest[rest.endIndex...]
                break
            }
            let inhalt = danach[danach.startIndex..<ende.lowerBound]
            if let (name, argument) = kopf(inhalt) {
                if marker.count < maxMarker, let art = pruefen(name: name, argument: argument) { marker.append(art) }
            } else {
                text.append(contentsOf: rest[start.lowerBound..<ende.upperBound])
            }
            rest = danach[ende.upperBound...]
        }
        text.append(contentsOf: rest)
        return Zerlegt(text: text.trimmingCharacters(in: .whitespacesAndNewlines), marker: marker)
    }

    // MARK: - Einzelne Marker

    private static let schluessel: Set<String> = ["weiter", "gehe", "gewohnheit", "plan", "merke"]

    /// `name: argument` mit einem Namen aus Buchstaben und Unterstrichen. Alles andere ist kein Marker und bleibt Text.
    private static func kopf(_ inhalt: Substring) -> (name: String, argument: String)? {
        guard inhalt.count <= 800, let doppelpunkt = inhalt.firstIndex(of: ":") else { return nil }
        let name = inhalt[inhalt.startIndex..<doppelpunkt].trimmingCharacters(in: .whitespaces).lowercased()
        guard (1...16).contains(name.count), name.allSatisfy(istNamenszeichen) else { return nil }
        let argument = inhalt[inhalt.index(after: doppelpunkt)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (name, argument)
    }

    private static func klingtNachMarker(_ danach: Substring) -> Bool {
        let anfang = danach.prefix { $0 != ":" }.trimmingCharacters(in: .whitespaces)
        return anfang.count <= 16 && anfang.allSatisfy(istNamenszeichen)
    }

    private static func istNamenszeichen(_ zeichen: Character) -> Bool { zeichen.isLetter || zeichen == "_" }

    private static func felder(_ argument: String) -> [String] {
        argument.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func pruefen(name: String, argument: String) -> Art? {
        guard schluessel.contains(name) else { return nil }
        let teile = felder(argument)
        switch name {
        case "weiter":
            let fragen = teile.filter { !$0.isEmpty && $0.count <= 60 }.prefix(3)
            return fragen.isEmpty ? nil : .weiter(Array(fragen))
        case "gehe":
            guard let ziel = Ziel(rawValue: teile[0].lowercased()) else { return nil }
            let beschriftung = teile.count > 1 ? String(teile[1].prefix(24)) : ""
            return .gehe(ziel: ziel, beschriftung: beschriftung.isEmpty ? ziel.standardText : beschriftung)
        case "gewohnheit":
            let titel = teile[0]
            guard (2...maxGewohnheitName).contains(titel.count), !titel.contains(where: \.isNewline) else { return nil }
            return .gewohnheit(name: titel)
        case "plan":
            return ["morgen leicht", "morgen_leicht"].contains(teile[0].lowercased()) ? .planMorgenLeicht : nil
        default:
            return CoachGedaechtnisRegeln.sauber(argument).map { Art.merke($0) }
        }
    }
}

// MARK: - Zugriff für die Ansicht

extension CoachMarker.Zerlegt {
    var folgefragen: [String] {
        for art in marker { if case .weiter(let fragen) = art { return fragen } }
        return []
    }

    var wege: [(ziel: CoachMarker.Ziel, beschriftung: String)] {
        marker.compactMap { art -> (ziel: CoachMarker.Ziel, beschriftung: String)? in
            if case .gehe(let ziel, let beschriftung) = art { return (ziel, beschriftung) }
            return nil
        }
    }

    var merkeTexte: [String] {
        marker.compactMap { art -> String? in
            if case .merke(let text) = art { return text }
            return nil
        }
    }

    /// Die Marker als Chips mit Handlung: Folgefragen antworten, `gehe` öffnet die Seite, `gewohnheit` und `plan` handeln.
    var chips: [CoachChip] {
        marker.compactMap { art -> [CoachChip]? in
            switch art {
            case .weiter(let fragen):
                return fragen.map { CoachChip(id: "frage-\(CoachLokal.schluessel($0))", text: $0, aktion: .antworten($0)) }
            case .gehe(let ziel, let beschriftung):
                return [CoachChip(id: "gehe-\(ziel.rawValue)", text: beschriftung, aktion: .oeffne(ziel.route))]
            case .gewohnheit(let name):
                return [CoachChip(id: "gewohnheit-\(CoachLokal.schluessel(name))", text: "Mach ich", aktion: .gewohnheitAnlegen(name: name))]
            case .planMorgenLeicht:
                return [CoachChip(id: "plan-morgen-leicht", text: "Morgen leicht", aktion: .planMorgenLeicht)]
            case .merke:
                return nil
            }
        }.flatMap { $0 }
    }
}
