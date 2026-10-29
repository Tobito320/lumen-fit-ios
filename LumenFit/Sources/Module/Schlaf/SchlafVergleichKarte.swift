// Quelle: Lovea Health/SchlafVergleichKarte.swift
import SwiftUI

/// Detail einer Nacht: das Band gegen Health. Je Zeile die beiden Werte und der Unterschied, darunter, welcher Wert nach dem Abgleich gilt
/// (`SchlafVergleich.abgleich`). Der Abgleich ist nur ein Vergleich: die Zahl im Tab und die Auswertung ändert er nicht.
struct SchlafVergleichKarte: View {
    let nacht: SchlafVergleichNacht
    let verlauf: [SchlafVergleichNacht]
    @Environment(\.palette) private var palette

    var body: some View {
        let abweichung = SchlafVergleich.abweichung(nacht)
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Label("Band und Health im Vergleich", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                zeile("Einschlafen", band: nacht.band.map { Datum.uhrzeit($0.von) }, health: nacht.health.map { Datum.uhrzeit($0.von) },
                      unterschied: abweichung.map { SchlafVergleich.abstand($0.einschlafen, mehr: "später", weniger: "früher") })
                zeile("Aufwachen", band: nacht.band.map { Datum.uhrzeit($0.bis) }, health: nacht.health.map { Datum.uhrzeit($0.bis) },
                      unterschied: abweichung.map { SchlafVergleich.abstand($0.aufwachen, mehr: "später", weniger: "früher") })
                zeile("Schlafdauer", band: nacht.band.map { SchlafFormat.dauer($0.minuten) }, health: nacht.health.map { SchlafFormat.dauer($0.minuten) },
                      unterschied: abweichung.map { SchlafVergleich.abstand($0.dauer, mehr: "länger", weniger: "kürzer") })
                if let urteil = SchlafVergleich.abgleich(nacht, verlauf: verlauf) {
                    abgleich(urteil)
                }
            }
            .padding(Abstand.l)
        }
    }

    private func zeile(_ titel: String, band: String?, health: String?, unterschied: String?) -> some View {
        let ansage = unterschied.map { ", Unterschied \($0)" } ?? ""
        let label = "\(titel): Band \(band ?? "keine Daten"), Health \(health ?? "keine Daten")\(ansage)"
        return HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.subheadline).foregroundStyle(palette.text)
                Text("Band \(band ?? "–") · Health \(health ?? "–")")
                    .font(.caption)
                    .foregroundStyle(palette.text2)
                    .monospacedDigit()
            }
            Spacer(minLength: Abstand.s)
            if let unterschied {
                Text(unterschied)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func abgleich(_ urteil: SchlafUrteil) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Haarlinie()
            if urteil.quelle == .gemischt {
                Text("Abgleich: \(SchlafFormat.dauer(urteil.wert.minuten)), \(Datum.uhrzeit(urteil.wert.von)) bis \(Datum.uhrzeit(urteil.wert.bis))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
            }
            Text(SchlafVergleich.satz(urteil)).font(.footnote).foregroundStyle(palette.text2)
            Text("Der Abgleich ist nur ein Vergleich: die Zahl oben und die Auswertung ändert er nicht.")
                .font(.footnote)
                .foregroundStyle(palette.text2)
        }
        .accessibilityElement(children: .combine)
    }
}
