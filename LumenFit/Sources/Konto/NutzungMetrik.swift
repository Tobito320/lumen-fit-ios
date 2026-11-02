import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

/// Absturz und Hänger über MetricKit (Apple, kein Fremd-SDK). Aus den Berichten wird nur gezählt, wie viele es waren; Stacks, Texte und Gerätedaten
/// werden nie gelesen oder gespeichert. Nur mit Zustimmung angemeldet; Berichte, die vor dem "Ja" endeten, werden ignoriert.
/// iOS liefert die Berichte verspätet (meist am nächsten Tag), sie zählen dann zur App-Version, die sie gerade sendet.
enum NutzungMetrik {
    #if canImport(MetricKit)
    @MainActor private static var abonnent: Abonnent?

    /// An- oder abmelden, je nach Zustimmung. Mehrfaches Aufrufen mit demselben Wert tut nichts.
    @MainActor
    static func schalte(_ an: Bool, seit: String?, nutzung: NutzungSpeicher) {
        if an, abonnent == nil {
            let neu = Abonnent(seit: seit ?? "") { absturz, haenger in
                Task { @MainActor in
                    if absturz > 0 { nutzung.fehler(.absturz, anzahl: absturz) }
                    if haenger > 0 { nutzung.fehler(.haenger, anzahl: haenger) }
                }
            }
            abonnent = neu
            MXMetricManager.shared.add(neu)
        } else if !an, let alt = abonnent {
            MXMetricManager.shared.remove(alt)
            abonnent = nil
        }
    }

    /// Nur Zahlen verlassen die Methode, der Bericht selbst bleibt hier (er ist nicht `Sendable`).
    private final class Abonnent: NSObject, MXMetricManagerSubscriber, Sendable {
        let seit: String
        let melde: @Sendable (Int, Int) -> Void

        init(seit: String, melde: @escaping @Sendable (Int, Int) -> Void) {
            self.seit = seit
            self.melde = melde
        }

        func didReceive(_ payloads: [MXDiagnosticPayload]) {
            var absturz = 0
            var haenger = 0
            for bericht in payloads where Datum.text(bericht.timeStampEnd) >= seit {
                absturz += bericht.crashDiagnostics?.count ?? 0
                haenger += bericht.hangDiagnostics?.count ?? 0
            }
            melde(absturz, haenger)
        }
    }
    #else
    @MainActor
    static func schalte(_ an: Bool, seit: String?, nutzung: NutzungSpeicher) {}
    #endif
}
