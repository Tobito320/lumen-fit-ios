import Foundation

/// Stub des Grundgerüsts: das Modul `widgets` ersetzt den Inhalt. `start` ist idempotent und läuft synchron in `ModulStart.starteAlle`.
enum WidgetsModul {
    @MainActor static func start(_ umgebung: AppUmgebung) {}

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte).
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {}
}
