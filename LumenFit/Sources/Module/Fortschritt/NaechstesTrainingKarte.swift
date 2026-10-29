import SwiftUI

/// Idee 34: "Heute Beine, 45 Minuten" mit Begründung. Die Zeit wählst du in vier Schritten, der Vorschlag rechnet neu. Die eine mutige Karte des Segments.
struct NaechstesTrainingKarte: View {
    let erholung: [MuskelTeil: Int]
    let plantag: TrainingsTag?
    let beiStart: () -> Void
    @State private var minuten = 45
    @Environment(\.palette) private var palette

    static let zeiten = [30, 45, 60, 90]

    var body: some View {
        let vorschlag = NaechstesTraining.vorschlag(erholung: erholung, plantag: plantag, minuten: minuten)
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                Label("Nächstes Training", systemImage: "figure.strengthtraining.traditional")
                    .font(.footnote.weight(.semibold))
                if let vorschlag {
                    Text(vorschlag.titel).font(.title2.weight(.bold)).fontDesign(.rounded)
                    Text(vorschlag.begruendung).font(.subheadline)
                    Text("Etwa \(vorschlag.saetze) Sätze passen in die Zeit.").font(.footnote)
                } else {
                    Text("Noch kein Vorschlag").font(.title2.weight(.bold)).fontDesign(.rounded)
                    Text("Nach deinem ersten Training sagt Lumi dir, welche Muskeln frisch sind.").font(.subheadline)
                }
                zeitWahl
                Button(action: beiStart) {
                    // Der Text trägt seine Farbe selbst: ein Stil überschreibt sonst die Farbe von außen.
                    Text("Training starten").font(.headline).foregroundStyle(palette.akzent).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.aufAkzent)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var zeitWahl: some View {
        HStack(spacing: Abstand.s) {
            ForEach(Self.zeiten, id: \.self) { zeit in
                Button {
                    minuten = zeit
                } label: {
                    Text("\(zeit) min")
                        .font(.footnote.weight(.semibold)).monospacedDigit()
                        .padding(.horizontal, Abstand.m)
                        .frame(minHeight: Abstand.tippflaeche)
                        .background(minuten == zeit ? palette.aufAkzent.opacity(0.28) : Color.clear, in: .capsule)
                        .overlay(Capsule().stroke(palette.aufAkzent, lineWidth: minuten == zeit ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(zeit) Minuten")
                .accessibilityAddTraits(minuten == zeit ? .isSelected : [])
            }
        }
    }
}
