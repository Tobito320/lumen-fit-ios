import SwiftUI
import WidgetKit

/// Gemeinsamer Platzhalter der Stub-Widgets des Grundgerüsts. Das Modul widgets ersetzt die Widgets und löscht diese Datei.
struct StubEintrag: TimelineEntry { let date: Date }

struct StubAnbieter: TimelineProvider {
    func placeholder(in context: Context) -> StubEintrag { StubEintrag(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (StubEintrag) -> Void) { completion(StubEintrag(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StubEintrag>) -> Void) {
        completion(Timeline(entries: [StubEintrag(date: Date())], policy: .never))
    }
}

struct StubAnsicht: View {
    let titel: String

    var body: some View {
        Text(titel)
            .font(.headline)
            .containerBackground(.background, for: .widget)
    }
}
