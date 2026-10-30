import Foundation

/// Die Umsetzung des Dateivertrags (`PartnerAustausch`). `ordner` ist der Ordner der Lovea-Gruppe (`AppGruppe.loveaOrdner()`),
/// nil ohne Signierung: dann gilt überall "nicht verbunden". Tests geben einen Temp-Ordner.
/// Lesen verträgt fehlende und kaputte Dateien (= nicht verbunden) und eine unbekannte `version` (= `.unbekannteVersion`).
struct LoveaBruecke: PartnerAustausch {
    let ordner: URL?

    init(ordner: URL?) { self.ordner = ordner }

    private var vertragsOrdner: URL? { ordner?.appendingPathComponent(LoveaVertrag.ordnerName, isDirectory: true) }

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
        let name = kennung.prefix(1).uppercased() + kennung.dropFirst()
        var ereignisse: [PartnerEreignis] = []
        if stand.gymLetzte7?[kennung]?.contains(where: { $0.datum == tag && $0.erledigt }) == true {
            ereignisse.append(PartnerEreignis(id: "gymEnde-\(tag)", art: .gymEnde, zeit: geschrieben, text: "\(name) war im Gym"))
        }
        if let s = heute.schritte, let ziel = stand.zielSchritte?[kennung], ziel > 0, s >= ziel {
            ereignisse.append(PartnerEreignis(id: "ziel-\(tag)", art: .ziel, zeit: geschrieben, text: "\(name) hat das Schrittziel erreicht"))
        }
        if let m = heute.schlafMinuten, let ziel = stand.zielSchlafMinuten?[kennung], ziel > 0, m >= ziel {
            ereignisse.append(PartnerEreignis(id: "schlafGut-\(tag)", art: .schlafGut, zeit: geschrieben, text: "\(name) hat gut geschlafen"))
        }
        return ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: geschrieben, profilName: name,
                                    freigaben: freigaben, heute: heute, ereignisse: ereignisse)
    }

    // MARK: - Schreiben und Band

    func schreibe(zusammenfassung: ZusammenfassungDatei) { schreibe(zusammenfassung, LoveaVertrag.zusammenfassungDatei) }

    func schreibe(status: BandStatusDatei) { schreibe(status, LoveaVertrag.statusDatei) }

    func wuensche() -> [BandWunsch] {
        guard let url = vertragsOrdner?.appendingPathComponent(LoveaVertrag.wuenscheDatei), let daten = try? Data(contentsOf: url),
              let datei = try? LoveaVertrag.decoder().decode(BandWuenscheDatei.self, from: daten), datei.version == LoveaVertrag.version else { return [] }
        return datei.wuensche
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
    func loescheEigeneDateien() {
        guard let ordner = vertragsOrdner else { return }
        try? FileManager.default.removeItem(at: ordner)
    }

    private func schreibe<T: Encodable>(_ wert: T, _ dateiName: String) {
        guard let ordner = vertragsOrdner, let daten = try? LoveaVertrag.encoder().encode(wert) else { return }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try? daten.write(to: ordner.appendingPathComponent(dateiName), options: .atomic)
    }
}
