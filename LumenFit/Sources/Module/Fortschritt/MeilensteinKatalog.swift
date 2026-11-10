import Foundation

/// Eine Medaille: Kennung (steht im Op `fit.lumi.meilenstein`), Titel, die Bedingung in einem Satz und ein Symbol.
struct Meilenstein: Identifiable, Equatable, Sendable {
    let id: String
    let titel: String
    let bedingung: String
    let symbol: String
    let bereich: Datenbereich
    /// Unter welcher Überschrift die Medaille steht; schaltet man den Bereich ab, verschwindet sie aus der Ansicht.
    let gruppe: MedaillenGruppe
}

/// Die Abschnitte der Meilensteine-Seite. Gym, Schlaf und Essen hängen an einem wählbaren Bereich, Schritte und Körper bleiben immer.
enum MedaillenGruppe: String, CaseIterable, Sendable {
    case gym, schritte, schlaf, essen, koerper

    var titel: String {
        switch self {
        case .gym: String(localized: "Gym")
        case .schritte: String(localized: "Schritte")
        case .schlaf: String(localized: "Schlaf")
        case .essen: String(localized: "Essen")
        case .koerper: String(localized: "Körper")
        }
    }

    var bereich: AppBereich? {
        switch self {
        case .gym: .gym
        case .schlaf: .schlaf
        case .essen: .essen
        case .schritte, .koerper: nil
        }
    }
}

/// Die Medaillen (Idee 37) als Daten: die ersten 25 und die Ziel-Medaillen der Runde "Mehrheit". Die Kennungen sind fest: ein Op mit einer Kennung, die hier fehlt,
/// zählt in Lumis Stufe mit (`MeilensteinKatalog.stufenZahl`), darum nie eine Kennung umbenennen oder entfernen.
enum MeilensteinKatalog {
    nonisolated static let alle: [Meilenstein] = [
        // Trainieren
        Meilenstein(id: "erster-satz", titel: String(localized: "Erster Satz"), bedingung: String(localized: "Hake deinen ersten Satz ab."), symbol: "dumbbell.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "erste-woche", titel: String(localized: "Erste Woche"), bedingung: String(localized: "Erreiche dein Wochenziel an Gym-Tagen."), symbol: "calendar", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "gym-10", titel: String(localized: "10 Gym-Tage"), bedingung: String(localized: "Sei an 10 Tagen im Gym."), symbol: "figure.strengthtraining.traditional", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "gym-50", titel: String(localized: "50 Gym-Tage"), bedingung: String(localized: "Sei an 50 Tagen im Gym."), symbol: "figure.strengthtraining.traditional", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "gym-100", titel: String(localized: "100 Gym-Tage"), bedingung: String(localized: "Sei an 100 Tagen im Gym."), symbol: "trophy.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "gym-200", titel: String(localized: "200 Gym-Tage"), bedingung: String(localized: "Sei an 200 Tagen im Gym."), symbol: "trophy.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "volumen-10000", titel: String(localized: "10 Tonnen"), bedingung: String(localized: "Bewege insgesamt 10.000 kg."), symbol: "scalemass.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "volumen-50000", titel: String(localized: "50 Tonnen"), bedingung: String(localized: "Bewege insgesamt 50.000 kg."), symbol: "scalemass.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "volumen-100000", titel: String(localized: "100 Tonnen"), bedingung: String(localized: "Bewege insgesamt 100.000 kg."), symbol: "scalemass.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "volumen-500000", titel: String(localized: "500 Tonnen"), bedingung: String(localized: "Bewege insgesamt 500.000 kg."), symbol: "scalemass.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "serie-4", titel: String(localized: "4 Wochen in Folge"), bedingung: String(localized: "Trainiere 4 Wochen hintereinander."), symbol: "flame.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "serie-12", titel: String(localized: "12 Wochen in Folge"), bedingung: String(localized: "Trainiere 12 Wochen hintereinander."), symbol: "flame.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "serie-26", titel: String(localized: "Ein halbes Jahr"), bedingung: String(localized: "Trainiere 26 Wochen hintereinander."), symbol: "flame.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "erster-rekord", titel: String(localized: "Erster Rekord"), bedingung: String(localized: "Schlage deine Bestleistung in einer Übung."), symbol: "medal.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "rekorde-10", titel: String(localized: "10 Rekorde"), bedingung: String(localized: "Schlage deine Bestleistung 10 Mal."), symbol: "medal.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "rekorde-25", titel: String(localized: "25 Rekorde"), bedingung: String(localized: "Schlage deine Bestleistung 25 Mal."), symbol: "medal.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "ganzer-koerper", titel: String(localized: "Ganzer Körper"), bedingung: String(localized: "Trainiere Brust, Rücken, Schultern, Arme, Bauch und Beine in einer Woche."), symbol: "figure.arms.open", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "lange-einheit", titel: String(localized: "Eine volle Stunde"), bedingung: String(localized: "Trainiere eine Einheit lang mindestens 60 Minuten."), symbol: "timer", bereich: .trainieren, gruppe: .gym),
        // Erholen
        Meilenstein(id: "schlaf-7", titel: String(localized: "7 Nächte im Ziel"), bedingung: String(localized: "Erreiche dein Schlafziel 7 Nächte hintereinander."), symbol: "moon.zzz.fill", bereich: .erholen, gruppe: .schlaf),
        Meilenstein(id: "schlaf-30", titel: String(localized: "30 gute Nächte"), bedingung: String(localized: "Erreiche dein Schlafziel in 30 Nächten."), symbol: "bed.double.fill", bereich: .erholen, gruppe: .schlaf),
        Meilenstein(id: "wiegen-erste", titel: String(localized: "Erste Wiegung"), bedingung: String(localized: "Trage dein Gewicht zum ersten Mal ein."), symbol: "scalemass.fill", bereich: .erholen, gruppe: .koerper),
        Meilenstein(id: "gewicht-ziel", titel: String(localized: "Gewichtsziel erreicht"), bedingung: String(localized: "Komm mit deinem Gewicht ans Ziel."), symbol: "target", bereich: .erholen, gruppe: .koerper),
        // Essen (hat keine eigene Datenfarbe; der Rand der Medaille nimmt die Farbe von Trainieren)
        Meilenstein(id: "fruehstueck", titel: String(localized: "Erstes Frühstück"), bedingung: String(localized: "Trage dein erstes Frühstück ein."), symbol: "sunrise.fill", bereich: .trainieren, gruppe: .essen),
        Meilenstein(id: "tagebuch-7", titel: String(localized: "7 Tage Tagebuch"), bedingung: String(localized: "Trage an 7 Tagen etwas ein."), symbol: "fork.knife", bereich: .trainieren, gruppe: .essen),
        Meilenstein(id: "tagebuch-30", titel: String(localized: "30 Tage Tagebuch"), bedingung: String(localized: "Trage an 30 Tagen etwas ein."), symbol: "fork.knife", bereich: .trainieren, gruppe: .essen),
        // Ziel-Medaillen (Runde "Mehrheit"; zählen nicht für Lumis Stufe, siehe `neueIds`)
        Meilenstein(id: "wochenziel-4", titel: String(localized: "4 Wochen im Ziel"), bedingung: String(localized: "Erreiche dein Gym-Wochenziel 4 Wochen hintereinander."), symbol: "calendar.badge.checkmark", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "wochenziel-12", titel: String(localized: "12 Wochen im Ziel"), bedingung: String(localized: "Erreiche dein Gym-Wochenziel 12 Wochen hintereinander."), symbol: "calendar.badge.checkmark", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "wochenziel-26", titel: String(localized: "26 Wochen im Ziel"), bedingung: String(localized: "Erreiche dein Gym-Wochenziel 26 Wochen hintereinander."), symbol: "calendar.badge.checkmark", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "schritte-7", titel: String(localized: "7 Tage Schrittziel"), bedingung: String(localized: "Erreiche dein Schrittziel 7 Tage hintereinander."), symbol: "figure.walk", bereich: .trainieren, gruppe: .schritte),
        Meilenstein(id: "schritte-30", titel: String(localized: "30 Tage Schrittziel"), bedingung: String(localized: "Erreiche dein Schrittziel an 30 Tagen."), symbol: "figure.walk", bereich: .trainieren, gruppe: .schritte),
        Meilenstein(id: "protein-7", titel: String(localized: "7 Tage Proteinziel"), bedingung: String(localized: "Erreiche dein Proteinziel 7 Tage hintereinander."), symbol: "fork.knife", bereich: .trainieren, gruppe: .essen),
        Meilenstein(id: "protein-30", titel: String(localized: "30 Tage Proteinziel"), bedingung: String(localized: "Erreiche dein Proteinziel an 30 Tagen."), symbol: "fork.knife", bereich: .trainieren, gruppe: .essen),
        Meilenstein(id: "kalorien-7", titel: String(localized: "7 Tage im Rahmen"), bedingung: String(localized: "Bleib an 7 Tagen im Rahmen deines Kalorienziels."), symbol: "checkmark.circle", bereich: .trainieren, gruppe: .essen),
    ]

    /// Die Ziel-Medaillen der Runde "Mehrheit". Sie zählen nicht für Lumis Stufe: sonst höbe die Aufnahme neuer Abzeichen heimlich Stufen an.
    nonisolated static let neueIds: Set<String> = ["wochenziel-4", "wochenziel-12", "wochenziel-26", "schritte-7", "schritte-30", "protein-7", "protein-30", "kalorien-7"]

    /// Die Zahl, aus der Lumis Stufe folgt: alle erreichten Kennungen ohne die Ziel-Medaillen.
    nonisolated static func stufenZahl(_ ids: some Sequence<String>) -> Int { ids.filter { !neueIds.contains($0) }.count }

    nonisolated static let nachId: [String: Meilenstein] = Dictionary(uniqueKeysWithValues: alle.map { ($0.id, $0) })

    nonisolated static var anzahl: Int { alle.count }
}
