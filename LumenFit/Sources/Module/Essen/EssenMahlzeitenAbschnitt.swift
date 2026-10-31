// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (TagebuchAnsicht.mahlzeiten, mahlzeitZeile)
import SwiftUI

/// Die Mahlzeit-Zeilen: Mini-Ring (Anteil am Richtwert der Mahlzeit), Name mit Pfeil, "kcal / Richtwert" als rollende Zahl, die Lebensmittel in einer Zeile,
/// rechts das Plus. Tipp auf die Zeile öffnet die Mahlzeit-Seite; lang drücken speichert die Mahlzeit als Gericht.
struct EssenMahlzeitenAbschnitt: View {
    let essen: EssenStore
    let tag: String
    let zielKcal: Int
    let bearbeitbar: Bool
    let oeffnen: @MainActor (Mahlzeit) -> Void
    let hinzufuegen: @MainActor (Mahlzeit) -> Void
    let alsGericht: @MainActor (Mahlzeit) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @Environment(\.bewegungAus) private var bewegungAus

    var body: some View {
        ListenKarte {
            ForEach(Mahlzeit.allCases) { m in
                zeile(m)
                if m != Mahlzeit.allCases.last { Haarlinie().padding(.leading, 76) }
            }
        }
    }

    private func zeile(_ m: Mahlzeit) -> some View {
        let eintraege = essen.eintraege(tag, m)
        let kcal = Int(ErnaehrungLogik.summe(eintraege).kcal.rounded())
        let richtwert = EssenTagebuchLogik.richtwert(m, zielKcal: zielKcal)
        let anteil = EssenTagebuchLogik.anteil(ist: Double(kcal), soll: Double(richtwert))
        let namen = eintraege.map(\.lebensmittel.anzeigeName).joined(separator: ", ")
        let name = essen.mahlzeitName(m)
        return HStack(spacing: Abstand.s) {
            Button { oeffnen(m) } label: {
                HStack(spacing: Abstand.m) {
                    ZStack {
                        Circle().stroke(palette.haar, lineWidth: 4)
                        Circle().trim(from: 0, to: anteil)
                            .stroke(aufbau.farbe(LoveaDaten.essen, sonst: palette.akzent), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(bewegungAus ? nil : Feder.weich, value: anteil)
                        Image(systemName: m.symbol).font(.body).foregroundStyle(palette.text2)
                    }
                    .frame(width: 46, height: 46)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Abstand.xs) {
                            Text(name).font(.headline.weight(.bold)).foregroundStyle(palette.text)
                            Image(systemName: "arrow.right").font(.footnote.weight(.bold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                        Text("\(kcal) / \(richtwert) kcal").font(.subheadline).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text)
                            .contentTransition(.numericText(value: Double(kcal)))
                            .animation(bewegungAus ? nil : Feder.weich, value: kcal)
                        if !namen.isEmpty {
                            Text(namen).font(.footnote).foregroundStyle(palette.text2).lineLimit(1)
                        }
                    }
                    Spacer(minLength: Abstand.xs)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Zeigt, was du gegessen hast")
            .contextMenu {
                if !eintraege.isEmpty { Button("Als Gericht speichern", systemImage: "star") { alsGericht(m) } }
            }
            if bearbeitbar {
                Button { hinzufuegen(m) } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(palette.aufAkzent)
                        .frame(width: 38, height: 38)
                        .background(palette.akzent, in: .circle)
                        .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Zu \(name) hinzufügen")
            }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
    }
}
