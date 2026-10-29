import SwiftUI
import WidgetKit

struct PlatzhalterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "platzhalter", provider: PlatzhalterAnbieter()) { _ in Text("Lumen Fit") }
            .configurationDisplayName("Lumen Fit")
    }
}

struct PlatzhalterEintrag: TimelineEntry { let date: Date }

struct PlatzhalterAnbieter: TimelineProvider {
    func placeholder(in context: Context) -> PlatzhalterEintrag { PlatzhalterEintrag(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (PlatzhalterEintrag) -> Void) { completion(PlatzhalterEintrag(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlatzhalterEintrag>) -> Void) {
        completion(Timeline(entries: [PlatzhalterEintrag(date: Date())], policy: .never))
    }
}

@main
struct LumenFitWidgetsBundle: WidgetBundle {
    var body: some Widget { PlatzhalterWidget() }
}
