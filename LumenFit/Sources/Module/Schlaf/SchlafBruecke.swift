import Foundation

/// Brücke zu Lumen Alarm (09.11.2026, Schlaf planen zieht dorthin um): Lumen Fit schreibt in `<eigene Gruppe>/LumenAlarm/` die Band-Nächte
/// (`schlaf-band.json`, nach jeder Band-Runde neu, nur bei Änderung) und einmal die Übergabe (`schlaf-uebergabe.json`: Nächte von Hand und Ziel).
/// Lumen Alarm liest nur; die Form steht dort in `docs/BAND-VERTRAG.md`. Datumswerte wie die anderen Brücken-Dateien (`LoveaVertrag`).
struct SchlafBandDatei: Codable, Equatable, Sendable {
    struct Phase: Codable, Equatable, Sendable {
        var art: String
        var von: Date
        var bis: Date
    }

    struct Nacht: Codable, Equatable, Sendable {
        var tag: String
        var bett: Date
        var auf: Date
        var minuten: Int
        var phasen: [Phase]
    }

    var version = 1
    var geschrieben: Date
    var naechte: [Nacht]
}

struct SchlafUebergabeDatei: Codable, Equatable, Sendable {
    struct Hand: Codable, Equatable, Sendable {
        var tag: String
        var bett: Date
        var auf: Date
    }

    struct Ziel: Codable, Equatable, Sendable {
        var minuten: Int
        var extraMinuten: Int
        var extraTage: Int
    }

    var version = 1
    var geschrieben: Date
    var hand: [Hand]
    var ziel: Ziel
}

enum SchlafBruecke {
    nonisolated static let bandDatei = "schlaf-band.json"
    nonisolated static let uebergabeDatei = "schlaf-uebergabe.json"
    nonisolated static let hoechstens = 30

    /// Die letzten 30 Band-Nächte, je Aufwachtag die zuletzt eingetroffene Op, älteste zuerst.
    static func band(ops: [BandSchlafOp], jetzt: Date) -> SchlafBandDatei {
        var jeTag: [String: BandSchlafOp] = [:]
        for op in ops { jeTag[op.tag] = op }
        let naechte = jeTag.values.sorted { $0.tag < $1.tag }.suffix(hoechstens).map { op in
            SchlafBandDatei.Nacht(tag: op.tag, bett: op.start, auf: op.ende, minuten: minuten(op.phasen, start: op.start, ende: op.ende),
                                  phasen: op.phasen.map { SchlafBandDatei.Phase(art: art($0.phase), von: $0.von, bis: $0.bis) })
        }
        return SchlafBandDatei(geschrieben: jetzt, naechte: Array(naechte))
    }

    static func art(_ phase: SchlafPhase) -> String {
        switch phase {
        case .wach: "wach"
        case .rem: "rem"
        case .kern: "kern"
        case .tief: "tief"
        case .unbestimmt: "schlaf"
        }
    }

    /// Geschlafene Minuten ohne Wach; ohne Phasen die ganze Spanne.
    static func minuten(_ phasen: [SchlafAbschnitt], start: Date, ende: Date) -> Int {
        let schlaf = phasen.filter { $0.phase.schlaeft }.reduce(0.0) { $0 + $1.bis.timeIntervalSince($1.von) }
        let sekunden = phasen.isEmpty ? ende.timeIntervalSince(start) : schlaf
        return max(0, Int((sekunden / 60).rounded()))
    }

    static func uebergabe(hand: [String: SchlafNacht], zielMinuten: Int, extra: SchlafZielExtra, jetzt: Date) -> SchlafUebergabeDatei {
        let eintraege = hand.values.sorted { $0.tag < $1.tag }.map { SchlafUebergabeDatei.Hand(tag: $0.tag, bett: $0.von, auf: $0.bis) }
        return SchlafUebergabeDatei(geschrieben: jetzt, hand: eintraege, ziel: .init(minuten: zielMinuten, extraMinuten: extra.extraMinuten, extraTage: extra.extraTage))
    }

    /// Schreibt beide Dateien in den Alarm-Ordner: die Band-Datei nur, wenn sich die Nächte geändert haben; die Übergabe nur, wenn sie fehlt.
    /// Ohne Ordner (keine Signierung) oder ohne Profil passiert nichts.
    @MainActor static func schreiben(_ umgebung: AppUmgebung, ordner: URL? = AppGruppe.alarmOrdner()) {
        guard let ordner, let daten = umgebung.daten else { return }
        let jetzt = umgebung.uhr()
        let raum = daten.raum
        schreibeBand(band(ops: SchlafEigeneQuellen.bandOps(raum), jetzt: jetzt), in: ordner)
        let ziel = ordner.appendingPathComponent(uebergabeDatei)
        guard !FileManager.default.fileExists(atPath: ziel.path) else { return }
        let extra = SchlafZielLogik.extra(ops: raum.ops(arten: [SchlafZielLogik.art]))
        schreibe(uebergabe(hand: SchlafEigeneQuellen.handNaechte(raum), zielMinuten: daten.ziele.ziele.schlafMinuten, extra: extra, jetzt: jetzt), ziel)
    }

    /// Nur schreiben, wenn sich die Nächte geändert haben (verglichen über die Textform, nicht über `geschrieben`).
    static func schreibeBand(_ neu: SchlafBandDatei, in ordner: URL) {
        let url = ordner.appendingPathComponent(bandDatei)
        let encoder = LoveaVertrag.encoder()
        if let alt = try? Data(contentsOf: url), let d = try? LoveaVertrag.decoder().decode(SchlafBandDatei.self, from: alt),
           (try? encoder.encode(d.naechte)) == (try? encoder.encode(neu.naechte)) { return }
        schreibe(neu, url)
    }

    private static func schreibe<T: Encodable>(_ wert: T, _ url: URL) {
        guard let daten = try? LoveaVertrag.encoder().encode(wert) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: url, options: .atomic)
    }
}
