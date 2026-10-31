import Foundation
import Observation

/// Wie weit ein Auftrag an Lumen Alarm ist, für die Karte im Coach.
struct WeckerKarte: Equatable, Identifiable, Sendable {
    enum Zustand: Equatable, Sendable {
        /// Geschrieben, Lumen Alarm hat noch nichts gemeldet.
        case wartet
        case ok
        case fehler(String)
    }

    var id: String
    var text: String
    var zustand: Zustand
}

/// Die Brücke für Wecker und Erinnerungen des Coachs (Vertrag mit Lumen Alarm, Abschnitt 2), Ordner `<Lumen-Fit-Gruppe>/LumenAlarm/`:
/// liest `wecker-stand.json` und `wecker-ergebnis.json` (Lumen Alarm schreibt sie), schreibt `wecker-auftraege.json` und sendet danach den Darwin-Namen
/// `com.onlyus.lumen-fit.wecker-auftrag`. Lumen Fit stellt nie selbst einen Wecker. Ohne Ordner (kein Signieren, Tests ohne Temp-Ordner) tut nichts etwas.
@MainActor @Observable
final class AlarmWeckerDienst {
    nonisolated static let standDatei = "wecker-stand.json"
    nonisolated static let auftraegeDatei = "wecker-auftraege.json"
    nonisolated static let ergebnisDatei = "wecker-ergebnis.json"
    /// So viele Aufträge bleiben in der Datei (die ältesten fallen weg; Lumen Alarm merkt sich die Ids selbst).
    nonisolated static let auftraegeMaximal = 100
    nonisolated static let alarmAdresse = "lumen-alarm://wecker-auftrag"
    /// Höchstens so viele Wecker und Erinnerungen gehen in den Prompt des Coachs.
    nonisolated static let promptMaximal = 10

    private(set) var stand: WeckerStandDatei?
    private(set) var auftraege: [WeckerAuftrag] = []
    private(set) var ergebnisse: [WeckerErgebnisDatei.Ergebnis] = []

    @ObservationIgnored private let ordner: URL?
    @ObservationIgnored private let sende: (String) -> Void
    @ObservationIgnored private let neueId: () -> String
    @ObservationIgnored private var beobachter: DarwinBeobachter?
    /// Die Zeile zu jedem Auftrag dieser Sitzung (nur im Speicher, für die Karte).
    @ObservationIgnored private var texte: [String: String] = [:]

    /// `ordner`: `<Lumen-Fit-Gruppe>/LumenAlarm` (nil ohne Signierung).
    init(ordner: URL?, sende: @escaping (String) -> Void = DarwinKanal.sende, neueId: @escaping () -> String = { UUID().uuidString }) {
        self.ordner = ordner
        self.sende = sende
        self.neueId = neueId
    }

    /// Hört auf `wecker-ergebnis` von Lumen Alarm (weckt keine beendete App; gelesen wird auch beim Vordergrund).
    func beobachte() {
        guard beobachter == nil else { return }
        beobachter = DarwinBeobachter(name: DarwinKanal.weckerErgebnis) { [weak self] in self?.aktualisieren() }
    }

    /// Der Coach darf Wecker und Erinnerungen vorschlagen, wenn Lumen Alarm einen Stand geschrieben hat.
    var verbunden: Bool { stand != nil }

    // MARK: - Lesen

    func aktualisieren() {
        let neuerStand = lies(WeckerStandDatei.self, Self.standDatei)
        stand = neuerStand?.version == LoveaVertrag.version ? neuerStand : nil
        auftraege = leseAuftraege()
        let neueErgebnisse = lies(WeckerErgebnisDatei.self, Self.ergebnisDatei)
        ergebnisse = neueErgebnisse?.version == LoveaVertrag.version ? (neueErgebnisse?.ergebnisse ?? []) : []
    }

    private func lies<T: Decodable>(_ typ: T.Type, _ name: String) -> T? {
        guard let url = ordner?.appendingPathComponent(name), let daten = try? Data(contentsOf: url) else { return nil }
        return try? LoveaVertrag.decoder().decode(typ, from: daten)
    }

    private func leseAuftraege() -> [WeckerAuftrag] {
        guard let datei = lies(WeckerAuftraegeDatei.self, Self.auftraegeDatei), datei.version == LoveaVertrag.version else { return [] }
        return datei.auftraege
    }

    // MARK: - Aufträge schreiben

    /// Schreibt einen Auftrag (neue Id) ans Ende der Datei und stößt Lumen Alarm an. Liefert die Id, oder nil, wenn nichts geschrieben werden konnte.
    @discardableResult
    func lege(_ befehl: WeckerBefehl, jetzt: Date = Date()) -> String? {
        guard let ordner else { return nil }
        let auftrag = WeckerAuftrag(id: neueId(), angelegt: jetzt, befehl: befehl)
        let neu = Array((leseAuftraege() + [auftrag]).suffix(Self.auftraegeMaximal))
        guard let daten = try? LoveaVertrag.encoder().encode(WeckerAuftraegeDatei(version: LoveaVertrag.version, auftraege: neu)) else { return nil }
        do {
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            try daten.write(to: ordner.appendingPathComponent(Self.auftraegeDatei), options: .atomic)
        } catch {
            return nil
        }
        auftraege = neu
        texte[auftrag.id] = befehl.zeile(stand: stand)
        sende(DarwinKanal.weckerAuftrag)
        return auftrag.id
    }

    // MARK: - Karten

    /// Wie weit die Aufträge sind. `ok` erst, wenn `wecker-ergebnis.json` es meldet; sonst "wartet".
    func karten(fuer ids: [String]) -> [WeckerKarte] {
        ids.map { id in
            let text = texte[id] ?? "Auftrag an Lumen Alarm"
            guard let ergebnis = ergebnisse.first(where: { $0.id == id }) else { return WeckerKarte(id: id, text: text, zustand: .wartet) }
            let zustand: WeckerKarte.Zustand = ergebnis.ok ? .ok : .fehler(ergebnis.grund ?? "unbekannt")
            return WeckerKarte(id: id, text: text, zustand: zustand)
        }
    }

    // MARK: - Coach-Kontext

    /// Die Zeilen für den Prompt des Coachs: die Wecker und Erinnerungen mit Ids und die Regeln der Marker. Leer ohne Stand von Lumen Alarm.
    nonisolated static func promptZeilen(stand: WeckerStandDatei?) -> [String] {
        guard let stand else { return [] }
        func tage(_ t: [Int], datum: String?) -> String { datum ?? WeckerBefehl.wort(tage: t) }
        var zeilen = ["Lumen Alarm ist verbunden. Wecker der Person (Id | Zeit | Wiederholung | Name | an oder aus):"]
        if let h = stand.haupt {
            zeilen.append("haupt | \(Datum.uhrzeit(minuten: h.minute)) | taeglich | \(h.name ?? "Hauptwecker") | \(h.aktiv ? "an" : "aus")")
        }
        for w in stand.wecker.prefix(promptMaximal) {
            zeilen.append("\(w.id) | \(Datum.uhrzeit(minuten: w.minute)) | \(tage(w.tage, datum: w.einmalAm)) | \(w.name ?? "") | \(w.aktiv ? "an" : "aus")")
        }
        zeilen.append("Erinnerungen der Person (Id | Zeit | Wiederholung | Text | an oder aus):")
        for e in stand.erinnerungen.prefix(promptMaximal) {
            zeilen.append("\(e.id) | \(Datum.uhrzeit(minuten: e.minute)) | \(tage(e.tage, datum: e.datum)) | \(e.text) | \(e.aktiv ? "an" : "aus")")
        }
        zeilen.append("Wecker und Erinnerungen kannst du nur vorschlagen. Schreibe dafür am Ende der Antwort eine Zeile: "
                      + "[[wecker: neu | 06:30 | werktags | Name]], [[wecker: aendern | Id | 06:45 | werktags | Name]], [[wecker: an | Id]], [[wecker: aus | Id]], "
                      + "[[wecker: loeschen | Id]]. Für Erinnerungen dasselbe mit erinnern und einem Text statt dem Namen, [[erinnern: neu | 18:00 | einmalig | Text]]; "
                      + "dort ist auch ein Datum JJJJ-MM-TT statt der Wiederholung möglich.")
        zeilen.append("Wiederholung: einmalig, taeglich, werktags, wochenende oder Tage wie mo,mi. Ids nur aus den Listen oben, haupt nur für an und aus.")
        zeilen.append("Sag nie, dass etwas gestellt ist: die Person bestätigt den Vorschlag, Lumen Alarm führt ihn aus und die App zeigt das Ergebnis.")
        return zeilen
    }
}
