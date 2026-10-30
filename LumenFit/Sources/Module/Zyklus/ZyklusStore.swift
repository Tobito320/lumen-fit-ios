// Quelle: Lovea Zyklus/EchterZyklusSpeicher.swift (Ops statt eigener Datei; kein Gerät-Gegenüber, nur das eigene Profil)
import Foundation
import Observation

/// Kleine lokale Werte des Zyklus (nicht Teil des Op-Logs): Schalter, Sperre, Health, Vorhersage-Breite und die Angaben der Modi.
/// Alles optional oder mit Standard, damit eine ältere Datei lesbar bleibt.
struct ZyklusLokaleWerte: Codable, Equatable, Sendable {
    /// "Zyklus verwenden". Standard aus: ohne Schalter zeigt die App nichts vom Zyklus.
    var aktiv = false
    /// Face ID oder Gerätecode vor dem Zyklus. Standard an.
    var sperre = true
    /// Periode, Basaltemperatur und Gewicht aus Health in leere Tage lesen. Standard aus.
    var healthLesen = false
    var healthStand: Date?
    /// Hinweise zu Training und Alltag auf der Heute-Seite. Standard an (wirkt nur bei aktivem Zyklus).
    var imTraining = true
    /// Breite der Perioden-Vorhersage, -1 = automatisch (`ZyklusZeitraum.wahl`).
    var zeitraum = -1
    /// Partner sieht Phase und Tag in kurzen Hinweisen (Feld `zyklus` der Tageszusammenfassung). Standard aus.
    var partnerZeigen = false
    var schwangerTermin: String?
    var pillePackung = ZyklusModiLogik.Packung.einundzwanzig
    var pilleStart: String?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case aktiv, sperre, healthLesen, healthStand, imTraining, zeitraum, partnerZeigen, schwangerTermin, pillePackung, pilleStart
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv) ?? false
        sperre = try c.decodeIfPresent(Bool.self, forKey: .sperre) ?? true
        healthLesen = try c.decodeIfPresent(Bool.self, forKey: .healthLesen) ?? false
        healthStand = try c.decodeIfPresent(Date.self, forKey: .healthStand)
        imTraining = try c.decodeIfPresent(Bool.self, forKey: .imTraining) ?? true
        zeitraum = try c.decodeIfPresent(Int.self, forKey: .zeitraum) ?? -1
        partnerZeigen = try c.decodeIfPresent(Bool.self, forKey: .partnerZeigen) ?? false
        schwangerTermin = try c.decodeIfPresent(String.self, forKey: .schwangerTermin)
        pillePackung = (try? c.decodeIfPresent(ZyklusModiLogik.Packung.self, forKey: .pillePackung)).flatMap { $0 } ?? .einundzwanzig
        pilleStart = try c.decodeIfPresent(String.self, forKey: .pilleStart)
    }
}

/// Das Zyklus-Tagebuch eines Profils: faltet `zyklus.tag` und `zyklus.einstellung` aus dem Op-Log (Format wie in Lovea) und schreibt neue Ops dorthin.
/// Alles bleibt auf dem Gerät. Die Anzeige hängt am Schalter `werte.aktiv` (Standard aus).
@MainActor @Observable
final class ZyklusStore {
    @ObservationIgnored private let raum: LokalerRaum
    @ObservationIgnored private let datei: JSONDatei<ZyklusLokaleWerte>?
    @ObservationIgnored private let uhr: Uhr
    private var stand = ZyklusStand()
    private(set) var werte: ZyklusLokaleWerte

    /// `ordner` nil = nur im Speicher (Tests).
    init(raum: LokalerRaum, ordner: URL?, uhr: @escaping Uhr = { Date() }) {
        self.raum = raum
        self.uhr = uhr
        datei = ordner.map { JSONDatei<ZyklusLokaleWerte>($0.appendingPathComponent("zyklus-lokal.json")) }
        werte = datei?.lade() ?? ZyklusLokaleWerte()
        raum.beobachten(ZyklusOps.arten) { [weak self] op in self?.stand.anwenden(op) }
    }

    // MARK: - Lesen

    var aktiv: Bool { werte.aktiv }
    var tage: [String: ZyklusTag] { stand.tage }
    var einstellung: ZyklusEinstellung { stand.einstellung }
    var heute: String { Datum.text(uhr()) }

    func logik(heute: String? = nil) -> ZyklusLogik {
        ZyklusLogik(tage: Array(stand.tage.values), einstellung: stand.einstellung, heute: heute ?? self.heute)
    }

    /// Hinweis für Training und Alltag von heute; nil, solange der Zyklus aus ist oder der Schalter fehlt.
    func hinweisHeute() -> ZyklusHinweis? {
        guard werte.aktiv, werte.imTraining else { return nil }
        return ZyklusVerknuepfung.hinweis(logik: logik(), am: heute)
    }

    /// Phase und Tag für den Partner, in kurzen Hinweisen. nil ohne Phase oder bei einem anderen Modus als Zyklus.
    func uebersetzung() -> ZyklusUebersetzer.Botschaft? {
        guard werte.aktiv else { return nil }
        let l = logik()
        guard l.einstellung.modus == .zyklus else { return nil }
        return ZyklusUebersetzer.fuer(phase: l.phase(am: heute), tag: stand.tage[heute])
    }

    /// Was der Partner sieht: nur mit "Zyklus verwenden" und "Partner darf Phase sehen", sonst nil (das Feld fehlt dann in der Datei).
    func partnerZusammenfassung() -> ZyklusZusammenfassung? {
        guard werte.aktiv, werte.partnerZeigen else { return nil }
        return ZyklusZusammenfassung.bauen(logik: logik(), heute: heute, eintrag: stand.tage[heute])
    }

    // MARK: - Schreiben

    func setze(_ tag: ZyklusTag) {
        raum.senden(ZyklusOps.tagArt, ZyklusOps.TagD(id: tag.id, tag: tag.istLeer ? nil : tag))
    }

    func setzeEinstellung(_ neu: ZyklusEinstellung) {
        guard neu != stand.einstellung else { return }
        raum.senden(ZyklusOps.einstellungArt, ZyklusOps.EinstellungD(einstellung: neu))
    }

    /// Leert alle Tage (Löschmarke je Tag). Der Op-Log bleibt Anhängen-nur: ganz weg gehen die alten Zeilen erst mit "Alles löschen" im Profil.
    func alleTageLeeren() {
        for id in Array(stand.tage.keys) { setze(ZyklusTag(id: id)) }
    }

    func aendere(_ f: (inout ZyklusLokaleWerte) -> Void) {
        var neu = werte
        f(&neu)
        guard neu != werte else { return }
        werte = neu
        datei?.speichere(neu)
    }
}
