import Foundation

/// Reicht die Zusammenfassung für den Partner an den Lumen-Server weiter. Wird gesetzt, sobald `KontoDienst` steht (die Brücke ist früher da).
/// Eine Sperre schützt den Verweis: gesetzt wird einmal beim Start auf dem Hauptakteur, gerufen wird von überall.
final class PartnerHochlader: @unchecked Sendable {   // @unchecked: der Verweis liegt hinter einer Sperre
    private let sperre = NSLock()
    private var aufruf: (@Sendable (Data) -> Void)?

    func setze(_ neu: @escaping @Sendable (Data) -> Void) { sperre.lock(); aufruf = neu; sperre.unlock() }

    func rufe(_ daten: Data) {
        sperre.lock(); let f = aufruf; sperre.unlock()
        f?(daten)
    }
}

/// Die Brücke zum Partner, wenn es einen Lumen-Fit-Server gibt: der Partner-Stand kommt vom Server (Datei `partner-server.json`, vom `KontoDienst`
/// geschrieben), die eigene Zusammenfassung geht zusätzlich dorthin. Der Datei-Weg zu Lovea (`innen`) bleibt unverändert, solange Lovea ihn nutzt:
/// er liefert den Partner, wenn der Server keinen frischen hat, und bekommt weiter alles geschrieben. Band-Wünsche laufen weiter nur über die Datei.
struct ServerPartnerBruecke: PartnerAustausch {
    let innen: any PartnerAustausch
    /// `<Ordner>/partner-server.json`
    let serverDatei: URL
    let hochlader: PartnerHochlader

    /// Frischer Server-Stand gewinnt, dann Lovea-Datei; ist beides nicht frisch, gilt der Server-Stand als veraltet. Rein und testbar.
    static func waehle(server: ZusammenfassungDatei?, innen: PartnerStand, jetzt: Date) -> PartnerStand {
        if let s = server, jetzt.timeIntervalSince(s.geschrieben) <= LoveaVertrag.frist { return .verbunden(s) }
        if case .verbunden = innen { return innen }
        if let s = server { return .veraltet(s) }
        return innen
    }

    /// Mit Verbindungen vom Server gilt er allein: ohne aktive, nicht pausierte Lovea-Verbindung gibt es keinen Partner (auch nicht aus der Datei von Lovea,
    /// sonst käme eine entfernte oder pausierte Person von dort zurück). Hat der Server noch keine Daten der Person, hilft die Datei von Lovea, begrenzt auf das,
    /// was die Verbindung zeigt. Ohne Verbindungs-Stand (älterer Server, erster Start) bleibt die Wahl von früher.
    static func waehle(liste: VerbindungenAntwort, server: ZusammenfassungDatei?, innen: PartnerStand, jetzt: Date) -> PartnerStand {
        guard let lovea = liste.verbindungen.first(where: { $0.lovea && $0.aktiv && !$0.ich.pause }) else { return .nichtVerbunden }
        if let s = server, jetzt.timeIntervalSince(s.geschrieben) <= LoveaVertrag.frist { return .verbunden(s) }
        if case .verbunden(let d) = innen { return .verbunden(VerbindungenLogik.begrenze(d, auf: Set(lovea.sichtbareBereiche.compactMap(\.freigabe)))) }
        if let s = server { return .veraltet(s) }
        return .nichtVerbunden
    }

    func partner(jetzt: Date) -> PartnerStand {
        let server = (try? Data(contentsOf: serverDatei)).flatMap { try? LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: $0) }
        let verbindungen = serverDatei.deletingLastPathComponent().appendingPathComponent(VerbindungenSpeicher.dateiName)
        if let liste = (try? Data(contentsOf: verbindungen)).flatMap({ try? LoveaVertrag.decoder().decode(VerbindungenAntwort.self, from: $0) }) {
            return Self.waehle(liste: liste, server: server, innen: innen.partner(jetzt: jetzt), jetzt: jetzt)
        }
        return Self.waehle(server: server, innen: innen.partner(jetzt: jetzt), jetzt: jetzt)
    }

    /// Nur der Datei-Weg zu Lovea: die Datei mit den Freigaben aus `verbindung.freigaben`. Der Server bekommt seinen eigenen Stand (`schreibe(serverStand:)`).
    func schreibe(zusammenfassung: ZusammenfassungDatei) {
        innen.schreibe(zusammenfassung: zusammenfassung)
    }

    /// Die Zusammenfassung für den Server, mit allen Bereichen, die eine Verbindung zeigt. Je Verbindung begrenzt der Server beim Ausliefern.
    func schreibe(serverStand: ZusammenfassungDatei) {
        if let daten = try? LoveaVertrag.encoder().encode(serverStand) { hochlader.rufe(daten) }
    }

    func wuensche() -> [BandWunsch] { innen.wuensche() }
    func melde(erledigt ids: [String]) { innen.melde(erledigt: ids) }
    func schreibe(status: BandStatusDatei) { innen.schreibe(status: status) }

    func loescheEigeneDateien() {
        innen.loescheEigeneDateien()
        try? FileManager.default.removeItem(at: serverDatei)
        try? FileManager.default.removeItem(at: serverDatei.deletingLastPathComponent().appendingPathComponent(VerbindungenSpeicher.dateiName))
    }
}
