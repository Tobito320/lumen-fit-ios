import SwiftUI
import WidgetKit

/// Idee 97: klein, Rest-Kalorien und Rest-Protein von heute. Ein Tipp öffnet den Scan. Essen ist monochrom (keine Datenfarbe).
struct EssenRestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.essen-rest", provider: SnapshotAnbieter()) { eintrag in
            EssenRestAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Essen")
        .description("Kalorien und Protein, die heute noch übrig sind. Ein Tipp öffnet den Scan.")
        .supportedFamilies([.systemSmall])
    }
}

struct EssenRestAnsicht: View {
    let eintrag: SnapshotEintrag

    var body: some View {
        WidgetRahmen(snapshot: eintrag.snapshot, link: RouteURL.url(fuer: .essen(.scan))) { farben in
            if let rest = WidgetAnzeige.essenRest(eintrag.snapshot, jetzt: eintrag.date) {
                inhalt(rest, farben)
            } else {
                WidgetLeerAnsicht(farben: farben, titel: String(localized: "Noch kein Essen"), text: String(localized: "Tippe, um dein erstes Essen zu scannen."))
            }
        }
    }

    private func inhalt(_ rest: WidgetAnzeige.EssenRest, _ farben: WidgetFarben) -> some View {
        let uebrig = rest.kcal >= 0
        return VStack(alignment: .leading, spacing: 4) {
            Label("Essen heute", systemImage: "fork.knife")
                .font(.caption.weight(.semibold))
                .foregroundStyle(farben.text2)
                .lineLimit(1)
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(WidgetAnzeige.zahlText(abs(rest.kcal)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(farben.text)
                .widgetAccentable()
            Text(uebrig ? "kcal übrig" : "kcal drüber").font(.subheadline).foregroundStyle(farben.text2)
            WidgetBalken(anteil: rest.anteil, farbe: farben.akzent, spur: farben.text2.opacity(0.25))
                .padding(.vertical, 2)
            Text("\(rest.protein) g Protein offen").font(.caption).foregroundStyle(farben.text2).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Essen heute: \(WidgetAnzeige.zahlText(abs(rest.kcal))) Kilokalorien \(uebrig ? String(localized: "übrig") : String(localized: "drüber")), \(rest.protein) Gramm Protein offen. Tippen öffnet den Scan.")
    }
}
