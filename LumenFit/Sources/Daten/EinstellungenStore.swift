import Foundation
import Observation

/// Einstellungen des Profils (`einstellungen.json` im Profilordner). Jede Änderung wird sofort gespeichert und gemeldet.
@MainActor @Observable
final class EinstellungenStore {
    @ObservationIgnored private let datei: JSONDatei<Einstellungen>?
    @ObservationIgnored private let ereignisse: EreignisKanal?
    private var gespeichert = Einstellungen()

    /// Von Hand zu setzen (`$store.werte.haptik` in Ansichten) oder über `aendere`; beides speichert.
    var werte: Einstellungen {
        get { gespeichert }
        set { setze(newValue) }
    }

    /// Ohne Ordner nur im Speicher (Vorschau und Tests).
    init(ordner: URL? = nil, ereignisse: EreignisKanal? = nil) {
        datei = ordner.map { JSONDatei<Einstellungen>($0.appendingPathComponent("einstellungen.json")) }
        self.ereignisse = ereignisse
        if let alt = datei?.lade() {
            gespeichert = Einstellungen.schlichtEinmal(alt)
            if gespeichert != alt { datei?.speichere(gespeichert) }
        }
    }

    func aendere(_ f: (inout Einstellungen) -> Void) {
        var neu = gespeichert
        f(&neu)
        setze(neu)
    }

    private func setze(_ neu: Einstellungen) {
        guard neu != gespeichert else { return }
        gespeichert = neu
        datei?.speichere(neu)
        ereignisse?.senden(.einstellungenGeaendert)
    }
}
