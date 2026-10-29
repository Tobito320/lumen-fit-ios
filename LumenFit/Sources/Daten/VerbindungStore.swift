import Foundation
import Observation

/// Verbindung zu Lovea und Freunden: Partner-Stand aus der Brücke, Freigaben und Freundeskarten (`freigaben.json`, `freunde.json`).
/// Nicht verbunden heißt: kein Partner-Teil in der Oberfläche, nicht einmal ein Platzhalter.
@MainActor @Observable
final class VerbindungStore {
    @ObservationIgnored private let freigabenDatei: JSONDatei<[FreigabeArt]>?
    @ObservationIgnored private let freundeDatei: JSONDatei<[FreundKarte]>?
    @ObservationIgnored private let bruecke: any PartnerAustausch
    @ObservationIgnored private let einstellungen: EinstellungenStore?
    @ObservationIgnored private let ereignisse: EreignisKanal?
    private var gespeicherteFreigaben: Set<FreigabeArt> = []
    private var gespeicherteFreunde: [FreundKarte] = []

    private(set) var partner: PartnerStand = .nichtVerbunden

    /// Wer sieht was: Standard leer, jede Art hat ihre eigene Freigabe. Zuweisen speichert.
    var freigaben: Set<FreigabeArt> {
        get { gespeicherteFreigaben }
        set {
            gespeicherteFreigaben = newValue
            freigabenDatei?.speichere(FreigabeArt.allCases.filter { newValue.contains($0) })
        }
    }

    /// Importierte Freundeskarten. Zuweisen speichert.
    var freunde: [FreundKarte] {
        get { gespeicherteFreunde }
        set {
            gespeicherteFreunde = newValue
            freundeDatei?.speichere(newValue)
        }
    }

    var verbunden: Bool { if case .verbunden = partner { true } else { false } }

    init(ordner: URL? = nil, bruecke: any PartnerAustausch = KeinePartnerBruecke(), einstellungen: EinstellungenStore? = nil, ereignisse: EreignisKanal? = nil) {
        freigabenDatei = ordner.map { JSONDatei<[FreigabeArt]>($0.appendingPathComponent("freigaben.json")) }
        freundeDatei = ordner.map { JSONDatei<[FreundKarte]>($0.appendingPathComponent("freunde.json")) }
        self.bruecke = bruecke
        self.einstellungen = einstellungen
        self.ereignisse = ereignisse
        if let f = freigabenDatei?.lade() { gespeicherteFreigaben = Set(f) }
        if let f = freundeDatei?.lade() { gespeicherteFreunde = f }
    }

    /// Liest den Partner-Stand neu. Ist die Einstellung `loveaVerbunden` aus, bleibt alles "nicht verbunden".
    func aktualisiere(jetzt: Date) {
        let neu: PartnerStand = (einstellungen?.werte.loveaVerbunden ?? true) ? bruecke.partner(jetzt: jetzt) : .nichtVerbunden
        guard neu != partner else { return }
        partner = neu
        ereignisse?.senden(.partnerAktualisiert)
    }
}
