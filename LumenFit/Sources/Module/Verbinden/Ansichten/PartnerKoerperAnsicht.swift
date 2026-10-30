import Charts
import SwiftUI

/// Der Person-Umschalter in den Messungen (Gleichstand Lovea "Person-Umschalter in Messungen"): oben "Ich / Partner", aber nur, wenn der Partner Körperwerte
/// freigegeben hat und etwas geteilt ist. "Ich" zeigt die eigenen Messungen (`eigene`), der Partner seine Werte nur zum Lesen.
struct PartnerKoerperWeiche<Eigene: View>: View {
    let eigene: Eigene
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var partnerAnsicht = false

    init(@ViewBuilder eigene: () -> Eigene) { self.eigene = eigene() }

    var body: some View {
        let stand = PartnerAnsichtLogik.aktuellerStand(umgebung)
        let sichtbar = PartnerAnsichtLogik.umschalterSichtbar(stand)
        Group {
            if sichtbar && partnerAnsicht { PartnerKoerperAnsicht() } else { eigene }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if sichtbar { umschalter(stand) }
        }
        .haptik(.auswahl, bei: partnerAnsicht)
    }

    private func umschalter(_ stand: PartnerStand) -> some View {
        let name: String
        switch stand {
        case .verbunden(let d), .veraltet(let d): name = d.profilName
        case .nichtVerbunden, .unbekannteVersion: name = "Partner"
        }
        return Picker("Wessen Werte", selection: $partnerAnsicht) {
            Text("Ich").tag(false)
            Text(name).tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .background(.bar)
    }
}

/// Die Körperwerte des Partners: Gewicht und Maße wie in den eigenen Messungen (Auswahl der Messung, großer Wert, Kurve, Historie), nur lesen.
struct PartnerKoerperAnsicht: View {
    var body: some View {
        PartnerAnsichtRahmen(art: .koerper, titel: "Messungen") { datei in
            PartnerKoerperInhalt(datei: datei)
        }
    }
}

private struct PartnerKoerperInhalt: View {
    let datei: ZusammenfassungDatei
    @State private var art: MessArt
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    init(datei: ZusammenfassungDatei) {
        self.datei = datei
        let arten = PartnerAnsichtLogik.koerperArten(datei)
        _art = State(initialValue: arten.contains(.gewicht) ? .gewicht : (arten.first ?? .gewicht))
    }

    var body: some View {
        let arten = PartnerAnsichtLogik.koerperArten(datei)
        let punkte = PartnerAnsichtLogik.punkte(datei, art)
        auswahl(arten).partnerErscheint(0)
        if let letzter = punkte.last {
            karte(punkte, letzter: letzter).partnerErscheint(1)
            historie(punkte).partnerErscheint(2)
        }
    }

    private func auswahl(_ arten: [MessArt]) -> some View {
        ListenKarte {
            HStack {
                Text("Messung von \(datei.profilName)").font(.body).foregroundStyle(palette.text)
                Spacer()
                Picker("Messung", selection: $art) {
                    ForEach(arten) { Text($0.titel).tag($0) }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, Abstand.l)
            .frame(minHeight: Abstand.tippflaeche)
        }
        .haptik(.auswahl, bei: art)
    }

    private func karte(_ punkte: [MessPunkt], letzter: MessPunkt) -> some View {
        let zusatz = MessErfassung.aenderung(punkte, art: art)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Text(art.titel).font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
            HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                RollZahl(wert: Double(letzter.zehntel) / 10, format: .number.precision(.fractionLength(1))).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                Text(art.einheit).font(.title3).foregroundStyle(palette.text2)
            }
            .id(art)
            Text(zusatz.map { "\(Datum.anzeige(letzter.tag)) · \($0)" } ?? Datum.anzeige(letzter.tag)).font(.subheadline).foregroundStyle(palette.text2)
            if punkte.count > 1 { diagramm(punkte) }
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .contain)
    }

    private func diagramm(_ punkte: [MessPunkt]) -> some View {
        let farbe = LumenFarben.tief(.bewegen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let werte = punkte.map { Double($0.zehntel) / 10 }
        let niedrig = (werte.min() ?? 0) - 1, hoch = (werte.max() ?? 1) + 1
        return Chart(punkte) { p in
            LineMark(x: .value("Tag", Datum.datum(p.tag)), y: .value(art.einheit, Double(p.zehntel) / 10))
                .foregroundStyle(farbe)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Tag", Datum.datum(p.tag)), y: .value(art.einheit, Double(p.zehntel) / 10))
                .foregroundStyle(farbe)
                .symbolSize(p.id == punkte.last?.id ? 90 : 28)
        }
        .chartYScale(domain: niedrig...hoch)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(palette.text2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel().foregroundStyle(palette.text2)
            }
        }
        .frame(height: 180)
        .partnerZeichnet()
        .id(art)
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: "\(art.titel) von \(datei.profilName)", zusammenfassung: "\(art.titel): \(art.text(punkte.last?.zehntel ?? 0)), \(punkte.count) Messungen",
            xTitel: "Tag", yTitel: art.titel, einheit: art.einheit, stetig: true,
            punkte: punkte.map { .init(x: PartnerAnsichtLogik.kurzDatum($0.tag), y: Double($0.zehntel) / 10) }))
    }

    private func historie(_ punkte: [MessPunkt]) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("\(art.titel) Historie").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
            ListenKarte {
                ForEach(punkte.reversed()) { p in
                    HStack {
                        Text(Datum.anzeige(p.tag)).font(.body).foregroundStyle(palette.text)
                        Spacer(minLength: Abstand.s)
                        Text(art.text(p.zehntel)).font(.body.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                    .padding(.horizontal, Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                    .accessibilityElement(children: .combine)
                    if p.id != punkte.first?.id { Haarlinie() }
                }
            }
        }
    }
}
