import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

/// Absturz und Hänger über MetricKit (Apple, kein Fremd-SDK). Aus den Berichten wird nur gezählt, wie viele es waren und welcher Art (aus den Zahlen
/// Signal und Ausnahme); Stacks, Texte und Gerätedaten werden nie gelesen oder gespeichert. Dazu einmal am Tag die Zähler ungewollter Enden von iOS
/// (vorne oder im Hintergrund, Watchdog, Speicher). Nur mit Zustimmung angemeldet; Berichte, die vor dem "Ja" endeten, werden ignoriert.
/// iOS liefert die Berichte verspätet (meist am nächsten Tag), sie zählen dann zur App-Version, die sie gerade sendet.
enum NutzungMetrik {
    /// Die Art eines Absturzes aus Signal und Mach-Ausnahme des Berichts (nur Zahlen). Eine Swift-Falle (Unwrap, Index, Hauptakteur-Prüfung) ist SIGTRAP oder EXC_BREAKPOINT.
    nonisolated static func art(signal: Int?, ausnahme: Int?) -> NutzungFehler {
        switch (signal, ausnahme) {
        case (5, _), (_, 6): .absturzFalle
        case (11, _), (10, _), (_, 1): .absturzZugriff
        case (6, _): .absturzAbbruch
        case (9, _): .absturzBeendet
        default: .absturzAnders
        }
    }

    #if canImport(MetricKit)
    @MainActor private static var abonnent: Abonnent?

    /// An- oder abmelden, je nach Zustimmung. Mehrfaches Aufrufen mit demselben Wert tut nichts.
    @MainActor
    static func schalte(_ an: Bool, seit: String?, nutzung: NutzungSpeicher) {
        if an, abonnent == nil {
            let neu = Abonnent(seit: seit ?? "") { zaehler in
                Task { @MainActor in
                    for (art, anzahl) in zaehler where anzahl > 0 { nutzung.fehler(art, anzahl: anzahl) }
                }
            }
            abonnent = neu
            MXMetricManager.shared.add(neu)
        } else if !an, let alt = abonnent {
            MXMetricManager.shared.remove(alt)
            abonnent = nil
        }
    }

    /// Nur Zahlen verlassen die Methoden, die Berichte selbst bleiben hier (sie sind nicht `Sendable`).
    private final class Abonnent: NSObject, MXMetricManagerSubscriber, Sendable {
        let seit: String
        let melde: @Sendable ([NutzungFehler: Int]) -> Void

        init(seit: String, melde: @escaping @Sendable ([NutzungFehler: Int]) -> Void) {
            self.seit = seit
            self.melde = melde
        }

        func didReceive(_ payloads: [MXDiagnosticPayload]) {
            var zaehler: [NutzungFehler: Int] = [:]
            for bericht in payloads where Datum.text(bericht.timeStampEnd) >= seit {
                for absturz in bericht.crashDiagnostics ?? [] {
                    zaehler[.absturz, default: 0] += 1
                    zaehler[NutzungMetrik.art(signal: absturz.signal?.intValue, ausnahme: absturz.exceptionType?.intValue), default: 0] += 1
                }
                zaehler[.haenger, default: 0] += bericht.hangDiagnostics?.count ?? 0
            }
            melde(zaehler)
        }

        func didReceive(_ payloads: [MXMetricPayload]) {
            var zaehler: [NutzungFehler: Int] = [:]
            for bericht in payloads where Datum.text(bericht.timeStampEnd) >= seit {
                guard let enden = bericht.applicationExitMetrics else { continue }
                let v = enden.foregroundExitData, h = enden.backgroundExitData
                zaehler[.endeVorneAbsturz, default: 0] += v.cumulativeAbnormalExitCount + v.cumulativeBadAccessExitCount + v.cumulativeIllegalInstructionExitCount
                zaehler[.endeVorneWatchdog, default: 0] += v.cumulativeAppWatchdogExitCount
                zaehler[.endeVorneSpeicher, default: 0] += v.cumulativeMemoryResourceLimitExitCount
                zaehler[.endeHintenAbsturz, default: 0] += h.cumulativeAbnormalExitCount + h.cumulativeBadAccessExitCount + h.cumulativeIllegalInstructionExitCount
                zaehler[.endeHintenWatchdog, default: 0] += h.cumulativeAppWatchdogExitCount
                zaehler[.endeHintenSpeicher, default: 0] += h.cumulativeMemoryResourceLimitExitCount
                zaehler[.endeHintenZeit, default: 0] += h.cumulativeBackgroundTaskAssertionTimeoutExitCount
                zaehler[.endeHintenDatei, default: 0] += h.cumulativeSuspendedWithLockedFileExitCount
            }
            melde(zaehler)
        }
    }
    #else
    @MainActor
    static func schalte(_ an: Bool, seit: String?, nutzung: NutzungSpeicher) {}
    #endif
}
