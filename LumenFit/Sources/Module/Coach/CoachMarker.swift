// Quelle: Lovea Health/Coach/CoachMarker.swift
import Foundation

// Health-Coach, Marker: eine Antwort darf am Ende bis zu vier Zeilen der Form `[[name: a | b]]` tragen. Das Sprachmodell liefert Chips
// strukturiert; die Marker sind der zweite Weg (Textbausteine, ältere Verläufe) und der Schutz, dass nie ein halber Marker im Chat steht.
// Alles Unbekannte oder Kaputte verschwindet still. Marker für Kalender gibt es in Lumen Fit nicht: sie fallen wie jeder unbekannte Marker weg.
// Wecker und Erinnerungen (`wecker`, `erinnern`, `CoachWecker.swift`) werden Aufträge für Lumen Alarm, nie ein Wecker in Lumen Fit. Reine Logik.
//
// Übernommen: `weiter` (Folgefragen), `gehe` (Sprung), `chart` und `linie` (Diagramm), `fortschritt` (Ring), `ziel`, `schlaf` (Nacht),
// die Eintrags-Marker `essen`, `mahlzeit`, `wasser`, `supplement` (Kreatin), `gefuehl` (Schlafgefühl), `gewicht`, die Gedächtnis-Marker
// `merke`, `aendere`, `vergiss` und die Training-Marker `training`, `satz`, `tausche`. Neu für Lumen Fit: `gewohnheit` und `plan` (Chips).
// Eintrags-Marker trägt die App nie von selbst ein: sie werden zum Vorschlag mit Bestätigen und Rückgängig (`CoachTracking.Eintrag`).

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
        /// `[[chart: Titel | Mo 8200 | Di 7400 | ...]]` (Balken) und `[[linie: ...]]` (Linie): drei bis acht Punkte.
        case chart(titel: String, punkte: [Punkt])
        case linie(titel: String, punkte: [Punkt])
        /// `[[fortschritt: Schritte | 6200 | 8000]]`: ein Ring mit "Mehr dazu".
        case fortschritt(label: String, aktuell: Double, ziel: Double)
        /// `[[ziel: Text]]`: Vorschlag für das eigene Ziel (nie mit Gewicht, Kilo, Kalorien oder Abnehmen).
        case ziel(String)
        /// `[[schlaf: JJJJ-MM-TT]]`: Nacht-Diagramm aus den Gesundheitsdaten (Aufwachtag).
        case schlafNacht(tag: String)
        /// Eintrags-Marker: `essen` (geschätzte Mahlzeit, kurze Form), `mahlzeit` (volle Form), `wasser` (ml), `supplement` (Kreatin in g),
        /// `gefuehl` (Schlafgefühl) und `gewicht` (kg).
        case essen(Essen)
        case mahlzeit(MahlzeitDaten)
        case wasser(ml: Int)
        case kreatin(gramm: Double)
        case schlafGefuehl(Gefuehl)
        case gewicht(kg: Double)
        /// Gedächtnis: `aendere` ersetzt den Eintrag mit dieser Kennung (Schlüssel oder ganzer Text), `vergiss` löscht ihn.
        case aendere(id: String, text: String)
        case vergiss(id: String)
        /// Training-Marker: Einheit starten (optional mit Trainingstag) oder beenden, Satz eintragen, Übung tauschen.
        /// `uebung` ist die Plan-Id aus dem Kontext, `katalogId` eine Katalog-Id oder ein Name. Geprüft ist hier nur die Form.
        case trainingStart(name: String?)
        case trainingEnde
        case satz(uebung: String, kg: Double, wdh: Int)
        case tausche(uebung: String, katalogId: String)
        /// `[[wecker: ...]]` und `[[erinnern: ...]]`: ein Befehl für Lumen Alarm (nur die Form ist geprüft, die Ids prüft `WeckerBefehl.geprueft`).
        case weckerSteuern(WeckerBefehl)
    }

    struct Punkt: Equatable, Sendable {
        let label: String
        let wert: Double
    }

    /// `[[essen: Name | mahlzeit | kcal | Eiweiß | Kohlenhydrate | Fett]]`, die letzten drei optional.
    struct Essen: Equatable, Sendable {
        let name: String
        let art: Mahlzeit?
        let kcal: Int
        let protein: Double?
        let kohlenhydrate: Double?
        let fett: Double?
    }

    /// `[[mahlzeit: Mahlzeit | Name | kcal | Eiweiß | Kohlenhydrate | Fett | Zucker]]`, der Zucker ist optional.
    struct MahlzeitDaten: Equatable, Sendable {
        let mahlzeit: Mahlzeit
        let name: String
        let kcal: Int
        let eiweiss: Double
        let kohlenhydrate: Double
        let fett: Double
        let zucker: Double?
    }

    /// `[[gefuehl: schlaf | gut]]`: die eigene Aussage der Person. Wert 1 bis 3.
    enum Gefuehl: String, Equatable, Sendable {
        case schlecht, mittel, gut

        var wert: Int {
            switch self {
            case .schlecht: 1
            case .mittel: 2
            case .gut: 3
            }
        }
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

    private static let schluessel: Set<String> = ["weiter", "gehe", "gewohnheit", "plan", "merke", "chart", "linie", "fortschritt", "ziel", "schlaf",
                                                   "essen", "mahlzeit", "wasser", "supplement", "gefuehl", "gewicht", "aendere", "vergiss",
                                                   "training", "satz", "tausche", "wecker", "erinnern"]
    private static let verbotenImZiel = ["kg", "abnehm", "kcal", "kalor", "gewicht", "defizit", "körperfett"]

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
        case "chart", "linie":
            guard teile.count >= 4, !teile[0].isEmpty else { return nil }
            let punkte = teile.dropFirst().compactMap(punkt).prefix(8)
            guard punkte.count >= 3 else { return nil }
            let titel = String(teile[0].prefix(40))
            return name == "chart" ? .chart(titel: titel, punkte: Array(punkte)) : .linie(titel: titel, punkte: Array(punkte))
        case "fortschritt":
            guard teile.count == 3, !teile[0].isEmpty, let aktuell = zahl(teile[1]), let ziel = zahl(teile[2]), aktuell >= 0, ziel > 0 else { return nil }
            return .fortschritt(label: String(teile[0].prefix(40)), aktuell: aktuell, ziel: ziel)
        case "schlaf":
            guard teile.count == 1, SchlafNachtLogik.gueltigerTag(teile[0]) else { return nil }
            return .schlafNacht(tag: teile[0])
        case "wasser":
            guard teile.count == 1, let ml = zahl(teile[0], einheit: "ml"), (50...2000).contains(ml.rounded()) else { return nil }
            return .wasser(ml: Int(ml.rounded()))
        case "supplement":
            // Nur Kreatin; ohne Menge eine Portion. Alles andere fällt weg.
            guard ["kreatin", "creatin"].contains(teile[0].lowercased()), teile.count <= 2 else { return nil }
            let gramm: Double? = teile.count == 2 ? zahl(teile[1], einheit: "g") : Habit.creatinGramm
            guard let gramm, (0.5...20).contains(gramm) else { return nil }
            return .kreatin(gramm: gramm)
        case "gefuehl":
            guard teile.count == 2, teile[0].lowercased() == "schlaf", let gefuehl = Gefuehl(rawValue: teile[1].lowercased()) else { return nil }
            return .schlafGefuehl(gefuehl)
        case "gewicht":
            return kilo(argument).map { Art.gewicht(kg: $0) }
        case "essen":
            guard teile.count >= 3, !teile[0].isEmpty, let kcal = zahl(teile[2]), (1...5000).contains(kcal.rounded()) else { return nil }
            let werte = teile.dropFirst(3).prefix(3).map { zahl($0).map { min(max($0, 0), 1000) } }
            func wert(_ i: Int) -> Double? { i < werte.count ? werte[i] : nil }
            return .essen(Essen(name: String(teile[0].prefix(60)), art: mahlzeitArt(teile[1]), kcal: Int(kcal.rounded()),
                                protein: wert(0), kohlenhydrate: wert(1), fett: wert(2)))
        case "mahlzeit":
            return mahlzeitDaten(teile).map(Art.mahlzeit)
        case "aendere":
            guard let strich = argument.firstIndex(of: "|") else { return nil }
            let id = argument[..<strich].trimmingCharacters(in: .whitespaces)
            let text = String(argument[argument.index(after: strich)...])
            guard kennung(id), let sauber = CoachGedaechtnisRegeln.sauber(text) else { return nil }
            return .aendere(id: id, text: sauber)
        case "vergiss":
            return kennung(argument) ? .vergiss(id: argument) : nil
        case "training":
            let wort = teile[0].lowercased()
            if wort == "ende", teile.count == 1 { return .trainingEnde }
            guard wort == "start", teile.count <= 2 else { return nil }
            if teile.count == 1 { return .trainingStart(name: nil) }
            return kennung(teile[1]) ? .trainingStart(name: teile[1]) : nil
        case "satz":
            guard teile.count == 3, kennung(teile[0]), let kg = hantelKilo(teile[1]), let wdh = ganzzahl(teile[2], 1...100) else { return nil }
            return .satz(uebung: teile[0], kg: kg, wdh: wdh)
        case "wecker", "erinnern":
            return WeckerBefehl.aus(name, teile).map(Art.weckerSteuern)
        case "tausche":
            guard teile.count == 2, kennung(teile[0]), kennung(teile[1]) else { return nil }
            return .tausche(uebung: teile[0], katalogId: teile[1])
        case "ziel":
            let text = String(argument.prefix(100)).trimmingCharacters(in: .whitespaces)
            let klein = text.lowercased()
            guard !text.isEmpty, !text.contains(where: \.isNewline), !verbotenImZiel.contains(where: { klein.contains($0) }) else { return nil }
            return .ziel(text)
        default:
            return CoachGedaechtnisRegeln.sauber(argument).map { Art.merke($0) }
        }
    }

    // MARK: - Hilfen für Zahlen und Kennungen

    private static func zahl(_ text: String) -> Double? {
        guard let wert = Double(text.replacingOccurrences(of: ",", with: ".")), wert.isFinite else { return nil }
        return wert
    }

    /// "250" oder "250 ml": die Einheit am Ende ist erlaubt.
    private static func zahl(_ text: String, einheit: String) -> Double? {
        var t = text.lowercased()
        if t.hasSuffix(einheit) { t = String(t.dropLast(einheit.count)) }
        return zahl(t.trimmingCharacters(in: .whitespaces))
    }

    /// "81,3", "81.3", "81 kg": 1 bis 3 Ziffern, höchstens ein Trenner mit genau einer Nachkommastelle, 30 bis 300 kg. Sonst `nil`.
    static func kilo(_ argument: String) -> Double? {
        var t = argument.lowercased()
        if t.hasSuffix("kg") { t = String(t.dropLast(2)) }
        t = t.trimmingCharacters(in: .whitespaces)
        let teile = t.split(omittingEmptySubsequences: false) { $0 == "." || $0 == "," }
        guard (1...2).contains(teile.count) else { return nil }
        let nachkomma = teile.count == 2 ? teile[1] : "0"
        guard (1...3).contains(teile[0].count), nachkomma.count == 1 else { return nil }
        guard (teile[0] + nachkomma).allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        guard let kg = Double("\(teile[0]).\(nachkomma)"), (30.0...300.0).contains(kg) else { return nil }
        return kg
    }

    /// Eine Id oder ein Name: 1 bis 80 Zeichen, ohne Klammern, Strich und Zeilenumbruch.
    private static func kennung(_ text: String) -> Bool {
        (1...80).contains(text.count) && !text.contains { $0 == "[" || $0 == "]" || $0 == "|" || $0.isNewline }
    }

    /// Ganze Zahl in `bereich`: nur ASCII-Ziffern, höchstens drei Stellen.
    private static func ganzzahl(_ text: String, _ bereich: ClosedRange<Int>) -> Int? {
        guard (1...3).contains(text.count), text.allSatisfy({ $0.isASCII && $0.isNumber }), let n = Int(text), bereich.contains(n) else { return nil }
        return n
    }

    /// Gewicht einer Hantel: "80", "62,5", "62.25", "80 kg". 0 bis 500 kg, höchstens zwei Nachkommastellen, nur ASCII-Ziffern. Sonst `nil`.
    private static func hantelKilo(_ argument: String) -> Double? {
        var t = argument.lowercased()
        if t.hasSuffix("kg") { t = String(t.dropLast(2)) }
        t = t.trimmingCharacters(in: .whitespaces)
        let teile = t.split(omittingEmptySubsequences: false) { $0 == "." || $0 == "," }
        guard (1...2).contains(teile.count), (1...3).contains(teile[0].count), teile.count == 1 || (1...2).contains(teile[1].count) else { return nil }
        let text = teile.joined(separator: ".")
        guard text.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." }), let kg = Double(text), (0.0...500.0).contains(kg) else { return nil }
        return kg
    }

    /// Dieselben Grenzen wie in Lovea: sechs oder sieben Felder, nur Zahlen, die Werte müssen zu den kcal passen.
    private static func mahlzeitDaten(_ teile: [String]) -> MahlzeitDaten? {
        guard (6...7).contains(teile.count), let mahlzeit = mahlzeitArt(teile[0]), !teile[1].isEmpty, teile[1].count <= 60 else { return nil }
        let zahlen = teile.dropFirst(2).compactMap { zahl($0) }
        guard zahlen.count == teile.count - 2, zahlen.allSatisfy({ $0 >= 0 }) else { return nil }
        let (kcal, eiweiss, kh, fett) = (zahlen[0], zahlen[1], zahlen[2], zahlen[3])
        guard kcal.rounded() >= 1, kcal <= 5000, eiweiss <= 300, kh <= 1000, fett <= 500 else { return nil }
        guard abs(4 * eiweiss + 4 * kh + 9 * fett - kcal) <= max(60, kcal * 0.5) else { return nil }
        return MahlzeitDaten(mahlzeit: mahlzeit, name: teile[1], kcal: Int(kcal.rounded()), eiweiss: eiweiss, kohlenhydrate: kh, fett: fett,
                             zucker: zahlen.count > 4 ? min(zahlen[4], kh) : nil)
    }

    private static func mahlzeitArt(_ text: String) -> Mahlzeit? {
        switch text.lowercased() {
        case "fruehstueck", "frühstück": .fruehstueck
        case "mittag", "mittagessen": .mittag
        case "abend", "abendessen": .abend
        case "snack", "snacks": .snack
        default: nil
        }
    }

    /// "Mo 8200" oder "12.10. 7400": das letzte Wort ist der Wert, der Rest das Label.
    private static func punkt(_ teil: String) -> Punkt? {
        guard let leer = teil.lastIndex(of: " ") else { return nil }
        let label = teil[teil.startIndex..<leer].trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, let wert = zahl(String(teil[teil.index(after: leer)...])), wert >= 0 else { return nil }
        return Punkt(label: String(label.prefix(12)), wert: wert)
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

    var diagramm: (titel: String, punkte: [CoachMarker.Punkt])? {
        for art in marker { if case .chart(let titel, let punkte) = art { return (titel, punkte) } }
        return nil
    }

    var linie: (titel: String, punkte: [CoachMarker.Punkt])? {
        for art in marker { if case .linie(let titel, let punkte) = art { return (titel, punkte) } }
        return nil
    }

    var fortschritt: (label: String, aktuell: Double, ziel: Double)? {
        for art in marker { if case .fortschritt(let label, let aktuell, let ziel) = art { return (label, aktuell, ziel) } }
        return nil
    }

    var vorgeschlagenesZiel: String? {
        for art in marker { if case .ziel(let text) = art { return text } }
        return nil
    }

    /// Aufwachtag der Nacht, deren Diagramm gezeigt werden soll (höchstens eins).
    var schlafNacht: String? {
        for art in marker { if case .schlafNacht(let tag) = art { return tag } }
        return nil
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
            default:
                return nil
            }
        }.flatMap { $0 }
    }
}
