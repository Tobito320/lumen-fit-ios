import ActivityKit
import SwiftUI
import WidgetKit

/// Stub des Grundgerüsts: die Training-Live-Activity. Das Modul widgets baut Sperrbildschirm, Dynamic Island und den Knopf "Satz fertig".
struct TrainingLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingAktivitaet.self) { kontext in
            Text(kontext.state.stand.uebung).padding()
        } dynamicIsland: { kontext in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { Text(kontext.state.stand.uebung) }
            } compactLeading: {
                Text("\(kontext.state.stand.satz)")
            } compactTrailing: {
                Text("\(kontext.state.stand.von)")
            } minimal: {
                Text("\(kontext.state.stand.satz)")
            }
        }
    }
}
