import SwiftUI
import WidgetKit

/// Das Bundle listet alle Widgets, Steuerelemente und die Live Activity; das Grundgerüst legt sie als Stubs an, das Modul widgets füllt sie.
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
