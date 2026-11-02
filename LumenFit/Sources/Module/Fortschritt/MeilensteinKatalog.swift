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
        case .gym: "Gym"
        case .schritte: "Schritte"
        case .schlaf: "Schlaf"
        case .essen: "Essen"
        case .koerper: "Körper"
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
        Meilenstein(id: "erster-satz", titel: "Erster Satz", bedingung: "Hake deinen ersten Satz ab.", symbol: "dumbbell.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "erste-woche", titel: "Erste Woche", bedingung: "Erreiche dein Wochenziel an Gym-Tagen.", symbol: "calendar", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "gym-10", titel: "10 Gym-Tage", bedingung: "Sei an 10 Tagen im Gym.", symbol: "figure.strengthtraining.traditional", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "gym-50", titel: "50 Gym-Tage", bedingung: "Sei an 50 Tagen im Gym.", symbol: "figure.strengthtraining.traditional", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "gym-100", titel: "100 Gym-Tage", bedingung: "Sei an 100 Tagen im Gym.", symbol: "trophy.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "gym-200", titel: "200 Gym-Tage", bedingung: "Sei an 200 Tagen im Gym.", symbol: "trophy.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "volumen-10000", titel: "10 Tonnen", bedingung: "Bewege insgesamt 10.000 kg.", symbol: "scalemass.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "volumen-50000", titel: "50 Tonnen", bedingung: "Bewege insgesamt 50.000 kg.", symbol: "scalemass.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "volumen-100000", titel: "100 Tonnen", bedingung: "Bewege insgesamt 100.000 kg.", symbol: "scalemass.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "volumen-500000", titel: "500 Tonnen", bedingung: "Bewege insgesamt 500.000 kg.", symbol: "scalemass.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "serie-4", titel: "4 Wochen in Folge", bedingung: "Trainiere 4 Wochen hintereinander.", symbol: "flame.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "serie-12", titel: "12 Wochen in Folge", bedingung: "Trainiere 12 Wochen hintereinander.", symbol: "flame.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "serie-26", titel: "Ein halbes Jahr", bedingung: "Trainiere 26 Wochen hintereinander.", symbol: "flame.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "erster-rekord", titel: "Erster Rekord", bedingung: "Schlage deine Bestleistung in einer Übung.", symbol: "medal.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "rekorde-10", titel: "10 Rekorde", bedingung: "Schlage deine Bestleistung 10 Mal.", symbol: "medal.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "rekorde-25", titel: "25 Rekorde", bedingung: "Schlage deine Bestleistung 25 Mal.", symbol: "medal.fill", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "ganzer-koerper", titel: "Ganzer Körper", bedingung: "Trainiere Brust, Rücken, Schultern, Arme, Bauch und Beine in einer Woche.", symbol: "figure.arms.open", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "lange-einheit", titel: "Eine volle Stunde", bedingung: "Trainiere eine Einheit lang mindestens 60 Minuten.", symbol: "timer", bereich: .trainieren, gruppe: .gym),
        // Erholen
        Meilenstein(id: "schlaf-7", titel: "7 Nächte im Ziel", bedingung: "Erreiche dein Schlafziel 7 Nächte hintereinander.", symbol: "moon.zzz.fill", bereich: .erholen, gruppe: .schlaf),
        Meilenstein(id: "schlaf-30", titel: "30 gute Nächte", bedingung: "Erreiche dein Schlafziel in 30 Nächten.", symbol: "bed.double.fill", bereich: .erholen, gruppe: .schlaf),
        Meilenstein(id: "wiegen-erste", titel: "Erste Wiegung", bedingung: "Trage dein Gewicht zum ersten Mal ein.", symbol: "scalemass.fill", bereich: .erholen, gruppe: .koerper),
        Meilenstein(id: "gewicht-ziel", titel: "Gewichtsziel erreicht", bedingung: "Komm mit deinem Gewicht ans Ziel.", symbol: "target", bereich: .erholen, gruppe: .koerper),
        // Essen (hat keine eigene Datenfarbe; der Rand der Medaille nimmt die Farbe von Trainieren)
        Meilenstein(id: "fruehstueck", titel: "Erstes Frühstück", bedingung: "Trage dein erstes Frühstück ein.", symbol: "sunrise.fill", bereich: .trainieren, gruppe: .essen),
        Meilenstein(id: "tagebuch-7", titel: "7 Tage Tagebuch", bedingung: "Trage an 7 Tagen etwas ein.", symbol: "fork.knife", bereich: .trainieren, gruppe: .essen),
        Meilenstein(id: "tagebuch-30", titel: "30 Tage Tagebuch", bedingung: "Trage an 30 Tagen etwas ein.", symbol: "fork.knife", bereich: .trainieren, gruppe: .essen),
        // Ziel-Medaillen (Runde "Mehrheit"; zählen nicht für Lumis Stufe, siehe `neueIds`)
        Meilenstein(id: "wochenziel-4", titel: "4 Wochen im Ziel", bedingung: "Erreiche dein Gym-Wochenziel 4 Wochen hintereinander.", symbol: "calendar.badge.checkmark", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "wochenziel-12", titel: "12 Wochen im Ziel", bedingung: "Erreiche dein Gym-Wochenziel 12 Wochen hintereinander.", symbol: "calendar.badge.checkmark", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "wochenziel-26", titel: "26 Wochen im Ziel", bedingung: "Erreiche dein Gym-Wochenziel 26 Wochen hintereinander.", symbol: "calendar.badge.checkmark", bereich: .trainieren, gruppe: .gym),
        Meilenstein(id: "schritte-7", titel: "7 Tage Schrittziel", bedingung: "Erreiche dein Schrittziel 7 Tage hintereinander.", symbol: "figure.walk", bereich: .trainieren, gruppe: .schritte),
        Meilenstein(id: "schritte-30", titel: "30 Tage Schrittziel", bedingung: "Erreiche dein Schrittziel an 30 Tagen.", symbol: "figure.walk", bereich: .trainieren, gruppe: .schritte),
        Meilenstein(id: "protein-7", titel: "7 Tage Proteinziel", bedingung: "Erreiche dein Proteinziel 7 Tage hintereinander.", symbol: "fork.knife", bereich: .trainieren, gruppe: .essen),
        Meilenstein(id: "protein-30", titel: "30 Tage Proteinziel", bedingung: "Erreiche dein Proteinziel an 30 Tagen.", symbol: "fork.knife", bereich: .trainieren, gruppe: .essen),
        Meilenstein(id: "kalorien-7", titel: "7 Tage im Rahmen", bedingung: "Bleib an 7 Tagen im Rahmen deines Kalorienziels.", symbol: "checkmark.circle", bereich: .trainieren, gruppe: .essen),
    ]

    /// Die Ziel-Medaillen der Runde "Mehrheit". Sie zählen nicht für Lumis Stufe: sonst höbe die Aufnahme neuer Abzeichen heimlich Stufen an.
    nonisolated static let neueIds: Set<String> = ["wochenziel-4", "wochenziel-12", "wochenziel-26", "schritte-7", "schritte-30", "protein-7", "protein-30", "kalorien-7"]

    /// Die Zahl, aus der Lumis Stufe folgt: alle erreichten Kennungen ohne die Ziel-Medaillen.
    nonisolated static func stufenZahl(_ ids: some Sequence<String>) -> Int { ids.filter { !neueIds.contains($0) }.count }

    nonisolated static let nachId: [String: Meilenstein] = Dictionary(uniqueKeysWithValues: alle.map { ($0.id, $0) })

    nonisolated static var anzahl: Int { alle.count }
}
