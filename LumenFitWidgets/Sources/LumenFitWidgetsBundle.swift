import SwiftUI
import WidgetKit

/// Das Bundle listet alle Widgets, Steuerelemente und die Live Activity (zwölf Einträge, alle ausgefüllt, Modul widgets).
/// In zwei Teilen: ein Builder trägt sicher nur zehn Einträge, mehr gäbe einen Compilerfehler.
@main
struct LumenFitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        statisch
        live
    }

    @WidgetBundleBuilder private var statisch: some Widget {
        BoegenWidget()
        PlanSerieWidget()
        SperrbildschirmWidget()
        SchlafSperrbildschirmWidget()
        GymWocheWidget()
        GymDuellWidget()
    }

    @WidgetBundleBuilder private var live: some Widget {
        HabitEinzelWidget()
        EssenRestWidget()
        HabitenWidget()
        TrainingLiveWidget()
        EssenLiveWidget()
        SchnellzugriffSteuerung()
    }
}
