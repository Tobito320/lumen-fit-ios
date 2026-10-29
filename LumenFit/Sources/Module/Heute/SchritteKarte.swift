import Charts
import SwiftUI

/// Schritte heute (Idee 18, Teil 1): die Zahl, der Fortschritt zum Ziel, Distanz und Etagen. Ein Tipp öffnet das Detail mit Tag, Woche und Monat.
struct SchritteKarte: View {
    let schritte: HeuteSchritte
    let oeffne: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: oeffne) {
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    HeuteKartenKopf(symbol: "figure.walk", titel: "Schritte", zusatz: "Ziel \(HeuteQuellen.zahl(schritte.ziel))")
                    RollZahl(wert: Double(schritte.schritte), format: HeuteFormat.ganz())
                        .font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(palette.text)
                    ProgressView(value: schritte.anteil).tint(palette.text)
                    Text(unterzeile).font(.footnote).foregroundStyle(palette.text2)
                }
                .padding(Abstand.l)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schritte")
        .accessibilityValue("\(HeuteQuellen.zahl(schritte.schritte)) von \(HeuteQuellen.zahl(schritte.ziel)). \(unterzeile)")
        .accessibilityHint("Zeigt Tag, Woche und Monat")
        .accessibilityAddTraits(.isButton)
    }

    private var unterzeile: String {
        let km = String(format: "%.1f", schritte.distanzKm).replacingOccurrences(of: ".", with: ",")
        return "\(km) km, \(schritte.etagen) Etagen"
    }
}

/// Schritte im Detail (Idee 18, Teil 2; Blatt): Tag, Woche, Monat zum Blättern, Summe, Schnitt, Distanz, Etagen, die besten Tage und die Zielmarke im Diagramm.
struct SchritteDetailView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var zeitraum: SchritteZeitraum = .woche
    @State private var anker: String?

    var body: some View {
        let heute = Datum.text(umgebung.uhr())
        let aktuell = anker ?? heute
        let ziel = umgebung.daten?.ziele.ziele.schritte ?? 10_000
        let stand = SchritteDetailLogik.stand(zeitraum: zeitraum, anker: aktuell, heute: heute, tage: umgebung.gesundheit.tage, ziel: ziel)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    Picker("Zeitraum", selection: $zeitraum) {
                        ForEach(SchritteZeitraum.allCases, id: \.self) { Text(name($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: zeitraum) { _, _ in anker = nil }
                    blaettern(aktuell: aktuell, heute: heute, titel: stand.titel)
                    summe(stand)
                    diagramm(stand)
                    kennzahlen(stand)
                    if !stand.beste.isEmpty { beste(stand) }
                }
                .foregroundStyle(palette.text)
                .padding(Abstand.l)
            }
            .navigationTitle("Schritte")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func name(_ z: SchritteZeitraum) -> String {
        switch z {
        case .tag: "Tag"
        case .woche: "Woche"
        case .monat: "Monat"
        }
    }

    private func blaettern(aktuell: String, heute: String, titel: String) -> some View {
        let zurueck = SchritteLogik.verschoben(aktuell, zeitraum, um: -1, heute: heute)
        let vor = SchritteLogik.verschoben(aktuell, zeitraum, um: 1, heute: heute)
        return HStack {
            Button { anker = zurueck } label: { Image(systemName: "chevron.left").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                .accessibilityLabel("Davor")
            Spacer()
            Text(titel).font(.headline)
            Spacer()
            Button { anker = vor } label: { Image(systemName: "chevron.right").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                .disabled(vor == nil)
                .accessibilityLabel("Danach")
        }
        .foregroundStyle(palette.text)
    }

    private func summe(_ s: SchritteDetailStand) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            if let summe = s.summe {
                RollZahl(wert: Double(summe), format: HeuteFormat.ganz())
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(s.zeitraum == .tag ? "Schritte" : "Schritte zusammen").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                Text("Keine Daten").font(.title2.weight(.bold)).foregroundStyle(palette.text2)
                Text("Für diesen Zeitraum hat Health keine Schritte.").font(.subheadline).foregroundStyle(palette.text2)
            }
        }
    }

    private func diagramm(_ s: SchritteDetailStand) -> some View {
        DiagrammKarte(aussage: s.zielTage > 0 ? "\(s.zielTage) \(s.zielTage == 1 ? "Tag" : "Tage") über dem Ziel" : "Noch kein Tag über dem Ziel",
                      kernzeile: s.schnitt.map { "Im Schnitt \(HeuteQuellen.zahl($0)) Schritte am Tag" } ?? "Keine Werte") {
            Chart {
                ForEach(s.punkte) { p in
                    BarMark(x: .value("Tag", Datum.datum(p.tag), unit: .day), y: .value("Schritte", p.schritte)).cornerRadius(3)
                }
                RuleMark(y: .value("Ziel", s.ziel))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(palette.text2)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Ziel \(HeuteQuellen.zahl(s.ziel))").font(.caption2).foregroundStyle(palette.text2)
                    }
            }
            .foregroundStyle(palette.text)
            .chartYScale(domain: 0...Double(max(s.hoechster, 1)) * 1.15)
            .environment(\.locale, Locale(identifier: "de_DE"))
            .frame(height: 180)
            .accessibilityChartDescriptor(HeuteDiagrammBeschreibung(
                titel: "Schritte \(s.titel)", zusammenfassung: s.schnitt.map { "Im Schnitt \(HeuteQuellen.zahl($0)) Schritte am Tag, Ziel \(HeuteQuellen.zahl(s.ziel))" } ?? "Keine Werte",
                xTitel: "Tag", yTitel: "Schritte", einheit: "Schritte",
                punkte: s.punkte.map { HeuteDiagrammPunkt(name: SchritteDetailLogik.kurz($0.tag), wert: Double($0.schritte)) }))
        }
    }

    private func kennzahlen(_ s: SchritteDetailStand) -> some View {
        let km = String(format: "%.1f", s.distanzKm).replacingOccurrences(of: ".", with: ",")
        return ListenKarte {
            kennzahl("Distanz", "\(km) km")
            Haarlinie()
            kennzahl("Etagen", "\(s.etagen)")
            Haarlinie()
            kennzahl("Tage mit Schritten", "\(s.tageMitDaten)")
        }
    }

    private func kennzahl(_ titel: String, _ wert: String) -> some View {
        HStack {
            Text(titel).font(.body)
            Spacer()
            Text(wert).font(.body.monospacedDigit()).foregroundStyle(palette.text2)
        }
        .padding(Abstand.l)
        .accessibilityElement(children: .combine)
    }

    private func beste(_ s: SchritteDetailStand) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Beste Tage").font(.headline)
            ListenKarte {
                ForEach(Array(s.beste.enumerated()), id: \.element.id) { index, p in
                    if index > 0 { Haarlinie() }
                    HStack {
                        Text(Datum.anzeige(p.tag)).font(.body)
                        Spacer()
                        Text(HeuteQuellen.zahl(p.schritte)).font(.body.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                    .padding(Abstand.l)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
