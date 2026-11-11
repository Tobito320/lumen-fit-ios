import Foundation

/// Karte "Gestern verpasst" auf Heute (Besitzer 11.11.2026: "hast du vergessen gestern gym eintragen oder warst du garnicht"):
/// gestern war laut Plan ein Trainingstag, es gibt aber keine Einheit. `freie` sind die Tage, auf die der Plantag diese Woche nachgeholt werden kann.
struct GymVerpasst: Equatable, Sendable {
    var gestern: String
    var tag: TrainingsTag
    /// Freie Tage ab morgen bis Sonntag, der beste zuerst.
    var freie: [String]
    /// "Freitag ist frei, zwischen Beine und Ruhetag." für den ersten freien Tag; nil ohne.
    var freiText: String?

    /// Schlüssel für "beantwortet" (`TagesHinweisSpeicher`).
    var id: String { GymVerpasstLogik.id(gestern) }
    var name: String { GymVerpasstLogik.name(tag) }
    var wochentag: String { GymVerpasstLogik.wochentag(gestern) }
}

enum GymVerpasstLogik {
    static func id(_ gestern: String) -> String { "verpasst.\(gestern)" }

    static func name(_ tag: TrainingsTag) -> String { tag.name.isEmpty ? String(localized: "Training") : tag.name }

    static func wochentag(_ datum: String) -> String { TrainingLogik.wochentagName[Datum.wochentag(datum) - 1] }

    /// Die Karte, wenn gestern laut Plan (mit verlegten Tagen) ein Trainingstag ohne Einheit war, heute nichts läuft und nichts
    /// trainiert ist und die Karte für gestern noch nicht beantwortet wurde; sonst nil. `gymTage`: Tage mit Einheit oder Gym-Haken.
    static func karte(plan: TrainingsPlan, heute: String, gymTage: Set<String>, laeuft: Bool, beantwortet: Set<String>,
                      schwerpunkt: (TrainingsTag) -> Set<String> = RuhetagLogik.schwerpunkt) -> GymVerpasst? {
        let gestern = Datum.addTage(heute, -1)
        guard !laeuft, !gymTage.contains(heute), !gymTage.contains(gestern), !beantwortet.contains(id(gestern)),
              let tag = TrainingLogik.tag(plan, datum: gestern) else { return nil }
        let freie = freieTage(plan, tag: tag, gestern: gestern, heute: heute, gemacht: gymTage, schwerpunkt: schwerpunkt)
        return GymVerpasst(gestern: gestern, tag: tag, freie: freie, freiText: freie.first.map { freiText(plan, datum: $0) })
    }

    /// Die freien Tage ab morgen bis Sonntag, auf die `WochenLogik.verlegeZiele` den verpassten Tag lässt (ein vergangener Tag geht nur auf
    /// einen freien). Der früheste zuerst; Tage direkt neben einem Tag mit denselben Hauptmuskeln kommen nach hinten.
    static func freieTage(_ plan: TrainingsPlan, tag: TrainingsTag, gestern: String, heute: String, gemacht: Set<String>,
                          schwerpunkt: (TrainingsTag) -> Set<String>) -> [String] {
        let ziele = WochenLogik.verlegeZiele(plan, von: gestern, heute: heute, gemacht: gemacht).map(\.datum).filter { $0 > heute }
        let muskeln = schwerpunkt(tag)
        let eng = Set(ziele.filter { datum in
            [-1, 1].contains { versatz in
                TrainingLogik.tag(plan, datum: Datum.addTage(datum, versatz)).map { !schwerpunkt($0).isDisjoint(with: muskeln) } ?? false
            }
        })
        return ziele.filter { !eng.contains($0) } + ziele.filter { eng.contains($0) }
    }

    /// "Freitag ist frei, zwischen Beine und Ruhetag."
    static func freiText(_ plan: TrainingsPlan, datum: String) -> String {
        func nachbar(_ versatz: Int) -> String {
            TrainingLogik.tag(plan, datum: Datum.addTage(datum, versatz)).map { name($0) } ?? String(localized: "Ruhetag")
        }
        return String(localized: "\(wochentag(datum)) ist frei, zwischen \(nachbar(-1)) und \(nachbar(1)).")
    }

    /// Die Übungen des Plantags zum Nachtragen: Sätze mit den Werten vom letzten Mal (wie beim Trainingsstart), alle abgehakt, Cardio gemacht.
    /// `frueher`: Einheiten vor dem Tag, neueste zuerst.
    static func vorbelegt(_ tag: TrainingsTag, frueher: [GymSession]) -> [WorkoutUebung] {
        let leer = GymSession(id: "", tag: tag.id, start: Date(timeIntervalSince1970: 0), ende: nil, laeufe: [])
        return WorkoutLogik.uebungen(leer, tag: tag, frueher: frueher).map { u in
            var u = u
            for i in u.saetze.indices { u.saetze[i].ok = true }
            u.cardioFertig = u.planUebung.istCardio
            return u
        }
    }
}
