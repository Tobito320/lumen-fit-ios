import SwiftUI
import WidgetKit

/// Stub des Grundgerüsts: das Modul widgets füllt dieses Widget.
struct SperrbildschirmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.sperrbildschirm", provider: StubAnbieter()) { _ in StubAnsicht(titel: "Sperrbildschirm") }
            .configurationDisplayName("Sperrbildschirm")
            .description("Kommt bald.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
