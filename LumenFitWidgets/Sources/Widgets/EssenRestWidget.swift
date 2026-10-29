import SwiftUI
import WidgetKit

/// Stub des Grundgerüsts: das Modul widgets füllt dieses Widget.
struct EssenRestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.essen-rest", provider: StubAnbieter()) { _ in StubAnsicht(titel: "Essen") }
            .configurationDisplayName("Essen")
            .description("Kommt bald.")
            .supportedFamilies([.systemSmall])
    }
}
