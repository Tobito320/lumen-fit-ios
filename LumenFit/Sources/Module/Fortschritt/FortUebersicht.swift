import Foundation

/// Monat oder Woche in der Karte "Übersicht" (Standard Monat).
enum FortZeitraum: String, CaseIterable, Sendable {
    case monat, woche
}

/// Ein Balken der Übersicht: Trainings in einem Monat oder einer Woche. `id` ist `yyyy-MM` bzw. der Montag.
struct FortBalken: Equatable, Identifiable, Sendable {
    var id: String
    var beschriftung: String
    var anzahl: Int
    var aktuell: Bool
}

/// Alles, was die Karte "Übersicht" zeigt, vorgerechnet.
struct FortUebersichtDaten: Equatable, Sendable {
    var insgesamt: Int
    /// Trainings diesen Monat bzw. diese Woche.
    var imZeitraum: Int
    /// Geplante Trainings dieser Woche (nur Woche, nil ohne Plan).
    var geplant: Int?
    /// Gewicht jetzt minus vor 30 Tagen in kg; nil ohne zwei Einträge.
    var gewicht30: Double?
    var balken: [FortBalken]
}

/// Reine Rechnung der Karte "Übersicht" im Tab Fortschritt. Gezählt wird wie im Verlauf (`FortschrittLogik.beendet`).
enum FortUebersicht {
    static let monate = 4
    static let wochen = 8

    static func daten(_ sessions: [GymSession], plan: TrainingsPlan, gewicht: [String: Int], heute: String, jetzt: Date? = nil,
                      zeitraum: FortZeitraum) -> FortUebersichtDaten {
        let beendet = sessions.filter { FortschrittLogik.beendet($0, heute: heute, jetzt: jetzt) }.map { Datum.text($0.start) }.filter { $0 <= heute }
        let balken = zeitraum == .monat ? monatsBalken(beendet, heute: heute) : wochenBalken(beendet, heute: heute)
        var geplant: Int?
        if zeitraum == .woche {
            let n = WochenLogik.effektiverPlan(plan, woche: Datum.montagDerWoche(heute)).tage.flatMap(\.wochentage).count
            geplant = n > 0 ? n : nil
        }
        return FortUebersichtDaten(insgesamt: beendet.count, imZeitraum: balken.last?.anzahl ?? 0, geplant: geplant,
                                   gewicht30: gewicht30(gewicht, heute: heute), balken: balken)
    }

    /// Die letzten vier Kalendermonate bis zum Monat von `heute`, ältester zuerst.
    static func monatsBalken(_ tage: [String], heute: String) -> [FortBalken] {
        let monat = String(heute.prefix(7))
        let stil = Date.FormatStyle(calendar: Datum.kalender, timeZone: Datum.zone).month(.abbreviated)
        return (0..<monate).map { i in
            let m = KalenderLogik.naechster(monat, schritt: i - (monate - 1))
            return FortBalken(id: m, beschriftung: Datum.datum(m + "-01").formatted(stil), anzahl: tage.filter { $0.hasPrefix(m) }.count, aktuell: m == monat)
        }
    }

    /// Die letzten acht Wochen bis zur Woche von `heute`, älteste zuerst; die laufende heißt "Jetzt", die anderen tragen die Kalenderwoche.
    static func wochenBalken(_ tage: [String], heute: String) -> [FortBalken] {
        let montag = Datum.montagDerWoche(heute)
        return (0..<wochen).map { i in
            let m = Datum.addTage(montag, -7 * (wochen - 1 - i))
            let ende = Datum.addTage(m, 6)
            return FortBalken(id: m, beschriftung: m == montag ? String(localized: "Jetzt") : "\(FortschrittLogik.kalenderwoche(m))",
                              anzahl: tage.filter { $0 >= m && $0 <= ende }.count, aktuell: m == montag)
        }
    }

    /// Neuester Eintrag bis heute minus der letzte Eintrag vor mindestens 30 Tagen (gibt es keinen, der älteste). Werte in Zehntel-kg.
    static func gewicht30(_ werte: [String: Int], heute: String) -> Double? {
        let liste = werte.filter { $0.key <= heute && $0.value > 0 }.sorted { $0.key < $1.key }
        guard let neu = liste.last else { return nil }
        let grenze = Datum.addTage(heute, -30)
        guard let alt = liste.last(where: { $0.key <= grenze }) ?? liste.first, alt.key != neu.key else { return nil }
        return Double(neu.value - alt.value) / 10
    }

    /// Mehr als sonst: diese Woche mindestens ein Training und nicht weniger als im Schnitt der vier Wochen davor.
    static func mehrAlsSonst(_ v: TrainingsWochenVergleich) -> Bool {
        v.einheiten > 0 && Double(v.einheiten) >= v.einheitenSchnitt
    }

    static func lumiSatz(mehr: Bool) -> String {
        mehr ? String(localized: "Mehr als sonst. Genau so weiter.") : String(localized: "Etwas weniger als sonst. Ein Training holt das auf.")
    }

    /// "−1,2" / "+0,4" / "±0" für die Kachel Gewicht.
    static func gewichtText(_ kg: Double) -> String {
        let gerundet = (kg * 10).rounded() / 10
        if gerundet > 0 { return "+\(FortschrittLogik.zahl(gerundet))" }
        if gerundet < 0 { return "−\(FortschrittLogik.zahl(-gerundet))" }
        return "±0"
    }
}
