import Foundation

/// Alles, was der Heute-Tab zeigt, einmal gerechnet (`HeuteModell.berechne`). Reine Werte, keine Logik in den Ansichten.
struct HeuteStand {
    var tag: String
    var stunde: Int
    /// Health oder Band haben mindestens einen Tag oder eine Nacht geliefert. Ohne: Leerzustand mit "Health erlauben".
    var hatGesundheit: Bool
    var boegen: [BogenWert]
    /// Die drei Bögen als ein Satz für VoiceOver ("Schritte: 8.412 von 10.000. Gym: 1 von 3 Tagen. Schlaf: 7:12 h von 8:00 h.").
    var boegenSatz: String
    var boegenVoll: Bool
    var stimmung: LumiStimmung
    var morgensatz: String
    /// Antwort des Morgen-Checks von heute (1 bis 5), falls gegeben.
    var stimmungsWert: Int?
    var score: BereitScore.Ergebnis
    var plan: HeutePlan
    var energie: HeuteEnergie
    var habits: [HeuteHabitZeile]
    var gewicht: HeuteGewicht
    var schritte: HeuteSchritte
    var hinweise: [TagesHinweis]
    var woche: [WochenTag]
}

struct HeuteEnergiePunkt: Identifiable, Equatable {
    var stunde: Int
    var akku: Int
    var id: Int { stunde }
}

struct HeuteEnergie {
    var ergebnis: TagesformErgebnis
    var klartext: TagesformKlartext.Inhalt
    /// Die Zahl zu den Stunden des Tages bis jetzt (alle drei Stunden ab 6 Uhr und jetzt), nur wo es eine Zahl gab.
    var verlauf: [HeuteEnergiePunkt]
    /// Das eigene Gefühl von heute (1 bis 5), falls getippt.
    var gefuehl: Int?
    var vergleich: TagesformVergleich?
}

struct HeuteHabitZeile: Identifiable {
    var habit: Habit
    var wert: Int
    var ziel: Int?
    var erledigt: Bool
    var anteil: Double
    var serie: Int
    var id: String { habit.id }

    /// Zähl-Gewohnheiten: "5 von 8".
    var zaehlerText: String? { habit.zaehlen ? "\(wert) von \(ziel ?? habit.tagesziel ?? 1)" : nil }

    /// "Serie: 4 Tage" oder bei Wochenzielen "Serie: 2 Wochen"; nil ohne Serie.
    var serieText: String? {
        guard serie > 0 else { return nil }
        var wochen = false
        if case .proWoche = habit.haeufigkeit { wochen = true }
        return "Serie: \(serie) \(wochen ? (serie == 1 ? "Woche" : "Wochen") : (serie == 1 ? "Tag" : "Tage"))"
    }
}

struct HeuteGewichtPunkt: Identifiable, Equatable {
    var tag: String
    var kg: Double
    var id: String { tag }
}

struct HeuteGewicht {
    /// Das angezeigte Gewicht (Schnitt der 7 Tage bis zum neuesten Eintrag); nil ohne Eintrag.
    var aktuellKg: Double?
    var aenderung: String?
    var zielKg: Double?
    /// Die letzten 90 Tage, älteste zuerst.
    var punkte: [HeuteGewichtPunkt]
    var heuteEingetragen: Bool
    /// Startwert des Zahlenrads in Zehntel-kg (letzte Messung, sonst 75,0).
    var startZehntel: Int
}

struct HeuteSchritte {
    var schritte: Int
    var ziel: Int
    var distanzKm: Double
    var etagen: Int
    var anteil: Double { ziel > 0 ? min(1, Double(schritte) / Double(ziel)) : 0 }
}
