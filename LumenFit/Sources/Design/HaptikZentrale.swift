import SwiftUI

/// Haptik mit fester Bedeutung. Jedes Signal prüft zuerst den Schalter `Einstellungen.haptik` (Standard an). Nur bei klarer Ursache, nie dauernd.
enum HaptikArt: Sendable { case auswahl, start, stopp, satzFertig, mehr, weniger, pauseEnde, erfolg, stufe, fehler, warnung }

extension EnvironmentValues {
    /// Von `AppRootView` aus den Einstellungen gesetzt.
    @Entry var haptikAn: Bool = true
}

enum HaptikZentrale {
    nonisolated static func rueckmeldung(_ art: HaptikArt) -> SensoryFeedback {
        switch art {
        case .auswahl: .selection
        case .start: .impact(weight: .medium)
        case .stopp: .impact(weight: .light)
        case .satzFertig: .success
        case .mehr: .increase
        case .weniger: .decrease
        case .pauseEnde: .warning
        case .erfolg: .success
        case .stufe: .levelChange
        case .fehler: .error
        case .warnung: .warning
        }
    }
}

private struct HaptikModifier<Ausloeser: Equatable>: ViewModifier {
    let art: HaptikArt
    let ausloeser: Ausloeser
    @Environment(\.haptikAn) private var an

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: ausloeser) { _, _ in an ? HaptikZentrale.rueckmeldung(art) : nil }
    }
}

extension View {
    /// `.sensoryFeedback` mit Schalter aus den Einstellungen; nur bei klarer Ursache benutzen.
    func haptik<Ausloeser: Equatable>(_ art: HaptikArt, bei ausloeser: Ausloeser) -> some View {
        modifier(HaptikModifier(art: art, ausloeser: ausloeser))
    }
}
