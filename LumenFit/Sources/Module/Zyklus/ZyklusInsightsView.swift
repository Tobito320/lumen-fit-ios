// Quelle: Lovea Zyklus/ZyklusInsightsView.swift (Diagramme mit Swift Charts und Beschreibung für VoiceOver)
import Charts
import SwiftUI

/// Beschreibung eines Zyklus-Diagramms für VoiceOver: Titel, Kernzeile und ein Wert je Punkt.
struct ZyklusDiagrammBeschreibung: AXChartDescriptorRepresentable {
    let titel: String
    let zusammenfassung: String
    let xTitel: String
    let yTitel: String
    let einheit: String
    let punkte: [(name: String, wert: Double)]

    func makeChartDescriptor() -> AXChartDescriptor {
        let namen = punkte.map(\.name)
        let x = AXCategoricalDataAxisDescriptor(title: xTitel, categoryOrder: namen.isEmpty ? ["–"] : namen)
        let werte = punkte.map(\.wert)
        let untergrenze = min(0, werte.min() ?? 0)
        let obergrenze = max(untergrenze + 1, werte.max() ?? 1)
        let einheitText = einheit
        let y = AXNumericDataAxisDescriptor(title: yTitel, range: untergrenze...obergrenze, gridlinePositions: []) { wert in
            "\(wert.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_DE")))) \(einheitText)"
        }
        let serie = AXDataSeriesDescriptor(name: titel, isContinuous: false, dataPoints: punkte.map { AXDataPoint(x: $0.name, y: $0.wert) })
        return AXChartDescriptor(title: titel, summary: zusammenfassung, xAxis: x, yAxis: y, additionalAxes: [], series: [serie])
    }
}

/// Insights: Zykluslängen, Periode, Regelmäßigkeit, Symptome und Stimmung je Phase, Temperatur, Hinweise, Wissen.
struct ZyklusInsightsView: View {
    let store: ZyklusStore
    @State private var wissensPhase: ZyklusPhase = .periode
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let auswertung = ZyklusInsightsLogik(tage: Array(store.tage.values), einstellung: store.einstellung, heute: store.heute)
        ScrollView {
            VStack(spacing: Abstand.l) {
                zahlenKarte(auswertung)
                verlaufKarte(auswertung)
                if !auswertung.auffaelligkeiten.isEmpty { hinweisKarte(auswertung) }
                phasenKarte(auswertung)
                temperaturKarte(auswertung)
                wissenKarte
                Text(ZyklusInsightsLogik.arztHinweis).font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            }
            .padding(Abstand.l)
        }
        .lumenZyklusHintergrund()
    }

    /// Farbe kommt von der Heldenkarte (Text auf Akzent).
    private func zahl(_ wert: Double?, _ titel: String) -> some View {
        VStack(spacing: Abstand.xs) {
            if let wert {
                RollZahl(wert: wert, format: .number.precision(.fractionLength(0)))
                    .font(.title.bold()).fontDesign(.rounded)
            } else {
                Text("–").font(.title.bold()).fontDesign(.rounded)
            }
            Text(titel).font(.caption).opacity(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func zahlenKarte(_ a: ZyklusInsightsLogik) -> some View {
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HStack {
                    zahl(Double(a.mittlereZyklusLaenge), "Tage Zyklus")
                    zahl(Double(a.mittlerePeriodenLaenge), "Tage Periode")
                    zahl(a.hatZyklen ? Double(a.streuung) : nil, "Tage Streuung")
                }
                Text(a.regelmaessigkeit.titel).font(.headline)
                Text(a.regelmaessigkeit.text).font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func verlaufKarte(_ a: ZyklusInsightsLogik) -> some View {
        let werte = a.zyklusVerlauf()
        if werte.isEmpty {
            ZyklusKarte(titel: "Deine Zyklen", symbol: "chart.bar.fill") {
                ZyklusLeise("Sobald du zwei Perioden eingetragen hast, siehst du hier deinen Verlauf.")
            }
        } else {
            let eintraege = Array(werte.enumerated())
            DiagrammKarte(aussage: "Deine Zyklen", kernzeile: "Im Schnitt \(a.mittlereZyklusLaenge) Tage, die Linie zeigt den Durchschnitt.") {
                Chart {
                    ForEach(eintraege, id: \.offset) { i, tage in
                        BarMark(x: .value("Zyklus", "\(i + 1)"), y: .value("Tage", tage))
                            .annotation(position: .top) { Text("\(tage)").font(.caption2.weight(.semibold)).foregroundStyle(palette.text2) }
                    }
                    RuleMark(y: .value("Durchschnitt", a.mittlereZyklusLaenge))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                .foregroundStyle(palette.text)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...(Double((werte.max() ?? 28) + 6)))
                .frame(height: 150)
                .accessibilityChartDescriptor(ZyklusDiagrammBeschreibung(
                    titel: "Deine Zyklen", zusammenfassung: "Im Schnitt \(a.mittlereZyklusLaenge) Tage", xTitel: "Zyklus", yTitel: "Länge", einheit: "Tage",
                    punkte: eintraege.map { (name: "Zyklus \($0.offset + 1)", wert: Double($0.element)) }))
            }
        }
    }

    private func hinweisKarte(_ a: ZyklusInsightsLogik) -> some View {
        ZyklusKarte(titel: "Mir fällt etwas auf", symbol: "exclamationmark.circle.fill") {
            ForEach(Array(a.auffaelligkeiten.enumerated()), id: \.offset) { _, f in ZyklusLeise(f.text) }
            ZyklusLeise(ZyklusInsightsLogik.arztHinweis)
        }
    }

    private func phasenKarte(_ a: ZyklusInsightsLogik) -> some View {
        ZyklusKarte(titel: "Je Phase", symbol: "circle.hexagongrid.fill") {
            ForEach(ZyklusPhase.allCases, id: \.self) { phase in
                let sym = a.haeufigsteSymptome(in: phase, maximal: 2)
                let stim = a.haeufigsteStimmung(in: phase, maximal: 2)
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Label(ZyklusPhaseStil.name(phase), systemImage: ZyklusPhaseStil.symbol(phase))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.text)
                    if sym.isEmpty && stim.isEmpty {
                        ZyklusLeise("Noch nichts eingetragen.")
                    } else {
                        ZyklusFluss {
                            ForEach(sym, id: \.wert) { Pille(text: "\($0.wert.eintragTitel) \($0.anzahl)") }
                            ForEach(stim, id: \.wert) { Pille(text: "\($0.wert.eintragTitel) \($0.anzahl)") }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func temperaturKarte(_ a: ZyklusInsightsLogik) -> some View {
        let punkte = a.temperaturKurve
        if punkte.count < 2 {
            ZyklusKarte(titel: "Temperatur", symbol: "thermometer.medium") {
                ZyklusLeise("Miss morgens deine Temperatur, dann zeichne ich hier die Kurve.")
            }
        } else {
            let tiefste = punkte.map(\.grad).min() ?? 36
            let hoechste = punkte.map(\.grad).max() ?? 37
            DiagrammKarte(aussage: "Temperatur", kernzeile: "Nach dem Eisprung steigt sie meist um etwa 0,3 Grad.") {
                Chart(punkte, id: \.zyklusTag) { p in
                    LineMark(x: .value("Zyklustag", p.zyklusTag), y: .value("Grad", p.grad)).interpolationMethod(.monotone)
                    PointMark(x: .value("Zyklustag", p.zyklusTag), y: .value("Grad", p.grad)).symbolSize(28)
                }
                .foregroundStyle(ZyklusPhaseStil.farbe(.eisprung, dunkel: schema == .dark))
                .chartYScale(domain: (tiefste - 0.2)...(hoechste + 0.2))
                .frame(height: 140)
                .accessibilityChartDescriptor(ZyklusDiagrammBeschreibung(
                    titel: "Temperatur", zusammenfassung: "\(punkte.count) Messungen im Zyklus", xTitel: "Zyklustag", yTitel: "Temperatur", einheit: "Grad",
                    punkte: punkte.map { (name: "Tag \($0.zyklusTag)", wert: $0.grad) }))
            }
        }
    }

    private var wissenKarte: some View {
        let karte = ZyklusWissen.karte(fuer: wissensPhase)
        return ZyklusKarte(titel: "Gut zu wissen", symbol: "lightbulb.fill") {
            ZyklusFluss {
                ForEach(ZyklusPhase.allCases, id: \.self) { p in
                    Button { withAnimation(Feder.schnell) { wissensPhase = p } } label: {
                        ZyklusWahlChip(titel: ZyklusPhaseStil.name(p), symbol: ZyklusPhaseStil.symbol(p), gewaehlt: p == wissensPhase)
                    }
                    .buttonStyle(.federnd)
                }
            }
            .haptik(.auswahl, bei: wissensPhase)
            Text(karte.kurz).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            zeile("fork.knife", "Essen", karte.ernaehrung)
            zeile("figure.walk", "Bewegung", karte.sport)
            zeile("moon.zzz.fill", "Schlaf", karte.schlaf)
            zeile("heart.fill", "Stimmung", karte.stimmung)
        }
    }

    private func zeile(_ symbol: String, _ titel: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Abstand.m) {
            Image(systemName: symbol).foregroundStyle(palette.text).frame(width: 22).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.subheadline.weight(.bold)).foregroundStyle(palette.text)
                ZyklusLeise(text)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
