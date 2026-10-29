import Foundation

/// Eine Medaille: Kennung (steht im Op `fit.lumi.meilenstein`), Titel, die Bedingung in einem Satz und ein Symbol.
struct Meilenstein: Identifiable, Equatable, Sendable {
    let id: String
    let titel: String
    let bedingung: String
    let symbol: String
    let bereich: Datenbereich
}

/// Die 25 Medaillen (Idee 37) als Daten. Die Kennungen sind fest: ein Op mit einer Kennung, die hier fehlt, zählt in Lumis Stufe mit
/// (`MeilensteinStore.stufe` zählt alle Ops), darum nie eine Kennung umbenennen oder entfernen.
enum MeilensteinKatalog {
    nonisolated static let alle: [Meilenstein] = [
        // Trainieren
        Meilenstein(id: "erster-satz", titel: "Erster Satz", bedingung: "Hake deinen ersten Satz ab.", symbol: "dumbbell.fill", bereich: .trainieren),
        Meilenstein(id: "erste-woche", titel: "Erste Woche", bedingung: "Erreiche dein Wochenziel an Gym-Tagen.", symbol: "calendar", bereich: .trainieren),
        Meilenstein(id: "gym-10", titel: "10 Gym-Tage", bedingung: "Sei an 10 Tagen im Gym.", symbol: "figure.strengthtraining.traditional", bereich: .trainieren),
        Meilenstein(id: "gym-50", titel: "50 Gym-Tage", bedingung: "Sei an 50 Tagen im Gym.", symbol: "figure.strengthtraining.traditional", bereich: .trainieren),
        Meilenstein(id: "gym-100", titel: "100 Gym-Tage", bedingung: "Sei an 100 Tagen im Gym.", symbol: "trophy.fill", bereich: .trainieren),
        Meilenstein(id: "gym-200", titel: "200 Gym-Tage", bedingung: "Sei an 200 Tagen im Gym.", symbol: "trophy.fill", bereich: .trainieren),
        Meilenstein(id: "volumen-10000", titel: "10 Tonnen", bedingung: "Bewege insgesamt 10.000 kg.", symbol: "scalemass.fill", bereich: .trainieren),
        Meilenstein(id: "volumen-50000", titel: "50 Tonnen", bedingung: "Bewege insgesamt 50.000 kg.", symbol: "scalemass.fill", bereich: .trainieren),
        Meilenstein(id: "volumen-100000", titel: "100 Tonnen", bedingung: "Bewege insgesamt 100.000 kg.", symbol: "scalemass.fill", bereich: .trainieren),
        Meilenstein(id: "volumen-500000", titel: "500 Tonnen", bedingung: "Bewege insgesamt 500.000 kg.", symbol: "scalemass.fill", bereich: .trainieren),
        Meilenstein(id: "serie-4", titel: "4 Wochen in Folge", bedingung: "Trainiere 4 Wochen hintereinander.", symbol: "flame.fill", bereich: .trainieren),
        Meilenstein(id: "serie-12", titel: "12 Wochen in Folge", bedingung: "Trainiere 12 Wochen hintereinander.", symbol: "flame.fill", bereich: .trainieren),
        Meilenstein(id: "serie-26", titel: "Ein halbes Jahr", bedingung: "Trainiere 26 Wochen hintereinander.", symbol: "flame.fill", bereich: .trainieren),
        Meilenstein(id: "erster-rekord", titel: "Erster Rekord", bedingung: "Schlage deine Bestleistung in einer Übung.", symbol: "medal.fill", bereich: .trainieren),
        Meilenstein(id: "rekorde-10", titel: "10 Rekorde", bedingung: "Schlage deine Bestleistung 10 Mal.", symbol: "medal.fill", bereich: .trainieren),
        Meilenstein(id: "rekorde-25", titel: "25 Rekorde", bedingung: "Schlage deine Bestleistung 25 Mal.", symbol: "medal.fill", bereich: .trainieren),
        Meilenstein(id: "ganzer-koerper", titel: "Ganzer Körper", bedingung: "Trainiere Brust, Rücken, Schultern, Arme, Bauch und Beine in einer Woche.", symbol: "figure.arms.open", bereich: .trainieren),
        Meilenstein(id: "lange-einheit", titel: "Eine volle Stunde", bedingung: "Trainiere eine Einheit lang mindestens 60 Minuten.", symbol: "timer", bereich: .trainieren),
        // Erholen
        Meilenstein(id: "schlaf-7", titel: "7 Nächte im Ziel", bedingung: "Erreiche dein Schlafziel 7 Nächte hintereinander.", symbol: "moon.zzz.fill", bereich: .erholen),
        Meilenstein(id: "schlaf-30", titel: "30 gute Nächte", bedingung: "Erreiche dein Schlafziel in 30 Nächten.", symbol: "bed.double.fill", bereich: .erholen),
        Meilenstein(id: "wiegen-erste", titel: "Erste Wiegung", bedingung: "Trage dein Gewicht zum ersten Mal ein.", symbol: "scalemass.fill", bereich: .erholen),
        Meilenstein(id: "gewicht-ziel", titel: "Gewichtsziel erreicht", bedingung: "Komm mit deinem Gewicht ans Ziel.", symbol: "target", bereich: .erholen),
        // Essen (hat keine eigene Datenfarbe; der Rand der Medaille nimmt die Farbe von Trainieren)
        Meilenstein(id: "fruehstueck", titel: "Erstes Frühstück", bedingung: "Trage dein erstes Frühstück ein.", symbol: "sunrise.fill", bereich: .trainieren),
        Meilenstein(id: "tagebuch-7", titel: "7 Tage Tagebuch", bedingung: "Trage an 7 Tagen etwas ein.", symbol: "fork.knife", bereich: .trainieren),
        Meilenstein(id: "tagebuch-30", titel: "30 Tage Tagebuch", bedingung: "Trage an 30 Tagen etwas ein.", symbol: "fork.knife", bereich: .trainieren),
    ]

    nonisolated static let nachId: [String: Meilenstein] = Dictionary(uniqueKeysWithValues: alle.map { ($0.id, $0) })

    nonisolated static var anzahl: Int { alle.count }
}
