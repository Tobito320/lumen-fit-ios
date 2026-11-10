import Charts
import SwiftUI

/// "Gewichte": je Plan-Übung der schwerste Satz der letzten 8 Wochen als Linie, der aktuelle Wert und die Änderung seit 4 Wochen.
/// Ein Tipp öffnet die Übung (Kurve, Rekorde, letzte Einheiten). Sechs Zeilen sind sichtbar, der Rest hinter "Alle … Übungen".
struct GewichteListe: View {
    let zeilen: [GewichtZeile]
    @State private var alle = false
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    static let vorschau = 6
    private var sichtbar: [GewichtZeile] { alle ? zeilen : Array(zeilen.prefix(Self.vorschau)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            FortschrittAbschnitt(titel: "Gewichte", detail: "Schwerster Satz, 8 Wochen")
            if zeilen.isEmpty {
                LeerZustand(stimmung: .bereit, satz: "Noch kein Gewicht in den letzten 8 Wochen. Hake Sätze mit Gewicht ab, dann zeichnet Lumi die Linien.", handlung: "Training starten") {
                    umgebung.router.oeffne(.gym(.training))
                }
                .lumenKartenFlaeche()
            } else {
                ListenKarte {
                    ForEach(Array(sichtbar.enumerated()), id: \.element.id) { i, z in
                        if i > 0 { Haarlinie() }
                        Zeile(zeile: z)
                    }
                    if zeilen.count > Self.vorschau {
                        Haarlinie()
                        Button { alle.toggle() } label: {
                            Text(alle ? "Weniger anzeigen" : "Alle \(zeilen.count) Übungen aus dem Plan")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(palette.akzent)
                                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Änderung seit 4 Wochen. Tippen für Kurve, Rekorde und letzte Einheiten.").font(.footnote).foregroundStyle(palette.text2)
            }
        }
    }

    private struct Zeile: View {
        let zeile: GewichtZeile
        @Environment(\.palette) private var palette
        @Environment(\.colorScheme) private var schema
        @Environment(\.colorSchemeContrast) private var kontrast

        var body: some View {
            NavigationLink(value: Route.uebung(id: zeile.uebungId)) {
                HStack(spacing: Abstand.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(zeile.name).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text).multilineTextAlignment(.leading)
                        if !zeile.muskel.isEmpty { Text(zeile.muskel).font(.footnote).foregroundStyle(palette.text2) }
                    }
                    Spacer(minLength: Abstand.s)
                    linie
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(FortschrittLogik.zahl(zeile.aktuell)) kg").font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(palette.text)
                        Text(FortschrittLogik.aenderungText(zeile.aenderung4Wochen)).font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(aenderungFarbe)
                    }
                    .frame(minWidth: 64, alignment: .trailing)
                }
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.s)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(zeile.sprechtext)
            .accessibilityHint("Öffnet die Übung")
        }

        private struct Punkt: Identifiable {
            let woche: Int
            let kg: Double
            var id: Int { woche }
        }

        private var aenderungFarbe: Color {
            zeile.aenderung4Wochen > 0 ? LumenFarben.tief(.trainieren, dunkel: schema == .dark, kontrastHoch: kontrast == .increased) : palette.text2
        }

        /// Kleine Linie ohne Achsen, nur die Wochen mit Wert; der letzte Punkt ist gefüllt.
        private var linie: some View {
            let punkte = zeile.wochen.enumerated().compactMap { i, w in w.map { Punkt(woche: i, kg: $0) } }
            let niedrig = punkte.map(\.kg).min() ?? 0
            let hoch = max(punkte.map(\.kg).max() ?? 1, niedrig + 1)
            return Chart {
                ForEach(punkte) { p in
                    LineMark(x: .value("Woche", p.woche), y: .value("Gewicht", p.kg))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(palette.akzent)
                }
                if let letzter = punkte.last {
                    PointMark(x: .value("Woche", letzter.woche), y: .value("Gewicht", letzter.kg))
                        .symbolSize(30)
                        .foregroundStyle(palette.akzent)
                }
            }
            .chartXScale(domain: 0...(FortschrittLogik.wochenAnzahl - 1))
            .chartYScale(domain: (niedrig - (hoch - niedrig) * 0.15)...(hoch + (hoch - niedrig) * 0.15))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(width: 64, height: 28)
            .accessibilityHidden(true)
        }
    }
}
