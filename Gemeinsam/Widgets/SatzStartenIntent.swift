import AppIntents

/// Der Knopf "Satz starten" in der Live Activity, solange die Pause läuft: ein Tipp beendet die Pause und startet den nächsten Satz.
/// Wie `SatzFertigIntent`: läuft im Prozess der App, die Arbeit setzt `WidgetsModul.start`; im Widget-Prozess bleibt `ausfuehren` nil.
struct SatzStartenIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Satz starten" }

    @MainActor static var ausfuehren: (@MainActor () -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.ausfuehren?()
        return .result()
    }
}
