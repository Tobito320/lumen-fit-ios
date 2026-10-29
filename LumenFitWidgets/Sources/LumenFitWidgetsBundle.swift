import SwiftUI
import WidgetKit

/// Das Bundle listet alle Widgets, Steuerelemente und die Live Activity (sieben Einträge, alle ausgefüllt, Modul widgets).
@main
struct LumenFitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BoegenWidget()
        PlanSerieWidget()
        SperrbildschirmWidget()
        EssenRestWidget()
        HabitenWidget()
        TrainingLiveWidget()
        SchnellzugriffSteuerung()
    }
}
