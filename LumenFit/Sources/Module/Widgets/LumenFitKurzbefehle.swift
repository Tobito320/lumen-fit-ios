import AppIntents

/// Idee 98: Siri und Kurzbefehle ohne Einrichtung. Der einzige `AppShortcutsProvider` der App (nur im App-Ziel); die Intents liegen in `Gemeinsam/Widgets`.
/// Jede Phrase enthält den App-Namen (sonst Build-Fehler). Phrasen in der Entwicklungssprache Deutsch.
struct LumenFitKurzbefehle: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TrainingStartenIntent(),
            phrases: [
                "Training starten in \(.applicationName)",
                "Starte mein Training mit \(.applicationName)",
                "Training mit \(.applicationName) beginnen"
            ],
            shortTitle: "Training starten",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: GewichtEintragenIntent(),
            phrases: [
                "Gewicht eintragen in \(.applicationName)",
                "Trag mein Gewicht in \(.applicationName) ein"
            ],
            shortTitle: "Gewicht eintragen",
            systemImageName: "scalemass.fill"
        )
        AppShortcut(
            intent: EssenScannenIntent(),
            phrases: [
                "Essen scannen in \(.applicationName)",
                "Scanne mein Essen mit \(.applicationName)"
            ],
            shortTitle: "Essen scannen",
            systemImageName: "barcode.viewfinder"
        )
    }
}
