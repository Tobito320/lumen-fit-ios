import AppIntents
import SwiftUI
import WidgetKit

/// Idee 100: Knopf im Kontrollzentrum (auch Sperrbildschirm und Aktionstaste). Beim Hinzufügen wählst du, was er tut: Training starten oder Essen scannen.
/// Ein Steuerelement, weil das Bundle nur einen Platz dafür hat; die Wahl ist ein Parameter. Der Knopf öffnet die App und führt die Aktion über `SchnellzugriffIntent` aus.
struct SchnellzugriffSteuerung: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "com.onlyus.lumen-fit.schnellzugriff", provider: SchnellzugriffAnbieter()) { aktion in
            ControlWidgetButton(action: SchnellzugriffIntent(aktion: aktion)) {
                Label(aktion.titel, systemImage: aktion.symbolName)
            }
        }
        .displayName("Lumen Fit")
        .description("Startet dein Training oder öffnet den Scan für dein Essen.")
    }
}

/// Die Wahl beim Hinzufügen des Steuerelements.
struct SchnellzugriffWahl: ControlConfigurationIntent {
    static var title: LocalizedStringResource { "Schnellzugriff wählen" }

    @Parameter(title: "Aktion", default: .training) var aktion: SchnellzugriffAktion
}

struct SchnellzugriffAnbieter: AppIntentControlValueProvider {
    func previewValue(configuration: SchnellzugriffWahl) -> SchnellzugriffAktion { configuration.aktion }

    func currentValue(configuration: SchnellzugriffWahl) async throws -> SchnellzugriffAktion { configuration.aktion }
}
