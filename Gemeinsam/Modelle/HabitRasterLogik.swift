import Foundation

/// Reine Rechnung für die Raster der Gewohnheits-Seite (Woche, Monat, Jahr) und für die Kachel. Tage sind `Datum`-Texte.
enum HabitRaster {
    /// Anteile Mo bis So der laufenden Woche; Tage nach `heute` zählen 0.
    static func wochenAnteile(_ habit: Habit, werte: [String: Int], ziel: Int?, heute: String) -> [Double] {
        HabitLogik.wochenTage(heute: heute).map { $0 > heute ? 0 : HabitLogik.anteil(habit, wert: werte[$0] ?? 0, ziel: ziel) }
    }

    /// Erledigte Tage der laufenden Woche (bis heute).
    static func wochenErledigt(_ habit: Habit, werte: [String: Int], ziel: Int?, heute: String) -> Int {
        HabitLogik.wochenTage(heute: heute).filter { $0 <= heute && HabitLogik.erledigt(habit, wert: werte[$0] ?? 0, ziel: ziel) }.count
    }

    /// Immer 42 Zellen (sechs Wochen), damit die Höhe beim Wischen gleich bleibt. `nil` = Füllzelle.
    static func zellen(heute: String, monateZurueck: Int) -> [String?] {
        let gitter = HealthLogik.monatsGitter(heute: heute, monateZurueck: monateZurueck)
        return gitter + [String?](repeating: nil, count: max(0, 42 - gitter.count))
    }

    /// Erster Tag des Monats `monateZurueck` Monate vor dem von `heute`.
    static func monatsErster(heute: String, monateZurueck: Int) -> String {
        let zurueck = max(0, monateZurueck)
        let erster = String(heute.prefix(7)) + "-01"
        return Datum.kalender.date(byAdding: .month, value: -zurueck, to: Datum.datum(erster)).map(Datum.text) ?? erster
    }

    /// "Oktober 2026".
    static func monatsTitel(heute: String, monateZurueck: Int) -> String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        return Datum.datum(monatsErster(heute: heute, monateZurueck: monateZurueck)).formatted(stil.month(.wide).year())
    }

    /// "Okt" für das Jahr-Raster.
    static func monatsKurz(heute: String, monateZurueck: Int) -> String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        return Datum.datum(monatsErster(heute: heute, monateZurueck: monateZurueck)).formatted(stil.month(.abbreviated))
    }

    /// Die zwölf Monate des Jahr-Rasters als `monateZurueck`, ältester zuerst (11 ... 0).
    static let jahrMonate: [Int] = Array((0..<12).reversed())

    /// Tag im Monat als Zahl ("7"), leer bei kaputtem Text.
    static func tagesnummer(_ tag: String) -> String {
        guard let letzte = tag.split(separator: "-").last, let n = Int(letzte) else { return "" }
        return "\(n)"
    }

    /// Erledigte Tage in einem Monat (nur Tage bis heute), für die Zeile unter dem Monats-Titel und das Jahr-Raster.
    static func monatErledigt(_ habit: Habit, werte: [String: Int], ziel: Int?, heute: String, monateZurueck: Int) -> Int {
        zellen(heute: heute, monateZurueck: monateZurueck).compactMap { $0 }
            .filter { $0 <= heute && HabitLogik.erledigt(habit, wert: werte[$0] ?? 0, ziel: ziel) }.count
    }

    /// "1 Tag", "5 Tage"; bei "x pro Woche" Wochen.
    static func serieText(_ habit: Habit, _ n: Int) -> String {
        if case .proWoche = habit.haeufigkeit { return n == 1 ? "1 Woche" : "\(n) Wochen" }
        return n == 1 ? "1 Tag" : "\(n) Tage"
    }

    /// 0,4 -> "40 %".
    static func prozent(_ anteil: Double) -> String {
        anteil.formatted(.percent.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))
    }

    /// Ein Wochentag-Knopf der festen Tage: 1 = Mo ... 7 = So. Zählt nur gültige Tage und gibt sie sortiert zurück.
    static func festeTage(_ tage: Set<Int>) -> [Int] { tage.filter { (1...7).contains($0) }.sorted() }

    /// Vorschau und Speichern des Formulars: bei festen Tagen ohne Auswahl ist der Entwurf ungültig.
    static func formularGueltig(name: String, festeTageArt: Bool, tage: Set<Int>) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (!festeTageArt || !festeTage(tage).isEmpty)
    }
}
