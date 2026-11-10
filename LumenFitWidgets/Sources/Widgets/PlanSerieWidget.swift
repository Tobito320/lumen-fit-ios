import SwiftUI
import WidgetKit

/// Idee 92: mittel, links die Bögen, rechts der nächste Plantag ("Push morgen") und die Serie; klein nur Plan und Serie. Ein Tipp öffnet das Gym.
struct PlanSerieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.plan-serie", provider: SnapshotAnbieter()) { eintrag in
            PlanSerieAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Plan und Serie")
        .description("Dein nächstes Training, deine Serie und die Bögen von heute.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PlanSerieAnsicht: View {
    let eintrag: SnapshotEintrag
    @Environment(\.widgetFamily) private var familie

    var body: some View {
        WidgetRahmen(snapshot: eintrag.snapshot, link: RouteURL.url(fuer: .gym(.training))) { farben in
            if eintrag.snapshot == nil {
                WidgetLeerAnsicht(farben: farben)
            } else if familie == .systemMedium {
                HStack(spacing: 16) {
                    boegen(farben)
                    planSpalte(farben)
                }
            } else {
                planSpalte(farben)
            }
        }
    }

    private func boegen(_ farben: WidgetFarben) -> some View {
        let werte = WidgetAnzeige.boegen(eintrag.snapshot, jetzt: eintrag.date)
        return ZStack {
            WidgetBoegen(werte: werte, farben: farben, strich: 7, abstand: 3)
            if farben.vollfarbe {
                LumiView(stimmung: eintrag.snapshot?.lumi ?? .bereit, groesse: 32, stufe: eintrag.snapshot?.lumiStufe ?? 1)
            } else {
                Image(systemName: "figure.walk").font(.title3).foregroundStyle(farben.text).widgetAccentable()
            }
        }
        .frame(width: 100, height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetAnzeige.sprechtext(eintrag.snapshot, jetzt: eintrag.date))
    }

    private func planSpalte(_ farben: WidgetFarben) -> some View {
        let plan = WidgetAnzeige.planText(eintrag.snapshot?.plan, jetzt: eintrag.date)
        let serie = WidgetAnzeige.serieText(eintrag.snapshot?.serieWochen)
        return VStack(alignment: .leading, spacing: 4) {
            Label("Nächstes Training", systemImage: "figure.strengthtraining.traditional")
                .font(.caption.weight(.semibold))
                .foregroundStyle(farben.text2)
                .lineLimit(1)
                .widgetAccentable()
            Text(plan.titel)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(farben.text)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            if let wann = plan.wann {
                Text(wann).font(.subheadline).foregroundStyle(farben.text2)
            }
            Spacer(minLength: 0)
            Label(serie, systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(farben.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([String(localized: "Nächstes Training"), plan.titel, plan.wann, serie].compactMap { $0 }.joined(separator: ", "))
    }
}
