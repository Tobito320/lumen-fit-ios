import Foundation

/// Lässt den Snapshot höchstens einmal je `abstand` Sekunden schreiben (Standard 30). Eine Anforderung, die zu früh kommt, wird gemerkt und genau einmal
/// nachgeholt, sobald der Abstand um ist: die letzte Änderung geht nie verloren (Vorbild: Loveas `WidgetThrottle` plus Bahnherz' `WidgetDrossel`).
/// Uhr und Verzögerung kommen von außen, damit Tests mit künstlicher Uhr laufen.
@MainActor
final class WidgetsDrossel {
    nonisolated static let standardAbstand: TimeInterval = 30

    private let abstand: TimeInterval
    private let uhr: Uhr
    private let aktion: @MainActor () -> Void
    private let verzoegere: @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void
    private(set) var letztes: Date?
    private(set) var nachholenGeplant = false
    /// Nummer des geplanten Nachholens: eine alte, überholte Aufgabe erkennt sich daran und tut nichts.
    private var planNummer = 0

    init(abstand: TimeInterval = WidgetsDrossel.standardAbstand, uhr: @escaping Uhr, aktion: @escaping @MainActor () -> Void,
         verzoegere: @escaping @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void) {
        self.abstand = abstand
        self.uhr = uhr
        self.aktion = aktion
        self.verzoegere = verzoegere
    }

    /// Reine Wartezeit bis zum nächsten erlaubten Lauf (portiert aus Loveas `WidgetThrottle.wartezeit`).
    nonisolated static func wartezeit(zuletzt: Date, jetzt: Date, minAbstand: TimeInterval) -> TimeInterval {
        max(0, minAbstand - jetzt.timeIntervalSince(zuletzt))
    }

    /// `sofort` umgeht den Abstand (Profilwechsel, Hintergrund-Abruf); die Drosselung beginnt danach von vorn.
    func anfordern(sofort: Bool = false) {
        let jetzt = uhr()
        if sofort || letztes == nil || Self.wartezeit(zuletzt: letztes ?? jetzt, jetzt: jetzt, minAbstand: abstand) == 0 {
            fuehreAus(jetzt)
            return
        }
        guard !nachholenGeplant, let letztes else { return }
        nachholenGeplant = true
        planNummer += 1
        let nummer = planNummer
        verzoegere(max(1, Self.wartezeit(zuletzt: letztes, jetzt: jetzt, minAbstand: abstand))) { [self] in nachholen(nummer) }
    }

    /// Nur die jüngste Planung läuft; ein sofortiger Lauf dazwischen hat sie schon erledigt (`nachholenGeplant` ist dann false).
    private func nachholen(_ nummer: Int) {
        guard nachholenGeplant, nummer == planNummer else { return }
        fuehreAus(uhr())
    }

    private func fuehreAus(_ jetzt: Date) {
        letztes = jetzt
        nachholenGeplant = false
        aktion()
    }
}
