import Foundation

// Satz-Vorschlag (Auftrag 09.11.2026: "smart prediction helping with each sets for reps and kg calculations from the strength messured. For maximum growth"):
// aus der gemessenen Stärke (geschätztes 1RM der letzten Sätze, mit Reserve) Gewicht und Wiederholungen für den nächsten Satz. Formeln, Zahlen und
// Quellen: docs/research/satz-vorhersage.md. Reine Logik ohne Oberfläche und ohne Speicher; die Ansicht steht in SatzVorhersageAnzeige.swift.

/// Grobe Art einer Übung für Wiederholungsbereich und Reserve.
enum VorhersageArt: Equatable, Sendable {
    /// Freie Grundübung (Langhantel, Kurzhantel, SZ-Stange, Kettlebell, Zusatzgewicht, Körpergewicht): mehrgelenkig und schwer.
    case grund
    /// Grundübung an Maschine, Kabel, Multipresse oder Schlitten (Beinpresse, Latzug, Brustpresse, Rudern am Kabel).
    case maschine
    /// Eingelenkig (Curl, Beinstrecker, Beinbeuger, Fliegende, Trizepsdrücken).
    case isolation
    /// Kleine Muskeln (Waden, Unterarme, Bauch, Nacken).
    case klein
}

/// Wie schwer trainiert wird. `schwer` ist der Wunsch aus dem Auftrag ("mehr Gewicht, weniger Wiederholungen") und der Standard.
enum VorhersageZiel: String, CaseIterable, Identifiable, Sendable {
    case schwer, klassisch

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .schwer: "Schwer"
        case .klassisch: "Klassisch"
        }
    }

    /// Die Bereiche in Worten, für den Hinweis unter der Wahl.
    var bereicheText: String {
        switch self {
        case .schwer: "Grundübungen 4 bis 8, Maschinen und Isolation 6 bis 10, kleine Muskeln 8 bis 12 Wiederholungen."
        case .klassisch: "Grundübungen 6 bis 10, Maschinen und Isolation 8 bis 12, kleine Muskeln 10 bis 15 Wiederholungen."
        }
    }
}

/// Warum der Vorschlag so aussieht (eine Zeile unter dem Vorschlag).
enum VorschlagGrund: Equatable, Sendable {
    /// Letztes Mal oben im Bereich: ein Schritt mehr Gewicht.
    case mehrGewicht(Double)
    /// Letztes Mal weit über dem Bereich: so viel schwerer, dass die Wiederholungen in den Bereich fallen.
    case inDenBereich(Double)
    case mehrWiederholungen
    case halten
    case leichter(Double)
    /// Im Training: der letzte Satz war leicht.
    case schwerer(Double)
    /// Im Training: gleiches Gewicht, die Ermüdung des letzten Satzes ist eingerechnet.
    case ermuedung
    case deload
    case nachPause(Int)
    case aufwaermen(Int)
    case drop
    case ohneGewicht

    var text: String {
        switch self {
        case .mehrGewicht(let kg): "+\(TrainingLogik.kgText(kg)) kg: letztes Mal oben im Bereich geschafft"
        case .inDenBereich(let kg): "+\(TrainingLogik.kgText(kg)) kg: mehr Gewicht, weniger Wiederholungen"
        case .mehrWiederholungen: "Gleiches Gewicht, eine Wiederholung mehr als letztes Mal"
        case .halten: "Gleich wie letztes Mal, diesmal sauberer"
        case .leichter(let kg): "−\(TrainingLogik.kgText(kg)) kg, damit die Wiederholungen im Bereich bleiben"
        case .schwerer(let kg): "+\(TrainingLogik.kgText(kg)) kg: der letzte Satz war leicht"
        case .ermuedung: "Gleiches Gewicht, die Ermüdung ist eingerechnet"
        case .deload: "\(SatzVorhersageLogik.stillstandEinheiten) Einheiten ohne Fortschritt: heute 10 % leichter, gern ein Satz weniger (Deload)"
        case .nachPause(let tage): "Nach \(tage) Tagen Pause etwas leichter einsteigen"
        case .aufwaermen(let prozent): "Aufwärmen mit \(prozent) % vom Arbeitsgewicht"
        case .drop: "Dropsatz: 20 % leichter, so viele wie sauber gehen"
        case .ohneGewicht: "Eine Wiederholung mehr als zuletzt"
        }
    }

    /// Aufwärm- und Dropsätze haben kein Reserve-Ziel.
    var mitReserve: Bool {
        switch self {
        case .aufwaermen, .drop: false
        default: true
        }
    }
}

/// Ein Vorschlag für einen Satz. `kg` nil heißt ohne Gewicht. `reserve`: so viele Wiederholungen sollen am Ende noch drin sein (RIR).
struct SatzVorschlag: Equatable, Sendable {
    var kg: Double?
    var wdh: Int
    var reserve: Int
    var grund: VorschlagGrund

    /// "62,5 kg × 8", ohne Gewicht "12 Wdh".
    var text: String { kg.map { "\(TrainingLogik.kgText($0)) kg × \(wdh)" } ?? "\(wdh) Wdh" }

    /// "1 Wdh Reserve", bei 0 "bis kurz vor Schluss"; nil bei Aufwärm- und Dropsätzen.
    var reserveText: String? {
        guard grund.mitReserve else { return nil }
        return reserve == 0 ? "bis kurz vor Schluss" : "\(reserve) Wdh Reserve"
    }

    /// Steht genau das schon in der Zeile?
    func passt(_ satz: PlanSatz) -> Bool {
        satz.wdh == wdh && abs((satz.kg ?? 0) - (kg ?? 0)) < 0.01
    }
}

enum SatzVorhersageLogik {
    /// Reserve, wenn am Satz keine Anstrengung (RPE) eingetragen ist (Annahme, keine Studie: Arbeitssätze enden meist 2 bis 4 vor dem Versagen).
    static let annahmeReserve = 2.0
    /// So viele Einheiten ohne neuen Bestwert gelten als Stillstand: dann eine leichtere Einheit (Deload).
    static let stillstandEinheiten = 3
    static let deloadFaktor = 0.9
    /// Höchstens so viel schwerer je Einheit, mindestens aber ein Schritt (Technik vor Gewicht).
    static let maxSprung = 0.10
    /// Eine Einheit unter diesem Anteil des Bestwerts davor war leicht (Deload oder schlechter Tag).
    static let leichtGrenze = 0.93
    /// Ein abgehakter Satz unter diesem Anteil des vorgeschlagenen Arbeitsgewichts ist ein Rampensatz (nicht als Aufwärmen markiert) und steuert nichts.
    static let rampenGrenze = 0.8

    // MARK: - Stärke

    /// Anteil vom 1RM, mit dem genau `wiederholungen` bis zum Versagen gehen: Epley, wie das 1RM der Rekorde (`RekordLogik.e1rm`). Von 4 bis 10
    /// Wiederholungen liegt Epley höchstens 1,1 Punkte neben der RPE-Tabelle von Tuchscherer; 1 Wiederholung ist das 1RM selbst, über 30 wird nicht gerechnet.
    static func anteil(_ wiederholungen: Double) -> Double {
        wiederholungen <= 1 ? 1 : 1 / (1 + min(wiederholungen, 30) / 30)
    }

    /// Umkehrung von `anteil`: wie viele Wiederholungen bis zum Versagen mit diesem Anteil vom 1RM gehen (1 bis 30).
    static func wiederholungen(anteil a: Double) -> Double {
        guard a > 0 else { return 30 }
        return min(max(30 * (1 / a - 1), 1), 30)
    }

    /// Geschätztes 1RM aus Gewicht, Wiederholungen und Reserve (Wiederholungen bis zum Versagen = Wiederholungen + Reserve).
    static func e1rm(kg: Double, wdh: Int, reserve: Double) -> Double {
        kg / anteil(Double(wdh) + reserve)
    }

    /// Die Reserve eines Satzes: 0 bei "bis zum Versagen", sonst 10 − RPE (0 bis 5); nil ohne Angabe.
    static func reserve(_ s: PlanSatz) -> Double? {
        if s.failure { return 0 }
        guard let rpe = s.rpe else { return nil }
        return min(max(10 - rpe, 0), 5)
    }

    /// Arbeitssätze: ohne Aufwärm- und Dropsätze, mit Wiederholungen.
    static func arbeit(_ saetze: [PlanSatz]) -> [PlanSatz] {
        saetze.filter { $0.typ != "w" && $0.typ != "d" && $0.wdh > 0 }
    }

    /// Bestes geschätztes 1RM der Arbeitssätze mit Gewicht; nil ohne. Sätze mit höchstens 12 Wiederholungen bis zum Versagen gehen vor (genauer),
    /// gibt es keine, zählen alle.
    static func staerke(_ saetze: [PlanSatz]) -> Double? {
        let werte = arbeit(saetze).compactMap { s -> (n: Double, e: Double)? in
            guard let kg = s.kg, kg > 0 else { return nil }
            let r = reserve(s) ?? annahmeReserve
            return (Double(s.wdh) + r, e1rm(kg: kg, wdh: s.wdh, reserve: r))
        }
        let genau = werte.filter { $0.n <= 12 }
        return (genau.isEmpty ? werte : genau).map { $0.e }.max()
    }

    /// Wiederholungen bei `kg`, wenn danach noch `reserve` übrig sein sollen (abgerundet, nie unter 0).
    static func wdh(bei kg: Double, staerke: Double, reserve: Int) -> Int {
        guard staerke > 0, kg > 0 else { return 0 }
        return max(0, Int((wiederholungen(anteil: kg / staerke) - Double(reserve) + 0.05).rounded(.down)))
    }

    /// So viele Wiederholungen verliert der nächste Satz mit gleichem Gewicht: je näher am Versagen und je kürzer die Pause, desto mehr
    /// (Refalo 2023, 4 min Pause: bis Versagen 1,5, 1 Reserve 1,0, 3 Reserve 0,55 je Satz; Miranda 2009: 1 min Pause rund 1,7-mal so viel wie 3 min).
    static func abfall(reserve: Double, pause: Int) -> Double {
        let basis: Double = reserve < 1 ? 1.5 : reserve < 2 ? 1 : reserve < 3 ? 0.75 : 0.5
        let faktor: Double = pause > 0 && pause < 90 ? 1.6 : pause > 0 && pause < 150 ? 1.25 : pause > 0 && pause < 210 ? 1 : 0.9
        return basis * faktor
    }

    /// Auf den Schritt des Geräts abgerundet.
    static func abrunden(_ kg: Double, schritt: Double) -> Double {
        guard schritt > 0 else { return kg }
        return ((kg + 0.0001) / schritt).rounded(.down) * schritt
    }

    // MARK: - Art, Bereich, Reserve

    private static let kleinMuskeln: Set<String> = ["Waden", "Unterarme", "Bauch", "Nacken", "Schulterblattheber"]
    // Wörter in der Form von `UebungsKatalog.normal` (klein, ohne Umlaute, "ue" als "u", Bindestrich als Leerzeichen).
    private static let isolationWorte = [
        "curl", "fliegend", "butterfly", "flys", "beinstreck", "beinbeug", "extension", "kickback", "crunch", "shrug", "adduktor", "abduktor",
        "pullover", "uberzug", "uber kreuz", "trizepsdruck", "trizeps druck", "stirndruck", "french press", "pushdown", "pec deck",
    ]
    private static let verbundWorte = [
        "druck", "press", "kniebeuge", "squat", "kreuzheben", "deadlift", "rudern", "row", "latzug", "lat zug", "klimmzug", "pulldown",
        "pull up", "chin up", "dips", "ausfallschritt", "lunge", "hip thrust", "step up", "good morning", "thruster", "hackenschmidt",
    ]
    private static let freieGeraete: Set<String> = ["Langhantel", "Olympia-Langhantel", "Kurzhantel", "SZ-Stange", "Kettlebell", "Trap-Bar", "Zusatzgewicht", "Körpergewicht"]

    /// Die Art aus Katalog und Name; nil heißt kein Vorschlag (Cardio, assistierte Maschine: dort ist mehr Gewicht leichter).
    static func art(_ uebung: Uebung?, name: String) -> VorhersageArt? {
        let geraet = uebung?.geraet ?? ""
        guard geraet != "Assistiert", uebung?.istCardio != true else { return nil }
        let n = UebungsKatalog.normal(name)
        if kleinMuskeln.contains(uebung?.muskel ?? "") { return .klein }
        if isolationWorte.contains(where: { n.contains($0) }) { return .isolation }
        guard verbundWorte.contains(where: { n.contains($0) }) || (uebung?.neben.count ?? 0) >= 3 else { return .isolation }
        return freieGeraete.contains(geraet) ? .grund : .maschine
    }

    static func bereich(_ art: VorhersageArt, ziel: VorhersageZiel) -> ClosedRange<Int> {
        switch (art, ziel) {
        case (.grund, .schwer): 4...8
        case (.maschine, .schwer), (.isolation, .schwer), (.grund, .klassisch): 6...10
        case (.klein, .schwer), (.maschine, .klassisch), (.isolation, .klassisch): 8...12
        case (.klein, .klassisch): 10...15
        }
    }

    /// Ziel-Reserve: freie Grundübungen 2, sonst 1; der letzte Arbeitssatz einer Übung eine weniger; ein Satz "bis zum Versagen" 0.
    static func zielReserve(_ art: VorhersageArt, letzter: Bool, versagen: Bool) -> Int {
        if versagen { return 0 }
        let basis = art == .grund ? 2 : 1
        return letzter ? basis - 1 : basis
    }

    /// Aufwärmsätze je nach Anzahl der Aufwärmzeilen, eher schwer als leicht (Ribeiro 2020): einer 60 % × 6, zwei 65 % × 5 und 85 % × 2,
    /// ab drei wie "Aufwärmsätze einfügen" (`AufwaermRechner.standard`), damit Vorschlag und eingefügte Zeilen gleich sind.
    static func aufwaermStufen(anzahl: Int) -> [AufwaermRechner.Stufe] {
        switch anzahl {
        case ...1: [AufwaermRechner.Stufe(prozent: 60, wdh: 6)]
        case 2: [AufwaermRechner.Stufe(prozent: 65, wdh: 5), AufwaermRechner.Stufe(prozent: 85, wdh: 2)]
        default: AufwaermRechner.standard
        }
    }

    /// Scheiben pro Seite für Langhantel-Übungen ("20, 2 × 1,25"); nil, wenn es nicht genau aufgeht oder keine Langhantel ist.
    static func scheiben(kg: Double, geraet: String?) -> String? {
        guard geraet == "Langhantel" || geraet == "Olympia-Langhantel", kg > ScheibenRechner.stange else { return nil }
        let e = ScheibenRechner.berechne(kg: kg)
        return e.rest > 0 ? nil : ScheibenRechner.text(e)
    }

    // MARK: - Vorschlag

    /// Der Vorschlag für Zeile `i` (offen, also ohne Haken). `saetze`: die Zeilen der Übung heute; `historie`: frühere Einheiten mit ihren gezählten Sätzen,
    /// älteste zuerst (`RekordLogik.tage`, ohne das laufende Training); `schritt`: Gewichtsschritt des Geräts; `pause`: Pausenziel in Sekunden (0 = ohne);
    /// `heute`: `yyyy-MM-dd`. nil, wenn es nichts Gemessenes gibt.
    static func vorschlag(zeile i: Int, saetze: [PlanSatz], historie: [UebungTag], art: VorhersageArt, schritt: Double,
                          ziel: VorhersageZiel = .schwer, pause: Int = WorkoutLogik.standardPause, heute: String) -> SatzVorschlag? {
        guard saetze.indices.contains(i), saetze[i].ok != true, schritt > 0 else { return nil }
        let bereich = Self.bereich(art, ziel: ziel)
        if saetze[i].typ == "w" {
            return aufwaermen(zeile: i, saetze: saetze, historie: historie, art: art, schritt: schritt, bereich: bereich, heute: heute)
        }
        if saetze[i].typ == "d" { return drop(nach: saetze[..<i].last(where: { $0.typ != "w" }), schritt: schritt) }
        let letzter = !saetze[(i + 1)...].contains { $0.typ != "w" }
        let rir = zielReserve(art, letzter: letzter, versagen: saetze[i].failure)
        let erster = ersterSatz(historie: historie, bereich: bereich, rir: rir, schritt: schritt, heute: heute)
        // Leichte Rampensätze vor dem schweren Satz (oft nicht als Aufwärmen markiert) steuern den nächsten Satz nicht.
        let fertig = arbeit(saetze.filter { $0.ok == true }).filter { s in
            guard let ziel = erster?.kg, let kg = s.kg else { return true }
            return kg >= ziel * rampenGrenze
        }
        if let zuletzt = fertig.last {
            return imTraining(nach: zuletzt, bereich: bereich, rir: rir, schritt: schritt, pause: pause)
        }
        return erster
    }

    /// Erster Arbeitssatz der Einheit: doppelte Progression aus der letzten Einheit (oben im Bereich: mehr Gewicht; darin: eine Wiederholung mehr;
    /// darunter: leichter), dazu Pause und Stillstand.
    private static func ersterSatz(historie: [UebungTag], bereich: ClosedRange<Int>, rir: Int, schritt: Double, heute: String) -> SatzVorschlag? {
        let einheiten = Array(historie.suffix(6))
        guard let letzte = einheiten.last else { return nil }
        let arbeitLetzte = arbeit(letzte.saetze)
        guard !arbeitLetzte.isEmpty else { return nil }
        guard arbeitLetzte.contains(where: { ($0.kg ?? 0) > 0 }) else {
            // Ohne Gewicht (Klimmzüge, Liegestütze): eine Wiederholung mehr als der beste Satz.
            return SatzVorschlag(kg: nil, wdh: (arbeitLetzte.map(\.wdh).max() ?? 0) + 1, reserve: rir, grund: .ohneGewicht)
        }
        let werte = einheiten.map { staerke($0.saetze) ?? 0 }
        var referenz = letzte
        let vorher = werte.dropLast().suffix(3)
        if let bestVorher = vorher.max(), let zuletzt = werte.last, bestVorher > 0, zuletzt < leichtGrenze * bestVorher,
           let j = vorher.indices.max(by: { werte[$0] < werte[$1] }) {
            // Die letzte Einheit war deutlich leichter (Deload oder schlechter Tag): weiter vom Stand davor.
            referenz = einheiten[j]
        }
        guard let top = topSatz(referenz.saetze), let w = top.kg else { return nil }
        let amGewicht = arbeit(referenz.saetze).filter { abs(($0.kg ?? 0) - w) < 0.01 }
        let r = top.wdh
        let tage = Datum.tageZwischen(Datum.text(letzte.datum), heute)
        if tage > 14 {
            let neu = abrunden(w * (tage > 28 ? 0.9 : 0.95), schritt: schritt)
            if neu > 0, neu < w {
                return SatzVorschlag(kg: neu, wdh: min(max(r, bereich.lowerBound), bereich.upperBound), reserve: rir, grund: .nachPause(tage))
            }
        }
        if referenz.id == letzte.id, stillstand(werte) {
            let neu = abrunden(w * deloadFaktor, schritt: schritt)
            if neu > 0, neu < w {
                return SatzVorschlag(kg: neu, wdh: min(max(r, bereich.lowerBound), bereich.upperBound), reserve: rir + 2, grund: .deload)
            }
        }
        let e = staerke(referenz.saetze) ?? e1rm(kg: w, wdh: r, reserve: annahmeReserve)
        let oben = r >= bereich.upperBound && amGewicht.allSatisfy { $0.wdh >= bereich.upperBound - 1 }
        if oben || r > bereich.upperBound + 1 {
            return schwerer(w: w, r: r, e: e, bereich: bereich, rir: rir, schritt: schritt)
        }
        if r < bereich.lowerBound {
            var neu = w
            while wdh(bei: neu, staerke: e, reserve: rir) < bereich.lowerBound, let tiefer = LetztesMal.kg(neu, richtung: -1, schritt: schritt), tiefer >= w * 0.7 {
                neu = tiefer
            }
            if neu < w {
                let rn = wdh(bei: neu, staerke: e, reserve: rir)
                return SatzVorschlag(kg: neu, wdh: min(max(rn, 1), bereich.upperBound), reserve: rir, grund: .leichter(w - neu))
            }
        }
        // Im Bereich: gleiches Gewicht und eine Wiederholung mehr; ging der Satz bis zum Versagen, erst einmal halten.
        if (reserve(top) ?? annahmeReserve) < 1 { return SatzVorschlag(kg: w, wdh: r, reserve: rir, grund: .halten) }
        return SatzVorschlag(kg: w, wdh: r + 1, reserve: rir, grund: .mehrWiederholungen)
    }

    /// Mehr Gewicht: ein Schritt; lag man weit über dem Bereich, so weit, dass oben im Bereich herauskommt (höchstens 10 % mehr oder ein Schritt).
    /// Fiele man mit dem Schritt unter den Bereich (grobe Stufen an Maschinen), erst Wiederholungen dazu; ab 3 über dem Bereich trotzdem hoch.
    private static func schwerer(w: Double, r: Int, e: Double, bereich: ClosedRange<Int>, rir: Int, schritt: Double) -> SatzVorschlag {
        guard var neu = LetztesMal.kg(w, richtung: 1, schritt: schritt), neu > w else {
            return SatzVorschlag(kg: w, wdh: r + 1, reserve: rir, grund: .mehrWiederholungen)
        }
        let weitDrueber = r > bereich.upperBound + 1
        if weitDrueber {
            let grenze = max(neu, w * (1 + maxSprung))
            while let weiter = LetztesMal.kg(neu, richtung: 1, schritt: schritt), weiter > neu, weiter <= grenze + 0.001,
                  wdh(bei: weiter, staerke: e, reserve: rir) >= bereich.upperBound {
                neu = weiter
            }
        }
        let rn = wdh(bei: neu, staerke: e, reserve: rir)
        guard rn >= bereich.lowerBound || r >= bereich.upperBound + 3 else {
            return SatzVorschlag(kg: w, wdh: r + 1, reserve: rir, grund: .mehrWiederholungen)
        }
        return SatzVorschlag(kg: neu, wdh: min(max(rn, bereich.lowerBound - 1, 1), bereich.upperBound), reserve: rir,
                             grund: weitDrueber ? .inDenBereich(neu - w) : .mehrGewicht(neu - w))
    }

    /// Nächster Satz im laufenden Training: die Stärke von heute aus dem letzten Satz, minus Ermüdung (Autoregulation). War er leicht, mehr Gewicht;
    /// fallen die Wiederholungen unter den Bereich, leichter (höchstens 30 % weniger).
    private static func imTraining(nach k: PlanSatz, bereich: ClosedRange<Int>, rir: Int, schritt: Double, pause: Int) -> SatzVorschlag {
        let rk = reserve(k) ?? annahmeReserve
        let kapazitaet = max(1, Double(k.wdh) + rk - abfall(reserve: rk, pause: pause))
        guard let w = k.kg, w > 0 else {
            return SatzVorschlag(kg: nil, wdh: max(1, Int((kapazitaet - Double(rir) + 0.05).rounded(.down))), reserve: rir, grund: .ermuedung)
        }
        let e = w / anteil(kapazitaet)
        let r = wdh(bei: w, staerke: e, reserve: rir)
        if r > bereich.upperBound + 1, let hoch = LetztesMal.kg(w, richtung: 1, schritt: schritt), hoch > w {
            let rh = wdh(bei: hoch, staerke: e, reserve: rir)
            if rh >= bereich.lowerBound { return SatzVorschlag(kg: hoch, wdh: min(rh, bereich.upperBound), reserve: rir, grund: .schwerer(hoch - w)) }
        }
        if r >= bereich.lowerBound { return SatzVorschlag(kg: w, wdh: r, reserve: rir, grund: .ermuedung) }
        var kandidat = w
        while let tiefer = LetztesMal.kg(kandidat, richtung: -1, schritt: schritt), tiefer >= w * 0.7 {
            kandidat = tiefer
            let rt = wdh(bei: kandidat, staerke: e, reserve: rir)
            if rt >= bereich.lowerBound {
                return SatzVorschlag(kg: kandidat, wdh: min(rt, bereich.upperBound), reserve: rir, grund: .leichter(w - kandidat))
            }
        }
        return SatzVorschlag(kg: w, wdh: max(r, 1), reserve: rir, grund: .ermuedung)
    }

    /// Aufwärmzeile: Prozent vom Arbeitsgewicht (Vorschlag für den ersten Arbeitssatz, sonst dessen eingetragenes Gewicht), auf den Schritt gerundet.
    private static func aufwaermen(zeile i: Int, saetze: [PlanSatz], historie: [UebungTag], art: VorhersageArt, schritt: Double,
                                   bereich: ClosedRange<Int>, heute: String) -> SatzVorschlag? {
        let warm = saetze.indices.filter { saetze[$0].typ == "w" }
        guard let position = warm.firstIndex(of: i), let erster = saetze.firstIndex(where: { $0.typ != "w" }) else { return nil }
        let rir = zielReserve(art, letzter: false, versagen: false)
        let vorgeschlagen = ersterSatz(historie: historie, bereich: bereich, rir: rir, schritt: schritt, heute: heute)?.kg
        guard let arbeitKg = vorgeschlagen ?? saetze[erster].kg, arbeitKg > 0 else { return nil }
        let stufen = aufwaermStufen(anzahl: warm.count)
        let stufe = stufen[min(position, stufen.count - 1)]
        let kg = min(arbeitKg, max(schritt, (arbeitKg * Double(stufe.prozent) / 100 / schritt).rounded() * schritt))
        return SatzVorschlag(kg: kg, wdh: stufe.wdh, reserve: 0, grund: .aufwaermen(stufe.prozent))
    }

    /// Dropsatz: 20 % leichter als der Satz davor, gleiche Wiederholungen als Ziel.
    private static func drop(nach vorher: PlanSatz?, schritt: Double) -> SatzVorschlag? {
        guard let vorher, let kg = vorher.kg, kg > 0 else { return nil }
        let leichter = abrunden(kg * 0.8, schritt: schritt)
        guard leichter > 0 else { return nil }
        return SatzVorschlag(kg: leichter, wdh: max(vorher.wdh, 1), reserve: 0, grund: .drop)
    }

    /// Der schwerste Arbeitssatz mit Gewicht (bei gleichem Gewicht der mit den meisten Wiederholungen).
    static func topSatz(_ saetze: [PlanSatz]) -> PlanSatz? {
        arbeit(saetze).filter { ($0.kg ?? 0) > 0 }.max { ($0.kg ?? 0, $0.wdh) < ($1.kg ?? 0, $1.wdh) }
    }

    /// Stillstand: die besten Werte der letzten drei Einheiten liegen nicht über dem Bestwert davor (mindestens fünf Einheiten mit Gewicht), und keine
    /// der drei war deutlich leichter (sonst war der Deload schon da oder es war ein schlechter Tag).
    static func stillstand(_ werte: [Double]) -> Bool {
        guard werte.count >= stillstandEinheiten + 2, werte.allSatisfy({ $0 > 0 }) else { return false }
        let zuletzt = werte.suffix(stillstandEinheiten)
        guard let neu = zuletzt.max(), let alt = werte.dropLast(stillstandEinheiten).max() else { return false }
        return neu <= alt * 1.005 && !zuletzt.contains { $0 < leichtGrenze * alt }
    }
}
