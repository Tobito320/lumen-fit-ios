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

    func partner(jetzt: Date) -> PartnerStand {
        let server = (try? Data(contentsOf: serverDatei)).flatMap { try? LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: $0) }
        return Self.waehle(server: server, innen: innen.partner(jetzt: jetzt), jetzt: jetzt)
    }

    func schreibe(zusammenfassung: ZusammenfassungDatei) {
        innen.schreibe(zusammenfassung: zusammenfassung)
        if let daten = try? LoveaVertrag.encoder().encode(zusammenfassung) { hochlader.rufe(daten) }
    }

    func wuensche() -> [BandWunsch] { innen.wuensche() }
    func melde(erledigt ids: [String]) { innen.melde(erledigt: ids) }
    func schreibe(status: BandStatusDatei) { innen.schreibe(status: status) }

    func loescheEigeneDateien() {
        innen.loescheEigeneDateien()
        try? FileManager.default.removeItem(at: serverDatei)
    }
}
