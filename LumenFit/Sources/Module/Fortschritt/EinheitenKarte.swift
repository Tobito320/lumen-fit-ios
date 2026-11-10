import Charts
import SwiftUI

/// "Einheiten": Balken der letzten 8 Kalenderwochen, umschaltbar zwischen Dauer, Volumen und Wiederholungen. Über dem Diagramm steht der Wert der laufenden Woche.
/// Die Pillen sind Knöpfe (44 pt hoch, gewählt mit Haken-Merkmal); das Diagramm hat einen Descriptor für VoiceOver.
struct EinheitenKarte: View {
    let sessions: [GymSession]
    let heute: String
    @State private var art = StatistikArt.dauer
    @Environment(\.palette) private var palette

    var body: some View {
        let werte = FortschrittLogik.wochen(sessions, heute: heute, art: art)
        let jetzt = werte.last?.wert ?? 0
        let text = Self.text(jetzt, art: art)
        VStack(alignment: .leading, spacing: Abstand.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Diese Woche").font(.footnote).foregroundStyle(palette.text2)
                Text(text).font(.largeTitle.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .combine)
            diagramm(werte, text: text)
            Text("Kalenderwoche").font(.footnote).foregroundStyle(palette.text2).frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            HStack(spacing: Abstand.s) {
                ForEach(StatistikArt.allCases, id: \.self) { pille($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .haptik(.auswahl, bei: art)
    }

    /// Dauer als "2:17 h" (Minuten), Volumen als "12,9 t" oder "9.690 kg", Wiederholungen als Zahl.
    static func text(_ wert: Double, art: StatistikArt) -> String {
        switch art {
        case .dauer: TrainingLogik.dauerText(wert * 60)
        case .volumen: FortschrittLogik.volumenText(wert)
        case .wiederholungen: "\(Int(wert.rounded())) Wdh"
        }
    }

    private func diagramm(_ werte: [WochenWert], text: String) -> some View {
        Chart(werte, id: \.montag) { w in
            BarMark(x: .value("Woche", String(FortschrittLogik.kalenderwoche(w.montag))), y: .value(art.titel, w.wert))
                .foregroundStyle(w.montag == werte.last?.montag ? palette.akzent : palette.akzent.opacity(0.65))
                .cornerRadius(4)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().foregroundStyle(palette.text2) }
        }
        .frame(height: 140)
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: "\(art.titel) je Woche", zusammenfassung: "Diese Woche \(text). Die letzten \(werte.count) Wochen.", xTitel: "Kalenderwoche", yTitel: art.titel,
            einheit: art == .dauer ? "Minuten" : art == .volumen ? "kg" : "Wiederholungen", stetig: false,
            punkte: werte.map { .init(x: "KW \(FortschrittLogik.kalenderwoche($0.montag))", y: $0.wert) }))
    }

    private func pille(_ a: StatistikArt) -> some View {
        let gewaehlt = a == art
        return Button { art = a } label: {
            Text(a.titel)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(gewaehlt ? palette.aufAkzent : palette.text)
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                .background(gewaehlt ? palette.akzent : palette.haar, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }
}
