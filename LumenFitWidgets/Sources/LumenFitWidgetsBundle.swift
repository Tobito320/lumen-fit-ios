import SwiftUI
import WidgetKit

/// Das Bundle listet alle Widgets, Steuerelemente und die Live Activity (zwölf Einträge, alle ausgefüllt, Modul widgets).
@main
struct LumenFitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BoegenWidget()
        PlanSerieWidget()
        SperrbildschirmWidget()
        SchlafSperrbildschirmWidget()
        GymWocheWidget()
        GymDuellWidget()
        HabitEinzelWidget()
        EssenRestWidget()
        HabitenWidget()
        TrainingLiveWidget()
        EssenLiveWidget()
        SchnellzugriffSteuerung()
    }
}
