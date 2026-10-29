import Foundation
import Observation

/// Ziele und Körperdaten des Profils (`ziele.json`, `koerper.json` im Profilordner).
@MainActor @Observable
final class ZieleStore {
    @ObservationIgnored private let zieleDatei: JSONDatei<Ziele>?
    @ObservationIgnored private let koerperDatei: JSONDatei<Koerperdaten>?
    private var gespeicherteZiele = Ziele()
    private var gespeicherterKoerper = Koerperdaten()

    var ziele: Ziele {
        get { gespeicherteZiele }
        set { setze(newValue) }
    }

    var koerper: Koerperdaten {
        get { gespeicherterKoerper }
        set { setzeKoerper(newValue) }
    }

    /// Ohne Ordner nur im Speicher (Vorschau und Tests).
    init(ordner: URL? = nil) {
        zieleDatei = ordner.map { JSONDatei<Ziele>($0.appendingPathComponent("ziele.json")) }
        koerperDatei = ordner.map { JSONDatei<Koerperdaten>($0.appendingPathComponent("koerper.json")) }
        if let z = zieleDatei?.lade() { gespeicherteZiele = z }
        if let k = koerperDatei?.lade() { gespeicherterKoerper = k }
    }

    func setze(_ ziele: Ziele) {
        gespeicherteZiele = ziele
        zieleDatei?.speichere(ziele)
    }

    func setzeKoerper(_ koerper: Koerperdaten) {
        gespeicherterKoerper = koerper
        koerperDatei?.speichere(koerper)
    }
}
