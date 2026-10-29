import Foundation

/// Übernimmt die Tipps aus `widget-ops.jsonl` (das Widget hängt sie an) für das aktive Profil in den Raum.
/// - Die Datei wird zuerst umbenannt (`widget-ops.lese-<id>.jsonl`), dann gelesen: ein Tipp, der währenddessen ankommt, landet in einer neuen Datei und geht nicht verloren.
/// - Idempotent über die Op-Id: der Raum überspringt doppelte Ids; liegen geblieben Lese-Dateien (Abbruch) werden beim nächsten Mal noch einmal gelesen.
/// - Tipps für andere Profile gehen zurück in die Datei (bis zu sieben Tage), alles andere ist erledigt.
enum WidgetOpsImport {
    nonisolated static let leseVorsilbe = "widget-ops.lese-"
    /// So lange wartet ein Tipp für ein anderes Profil auf dessen Anmeldung.
    nonisolated static let wartezeit: TimeInterval = 7 * 24 * 3600

    /// Gibt die Tage zurück, für die ein Tipp übernommen wurde (der Aufrufer sendet `Ereignis.habitGeaendert`).
    @MainActor
    @discardableResult
    static func uebernimm(ordner: URL, profil: ProfilID, raum: LokalerRaum, jetzt: Date) -> [String] {
        let fm = FileManager.default
        let live = WidgetOpsDatei.url(ordner: ordner)
        if fm.fileExists(atPath: live.path) {
            let lese = ordner.appendingPathComponent("\(leseVorsilbe)\(UUID().uuidString).jsonl")
            try? fm.moveItem(at: live, to: lese)
        }
        let dateien = ((try? fm.contentsOfDirectory(at: ordner, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(leseVorsilbe) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !dateien.isEmpty else { return [] }

        var tage: [String] = []
        var zurueck: [WidgetHabitOp] = []
        for op in WidgetOpsMerge.eindeutig(dateien.flatMap { WidgetOpsDatei.lies($0) }) {
            if op.profil == profil.rawValue {
                guard let d = try? JSONEncoder().encode(HabitSetzenD(art: op.habit, datum: op.tag, wert: max(0, op.wert ?? 1))) else { continue }
                raum.einreihen(Op(id: op.opId, art: "habit.setzen", von: profil, zeit: op.zeit ?? jetzt, d: d))
                if !tage.contains(op.tag) { tage.append(op.tag) }
            } else if jetzt.timeIntervalSince(op.zeit ?? jetzt) < wartezeit {
                zurueck.append(op)
            }
        }
        for op in zurueck { WidgetOpsDatei.haengeAn(op, an: live) }
        for datei in dateien { try? fm.removeItem(at: datei) }
        return tage
    }
}

/// Hört auf den Darwin-Anstoß des Widgets und ruft `aktion` auf dem Hauptakteur. Der Rückruf ist eine C-Funktion ohne Erfassung (SPEC 5.9 Vertrag 10):
/// der Zustand reicht über einen `Unmanaged`-Zeiger herein, danach geht es mit `Task { @MainActor }` weiter.
final class WidgetAnstossHoerer: Sendable {
    private let aktion: @Sendable () -> Void

    init(aktion: @escaping @Sendable () -> Void) {
        self.aktion = aktion
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
            { _, beobachter, _, _, _ in
                guard let beobachter else { return }
                Unmanaged<WidgetAnstossHoerer>.fromOpaque(beobachter).takeUnretainedValue().aktion()
            },
            WidgetAnstoss.name as CFString, nil, .deliverImmediately)
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
    }
}
