import SwiftUI
import WidgetKit

/// Stub des Grundgerüsts: das Modul widgets füllt dieses Widget.
struct BoegenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.boegen", provider: StubAnbieter()) { _ in StubAnsicht(titel: "Bögen") }
            .configurationDisplayName("Bögen")
            .description("Kommt bald.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
