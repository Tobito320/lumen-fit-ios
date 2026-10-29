// Quelle: Lovea Health/LoveaWidgets/Shared/GymSchrittIntent.swift
import AppIntents

/// Der Knopf "Satz fertig" in der Live Activity (Sperrbildschirm, Dynamic Island), ohne die App zu öffnen.
/// Ein `LiveActivityIntent` läuft im Prozess der App, nicht im Widget. Deshalb steht die Arbeit nicht hier, sondern hinter `ausfuehren`,
/// das `WidgetsModul.start` setzt (SPEC 5.9 Vertrag 9). Im Widget-Prozess bleibt es nil. Der Intent kennt keinen App-Typ.
struct SatzFertigIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Satz fertig" }

    @MainActor static var ausfuehren: (@MainActor () -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.ausfuehren?()
        return .result()
    }
}
