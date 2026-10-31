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
    /// Eigene Merkliste für die Wünsche von Lumen Alarm: bis 1000 Wünsche je Weckzeit und zwei Weckzeiten, die Liste von Lovea (200) würde die ältesten vergessen.
    nonisolated static let alarmSchluessel = "fit.band.alarm.erledigt"
    nonisolated static let alarmMerkMaximal = 4000
    /// Fällige Wünsche, die jünger sind, laufen einzeln (die Stöße einer Gruppe liegen 0,7 Sekunden auseinander); ältere werden zu einem zusammengefasst.
    nonisolated static let staufrist: TimeInterval = 10
    /// Wünsche mit dieser Id-Vorsilbe sind Weck-Wünsche, auch wenn `von` etwas anderes sagt (der Fühlen-Knopf in Lumen Alarm).
    nonisolated static let fuehlenPraefix = "fuehlen-"
    /// Absender der Weck-Wünsche von Lumen Alarm (`von` in `band-wuensche.json`).
    nonisolated static let weckerAbsender = "wecker"

    private let bruecke: any PartnerAustausch
    private let ausfuehren: @MainActor (BandWunsch) -> Ergebnis
    private let defaults: UserDefaults
    private let uhr: Uhr
    private let merkSchluessel: String
    private let merkMaximal: Int
    private let zusammenfassen: Bool

    /// `zusammenfassen`: von mehreren fälligen Wünschen läuft nur der jüngste, die früheren gelten als erledigt (kam die App nach Minuten zurück, summt das Band nicht im Stau).
    init(bruecke: any PartnerAustausch, defaults: UserDefaults = .standard, uhr: @escaping Uhr = { Date() },
         schluessel: String = BandWunschSchlange.schluessel, merkMaximal: Int = LoveaVertrag.erledigteMaximal, zusammenfassen: Bool = false,
         ausfuehren: @escaping @MainActor (BandWunsch) -> Ergebnis) {
        self.bruecke = bruecke
        self.defaults = defaults
        self.uhr = uhr
        merkSchluessel = schluessel
        self.merkMaximal = merkMaximal
        self.zusammenfassen = zusammenfassen
        self.ausfuehren = ausfuehren
    }

    /// Im Speicher gehalten: die Liste hat bis 4000 Ids und wird bei jedem Takt gebraucht, `UserDefaults` kopiert sie sonst jedes Mal.
    private var erledigtSpeicher: [String]?

    private var erledigt: [String] {
        get {
            if let erledigtSpeicher { return erledigtSpeicher }
            let gelesen = defaults.stringArray(forKey: merkSchluessel) ?? []
            erledigtSpeicher = gelesen
            return gelesen
        }
        set {
            let gekuerzt = Array(newValue.suffix(merkMaximal))
            erledigtSpeicher = gekuerzt
            defaults.set(gekuerzt, forKey: merkSchluessel)
        }
    }

    /// Ist das ein Weck-Wunsch (keine Ruhezeit, keine Mindestpause)?
    nonisolated static func istWecker(_ wunsch: BandWunsch) -> Bool {
        wunsch.von == weckerAbsender || wunsch.id.hasPrefix(fuehlenPraefix)
    }

    /// Alle offenen Wünsche, deren Id mit `praefix` beginnt, gelten als erledigt (aufgestanden): sie laufen nicht mehr. Liefert die Ids.
    @discardableResult
    func erledigeAlle(praefix: String) -> [String] {
        let ids = offene().map(\.id).filter { $0.hasPrefix(praefix) }
        guard !ids.isEmpty else { return [] }
        erledigt += ids
        bruecke.melde(erledigt: ids)
        return ids
    }

    /// Wann der nächste noch nicht fällige Wunsch dran ist (für den Wecker-Takt), sonst `nil`.
    func naechsteZeit() -> Date? {
        let jetzt = uhr()
        return offene().map(\.zeit).filter { $0 > jetzt }.min()
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
        var faellig: [BandWunsch] = []
        for wunsch in offene() {
            if jetzt.timeIntervalSince(wunsch.zeit) > Self.verfall { fertig.append(wunsch.id); continue }
            // Ein Wunsch mit `zeit` in der Zukunft gilt erst ab dann: liegen lassen, nicht ausführen, nicht melden.
            if wunsch.zeit > jetzt { continue }
            faellig.append(wunsch)
        }
        if zusammenfassen {
            // Nur der Rückstau wird zu einem Puls: was jünger als `staufrist` ist, läuft einzeln (Stöße im Abstand von 0,7 Sekunden).
            let alt = faellig.filter { jetzt.timeIntervalSince($0.zeit) > Self.staufrist }
            let frisch = faellig.filter { jetzt.timeIntervalSince($0.zeit) <= Self.staufrist }
            if frisch.isEmpty, let juengster = alt.last {
                fertig += alt.dropLast().map(\.id)
                faellig = [juengster]
            } else {
                fertig += alt.map(\.id)
                faellig = frisch
            }
        }
        for wunsch in faellig {
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
