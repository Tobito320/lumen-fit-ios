import SwiftUI
import WidgetKit

/// Stub des Grundgerüsts: das Modul widgets füllt dieses Widget.
struct PlanSerieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.plan-serie", provider: StubAnbieter()) { _ in StubAnsicht(titel: "Plan und Serie") }
            .configurationDisplayName("Plan und Serie")
            .description("Kommt bald.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
