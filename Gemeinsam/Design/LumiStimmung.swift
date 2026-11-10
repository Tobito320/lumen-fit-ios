import SwiftUI

extension LumiStimmung {
    /// Für den Satz neben Lumi und für VoiceOver ("Lumi ist müde").
    var beschreibung: String {
        switch self {
        case .bereit: "Lumi ist bereit"
        case .muede: "Lumi ist müde"
        case .stolz: "Lumi freut sich über den Rekord"
        case .schlaeft: "Lumi schläft"
        case .denkt: "Lumi denkt nach"
        case .willkommen: "Lumi winkt dir zu"
        case .anfeuern: "Lumi feuert dich an"
        case .pause: "Lumi macht Pause"
        case .ziel: "Lumi jubelt"
        case .serie: "Lumi hält die Serie"
        case .erschoepft: "Lumi ist erschöpft"
        case .ruhetag: "Lumi hat Ruhetag"
        case .muskelkater: "Lumi hat Muskelkater"
        case .vermisst: "Lumi vermisst dich"
        }
    }

    /// Kurzer Titel (Profil > Lumi), wie im Lumi-Set.
    var titel: String {
        switch self {
        case .bereit: "Bereit"
        case .muede: "Schlecht geschlafen"
        case .stolz: "Neuer Rekord"
        case .schlaeft: "Schläft"
        case .denkt: "Denkt nach"
        case .willkommen: "Willkommen"
        case .anfeuern: "Training läuft"
        case .pause: "Pause zwischen Sätzen"
        case .ziel: "Ziel erreicht"
        case .serie: "Serie gehalten"
        case .erschoepft: "Erschöpft"
        case .ruhetag: "Ruhetag"
        case .muskelkater: "Muskelkater"
        case .vermisst: "Lange nicht da"
        }
    }

    /// Lumis eigener Satz zum Zustand (Lumi-Set, Feld `satz`).
    var satz: String {
        switch self {
        case .bereit: "Heute holen wir uns das."
        case .muede: "Kurze Nacht. Heute lieber leichter."
        case .stolz: "Neuer Rekord! Das bist du."
        case .schlaeft: "Schlaf ist auch Training."
        case .denkt: "Moment, ich schau mir deine Woche an."
        case .willkommen: "Hi, ich bin Lumi. Wir fangen klein an."
        case .anfeuern: "Noch eine Wiederholung. Du schaffst das."
        case .pause: "Atmen, trinken, gleich geht's weiter."
        case .ziel: "Ziel geschafft. Genau so."
        case .serie: "Woche für Woche. Die Serie hält."
        case .erschoepft: "Puh. Das war viel. Ruh dich gut aus."
        case .ruhetag: "Ruhetag. Muskeln wachsen jetzt."
        case .muskelkater: "Autsch. Leichte Bewegung hilft."
        case .vermisst: "Ich hab dich vermisst. Nur 20 Minuten?"
        }
    }

    /// Farben des Körpers (Mitte nach Rand), Hof, Füße, Arme, Kontur und Gesichtsfarbe. Seit dem Lumi-Set ein Gold für alle Zustände;
    /// erschöpft und müde sind blasser ("matt").
    struct Farbsatz: Sendable {
        let verlauf: [UInt32]       // vier Stufen bei 0, 0,45, 0,85 und 1
        let hof: UInt32
        let fuss: UInt32
        let arm: UInt32
        let kontur: UInt32
        let gesicht: UInt32
    }

    var farbsatz: Farbsatz {
        switch self {
        case .erschoepft, .muede:
            Farbsatz(verlauf: [0xFFF6E0, 0xFADB8E, 0xF0B55A, 0xD98A32], hof: 0xFADB8E, fuss: 0xD98A32, arm: 0xF0B55A, kontur: 0xC07320, gesicht: 0x3A2200)
        default:
            Farbsatz(verlauf: [0xFFF8D6, 0xFFD95A, 0xFFAE1F, 0xF07E00], hof: 0xFFD95A, fuss: 0xF07E00, arm: 0xFFAE1F, kontur: 0xD86A00, gesicht: 0x3A2200)
        }
    }
}
