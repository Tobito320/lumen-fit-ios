// Quelle: Lovea Health/LoveaWidgets/GymWocheWidget.swift (GymTageReihe)
import SwiftUI
import WidgetKit

/// Montag bis Sonntag als Punkte: erledigte Tage gefüllt mit Haken, heute umrandet. Gemeinsam für Gym-Woche und Gym-Duell.
/// Die Reihe ist reine Optik; die Aussage steht im Sprechtext des Widgets (`WidgetAnzeige.gymSprechtext`).
struct GymWochenPunkte: View {
    let tage: [WidgetGymTag]
    let heute: String
    let farben: WidgetFarben
    var groesse: CGFloat = 20
    var buchstaben = true

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(tage.enumerated()), id: \.element.tag) { index, tag in
                VStack(spacing: 2) {
                    if buchstaben {
                        Text(String(HabitLogik.wochentagKuerzel[index].prefix(1)))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(tag.tag == heute ? farben.text : farben.text2)
                    }
                    ZStack {
                        Circle().fill(tag.erledigt ? farben.trainieren : farben.text2.opacity(0.18))
                        if tag.erledigt {
                            Image(systemName: "checkmark")
                                .font(.system(size: groesse * 0.5, weight: .bold))
                                .foregroundStyle(farben.aufTrainieren)
                        }
                        if tag.tag == heute { Circle().stroke(farben.text, lineWidth: 1.5).padding(-2.5) }
                    }
                    .frame(width: groesse, height: groesse)
                    .widgetAccentable(tag.erledigt)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Der Haken-Knopf für Gym heute (mindestens 44 pt Fläche). Läuft über `GymHeuteIntent`: schreibt nur in die Gruppe, die App übernimmt es.
struct GymHeuteKnopf: View {
    let erledigt: Bool
    let farben: WidgetFarben

    var body: some View {
        Button(intent: GymHeuteIntent()) {
            Image(systemName: erledigt ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(erledigt ? farben.trainieren : farben.text2)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .widgetAccentable(erledigt)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gym heute")
        .accessibilityValue(erledigt ? "erledigt" : "offen")
        .accessibilityHint(erledigt ? "Tippen nimmt den Haken weg" : "Tippen hakt ab")
    }
}
