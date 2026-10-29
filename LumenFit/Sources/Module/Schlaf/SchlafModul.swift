import Foundation

/// Stub des Grundgerüsts: das Modul `schlaf` ersetzt den Inhalt. `start` ist idempotent und läuft synchron in `ModulStart.starteAlle`.
enum SchlafModul {
    @MainActor static func start(_ umgebung: AppUmgebung) {}

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte).
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {}
}
