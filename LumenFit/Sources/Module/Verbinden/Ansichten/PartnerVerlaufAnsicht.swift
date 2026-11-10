import Charts
import SwiftUI

/// Statuszeile und Verlauf des Partners (Gleichstand Lovea "Planansicht, Statuszeile, Verlauf"): ob die Person gerade im Gym ist, drei Kennzahlen,
/// die Dauer der letzten Einheiten als Diagramm und die Einheiten als Liste. Nur eine Zusammenfassung, nie Sätze oder Gewichte.
struct PartnerVerlaufAnsicht: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        PartnerAnsichtRahmen(art: .verlauf, titel: String(localized: "Training und Verlauf")) { datei in
            if let verlauf = datei.heute.verlauf { PartnerVerlaufInhalt(name: datei.profilName, verlauf: verlauf, jetzt: umgebung.uhr()) }
        }
    }
}

private struct PartnerVerlaufInhalt: View {
    let name: String
    let verlauf: PartnerVerlauf
    let jetzt: Date
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        status.partnerErscheint(0)
        kennzahlen.partnerErscheint(1)
        let punkte = PartnerAnsichtLogik.dauerPunkte(verlauf)
        if punkte.count >= 2 { diagramm(punkte).partnerErscheint(2) }
        liste.partnerErscheint(3)
    }

    private var status: some View {
        let zeile = PartnerAnsichtLogik.statusZeile(verlauf, jetzt: jetzt)
        return HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(name).font(.footnote.weight(.semibold))
                Text(zeile ?? String(localized: "Gerade nicht im Gym")).font(.title2.weight(.bold)).fontDesign(.rounded)
                if zeile == nil, let letztes = verlauf.trainings.first {
                    Text("Zuletzt: \(PartnerAnsichtLogik.trainingZeile(letztes).titel), \(PartnerAnsichtLogik.kurzDatum(letztes.tag))").font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var kennzahlen: some View {
        HStack(alignment: .top, spacing: Abstand.m) {
            ForEach(PartnerAnsichtLogik.kennzahlen(verlauf)) { k in
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    RollZahl(wert: Double(k.wert), format: .number.precision(.fractionLength(0))).font(.title.weight(.bold)).fontDesign(.rounded)
                    Text(k.titel).font(.caption).foregroundStyle(palette.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(palette.text)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }

    private func diagramm(_ punkte: [PartnerAnsichtLogik.DauerPunkt]) -> some View {
        let farbe = LumenFarben.tief(.trainieren, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let schnitt = punkte.reduce(0) { $0 + $1.minuten } / max(1, punkte.count)
        return DiagrammKarte(aussage: String(localized: "Dauer der letzten Einheiten"), kernzeile: String(localized: "Im Schnitt \(schnitt) min")) {
            Chart(punkte) { p in
                BarMark(x: .value("Tag", Datum.datum(p.tag), unit: .day), y: .value("Minuten", p.minuten))
                    .foregroundStyle(farbe)
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(palette.text2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(palette.haar)
                    AxisValueLabel().foregroundStyle(palette.text2)
                }
            }
            .frame(height: 160)
            .partnerZeichnet()
            .accessibilityChartDescriptor(FortschrittDeskriptor(
                titel: String(localized: "Dauer der letzten Einheiten"), zusammenfassung: String(localized: "\(punkte.count) Einheiten, im Schnitt \(schnitt) Minuten"),
                xTitel: String(localized: "Tag"), yTitel: String(localized: "Minuten"), einheit: "min", stetig: false,
                punkte: punkte.map { .init(x: PartnerAnsichtLogik.kurzDatum($0.tag), y: Double($0.minuten)) }))
        }
    }

    private var liste: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Letzte Einheiten").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
            if verlauf.trainings.isEmpty {
                Text("\(name) hat noch kein Training mit Sätzen.").font(.subheadline).foregroundStyle(palette.text2)
                    .padding(Abstand.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lumenKartenFlaeche()
            } else {
                ListenKarte {
                    ForEach(Array(verlauf.trainings.enumerated()), id: \.offset) { i, t in
                        if i > 0 { Haarlinie() }
                        zeile(t)
                    }
                }
            }
        }
    }

    private func zeile(_ t: PartnerTrainingKurz) -> some View {
        let z = PartnerAnsichtLogik.trainingZeile(t)
        return VStack(alignment: .leading, spacing: 2) {
            Text(z.titel).font(.body.weight(.semibold)).foregroundStyle(palette.text)
            Text(z.detail).font(.subheadline).foregroundStyle(palette.text2)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
