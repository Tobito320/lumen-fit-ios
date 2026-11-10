import Foundation

/// Ein Tag der Woche in der Karte "Plan für heute": heute in der Mitte, drei Tage davor und drei danach.
struct HeutePlanTag: Equatable, Sendable, Identifiable {
    enum Marke: Equatable, Sendable {
        /// Trainiert (Einheit oder Haken).
        case erledigt
        /// Laut Plan ein Trainingstag: Buchstabe und Name des Plantags.
        case training(buchstabe: String, name: String)
        /// Ruhetag oder nichts geplant.
        case ruhe
    }

    var tag: String
    var kuerzel: String
    var istHeute: Bool
    var zukunft: Bool
    var marke: Marke
    var id: String { tag }
}

/// Reine Logik der Heute-Karten im neuen Design (10.11.2026): Gruß, Plan-Woche, Buchstabe des Plantags, Dauer, Ziel-Wort, Lumis Fortschritts-Satz, Gewicht zur Vorwoche.
enum HeuteKartenLogik {
    /// "Guten Morgen" (5 bis 10 Uhr), "Guten Tag" (11 bis 16), "Guten Abend" (17 bis 21), sonst "Gute Nacht".
    static func gruss(stunde: Int) -> String {
        switch stunde {
        case 5..<11: String(localized: "Guten Morgen")
        case 11..<17: String(localized: "Guten Tag")
        case 17..<22: String(localized: "Guten Abend")
        default: String(localized: "Gute Nacht")
        }
    }

    /// Sieben Tage mit heute in der Mitte (Besitzer 10.11.: "heute immer in der Mitte"). Ein rollendes Fenster statt Mo bis So,
    /// damit auch montags drei vergangene Tage zum Antippen da sind. Jeder Tag fragt den Plan seiner eigenen Woche (verlegte Tage, Testwoche).
    static func planWoche(heute: String, plan: TrainingsPlan, gymTage: Set<String>) -> [HeutePlanTag] {
        (-3...3).map { versatz in
            let tag = Datum.addTage(heute, versatz)
            let wochentag = Datum.wochentag(tag)
            let marke: HeutePlanTag.Marke
            if versatz <= 0, gymTage.contains(tag) {
                marke = .erledigt
            } else if case .training(let t) = RuhetagLogik.art(WochenLogik.effektiverPlan(plan, woche: tag), wochentag) {
                marke = .training(buchstabe: buchstabe(t.name), name: t.name)
            } else {
                marke = .ruhe
            }
            return HeutePlanTag(tag: tag, kuerzel: HabitLogik.wochentagKuerzel[wochentag - 1], istHeute: versatz == 0, zukunft: versatz > 0, marke: marke)
        }
    }

    /// Der Buchstabe eines Plantags: "Ganzkörper B" -> "B" (ein einzelner Buchstabe am Ende), sonst der erste Buchstabe ("Push" -> "P").
    static func buchstabe(_ name: String) -> String {
        let worte = name.split(separator: " ")
        if worte.count > 1, let letztes = worte.last, letztes.count == 1 { return letztes.uppercased() }
        return name.first.map { String($0).uppercased() } ?? "–"
    }

    /// Geschätzte Dauer des Plantags auf 5 min gerundet (`ZeitSchaetzung`); 0 ohne Übungen.
    static func minuten(_ tag: TrainingsTag) -> Int {
        guard !tag.uebungen.isEmpty else { return 0 }
        return max(5, Int((Double(ZeitSchaetzung.minuten(tag)) / 5).rounded()) * 5)
    }

    /// Das Ziel als ein Wort für die Plan-Karte.
    static func zielWort(_ art: Zielart) -> String {
        switch art {
        case .aufbauen: String(localized: "Muskelaufbau")
        case .halten: String(localized: "Fitness")
        case .abnehmen: String(localized: "Abnehmen")
        }
    }

    /// Lumis Satz über den Fortschritt (Besitzer 10.11.: "anstatt heute holen wir uns das etwas anderes passend auf den fortschritt"):
    /// die Übung mit dem größten Plus in 4 Wochen. nil ohne Plus.
    static func fortschrittsSatz(_ gewichte: [GewichtZeile], ruhetag: Bool) -> String? {
        guard let beste = gewichte.filter({ $0.aenderung4Wochen > 0 }).max(by: { $0.aenderung4Wochen < $1.aenderung4Wochen }) else { return nil }
        let kg = beste.aenderung4Wochen.formatted(.number.precision(.fractionLength(0...1)))
        return ruhetag
            ? String(localized: "\(beste.name): +\(kg) kg in 4 Wochen. Heute wachsen die Muskeln.")
            : String(localized: "\(beste.name): +\(kg) kg in 4 Wochen. Weiter so.")
    }

    /// Gewicht (Schnitt der 7 Tage bis zum neuesten Eintrag) minus dem Schnitt eine Woche davor, in Zehntel-kg.
    /// nil, wenn es in der Woche davor (7 bis 13 Tage vor dem neuesten Eintrag) keinen Eintrag gibt.
    static func aenderungZurVorwoche(_ werte: [String: Int]) -> Int? {
        let gueltig = werte.filter { $0.value > 0 }
        guard let neuester = gueltig.keys.max(), let jetzt = GewichtLogik.berechnet(gueltig) else { return nil }
        let bis = Datum.addTage(neuester, -7)
        let ab = Datum.addTage(neuester, -13)
        guard let davor = GewichtLogik.berechnet(gueltig.filter { $0.key >= ab && $0.key <= bis }) else { return nil }
        return jetzt - davor
    }

    /// "−0,6 kg zur Vorwoche", "+1,2 kg zur Vorwoche", "±0,0 kg zur Vorwoche".
    static func vorwocheText(_ zehntel: Int) -> String {
        let zeichen = zehntel > 0 ? "+" : zehntel < 0 ? "−" : "±"
        let kg = (Double(abs(zehntel)) / 10).formatted(HeuteFormat.kilo())
        return String(localized: "\(zeichen)\(kg) kg zur Vorwoche")
    }
}
