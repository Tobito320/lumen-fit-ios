import SwiftUI
import WidgetKit

/// Idee 91: klein, drei Lumen-Bögen (Bewegen, Trainieren, Erholen) mit den Schritten in der Mitte, im Theme der App. Ein Tipp öffnet Heute.
struct BoegenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.boegen", provider: SnapshotAnbieter()) { eintrag in
            BoegenAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Bögen")
        .description("Schritte, Training und Schlaf von heute als drei Bögen.")
        .supportedFamilies([.systemSmall])
    }
}

struct BoegenAnsicht: View {
    let eintrag: SnapshotEintrag

    var body: some View {
        WidgetRahmen(snapshot: eintrag.snapshot, link: RouteURL.url(fuer: .heute)) { farben in
            if eintrag.snapshot == nil {
                WidgetLeerAnsicht(farben: farben)
            } else {
                inhalt(farben)
            }
        }
    }

    private func inhalt(_ farben: WidgetFarben) -> some View {
        let werte = WidgetAnzeige.boegen(eintrag.snapshot, jetzt: eintrag.date)
        return ZStack {
            WidgetBoegen(werte: werte, farben: farben, strich: 8, abstand: 3)
                .frame(width: 112, height: 112)
                .overlay(alignment: .bottom) {
                    // Die Symbole stehen in der Öffnung der Bögen, von außen nach innen: Bewegen, Trainieren, Erholen. Farbe trägt nie allein.
                    HStack(spacing: 8) {
                        ForEach(werte) { wert in
                            Image(systemName: wert.id.symbolName).font(.caption).foregroundStyle(farben.daten(wert.id)).widgetAccentable()
                        }
                    }
                }
            VStack(spacing: 0) {
                Image(systemName: "figure.walk").font(.caption).foregroundStyle(farben.text2)
                Text(werte[0].zahl)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(farben.text)
                    .widgetAccentable()
            }
            .frame(width: 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if farben.vollfarbe {
                LumiView(stimmung: eintrag.snapshot?.lumi ?? .bereit, groesse: 24, stufe: eintrag.snapshot?.lumiStufe ?? 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechtext)
    }

    private var sprechtext: String {
        let werte = WidgetAnzeige.sprechtext(eintrag.snapshot, jetzt: eintrag.date)
        guard let lumi = eintrag.snapshot?.lumi else { return werte }
        return "\(werte). \(lumi.beschreibung)"
    }
}
