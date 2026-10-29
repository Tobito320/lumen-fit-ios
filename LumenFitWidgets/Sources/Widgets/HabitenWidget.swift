import SwiftUI
import WidgetKit

/// Stub des Grundgerüsts: das Modul widgets füllt dieses Widget.
struct HabitenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.habiten", provider: StubAnbieter()) { _ in StubAnsicht(titel: "Gewohnheiten") }
            .configurationDisplayName("Gewohnheiten")
            .description("Kommt bald.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
