import Foundation

/// Die Umsetzung des Dateivertrags (`PartnerAustausch`). `ordner` ist der Ordner der Lovea-Gruppe (`AppGruppe.loveaOrdner()`),
/// nil ohne Signierung: dann gilt überall "nicht verbunden". Tests geben einen Temp-Ordner.
/// Lesen verträgt fehlende und kaputte Dateien (= nicht verbunden) und eine unbekannte `version` (= `.unbekannteVersion`).
struct LoveaBruecke: PartnerAustausch {
    let ordner: URL?
    /// Unterordner des Vertrags: `LumenFit` bei Lovea, `LumenAlarm` bei der Brücke zu Lumen Alarm (dort gehört `band-wuensche.json` der anderen App).
    let ordnerName: String

    init(ordner: URL?, ordnerName: String = LoveaVertrag.ordnerName) {
        self.ordner = ordner
        self.ordnerName = ordnerName
    }

    private let zwischenspeicher = WuenscheZwischenspeicher()

    private var vertragsOrdner: URL? { ordner?.appendingPathComponent(ordnerName, isDirectory: true) }

    // MARK: - Partner lesen

    /// Vertrag B (`partner.json`, `version` 1) gewinnt gegen Quelle A (`widget-stand.json`). Älter als 48 Stunden = veraltet.
    func partner(jetzt: Date) -> PartnerStand {
        if let b = vertragB() {
            switch b {
            case .version(let datei): return einstufen(datei, jetzt: jetzt)
            case .unbekannt: return .unbekannteVersion
            }
        }
        if let a = quelleA(jetzt: jetzt) { return einstufen(a, jetzt: jetzt) }
        return .nichtVerbunden
    }

    private func einstufen(_ datei: ZusammenfassungDatei, jetzt: Date) -> PartnerStand {
        jetzt.timeIntervalSince(datei.geschrieben) <= LoveaVertrag.frist ? .verbunden(datei) : .veraltet(datei)
    }

    private enum VertragB {
        case version(ZusammenfassungDatei)
        case unbekannt
    }

    private struct NurVersion: Decodable { var version: Int }

    private func vertragB() -> VertragB? {
        guard let url = vertragsOrdner?.appendingPathComponent(LoveaVertrag.partnerDatei),
              let daten = try? Data(contentsOf: url), let v = try? JSONDecoder().decode(NurVersion.self, from: daten) else { return nil }
        guard v.version == LoveaVertrag.version else { return .unbekannt }
        guard let datei = try? LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: daten) else { return nil }
        return .version(datei)
    }

    /// Quelle A: aus Loveas Stand die andere Kennung als Partner lesen, zustandslos (Ereignisse aus dem einen Stand).
    private func quelleA(jetzt: Date) -> ZusammenfassungDatei? {
        guard let url = ordner?.appendingPathComponent(LoveaVertrag.widgetStandDatei),
              let daten = try? Data(contentsOf: url), let stand = try? JSONDecoder().decode(LoveaWidgetStand.self, from: daten) else { return nil }
        let eigene = stand.eigenePerson ?? ""
        let kennungen = Set((stand.schritteHeute ?? [:]).keys).union((stand.gymLetzte7 ?? [:]).keys).union((stand.schlafMinutenHeute ?? [:]).keys)
            .union((stand.zielSchritte ?? [:]).keys).union((stand.zielGymWoche ?? [:]).keys).union((stand.zielSchlafMinuten ?? [:]).keys)
        guard !eigene.isEmpty, let kennung = kennungen.subtracting([eigene]).sorted().first else { return nil }
        let geschrieben = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? jetzt
        let tag = Datum.text(jetzt)
        var freigaben: [FreigabeArt] = []
        var heute = TagesZusammenfassung(tag: tag)
        if let s = stand.schritteHeute?[kennung] { freigaben.append(.schritte); heute.schritte = s; heute.schritteZiel = stand.zielSchritte?[kennung] }
        if let woche = stand.gymLetzte7?[kennung] {
            freigaben.append(.gym)
            heute.gymTageWoche = woche.filter(\.erledigt).count
            let montag = Datum.montagDerWoche(tag)
            let tage = woche.filter { $0.erledigt && $0.datum >= montag && $0.datum <= tag }.map(\.datum).sorted()
            heute.gymTage = tage.isEmpty ? nil : tage
            heute.gymZiel = stand.zielGymWoche?[kennung]
        }
        if let m = stand.schlafMinutenHeute?[kennung] { freigaben.append(.schlaf); heute.schlafMinuten = m; heute.schlafZiel = stand.zielSchlafMinuten?[kennung] }
        let name: String = kennung.prefix(1).uppercased() + kennung.dropFirst()
        var ereignisse: [PartnerEreignis] = []
        if stand.gymLetzte7?[kennung]?.contains(where: { $0.datum == tag && $0.erledigt }) == true {
            ereignisse.append(PartnerEreignis(id: "gymEnde-\(tag)", art: .gymEnde, zeit: geschrieben, text: String(localized: "\(name) war im Gym")))
        }
        if let s = heute.schritte, let ziel = stand.zielSchritte?[kennung], ziel > 0, s >= ziel {
            ereignisse.append(PartnerEreignis(id: "ziel-\(tag)", art: .ziel, zeit: geschrieben, text: String(localized: "\(name) hat das Schrittziel erreicht")))
        }
        if let m = heute.schlafMinuten, let ziel = stand.zielSchlafMinuten?[kennung], ziel > 0, m >= ziel {
            ereignisse.append(PartnerEreignis(id: "schlafGut-\(tag)", art: .schlafGut, zeit: geschrieben, text: String(localized: "\(name) hat gut geschlafen")))
        }
        return ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: geschrieben, profilName: name,
                                    freigaben: freigaben, heute: heute, ereignisse: ereignisse)
    }

    // MARK: - Schreiben und Band

    func schreibe(zusammenfassung: ZusammenfassungDatei) { schreibe(zusammenfassung, LoveaVertrag.zusammenfassungDatei) }

    func schreibe(status: BandStatusDatei) { schreibe(status, LoveaVertrag.statusDatei) }

    func wuensche() -> [BandWunsch] { wuenscheDatei()?.wuensche ?? [] }

    func weckFenster() -> [WeckFenster] { wuenscheDatei()?.wecker ?? [] }

    /// Die Datei der Wünsche, nur neu gelesen und dekodiert, wenn sich Änderungszeit oder Größe ändern (bis 2000 Wünsche: der Wecker-Takt liest sie alle 0,7 Sekunden).
    private func wuenscheDatei() -> BandWuenscheDatei? {
        guard let url = vertragsOrdner?.appendingPathComponent(LoveaVertrag.wuenscheDatei) else { return nil }
        let attribute = try? FileManager.default.attributesOfItem(atPath: url.path)
        let marke = WuenscheMarke(zeit: attribute?[.modificationDate] as? Date, groesse: (attribute?[.size] as? NSNumber)?.intValue ?? -1)
        if marke.zeit != nil, let treffer = zwischenspeicher.wert(url.path, marke) { return treffer }
        guard let daten = try? Data(contentsOf: url), let datei = try? LoveaVertrag.decoder().decode(BandWuenscheDatei.self, from: daten),
              datei.version == LoveaVertrag.version else { return nil }
        zwischenspeicher.merke(url.path, marke, datei)
        return datei
    }

    func schreibe(schritte: BandSchritteDatei) { schreibe(schritte, LoveaVertrag.schritteDatei) }

    func schritte() -> BandSchritteDatei? {
        guard let url = vertragsOrdner?.appendingPathComponent(LoveaVertrag.schritteDatei), let daten = try? Data(contentsOf: url) else { return nil }
        return try? LoveaVertrag.decoder().decode(BandSchritteDatei.self, from: daten)
    }

    /// Hängt die Ids an die zuletzt gemerkten und behält die letzten 200.
    func melde(erledigt ids: [String]) {
        guard let url = vertragsOrdner?.appendingPathComponent(LoveaVertrag.erledigtDatei) else { return }
        let alt = (try? Data(contentsOf: url)).flatMap { try? LoveaVertrag.decoder().decode(BandErledigtDatei.self, from: $0) }?.ids ?? []
        var neu = alt
        for id in ids where !neu.contains(id) { neu.append(id) }
        schreibe(BandErledigtDatei(version: LoveaVertrag.version, ids: Array(neu.suffix(LoveaVertrag.erledigteMaximal))), LoveaVertrag.erledigtDatei)
    }

    /// Entfernt den ganzen Ordner `<Lovea-Gruppe>/LumenFit/` (Zusammenfassung, Status, erledigte Wünsche; Loveas eigene Dateien daneben bleiben).
    /// Bei der Brücke zu Lumen Alarm nur die zwei eigenen Dateien: die Wünsche dort gehören Lumen Alarm.
    func loescheEigeneDateien() {
        guard let ordner = vertragsOrdner else { return }
        if ordnerName == LoveaVertrag.ordnerName { try? FileManager.default.removeItem(at: ordner); return }
        for datei in [LoveaVertrag.erledigtDatei, LoveaVertrag.statusDatei, LoveaVertrag.schritteDatei] { try? FileManager.default.removeItem(at: ordner.appendingPathComponent(datei)) }
    }

    private func schreibe<T: Encodable>(_ wert: T, _ dateiName: String) {
        guard let ordner = vertragsOrdner, let daten = try? LoveaVertrag.encoder().encode(wert) else { return }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try? daten.write(to: ordner.appendingPathComponent(dateiName), options: .atomic)
    }
}

/// Änderungszeit und Größe der Wunschdatei beim letzten Lesen.
struct WuenscheMarke: Equatable, Sendable {
    var zeit: Date?
    var groesse: Int
}

/// Merkt die zuletzt dekodierte Wunschdatei. Die Brücke ist ein Wert, darum ein Verweis mit Sperre.
final class WuenscheZwischenspeicher: @unchecked Sendable {
    // @unchecked Sendable: jeder Zugriff auf die Felder läuft über `schloss`.
    private let schloss = NSLock()
    private var pfad: String?
    private var marke: WuenscheMarke?
    private var datei: BandWuenscheDatei?

    func wert(_ pfad: String, _ marke: WuenscheMarke) -> BandWuenscheDatei? {
        schloss.withLock { self.pfad == pfad && self.marke == marke ? datei : nil }
    }

    func merke(_ pfad: String, _ marke: WuenscheMarke, _ datei: BandWuenscheDatei) {
        schloss.withLock {
            self.pfad = pfad
            self.marke = marke
            self.datei = datei
        }
    }
}
