import SwiftUI

extension LumiStimmung {
    /// Für den Satz neben Lumi und für VoiceOver ("Lumi ist müde").
    var beschreibung: String {
        switch self {
        case .bereit: String(localized: "Lumi ist bereit")
        case .muede: String(localized: "Lumi ist müde")
        case .stolz: String(localized: "Lumi freut sich über den Rekord")
        case .schlaeft: String(localized: "Lumi schläft")
        case .denkt: String(localized: "Lumi denkt nach")
        case .willkommen: String(localized: "Lumi winkt dir zu")
        case .anfeuern: String(localized: "Lumi feuert dich an")
        case .pause: String(localized: "Lumi macht Pause")
        case .ziel: String(localized: "Lumi jubelt")
        case .serie: String(localized: "Lumi hält die Serie")
        case .erschoepft: String(localized: "Lumi ist erschöpft")
        case .ruhetag: String(localized: "Lumi hat Ruhetag")
        case .muskelkater: String(localized: "Lumi hat Muskelkater")
        case .vermisst: String(localized: "Lumi vermisst dich")
        }
    }

    /// Kurzer Titel (Profil > Lumi), wie im Lumi-Set.
    var titel: String {
        switch self {
        case .bereit: String(localized: "Bereit")
        case .muede: String(localized: "Schlecht geschlafen")
        case .stolz: String(localized: "Neuer Rekord")
        case .schlaeft: String(localized: "Schläft")
        case .denkt: String(localized: "Denkt nach")
        case .willkommen: String(localized: "Willkommen")
        case .anfeuern: String(localized: "Training läuft")
        case .pause: String(localized: "Pause zwischen Sätzen")
        case .ziel: String(localized: "Ziel erreicht")
        case .serie: String(localized: "Serie gehalten")
        case .erschoepft: String(localized: "Erschöpft")
        case .ruhetag: String(localized: "Ruhetag")
        case .muskelkater: String(localized: "Muskelkater")
        case .vermisst: String(localized: "Lange nicht da")
        }
    }

    /// Lumis eigener Satz zum Zustand (Lumi-Set, Feld `satz`).
    var satz: String {
        switch self {
        case .bereit: String(localized: "Heute holen wir uns das.")
        case .muede: String(localized: "Kurze Nacht. Heute lieber leichter.")
        case .stolz: String(localized: "Neuer Rekord! Das bist du.")
        case .schlaeft: String(localized: "Schlaf ist auch Training.")
        case .denkt: String(localized: "Moment, ich schau mir deine Woche an.")
        case .willkommen: String(localized: "Hi, ich bin Lumi. Wir fangen klein an.")
        case .anfeuern: String(localized: "Noch eine Wiederholung. Du schaffst das.")
        case .pause: String(localized: "Atmen, trinken, gleich geht's weiter.")
        case .ziel: String(localized: "Ziel geschafft. Genau so.")
        case .serie: String(localized: "Woche für Woche. Die Serie hält.")
        case .erschoepft: String(localized: "Puh. Das war viel. Ruh dich gut aus.")
        case .ruhetag: String(localized: "Ruhetag. Muskeln wachsen jetzt.")
        case .muskelkater: String(localized: "Autsch. Leichte Bewegung hilft.")
        case .vermisst: String(localized: "Ich hab dich vermisst. Nur 20 Minuten?")
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
