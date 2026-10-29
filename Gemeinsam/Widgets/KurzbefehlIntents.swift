import AppIntents

/// Die Haken, die `WidgetsModul.start` in der App setzt. Die Intents liegen in `Gemeinsam` (App und Widget-Ziel kompilieren sie) und kennen keinen App-Typ
/// (SPEC 5.9 Vertrag 9). Im Widget-Prozess bleiben die Haken nil; mit `openAppWhenRun` läuft `perform()` aber im Prozess der App.
enum KurzbefehlHaken {
    /// Startet das Training des heutigen Plantags und zeigt es.
    @MainActor static var trainingStarten: (@MainActor () -> Void)?
    /// Öffnet eine Seite der App.
    @MainActor static var oeffne: (@MainActor (Route) -> Void)?
}

/// Siri, Kurzbefehle, Steuerelement und Aktionstaste: "Training starten".
struct TrainingStartenIntent: AppIntent {
    static var title: LocalizedStringResource { "Training starten" }
    static var description: IntentDescription { IntentDescription("Startet das Training von heute.") }
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        KurzbefehlHaken.trainingStarten?()
        return .result()
    }
}

/// "Gewicht eintragen": öffnet die Seite zum Eintragen.
struct GewichtEintragenIntent: AppIntent {
    static var title: LocalizedStringResource { "Gewicht eintragen" }
    static var description: IntentDescription { IntentDescription("Öffnet die Seite, auf der du dein Gewicht einträgst.") }
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        KurzbefehlHaken.oeffne?(.gewichtEintragen)
        return .result()
    }
}

/// "Essen scannen": öffnet den Scan.
struct EssenScannenIntent: AppIntent {
    static var title: LocalizedStringResource { "Essen scannen" }
    static var description: IntentDescription { IntentDescription("Öffnet den Barcode-Scan für dein Essen.") }
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        KurzbefehlHaken.oeffne?(.essen(.scan))
        return .result()
    }
}
