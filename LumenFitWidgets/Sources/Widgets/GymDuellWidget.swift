// Quelle: Lovea Health/LoveaWidgets/GymDuellWidget.swift
import SwiftUI
import WidgetKit

/// Gym-Duell (mittel): deine Woche und die deines Partners nebeneinander, heute abhakbar. Nur deine Spalte hat den Knopf.
/// Die Spalte des Partners zeigt nur, was er freigibt: ohne Verbindung steht dort ein ruhiger Satz, ohne Freigabe "Teilt kein Gym".
struct GymDuellWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.gymduell", provider: SnapshotAnbieter()) { eintrag in
            GymDuellAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Gym-Duell")
        .description("Deine Gym-Woche neben der deines Partners, heute direkt abhakbar.")
        .supportedFamilies([.systemMedium])
    }
}

struct GymDuellAnsicht: View {
    let eintrag: SnapshotEintrag

    private var meine: [WidgetGymTag] { WidgetAnzeige.gymWoche(eintrag.snapshot, jetzt: eintrag.date) }
    private var ziel: Int { WidgetAnzeige.gymZiel(eintrag.snapshot) }
    private var partner: WidgetPartnerStand? { WidgetAnzeige.partner(eintrag.snapshot, jetzt: eintrag.date) }

    var body: some View {
        WidgetRahmen(snapshot: eintrag.snapshot, link: RouteURL.url(fuer: .gym(.training))) { farben in
            if eintrag.snapshot == nil {
                WidgetLeerAnsicht(farben: farben)
            } else {
                HStack(spacing: 12) {
                    spalte(name: String(localized: "Du"), symbol: "person.fill", tage: meine, ziel: ziel, eigene: true, farben)
                    Rectangle().fill(farben.text2.opacity(0.25)).frame(width: 1).accessibilityHidden(true)
                    partnerSpalte(farben)
                }
            }
        }
    }

    @ViewBuilder
    private func partnerSpalte(_ farben: WidgetFarben) -> some View {
        if let partner {
            if let tage = WidgetAnzeige.partnerGymWoche(partner, jetzt: eintrag.date) {
                spalte(name: partner.name, symbol: "person.fill", tage: tage, ziel: max(partner.gymZiel ?? ziel, 1), eigene: false, farben)
            } else {
                leer(partner.name, String(localized: "Teilt kein Gym"), farben)
            }
        } else {
            leer(String(localized: "Partner"), String(localized: "Noch nicht verbunden"), farben)
        }
    }

    private func leer(_ name: String, _ text: String, _ farben: WidgetFarben) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(name, systemImage: "person.fill").font(.caption.weight(.semibold)).foregroundStyle(farben.text2).lineLimit(1)
            Spacer(minLength: 0)
            Text(text).font(.footnote).foregroundStyle(farben.text2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(text)")
    }

    private func spalte(name: String, symbol: String, tage: [WidgetGymTag], ziel: Int, eigene: Bool, _ farben: WidgetFarben) -> some View {
        let anzahl = WidgetAnzeige.gymZahl(tage, jetzt: eintrag.date)
        let fertig = WidgetAnzeige.gymHeuteErledigt(eigene ? eintrag.snapshot : nil, jetzt: eintrag.date)
        let kannAbhaken = eigene && !(eintrag.snapshot?.profilKennung ?? "").isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Label(name, systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(farben.text2)
                    .lineLimit(1)
                    .widgetAccentable(eigene)
                Spacer(minLength: 0)
                if kannAbhaken { GymHeuteKnopf(erledigt: fertig, farben: farben).padding(.top, -10).padding(.trailing, -10) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(anzahl)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(farben.text)
                    .widgetAccentable()
                Text("von \(ziel)").font(.caption).foregroundStyle(farben.text2)
            }
            Spacer(minLength: 0)
            GymWochenPunkte(tage: tage, heute: Datum.text(eintrag.date), farben: farben, groesse: 14, buchstaben: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WidgetAnzeige.gymSprechtext(name: name, tage: tage, ziel: ziel, jetzt: eintrag.date))
    }
}
