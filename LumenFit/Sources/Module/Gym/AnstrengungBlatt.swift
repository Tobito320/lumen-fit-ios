// Quelle: Lovea Health/WorkoutView.swift (AnstrengungBlatt: Farbpunkte, RIR-Erklärung)
import SwiftUI

/// "Wie anstrengend war der Satz?": sechs Stufen mit Farbpunkt, RIR und Klartext, plus "Ohne Angabe". Ein Tipp wählt und schließt.
struct AnstrengungBlatt: View {
    let aktuell: Double?
    let waehle: (Anstrengung?) -> Void
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var gewaehlt = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    Text("RIR heißt: wie viele Wiederholungen du noch geschafft hättest. RPE ist 10 minus RIR.")
                        .font(.subheadline).foregroundStyle(palette.text2)
                    ListenKarte {
                        ForEach(Array(Anstrengung.allCases.enumerated()), id: \.offset) { index, stufe in
                            if index > 0 { Haarlinie() }
                            Button { setze(stufe) } label: { zeile(stufe) }
                                .buttonStyle(.federnd)
                        }
                        Haarlinie()
                        Button { setze(nil) } label: {
                            Text("Ohne Angabe").font(.body).foregroundStyle(palette.text2)
                                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
                                .padding(.horizontal, Abstand.m)
                        }
                        .buttonStyle(.federnd)
                    }
                }
                .padding(Abstand.m)
            }
            .background(palette.grund)
            .navigationTitle("Anstrengung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
            .haptik(.auswahl, bei: gewaehlt)
        }
        .presentationDetents([.medium, .large])
    }

    private func zeile(_ stufe: Anstrengung) -> some View {
        let aktiv = aktuell.map { Anstrengung.stufe(rpe: $0) == stufe } ?? false
        return HStack(spacing: Abstand.s) {
            Circle().fill(AnstrengungFarbe.farbe(stufe)).frame(width: 14, height: 14).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(stufe.titel).font(.body).foregroundStyle(palette.text)
                Text("RIR \(stufe.rirText), RPE \(TrainingLogik.kgText(stufe.rpe))").font(.footnote).foregroundStyle(palette.text2)
            }
            Spacer(minLength: 0)
            if aktiv { Image(systemName: "checkmark").foregroundStyle(palette.akzent).accessibilityHidden(true) }
        }
        .padding(.horizontal, Abstand.m)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    private func setze(_ stufe: Anstrengung?) {
        gewaehlt += 1
        waehle(stufe)
        schliessen()
    }
}

/// Punktfarbe je Stufe: von Rot (Versagen) bis Grün (leicht). Die Farbe ergänzt den Text, sie ersetzt ihn nicht.
enum AnstrengungFarbe {
    static func farbe(_ stufe: Anstrengung) -> Color {
        switch stufe {
        case .versagen: .red
        case .fastVersagen: .orange
        case .eineNoch: .yellow
        case .zweiNoch: .mint
        case .dreiNoch: .green
        case .leicht: .teal
        }
    }
}
