// Quelle: Lovea Health/LoveaWidgets/Shared/WidgetPendingOp.swift
import AppIntents
import Foundation
import WidgetKit

/// Ein Tipp auf eine Gewohnheit im Widget: wartet in `widget-ops.jsonl` der Gruppe, bis die App ihn für das aktive Profil in den Raum übernimmt.
/// Gegenüber Lovea (`WidgetPendingOp`, eine Datei je Op, nur `habit.setzen`): eine Datei, eine Zeile je Tipp, ohne Server und ohne `geste`.
/// `wert` ist der genaue Tageswert (die App setzt ihn so), `zeit` und `wert` sind optional, damit eine ältere Zeile lesbar bleibt (Standard: abhaken, jetzt).
struct WidgetHabitOp: Codable, Sendable, Equatable, Identifiable {
    var opId: String
    var profil: String
    var habit: String
    var tag: String
    var wert: Int?
    var zeit: Date?
    var id: String { opId }
}

/// Reine Logik ohne Dateizugriff: testbar ohne App Group.
enum WidgetOpsMerge {
    /// Ein Verzeichnis-Listing oder zwei Leseversuche können dieselbe `opId` mehrfach liefern; die erste Fassung gewinnt.
    /// (Der Raum überspringt doppelte Ids ohnehin, aber dieselbe Op muss nicht zweimal in die Warteschlange.)
    static func eindeutig(_ ops: [WidgetHabitOp]) -> [WidgetHabitOp] {
        var gesehen = Set<String>()
        return ops.filter { gesehen.insert($0.opId).inserted }
    }
}

/// Die Datei `widget-ops.jsonl`: das Widget hängt Zeilen an, die App liest sie. Kaputte Zeilen werden übersprungen.
enum WidgetOpsDatei {
    nonisolated static let name = "widget-ops.jsonl"

    static func url(ordner: URL) -> URL { ordner.appendingPathComponent(name) }

    private static func zeile(_ op: WidgetHabitOp) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        guard var daten = try? encoder.encode(op) else { return nil }
        daten.append(UInt8(ascii: "\n"))
        return daten
    }

    /// Hängt den Tipp an. false, wenn das Schreiben nicht ging.
    @discardableResult
    static func haengeAn(_ op: WidgetHabitOp, an datei: URL) -> Bool {
        guard let zeile = zeile(op) else { return false }
        try? FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: datei.path) else { return (try? zeile.write(to: datei, options: .atomic)) != nil }
        // forUpdating: forWritingTo kann das Ende nicht lesen (Lehre aus dem Op-Log des Grundgerüsts).
        guard let handle = try? FileHandle(forUpdating: datei) else { return false }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: zeile)
            return true
        } catch {
            return false
        }
    }

    /// Alle lesbaren Tipps einer Datei, in Dateireihenfolge, doppelte Ids entfernt. Fehlende oder leere Datei: leer.
    static func lies(_ datei: URL) -> [WidgetHabitOp] {
        guard let daten = try? Data(contentsOf: datei), !daten.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let ops = daten.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true).compactMap { try? decoder.decode(WidgetHabitOp.self, from: Data($0)) }
        return WidgetOpsMerge.eindeutig(ops)
    }
}

/// Darwin-Anstoß vom Widget-Prozess an die laufende App ("es liegt ein Tipp bereit"). Er weckt keine beendete App; die liest beim Öffnen.
enum WidgetAnstoss {
    nonisolated static let name = "com.onlyus.lumen-fit.widget-ops"

    static func sende() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(rawValue: name as CFString), nil, nil, true)
    }
}

/// Die Arbeit des Intents, ohne System: Tipp anhängen und im Snapshot sofort den Haken zeigen (die App rechnet beim Übernehmen neu).
enum WidgetHabitAktion {
    @discardableResult
    static func abhaken(habit: String, wert: Int, tag: String, profil: String, ordner: URL, jetzt: Date = Date()) -> Bool {
        let op = WidgetHabitOp(opId: UUID().uuidString, profil: profil, habit: habit, tag: tag, wert: wert, zeit: jetzt)
        guard WidgetOpsDatei.haengeAn(op, an: WidgetOpsDatei.url(ordner: ordner)) else { return false }
        // Vorab-Anzeige: nur wenn der Snapshot zu diesem Tag und Profil gehört; die App ersetzt ihn beim Übernehmen.
        if var s = WidgetSnapshotDatei.lade(ordner: ordner), s.tag == tag, s.profilKennung == profil,
           let i = s.habits?.firstIndex(where: { $0.id == habit }) {
            s.habits?[i].heute = wert
            WidgetSnapshotDatei.schreibe(s, ordner: ordner)
        }
        // Gym: auch die Gym-Woche (Punkte im Gym-Widget) zeigt den Haken sofort.
        if habit == "gym", var s = WidgetSnapshotDatei.lade(ordner: ordner), s.tag == tag, s.profilKennung == profil, var woche = s.gymWoche,
           let i = woche.firstIndex(where: { $0.tag == tag }) {
            woche[i].erledigt = wert > 0
            s.gymWoche = woche
            WidgetSnapshotDatei.schreibe(s, ordner: ordner)
        }
        return true
    }
}

/// Der Haken im interaktiven Widget "Gewohnheiten". Läuft im Widget-Prozess und schreibt nur Dateien in die Gruppe (SPEC 5.9 Vertrag 9).
struct HabitAbhakenIntent: AppIntent {
    static var title: LocalizedStringResource { "Gewohnheit abhaken" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Gewohnheit") var habit: String
    @Parameter(title: "Wert") var wert: Int
    @Parameter(title: "Tag") var tag: String
    @Parameter(title: "Profil") var profil: String

    init() {}

    init(habit: String, wert: Int, tag: String, profil: String) {
        self.habit = habit
        self.wert = wert
        self.tag = tag
        self.profil = profil
    }

    func perform() async throws -> some IntentResult {
        WidgetHabitAktion.abhaken(habit: habit, wert: wert, tag: tag, profil: profil, ordner: AppGruppe.ordner())
        WidgetAnstoss.sende()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
