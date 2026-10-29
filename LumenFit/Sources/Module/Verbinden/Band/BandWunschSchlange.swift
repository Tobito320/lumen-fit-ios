import Foundation

/// Die Warteschlange der Vibrationswünsche (Idee 86): Lovea legt Wünsche in `band-wuensche.json`, Lumen Fit führt sie am Band aus und meldet die Ids in
/// `band-erledigt.json` (die letzten 200). Jeder Wunsch läuft höchstens einmal: die erledigten Ids merkt auch Lumen Fit selbst (`UserDefaults`), falls Lovea die
/// Datei nicht aufräumt. Ein Wunsch, der älter als `verfall` ist, wird nicht mehr ausgeführt (ein Puls von vor einer Stunde sagt nichts), aber als erledigt gemeldet.
/// Ist das Band gerade nicht verbunden, bleibt der Wunsch liegen, bis es verbunden ist oder er verfällt.
@MainActor
final class BandWunschSchlange {
    enum Ergebnis: Sendable {
        /// Am Band ausgeführt.
        case ausgefuehrt
        /// Nicht ausgeführt und auch später nicht (Schalter aus, Ruhezeit, Pause): gilt als erledigt.
        case verworfen
        /// Band nicht verbunden: später noch einmal.
        case spaeter
    }

    nonisolated static let verfall: TimeInterval = 15 * 60
    nonisolated static let schluessel = "fit.band.wuensche.erledigt"

    private let bruecke: any PartnerAustausch
    private let ausfuehren: @MainActor (BandWunsch) -> Ergebnis
    private let defaults: UserDefaults
    private let uhr: Uhr

    init(bruecke: any PartnerAustausch, defaults: UserDefaults = .standard, uhr: @escaping Uhr = { Date() },
         ausfuehren: @escaping @MainActor (BandWunsch) -> Ergebnis) {
        self.bruecke = bruecke
        self.defaults = defaults
        self.uhr = uhr
        self.ausfuehren = ausfuehren
    }

    private var erledigt: [String] {
        get { defaults.stringArray(forKey: Self.schluessel) ?? [] }
        set { defaults.set(Array(newValue.suffix(LoveaVertrag.erledigteMaximal)), forKey: Self.schluessel) }
    }

    /// Die Wünsche, die noch nicht erledigt sind, älteste zuerst.
    func offene() -> [BandWunsch] {
        let fertig = Set(erledigt)
        return bruecke.wuensche().filter { !fertig.contains($0.id) }.sorted { $0.zeit < $1.zeit }
    }

    /// Führt alle offenen Wünsche aus und meldet die erledigten. Liefert die Ids, die als erledigt gemeldet wurden.
    @discardableResult
    func verarbeite() -> [String] {
        let jetzt = uhr()
        var fertig: [String] = []
        for wunsch in offene() {
            if jetzt.timeIntervalSince(wunsch.zeit) > Self.verfall { fertig.append(wunsch.id); continue }
            switch ausfuehren(wunsch) {
            case .ausgefuehrt, .verworfen: fertig.append(wunsch.id)
            case .spaeter: continue
            }
        }
        guard !fertig.isEmpty else { return [] }
        erledigt += fertig
        bruecke.melde(erledigt: fertig)
        return fertig
    }
}
