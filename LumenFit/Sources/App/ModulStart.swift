import Foundation

enum ModulStart {
    /// Im Test-Host (`XCTestConfigurationFilePath`) startet nichts.
    nonisolated static var imTestHost: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }

    /// Synchron in `LumenFitApp.init()`: BGTask-Kennungen einmal und vor Ende des App-Starts registrieren, die Health-Beobachtung anmelden,
    /// dann jedes Modul starten (jedes `start` ist idempotent). Ports (`liveAnzeige`, `trainingSteuerung`, `band`) setzen die Module dabei.
    @MainActor static func starteAlle(_ umgebung: AppUmgebung) {
        guard !imTestHost else { return }
        AbrufPlaner.registriere(umgebung)
        umgebung.beobachteHealth()
        HeuteModul.start(umgebung)
        GymModul.start(umgebung)
        FortschrittModul.start(umgebung)
        EssenModul.start(umgebung)
        SchlafModul.start(umgebung)
        ProfilModul.start(umgebung)
        VerbindenModul.start(umgebung)
        WidgetsModul.start(umgebung)
    }

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild: jedes Modul legt seine erfundenen Beispieldaten an.
    @MainActor static func saeDemo(_ umgebung: AppUmgebung) {
        HeuteModul.demoSaat(umgebung)
        GymModul.demoSaat(umgebung)
        FortschrittModul.demoSaat(umgebung)
        EssenModul.demoSaat(umgebung)
        SchlafModul.demoSaat(umgebung)
        ProfilModul.demoSaat(umgebung)
        VerbindenModul.demoSaat(umgebung)
        WidgetsModul.demoSaat(umgebung)
    }
}
