import SwiftUI

/// Der heutige Trainingstag aus dem Split mit einem Tipp (Idee 14). Der Knopf startet das Training über den Port `trainingSteuerung` (Modul gym);
/// ohne Plan führt er in den Plan-Bereich des Gym-Tabs. "Heute locker" erscheint als Pille, wenn der Morgen-Check oder der Score es rät.
struct PlanKarte: View {
    let plan: HeutePlan
    let starte: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HeuteKartenKopf(symbol: "dumbbell.fill", titel: "Plan für heute")
                HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                    Text(plan.name).font(.title2.weight(.bold)).foregroundStyle(palette.text)
                    if plan.art == .training, plan.uebungen > 0 {
                        Text("\(plan.uebungen) Übungen").font(.subheadline).foregroundStyle(palette.text2)
                    }
                }
                if plan.locker { Pille(text: "Heute locker", symbolName: "leaf.fill") }
                Text(plan.tipp).font(.subheadline).foregroundStyle(palette.text2)
                if let knopf = plan.knopf {
                    Button(action: starte) {
                        Text(knopf).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.akzent)
                    .foregroundStyle(palette.aufAkzent)
                }
            }
            .padding(Abstand.l)
        }
        .accessibilityElement(children: .contain)
    }
}
