// Quelle: Lovea Health/LoveaWidgets/GymWocheWidget.swift
import SwiftUI
import WidgetKit

/// Gym-Woche: Montag bis Sonntag als Punkte mit Haken, heute umrandet, dazu "2 von 3" und ein Knopf, der heute ohne App abhakt (`GymHeuteIntent`).
/// Klein und mittel. Ohne Profilkennung im Snapshot (alte Datei) ist der Knopf weg und das Widget nur eine Anzeige.
struct GymWocheWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.gymwoche", provider: SnapshotAnbieter()) { eintrag in
            GymWocheAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Gym-Woche")
        .description("Deine Gym-Tage der Woche, heute direkt abhakbar.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GymWocheAnsicht: View {
    let eintrag: SnapshotEintrag
    @Environment(\.widgetFamily) private var familie

    private var tage: [WidgetGymTag] { WidgetAnzeige.gymWoche(eintrag.snapshot, jetzt: eintrag.date) }
    private var heute: String { Datum.text(eintrag.date) }
    private var ziel: Int { WidgetAnzeige.gymZiel(eintrag.snapshot) }
    private var kannAbhaken: Bool { !(eintrag.snapshot?.profilKennung ?? "").isEmpty }

    var body: some View {
        WidgetRahmen(snapshot: eintrag.snapshot, link: RouteURL.url(fuer: .gym(.training))) { farben in
            if eintrag.snapshot == nil {
                WidgetLeerAnsicht(farben: farben)
            } else {
                inhalt(farben)
            }
        }
    }

    private func inhalt(_ farben: WidgetFarben) -> some View {
        let anzahl = WidgetAnzeige.gymZahl(tage, jetzt: eintrag.date)
        let fertig = WidgetAnzeige.gymHeuteErledigt(eintrag.snapshot, jetzt: eintrag.date)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Label("Gym", systemImage: "dumbbell.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(farben.text2)
                    .widgetAccentable()
                Spacer(minLength: 0)
                if kannAbhaken { GymHeuteKnopf(erledigt: fertig, farben: farben).padding(.top, -10).padding(.trailing, -10) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(anzahl)")
                    .font(.system(familie == .systemSmall ? .title : .largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(farben.text)
                    .widgetAccentable()
                Text("von \(ziel)").font(.caption).foregroundStyle(farben.text2)
            }
            Spacer(minLength: 0)
            GymWochenPunkte(tage: tage, heute: heute, farben: farben, groesse: familie == .systemSmall ? 14 : 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WidgetAnzeige.gymSprechtext(name: String(localized: "Gym diese Woche"), tage: tage, ziel: ziel, jetzt: eintrag.date))
    }
}
