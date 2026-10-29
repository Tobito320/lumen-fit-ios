import Foundation

/// Aus dem Partner-Stand werden lokale Mitteilungen (Idee 83): "Partner ist im Gym", "Ziel erreicht", "hat gut geschlafen".
/// Regeln: nur im Stand `verbunden` (nicht veraltet, nicht unbekannte Version), nur frische Ereignisse (`frischBis`), je Art abschaltbar
/// (`Einstellungen.mitteilungen["partner.<art>"]`, Standard an), und jede Ereignis-Id höchstens einmal (die Ids merkt `partner-gemeldet.json` im
/// Profilordner, die letzten 200). Auch ein abgeschaltetes oder altes Ereignis wird als gesehen gemerkt, damit ein späteres Einschalten nicht alles nachholt.
/// Die Mitteilung kommt sofort (`Mitteiler.zeige`), nie als geplante Erinnerung.
@MainActor
final class PartnerEreignisRegeln {
    nonisolated static let gemerktMaximal = 200
    /// Älter als das gilt ein Ereignis als erledigt (kein Mitteilen von gestern).
    nonisolated static let frischBis: TimeInterval = 12 * 3600

    private let mitteiler: any Mitteiler
    private let datei: JSONDatei<[String]>?
    private var gemerkt: [String]
    /// Nach jeder neuen Mitteilung (für das Band: `BandQuelle.partner`).
    var beiNeuem: (@MainActor (PartnerEreignis) -> Void)?

    /// `ordner` ist der Profilordner; ohne Ordner nur im Speicher (Tests).
    init(mitteiler: any Mitteiler, ordner: URL?) {
        self.mitteiler = mitteiler
        datei = ordner.map { JSONDatei<[String]>($0.appendingPathComponent("partner-gemeldet.json")) }
        gemerkt = datei?.lade() ?? []
    }

    /// Der Schlüssel in `Einstellungen.mitteilungen` für eine Art.
    nonisolated static func schluessel(_ art: PartnerEreignisArt) -> String { "partner.\(art.rawValue)" }

    /// Die Texte der Schalter in der Oberfläche.
    nonisolated static func name(_ art: PartnerEreignisArt) -> String {
        switch art {
        case .gymStart: "Partner ist im Gym"
        case .gymEnde: "Partner war im Gym"
        case .ziel: "Partner hat das Ziel erreicht"
        case .rekord: "Partner hat einen Rekord"
        case .schlafGut: "Partner hat gut geschlafen"
        }
    }

    nonisolated static func an(_ art: PartnerEreignisArt, _ einstellungen: Einstellungen) -> Bool {
        einstellungen.mitteilungen[schluessel(art)] ?? true
    }

    /// Die Ereignisse, die jetzt eine Mitteilung bekommen sollen (ohne etwas zu senden oder zu merken). Reine Auswahl, getestet ohne Mitteiler.
    nonisolated static func neue(_ stand: PartnerStand, gemerkt: Set<String>, einstellungen: Einstellungen, jetzt: Date) -> [PartnerEreignis] {
        guard case .verbunden(let datei) = stand else { return [] }
        return datei.ereignisse
            .filter { !gemerkt.contains($0.id) && an($0.art, einstellungen) && jetzt.timeIntervalSince($0.zeit) <= frischBis }
            .sorted { $0.zeit < $1.zeit }
    }

    /// Verarbeitet den Stand: Mitteilungen für neue Ereignisse, danach alle Ids des Standes als gesehen merken. Liefert die gemeldeten Ereignisse.
    @discardableResult
    func verarbeite(_ stand: PartnerStand, einstellungen: Einstellungen, jetzt: Date) async -> [PartnerEreignis] {
        guard case .verbunden(let partner) = stand else { return [] }
        let neu = Self.neue(stand, gemerkt: Set(gemerkt), einstellungen: einstellungen, jetzt: jetzt)
        merke(partner.ereignisse.map(\.id))
        for ereignis in neu {
            await mitteiler.zeige(id: "partner.\(ereignis.id)", titel: "Lumen Fit", text: ereignis.text, route: .heute)
            beiNeuem?(ereignis)
        }
        return neu
    }

    private func merke(_ ids: [String]) {
        var geaendert = false
        for id in ids where !gemerkt.contains(id) {
            gemerkt.append(id)
            geaendert = true
        }
        guard geaendert else { return }
        if gemerkt.count > Self.gemerktMaximal { gemerkt.removeFirst(gemerkt.count - Self.gemerktMaximal) }
        datei?.speichere(gemerkt)
    }
}
