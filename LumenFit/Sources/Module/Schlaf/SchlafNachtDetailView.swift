import SwiftUI

/// Eine Nacht im Detail: Zeitleiste der Phasen (oder der einfache Zeitbalken), die Zeiten, die gewählte Quelle mit Grund und, wenn Band und
/// Health die Nacht beide kennen, der Vergleich.
struct SchlafNachtDetailView: View {
    let nacht: SchlafGewaehlteNacht
    let vergleich: SchlafVergleichNacht?
    let verlauf: [SchlafVergleichNacht]
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: Abstand.l) {
                diagramm
                zeiten
                quelle
                if let vergleich {
                    SchlafVergleichKarte(nacht: vergleich, verlauf: verlauf)
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
        }
        .navigationTitle(Datum.anzeige(nacht.nacht.tag))
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }

    @ViewBuilder
    private var diagramm: some View {
        if nacht.hatPhasen {
            DiagrammKarte(aussage: "Die Nacht in Phasen", kernzeile: "\(SchlafFormat.dauer(nacht.nacht.schlafMinuten)) geschlafen") {
                SchlafNachtDiagramm(nacht: nacht.nacht)
                PhasenBalken(nacht: nacht.nacht).padding(.top, Abstand.s)
            }
        } else {
            DiagrammKarte(aussage: "Die Nacht als Zeitbalken", kernzeile: "\(SchlafFormat.dauer(nacht.nacht.schlafMinuten)) geschlafen") {
                PhasenBalken(nacht: nacht.nacht)
            }
        }
    }

    private var zeiten: some View {
        ListenKarte {
            zeile("Eingeschlafen", Datum.uhrzeit(nacht.nacht.von))
            Haarlinie()
            zeile("Aufgewacht", Datum.uhrzeit(nacht.nacht.bis))
            Haarlinie()
            zeile("Geschlafen", SchlafFormat.dauer(nacht.nacht.schlafMinuten))
            if nacht.nacht.minuten(.wach) > 0 {
                Haarlinie()
                zeile("Wach im Bett", SchlafFormat.dauer(nacht.nacht.minuten(.wach)))
            }
        }
    }

    private var quelle: some View {
        ListenKarte {
            HStack(alignment: .top, spacing: Abstand.m) {
                Image(systemName: nacht.quelle.symbolName).frame(width: 28).foregroundStyle(palette.text2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text("Beste Quelle: \(nacht.quelle.name)").font(.headline).foregroundStyle(palette.text)
                    Text(nacht.erklaerung).font(.subheadline).foregroundStyle(palette.text2)
                }
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .accessibilityElement(children: .combine)
        }
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack {
            Text(titel).font(.body).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            Text(wert).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
        }
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
    }
}
