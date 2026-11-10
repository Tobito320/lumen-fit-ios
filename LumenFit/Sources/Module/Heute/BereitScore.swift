import Foundation

/// Der Bereit-Score (Idee 12): wie bereit der Körper heute für Belastung ist, 0 bis 100, aus Werten, die man nachrechnen kann.
/// Reine Logik. Fehlt ein Wert, fällt sein Teil aus der Rechnung und der Satz sagt es; ohne genug Daten gibt es keine Zahl statt einer erfundenen.
///
/// Formel und Begründung:
/// - Schlaf (Gewicht 0,40): Dauer gegen das Ziel, im Quadrat. Zu wenig Schlaf wirkt überproportional (7 von 8 h = 77, 6 h = 56, 5 h = 39).
/// - Erholung (0,40): HRV und Ruhepuls gegen den eigenen Schnitt der letzten 60 Tage, nie gegen Normwerte, weil sie von Mensch zu Mensch weit
///   auseinanderliegen. Mindestens 5 Vergleichstage. HRV: 75 Punkte beim Schnitt, 20 je Standardabweichung. Ruhepuls: 75 beim Schnitt,
///   6 je Schlag darüber (minus) oder darunter (plus).
/// - Belastung (0,20): Tageslast (aktive kcal plus 10 je Gym-Satz) der letzten 3 Tage gegen den Schnitt der 28 Tage davor. Bis 1,2-fach
///   volle Punkte, bei 2-fach 40, ab 3-fach null. Mindestens 7 Vergleichstage.
/// - Der Score wird nur gerechnet, wenn die vorhandenen Teile zusammen mindestens 0,35 Gewicht haben (Schlaf allein oder HRV und Ruhepuls reichen).
enum BereitScore {
    static let mindestGewicht = 0.35
    static let mindestVergleichstage = 5
    static let mindestLastTage = 7
    static let bereitAb = 70
    static let normalAb = 45
    static let neutral = 75.0
    static let hrvSteigung = 20.0
    static let hrvStreuungBoden = 0.08
    static let ruhepulsSteigung = 6.0
    static let lastGrenze = 1.2
    static let satzKcal = 10.0

    enum Art: String, CaseIterable, Sendable {
        case schlaf, erholung, belastung

        var titel: String {
            switch self {
            case .schlaf: String(localized: "Schlaf")
            case .erholung: String(localized: "Erholung")
            case .belastung: String(localized: "Belastung")
            }
        }

        var gewicht: Double {
            switch self {
            case .schlaf: 0.40
            case .erholung: 0.40
            case .belastung: 0.20
            }
        }
    }

    enum Stufe: String, Sendable { case keine, schonen, normal, bereit }

    struct Eingabe: Equatable, Sendable {
        /// Schlafminuten der letzten Nacht.
        var schlafMinuten: Int?
        var schlafZiel = 480
        /// Der neueste HRV-Wert und die Werte davor (bis 60 Tage, SDNN in ms).
        var hrv: Double?
        var hrvBasis: [Double] = []
        var ruhepuls: Double?
        var ruhepulsBasis: [Double] = []
        /// Tageslast ab gestern, neuester zuerst (Index 0 = gestern, 1 = vorgestern, ...), bis 31 Einträge. nil = keine Daten für den Tag.
        var last: [Double?] = []
    }

    struct Teil: Equatable, Sendable, Identifiable {
        var art: Art
        /// 0 bis 100: wie gut dieser Teil gerade ist (bei Belastung: wie viel Luft nach oben).
        var wert: Double
        var kurz: String
        var detail: String
        var id: String { art.rawValue }
    }

    struct Ergebnis: Equatable, Sendable {
        /// nil = zu wenig Daten für eine Zahl.
        var punkte: Int?
        var stufe: Stufe
        var teile: [Teil]
        var fehlend: [Art]
        /// Ein Satz: was die Zahl heißt, der schwächste Teil, was fehlt.
        var satz: String

        func teil(_ art: Art) -> Teil? { teile.first { $0.art == art } }
    }

    /// Die Formel in Worten, für das Detail unter dem Score.
    static let klartext = [
        String(localized: "Schlaf zählt 40 %: die Dauer gegen dein Ziel, im Quadrat. Zu wenig Schlaf wirkt stärker als ein bisschen zu viel."),
        String(localized: "Erholung zählt 40 %: HRV und Ruhepuls gegen deinen eigenen Schnitt der letzten 60 Tage, nicht gegen Normwerte."),
        String(localized: "Belastung zählt 20 %: dein Training und deine Bewegung der letzten 3 Tage gegen die 4 Wochen davor."),
        String(localized: "Fehlt ein Wert, rechnet Lumen Fit ohne ihn weiter. Ohne mindestens Schlaf oder HRV mit Ruhepuls gibt es keine Zahl."),
    ].joined(separator: "\n")

    static func rechnen(_ e: Eingabe) -> Ergebnis {
        var teile: [Teil] = []
        if let t = schlafTeil(e) { teile.append(t) }
        if let t = erholungTeil(e) { teile.append(t) }
        if let t = belastungTeil(e) { teile.append(t) }
        let fehlend = Art.allCases.filter { art in !teile.contains { $0.art == art } }
        let gewicht = teile.reduce(0.0) { $0 + $1.art.gewicht }
        guard gewicht >= mindestGewicht else {
            return Ergebnis(punkte: nil, stufe: .keine, teile: teile, fehlend: fehlend, satz: satz(punkte: nil, teile: teile, fehlend: fehlend))
        }
        let summe = teile.reduce(0.0) { $0 + $1.art.gewicht * $1.wert } / gewicht
        let punkte = Int(min(100, max(0, summe)).rounded())
        let stufe: Stufe = punkte >= bereitAb ? .bereit : (punkte >= normalAb ? .normal : .schonen)
        return Ergebnis(punkte: punkte, stufe: stufe, teile: teile, fehlend: fehlend, satz: satz(punkte: punkte, teile: teile, fehlend: fehlend))
    }

    // MARK: Teile

    private static func schlafTeil(_ e: Eingabe) -> Teil? {
        guard let minuten = e.schlafMinuten, minuten > 0, e.schlafZiel > 0 else { return nil }
        let anteil = min(1, Double(minuten) / Double(e.schlafZiel))
        let wert = 100 * anteil * anteil
        return Teil(art: .schlaf, wert: wert, kurz: String(localized: "Schlaf \(stunden(minuten))"),
                    detail: String(localized: "Letzte Nacht \(stunden(minuten)) von \(stunden(e.schlafZiel)) Ziel."))
    }

    private static func erholungTeil(_ e: Eingabe) -> Teil? {
        var werte: [Double] = []
        var zeilen: [String] = []
        if let h = e.hrv, let v = vergleich(h, basis: e.hrvBasis) {
            let z = (h - v.mittel) / max(v.streuung, hrvStreuungBoden * v.mittel)
            werte.append(klemmen(neutral + hrvSteigung * z))
            zeilen.append(String(localized: "HRV \(zahl(h)) ms, \(z < -0.5 ? String(localized: "unter") : (z > 0.5 ? String(localized: "über") : String(localized: "wie"))) deinem Schnitt von \(zahl(v.mittel)) ms"))
        }
        if let r = e.ruhepuls, let v = vergleich(r, basis: e.ruhepulsBasis) {
            werte.append(klemmen(neutral - ruhepulsSteigung * (r - v.mittel)))
            zeilen.append(String(localized: "Ruhepuls \(zahl(r)), Schnitt \(zahl(v.mittel))"))
        }
        guard !werte.isEmpty else { return nil }
        let wert = werte.reduce(0, +) / Double(werte.count)
        return Teil(art: .erholung, wert: wert, kurz: zeilen.first ?? String(localized: "Erholung"), detail: zeilen.joined(separator: ". ") + ".")
    }

    private static func belastungTeil(_ e: Eingabe) -> Teil? {
        let neu: [Double] = e.last.prefix(3).compactMap { $0 }
        let basis: [Double] = e.last.dropFirst(3).prefix(28).compactMap { $0 }.filter { $0 > 0 }
        guard !neu.isEmpty, basis.count >= mindestLastTage else { return nil }
        let ueblich = basis.reduce(0, +) / Double(basis.count)
        guard ueblich > 0 else { return nil }
        let r = (neu.reduce(0, +) / Double(neu.count)) / ueblich
        let wert: Double
        if r <= lastGrenze {
            wert = 100
        } else if r <= 2 {
            wert = 100 - 60 * (r - lastGrenze) / (2 - lastGrenze)
        } else {
            wert = klemmen(40 - 40 * (r - 2))
        }
        let wort = r > lastGrenze ? String(localized: "mehr als sonst") : (r < 0.7 ? String(localized: "weniger als sonst") : String(localized: "wie sonst"))
        return Teil(art: .belastung, wert: wert, kurz: String(localized: "Belastung der letzten 3 Tage \(wort)"),
                    detail: String(localized: "Das \(String(format: "%.1f", r).replacingOccurrences(of: ".", with: ","))-Fache deines üblichen Tages der letzten 4 Wochen."))
    }

    // MARK: Satz

    private static func satz(punkte: Int?, teile: [Teil], fehlend: [Art]) -> String {
        var teileSatz: [String] = []
        if let punkte {
            teileSatz.append(punkte >= bereitAb ? String(localized: "Gut erholt.") : (punkte >= normalAb ? String(localized: "Solide Basis.") : String(localized: "Dein Körper will Ruhe.")))
            if let schwach = teile.min(by: { $0.wert < $1.wert }), schwach.wert < 60 {
                teileSatz.append(String(localized: "Am meisten bremst: \(schwach.kurz)."))
            }
        } else {
            teileSatz.append(String(localized: "Noch zu wenig Daten für einen Score."))
        }
        if !fehlend.isEmpty {
            let namen = fehlend.map { $0.titel }
            let hilfe = fehlend.contains(.erholung) ? String(localized: " (HRV und Ruhepuls kommen von der Apple Watch)") : ""
            teileSatz.append(String(localized: "Ohne \(namen.joined(separator: String(localized: " und "))) gerechnet\(hilfe)."))
        }
        return teileSatz.joined(separator: " ")
    }

    // MARK: Hilfen

    private static func vergleich(_ heute: Double, basis: [Double]) -> (mittel: Double, streuung: Double)? {
        guard heute.isFinite, heute > 0 else { return nil }
        let gueltig = basis.filter { $0 > 0 && $0.isFinite }.prefix(60)
        guard gueltig.count >= mindestVergleichstage else { return nil }
        let mittel = gueltig.reduce(0, +) / Double(gueltig.count)
        let quadrate = gueltig.reduce(0.0) { $0 + ($1 - mittel) * ($1 - mittel) }
        return (mittel, (quadrate / Double(gueltig.count)).squareRoot())
    }

    private static func klemmen(_ x: Double) -> Double { min(100, max(0, x)) }

    private static func zahl(_ x: Double) -> String { String(Int(x.rounded())) }

    /// "6:10 h".
    static func stunden(_ minuten: Int) -> String { "\(minuten / 60):\(String(format: "%02d", minuten % 60)) h" }
}
