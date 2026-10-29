// Quelle: Lovea Health/Coach/CoachHintergrund.swift
import UIKit

// Coach-Frage und Hintergrund: Wischt die Person die App weg, solange der Coach noch antwortet, kann iOS die Rechenarbeit des Modells
// abbrechen. Statt sofort einen Fehler zu zeigen, wartet `sendenGeschuetzt` nach der Rückkehr und fragt genau einmal noch einmal.
// Der Server-Abgleich aus Lovea (Raum-Sync, `serverStand`) entfällt: Lumen Fit hat keinen Server, die Frage liegt schon im Verlauf.
//
// Akku: Die Hintergrund-Aufgabe lebt nur, solange die Frage läuft, und endet mit der Antwort, dem Fehler oder dem Ablauf-Handler von iOS
// (rund 30 s). Kein Timer, kein Dauerpolling.

/// Die reine Entscheidung, ohne Modell und ohne UIKit-Zustand.
enum CoachHintergrund {
    enum Schritt: Equatable, Sendable {
        case erfolg
        /// Zurück in die App, dann genau einmal dieselbe Frage noch einmal.
        case nochmalFragen
        case fehlerZeigen
    }

    /// Nur ein Fehler, nachdem die App im Hintergrund war, wird einmal wiederholt. Jeder andere Fehler (Modell nicht bereit, Frist) wird sofort
    /// gezeigt, nie zweimal gefragt.
    static func naechsterSchritt(gelungen: Bool, warImHintergrund: Bool, schonWiederholt: Bool) -> Schritt {
        if gelungen { return .erfolg }
        return warImHintergrund && !schonWiederholt ? .nochmalFragen : .fehlerZeigen
    }
}

/// Hält eine Coach-Frage am Leben, wenn die App währenddessen in den Hintergrund geht, und fängt den Abbruch ab. Eine Wache je Frage,
/// von `beenden()` im `defer` abgeräumt.
@MainActor
final class CoachHintergrundWache {
    /// Klebrig: gesetzt, sobald die App seit dem Versuchsbeginn im Hintergrund war. Der Fehler kommt oft erst nach der Rückkehr an.
    private(set) var warImHintergrund = false
    private var aufgabe = UIBackgroundTaskIdentifier.invalid
    private var beobachter: [NSObjectProtocol] = []
    private var wartender: CheckedContinuation<Void, Never>?

    init() {
        aufgabe = UIApplication.shared.beginBackgroundTask(withName: "Lumen-Coach-Frage") { [weak self] in
            MainActor.assumeIsolated { self?.aufgabeBeenden() }
        }
        let zentrale = NotificationCenter.default
        beobachter.append(zentrale.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.warImHintergrund = true }
        })
        beobachter.append(zentrale.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.vordergrundErreicht() }
        })
    }

    /// Endet die Hintergrund-Aufgabe und nimmt die Beobachter weg. Mehrfach aufrufbar.
    func beenden() {
        for eintrag in beobachter { NotificationCenter.default.removeObserver(eintrag) }
        beobachter = []
        aufgabeBeenden()
    }

    private func aufgabeBeenden() {
        guard aufgabe != .invalid else { return }
        UIApplication.shared.endBackgroundTask(aufgabe)
        aufgabe = .invalid
    }

    private func vordergrundErreicht() {
        wartender?.resume()
        wartender = nil
    }

    /// Wartet, bis die App wieder vorn ist; sofort fertig, wenn sie es schon ist. Kein Timer: ist die App suspendiert, steht auch das Warten.
    private func aufVordergrund() async {
        guard UIApplication.shared.applicationState != .active else { return }
        await withCheckedContinuation { (weiter: CheckedContinuation<Void, Never>) in
            wartender = weiter
        }
    }

    /// Fragt über `anfrage`. Bricht die Arbeit im Hintergrund ab (Fehler, die App war weg), wartet die Wache auf die Rückkehr und fragt
    /// einmal noch einmal; jeder andere Fehler wird weitergereicht.
    func fragenGeschuetzt(_ anfrage: () async throws -> CoachAntwort) async throws -> CoachAntwort {
        var wiederholt = false
        while true {
            do {
                return try await anfrage()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let schritt = CoachHintergrund.naechsterSchritt(gelungen: false, warImHintergrund: warImHintergrund, schonWiederholt: wiederholt)
                guard schritt == .nochmalFragen else { throw error }
                wiederholt = true
                warImHintergrund = false
                await aufVordergrund()
            }
        }
    }
}
