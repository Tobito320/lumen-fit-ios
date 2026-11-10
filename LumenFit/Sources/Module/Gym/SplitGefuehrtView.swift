// Quelle: Lovea Health/GymNeu/SplitAnsichten.swift (SplitGefuehrtView)
import SwiftUI

/// Drei Fragen (Tage, Ziel, Ausstattung), dann ein Vorschlag aus der Bibliothek mit Fortschrittsbalken.
struct SplitGefuehrtView: View {
    let sitzung: GymSitzung
    var fertig: () -> Void = {}
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig
    @State private var schritt = 0
    @State private var tage = 4
    @State private var ziel = "muskeln"
    @State private var geraet = "studio"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                fortschritt
                inhalt
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle(schritt < 3 ? "Geführt erstellen" : "Dein Vorschlag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if schritt > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zurück") { withAnimation(ruhig ? nil : Feder.schnell) { schritt -= 1 } }
                }
            }
        }
        .haptik(.auswahl, bei: schritt)
    }

    private var fortschritt: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(i <= schritt ? palette.akzent : palette.haar).frame(height: 3)
            }
        }
        .padding(.top, Abstand.s)
        .padding(.bottom, Abstand.l)
        .accessibilityElement()
        .accessibilityLabel("Schritt \(schritt + 1) von 4")
    }

    @ViewBuilder
    private var inhalt: some View {
        switch schritt {
        case 0:
            frage(String(localized: "Wie oft pro Woche?"), SplitLogik.tageWahl.map { String(localized: "\($0) Tage") }, gewaehlt: SplitLogik.tageWahl.firstIndex(of: tage)) { tage = SplitLogik.tageWahl[$0] }
        case 1:
            frage(String(localized: "Was ist dein Ziel?"), SplitLogik.ziele.map { $0.text }, gewaehlt: SplitLogik.ziele.firstIndex { $0.id == ziel }) { ziel = SplitLogik.ziele[$0].id }
        case 2:
            frage(String(localized: "Was steht dir zur Verfügung?"), SplitLogik.geraete.map { $0.text }, gewaehlt: SplitLogik.geraete.firstIndex { $0.id == geraet }) { geraet = SplitLogik.geraete[$0].id }
        default:
            vorschlag
        }
    }

    private func frage(_ titel: String, _ texte: [String], gewaehlt: Int?, _ setzen: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titel).font(.title2.bold()).foregroundStyle(palette.text).padding(.bottom, Abstand.s)
            ForEach(Array(texte.enumerated()), id: \.offset) { i, text in
                if i > 0 { Haarlinie() }
                Button {
                    setzen(i)
                    withAnimation(ruhig ? nil : Feder.schnell) { schritt += 1 }
                } label: {
                    HStack {
                        Text(text).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                        Spacer()
                        Image(systemName: i == gewaehlt ? "checkmark.circle.fill" : "circle").font(.title3)
                            .foregroundStyle(i == gewaehlt ? palette.akzent : palette.text2)
                    }
                    .frame(minHeight: 52)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(i == gewaehlt ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var vorschlag: some View {
        let geschlecht = umgebung.daten?.ziele.koerper.geschlecht
        if let v = SplitLogik.vorschlag(geschlecht, tage: tage, ziel: ziel, geraet: geraet) {
            Text("Passt zu deinen Antworten").font(.footnote).foregroundStyle(palette.text2)
            Text(v.name).font(.largeTitle.bold()).foregroundStyle(palette.text).padding(.bottom, Abstand.xs)
            Text(SplitLogik.unterzeile(v)).font(.subheadline).foregroundStyle(palette.text2)
            NavigationLink {
                SplitDetailView(sitzung: sitzung, vorlage: v, fertig: fertig)
            } label: {
                Text("Ansehen und übernehmen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.lumenHauptknopf)
            .padding(.top, Abstand.l)
        } else {
            Text("Dafür gibt es noch keinen fertigen Split. Leg ihn selbst an.").font(.subheadline).foregroundStyle(palette.text2)
        }
    }
}
