import Foundation
import Observation

/// Verlauf (Op `fit.coach.nachricht`) und Merkzettel (Op `fit.coach.merke`) des Coachs.
@MainActor @Observable
final class CoachStore {
    @ObservationIgnored private let raum: LokalerRaum
    private var nachrichten: [String: CoachNachricht] = [:]
    private var merken: [String] = []

    static let nachrichtArt = "fit.coach.nachricht"
    static let merkeArt = "fit.coach.merke"

    init(raum: LokalerRaum) {
        self.raum = raum
        raum.beobachten([Self.nachrichtArt, Self.merkeArt]) { [weak self] op in
            if op.art == Self.nachrichtArt, let n = op.daten(CoachNachricht.self) {
                self?.nachrichten[n.id] = n
            } else if op.art == Self.merkeArt, let m = op.daten(MerkEintrag.self) {
                self?.merken.removeAll { $0 == m.text }
                if !m.entfernt { self?.merken.append(m.text) }
            }
        }
    }

    /// Nach Zeit sortiert, älteste zuerst; gleiche `id` (zum Beispiel ein Daumen später) ersetzt die frühere.
    var verlauf: [CoachNachricht] { nachrichten.values.sorted { ($0.zeit, $0.id) < ($1.zeit, $1.id) } }
    var merkzettel: [String] { merken }

    func haenge(_ nachricht: CoachNachricht) { raum.senden(Self.nachrichtArt, nachricht) }

    func merke(_ text: String) {
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty, !merken.contains(sauber) else { return }
        raum.senden(Self.merkeArt, MerkEintrag(text: sauber, entfernt: false))
    }

    func vergiss(_ text: String) {
        guard merken.contains(text) else { return }
        raum.senden(Self.merkeArt, MerkEintrag(text: text, entfernt: true))
    }
}
