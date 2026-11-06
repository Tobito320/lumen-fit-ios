// Quelle: Lovea Health/Workout.swift ("Letztes Mal" und Schritte, neu gefasst)
import Foundation

/// "Letztes Mal" in der Satzzeile (Idee 21): je Satz der Wert vom letzten Training derselben Übung, dazu Plus und Minus
/// statt Zahlen tippen. Reine Logik, ohne Oberfläche.
enum LetztesMal {
    /// Der Satz aus `vorher` (die gezählten Sätze der letzten Einheit), der zu Zeile `i` gehört: Aufwärmsätze passen zu
    /// Aufwärmsätzen, alle anderen der Reihe nach zu den anderen. Hat die Zeile mehr Sätze als damals, gilt der letzte
    /// Arbeitssatz. nil, wenn es nichts Passendes gibt.
    static func satz(zeile i: Int, in saetze: [PlanSatz], vorher: [PlanSatz]) -> PlanSatz? {
        guard saetze.indices.contains(i) else { return nil }
        let warm = saetze[i].typ == "w"
        let nummer = saetze[..<i].filter { ($0.typ == "w") == warm }.count
        let gleiche = vorher.filter { ($0.typ == "w") == warm }
        if gleiche.indices.contains(nummer) { return gleiche[nummer] }
        return warm ? nil : gleiche.last
    }

    /// "60 kg × 8", ohne Gewicht "8 Wdh"; nil ohne Vorgänger.
    static func text(zeile i: Int, in saetze: [PlanSatz], vorher: [PlanSatz]) -> String? {
        satz(zeile: i, in: saetze, vorher: vorher).map(WorkoutLogik.satzText)
    }

    /// Zeile `i` nimmt Gewicht und Wiederholungen vom letzten Mal (Tipp auf die graue Zeile). Ohne Vorgänger bleibt sie.
    static func uebernehmen(zeile i: Int, in saetze: [PlanSatz], vorher: [PlanSatz]) -> [PlanSatz] {
        guard let alt = satz(zeile: i, in: saetze, vorher: vorher) else { return saetze }
        var neu = saetze
        neu[i].kg = alt.kg
        neu[i].wdh = alt.wdh
        return neu
    }

    // MARK: - Plus und Minus

    static let wdhBereich = 1...100
    static let kgMaximum = 500.0

    /// Gewichtsschritt je Gerät: Kurzhanteln gehen in 2-kg-Stufen, Maschinen und Kabel in 5, sonst 2,5.
    static func kgSchritt(geraet: String?) -> Double {
        switch geraet {
        case "Kurzhantel": 2
        case "Maschine", "Kabelzug", "Schlitten": 5
        default: 2.5
        }
    }

    /// Gewicht um einen Schritt hoch (`richtung` 1) oder runter (-1). Ohne Gewicht startet Plus beim Schritt; unter 0 wird
    /// es wieder "ohne Gewicht" (nil). Hochgesetzt wird auf das nächste Vielfache des Schritts, damit 61 kg nicht bei 63,5 hängen.
    static func kg(_ kg: Double?, richtung: Int, schritt: Double) -> Double? {
        let alt = kg ?? 0
        let neu: Double
        if richtung > 0 {
            neu = min(((alt / schritt).rounded(.down) + 1) * schritt, kgMaximum)
        } else {
            neu = ((alt / schritt).rounded(.up) - 1) * schritt
        }
        return neu > 0.001 ? neu : nil
    }

    /// Wiederholungen um eins, im Bereich 1 bis 100.
    static func wdh(_ wdh: Int, richtung: Int) -> Int {
        min(max(wdh + (richtung > 0 ? 1 : -1), wdhBereich.lowerBound), wdhBereich.upperBound)
    }

    /// Getipptes Gewicht ("12,5" und "12.5" gelten gleich): 0 bis `kgMaximum`, leer = 0 = ohne Gewicht. nil = ungültig, die Eingabe wird verworfen.
    static func kgAusText(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if t.isEmpty { return 0 }
        guard let kg = Double(t), kg.isFinite, (0...kgMaximum).contains(kg) else { return nil }
        return kg
    }

    /// Getippte Wiederholungen als ganze Zahl im `wdhBereich`; nil = leer oder ungültig.
    static func wdhAusText(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap { wdhBereich.contains($0) ? $0 : nil }
    }

    /// Eine Zeile ändern: Plus oder Minus am Gewicht.
    static func aendereKg(_ saetze: [PlanSatz], _ i: Int, richtung: Int, schritt: Double) -> [PlanSatz] {
        guard saetze.indices.contains(i) else { return saetze }
        var neu = saetze
        neu[i].kg = kg(saetze[i].kg, richtung: richtung, schritt: schritt)
        return neu
    }

    /// Getippte Werte: Gewicht von 0 bis 500 (0 oder leer = ohne Gewicht), Wiederholungen von 0 bis 100.
    static func setzeWerte(_ saetze: [PlanSatz], _ i: Int, kg: Double?, wdh: Int) -> [PlanSatz] {
        guard saetze.indices.contains(i) else { return saetze }
        var neu = saetze
        neu[i].kg = kg.flatMap { $0 > 0.001 ? min($0, kgMaximum) : nil }
        neu[i].wdh = min(max(wdh, 0), wdhBereich.upperBound)
        return neu
    }

    static func aendereWdh(_ saetze: [PlanSatz], _ i: Int, richtung: Int) -> [PlanSatz] {
        guard saetze.indices.contains(i) else { return saetze }
        var neu = saetze
        neu[i].wdh = wdh(saetze[i].wdh, richtung: richtung)
        return neu
    }
}
