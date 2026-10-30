import Foundation

/// Gemeinsamer Ordner von App und Widgets (`group.com.onlyus.lumen-fit`) und der von Lovea (`group.com.onlyus.lovea`, nur Brücke).
/// `containerURL` ist ohne Signierung (CI-Simulator, Tests) `nil`: jeder Aufrufer hält das aus.
enum AppGruppe {
    nonisolated static let eigene = "group.com.onlyus.lumen-fit"
    nonisolated static let lovea = "group.com.onlyus.lovea"

    /// Eigene Gruppe, sonst `fallback`, sonst der Application-Support-Ordner der App (Widgets sehen dann nichts, zeigen aber keinen Absturz).
    static func ordner(fallback: URL? = nil) -> URL {
        if let gruppe = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: eigene) {
            return gruppe.appendingPathComponent("LumenFit", isDirectory: true)
        }
        if let fallback { return fallback }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("LumenFit", isDirectory: true)
    }

    /// Wurzel der eigenen Gruppe (nicht `LumenFit/` darin): hier legt Lumen Alarm den Unterordner `LumenAlarm` an. nil ohne Signierung.
    static func eigeneWurzel() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: eigene)
    }

    /// Ordner der Lovea-Gruppe; nil ohne Signierung oder ohne Berechtigung = nicht verbunden.
    static func loveaOrdner() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: lovea)
    }
}
