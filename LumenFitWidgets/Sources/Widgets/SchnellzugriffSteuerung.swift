import AppIntents
import SwiftUI
import WidgetKit

/// Stub des Grundgerüsts: Steuerelement im Kontrollzentrum, öffnet die App. Das Modul widgets baut daraus den Schnellzugriff.
struct SchnellzugriffSteuerung: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.onlyus.lumen-fit.schnellzugriff") {
            ControlWidgetButton(action: SchnellzugriffOeffnenIntent()) {
                Label("Lumen Fit", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .displayName("Lumen Fit")
    }
}

struct SchnellzugriffOeffnenIntent: AppIntent {
    static let title: LocalizedStringResource = "Lumen Fit öffnen"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}
