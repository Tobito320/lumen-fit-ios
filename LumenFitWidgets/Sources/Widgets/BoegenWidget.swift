import SwiftUI
import WidgetKit

/// Idee 91: klein, drei Lumen-Bögen (Bewegen, Trainieren, Erholen) mit den Schritten in der Mitte, im Theme der App. Ein Tipp öffnet Heute.
/// Mittel (Schritte-Duell): links die Bögen, rechts du und dein Partner mit den Schritten von heute; ohne geteilte Schritte stehen dort die drei Werte als Zeilen.
struct BoegenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.boegen", provider: SnapshotAnbieter()) { eintrag in
            BoegenAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Bögen")
        .description("Schritte, Training und Schlaf von heute als drei Bögen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BoegenAnsicht: View {
    let eintrag: SnapshotEintrag
    @Environment(\.widgetFamily) private var familie

    var body: some View {
        WidgetRahmen(snapshot: eintrag.snapshot, link: RouteURL.url(fuer: .heute)) { farben in
            if eintrag.snapshot == nil {
                WidgetLeerAnsicht(farben: farben)
            } else {
                inhalt(farben)
            }
        }
    }

    @ViewBuilder
    private func inhalt(_ farben: WidgetFarben) -> some View {
        if familie == .systemMedium {
            HStack(spacing: 12) {
                boegen(farben).frame(width: 120)
                SchritteDuellTeil(eintrag: eintrag, farben: farben)
            }
        } else {
            boegen(farben)
        }
    }

    private func boegen(_ farben: WidgetFarben) -> some View {
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

/// Die rechte Seite der mittleren Größe: Schritte-Duell (du gegen deinen Partner) oder, wenn er keine Schritte teilt, die drei Werte von heute als Zeilen.
struct SchritteDuellTeil: View {
    let eintrag: SnapshotEintrag
    let farben: WidgetFarben

    private var boegen: WidgetBoegenWerte? { WidgetAnzeige.istVonHeute(eintrag.snapshot, jetzt: eintrag.date) ? eintrag.snapshot?.boegen : nil }
    private var partner: WidgetPartnerStand? { WidgetAnzeige.partner(eintrag.snapshot, jetzt: eintrag.date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let partner, let sein = partner.schritte {
                Label("Schritte-Duell", systemImage: "figure.walk").font(.caption.weight(.semibold)).foregroundStyle(farben.text2).lineLimit(1).widgetAccentable()
                zeile("Du", boegen?.schritte, boegen?.schritteZiel, farben.bewegen)
                zeile(partner.name, sein, partner.schritteZiel, farben.text2)
            } else {
                let werte = WidgetAnzeige.boegen(eintrag.snapshot, jetzt: eintrag.date)
                ForEach(werte) { wert in
                    zeile(wert.beschriftung, wert.zahl, wert.anteil, farben.daten(wert.id))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechtext)
    }

    /// Eine Zeile mit Name, Zahl und Balken; ohne Wert ein Strich und ein leerer Balken.
    private func zeile(_ name: String, _ schritte: Int?, _ ziel: Int?, _ farbe: Color) -> some View {
        zeile(name, schritte.map(WidgetAnzeige.zahlText) ?? "–", WidgetAnzeige.anteil(schritte, ziel), farbe)
    }

    private func zeile(_ name: String, _ zahl: String, _ anteil: Double, _ farbe: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.caption.weight(.semibold)).foregroundStyle(farben.text2).lineLimit(1)
                Spacer(minLength: 4)
                Text(zahl)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(farben.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            WidgetBalken(anteil: anteil, farbe: farbe, spur: farben.vollfarbe ? farbe.opacity(0.22) : .secondary.opacity(0.3))
        }
    }

    private var sprechtext: String {
        if let partner, let sein = partner.schritte {
            return "Schritte: du \(boegen?.schritte.map(WidgetAnzeige.zahlText) ?? "keine Daten"), \(partner.name) \(WidgetAnzeige.zahlText(sein))"
        }
        return WidgetAnzeige.sprechtext(eintrag.snapshot, jetzt: eintrag.date)
    }
}
