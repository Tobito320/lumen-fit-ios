import Foundation

/// Der Gewichtsverlauf (Idee 36): gleitender Mittelwert, Ziellinie und die Prognose "in 9 Wochen am Ziel". Die Prognose gibt es nur, wenn der Trend zum Ziel zeigt.
struct GewichtTrend: Equatable, Sendable {
    /// Gleitender Mittelwert über 7 Tage je Messtag (`GewichtLogik.mittelReihe`), älteste zuerst.
    let reihe: [GewichtMittel]
    /// Die Rohwerte je Messtag in kg, für die Punkte hinter der Linie.
    let punkte: [GewichtMittel]
    let zielKg: Double?
    /// Veränderung je Woche in kg (Ausgleichsgerade über das Fenster); nil unter drei Messtagen oder unter einer Woche Spanne.
    let kgProWoche: Double?
    /// Wochen bis zum Ziel, nur wenn der Trend zum Ziel zeigt (sonst nil).
    let prognoseWochen: Int?

    var aktuell: Double? { reihe.last?.kg }

    /// Näher als 0,3 kg am Ziel gilt als am Ziel.
    var amZiel: Bool {
        guard let aktuell, let zielKg else { return false }
        return abs(aktuell - zielKg) <= GewichtVerlauf.zielToleranz
    }
}

enum GewichtVerlauf {
    /// So viele Tage vor dem letzten Messtag gehen in den Trend ein.
    static let fensterTage = 28
    static let zielToleranz = 0.3
    /// Unter 0,05 kg je Woche ist es kein Trend, sondern Schwankung.
    static let mindestSteigung = 0.05
    /// Prognosen über zwei Jahre sagen nichts mehr.
    static let hoechstWochen = 104

    /// `werte`: Tag zu Zehntel-kg (wie `HabitStore.werte("gewicht")`). `heute` begrenzt nur die Anzeige nach hinten (Fenster bis `heute`).
    static func trend(werte: [String: Int], zielKg: Double?, heute: String) -> GewichtTrend {
        let ab = Datum.addTage(heute, -(fensterTage - 1))
        let sichtbar = werte.filter { $0.key >= ab && $0.key <= heute }
        // Der Mittelwert schaut 6 Tage zurück: mehr Vorlauf braucht das Fenster nicht (`mittelReihe` ist quadratisch, sonst über die ganze Historie je Render).
        let vorlauf = Datum.addTage(ab, -6)
        let reihe = GewichtLogik.mittelReihe(werte.filter { $0.key >= vorlauf && $0.key <= heute }).filter { $0.tag >= ab }
        let punkte = MessLogik.punkte(sichtbar).map { GewichtMittel(tag: $0.tag, kg: Double($0.zehntel) / 10) }
        let steigung = steigungProWoche(reihe)
        return GewichtTrend(reihe: reihe, punkte: punkte, zielKg: zielKg, kgProWoche: steigung,
                            prognoseWochen: prognose(aktuell: reihe.last?.kg, ziel: zielKg, steigung: steigung))
    }

    /// Kleinste Quadrate über (Tag, Mittelwert); Tage als Abstand zum ersten Messtag. Unter drei Punkten oder unter 7 Tagen Spanne nil.
    static func steigungProWoche(_ reihe: [GewichtMittel]) -> Double? {
        guard reihe.count >= 3, let erster = reihe.first, let letzter = reihe.last,
              Datum.tageZwischen(erster.tag, letzter.tag) >= 7 else { return nil }
        let x = reihe.map { Double(Datum.tageZwischen(erster.tag, $0.tag)) }
        let y = reihe.map(\.kg)
        let n = Double(reihe.count)
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        let nenner = x.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard nenner > 0 else { return nil }
        let zaehler = zip(x, y).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        return zaehler / nenner * 7
    }

    /// Wochen bis zum Ziel, aufgerundet. nil ohne Ziel, ohne Trend, wenn der Trend vom Ziel weg zeigt, oder wenn das Ziel schon erreicht ist.
    static func prognose(aktuell: Double?, ziel: Double?, steigung: Double?) -> Int? {
        guard let aktuell, let ziel, let steigung, abs(steigung) >= mindestSteigung else { return nil }
        let abstand = ziel - aktuell
        guard abs(abstand) > zielToleranz, abstand * steigung > 0 else { return nil }
        let wochen = Int((abstand / steigung).rounded(.up))
        return wochen <= hoechstWochen ? wochen : nil
    }

    /// Die Aussage als Titel: "In 9 Wochen am Ziel", "Am Ziel", sonst die Richtung.
    static func aussage(_ t: GewichtTrend) -> String {
        guard let aktuell = t.aktuell else { return String(localized: "Noch kein Gewicht eingetragen") }
        if t.amZiel { return String(localized: "Du bist am Ziel: \(kg(aktuell)) kg") }
        if let wochen = t.prognoseWochen { return String(localized: "In \(wochen) \(wochen == 1 ? String(localized: "Woche") : String(localized: "Wochen")) am Ziel") }
        guard let steigung = t.kgProWoche else { return String(localized: "Gewicht \(kg(aktuell)) kg") }
        if abs(steigung) < mindestSteigung { return String(localized: "Dein Gewicht bleibt stabil bei \(kg(aktuell)) kg") }
        if t.zielKg != nil { return String(localized: "Der Trend zeigt gerade vom Ziel weg") }
        return steigung > 0 ? String(localized: "Dein Gewicht steigt langsam") : String(localized: "Dein Gewicht sinkt langsam")
    }

    /// Die Kernzeile: aktueller Mittelwert, Trend je Woche und das Ziel.
    static func kernzeile(_ t: GewichtTrend) -> String {
        guard let aktuell = t.aktuell else { return String(localized: "Trag dein Gewicht ein, dann zeichnet Lumi die Kurve.") }
        var teile = [String(localized: "Mittel \(kg(aktuell)) kg")]
        if let s = t.kgProWoche {
            let wert = "\(s > 0 ? "+" : s < 0 ? "-" : "")\(kg(abs(s)))"
            teile.append(String(localized: "\(wert) kg je Woche"))
        }
        if let z = t.zielKg { teile.append(String(localized: "Ziel \(kg(z)) kg")) }
        return teile.joined(separator: " · ")
    }

    /// 78,4 -> "78,4"; zwei Stellen nur, wenn nötig ("0,25").
    static func kg(_ wert: Double) -> String {
        wert.formatted(.number.precision(.fractionLength(0...2)).locale(Datum.anzeigeLocale))
    }
}
