import SwiftUI

/// Die eine mutige Karte des Heute-Tabs (Idee 11): schwarze Platte mit Streifen, drei Lumen-Bögen (Schritte, Gym der Woche, Schlaf), Lumi in der Mitte
/// und darunter Lumis Satz (Idee 13). Die Bögen füllen sich beim ersten Öffnen; Reduce Motion zeigt sie sofort gefüllt.
struct Ringplatte: View {
    let stand: HeuteStand
    let stufe: Int
    @State private var gefuellt = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HeroKarte(platte: true) {
            VStack(alignment: .leading, spacing: Abstand.m) {
                LumenBogen(werte: angezeigt, mitte: LumiView(stimmung: stand.stimmung, groesse: 60, stufe: stufe))
                Text(stand.morgensatz)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(stand.stimmung.beschreibung)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .onAppear {
            guard !gefuellt else { return }
            if reduceMotion { gefuellt = true } else { withAnimation(.smooth(duration: 0.9)) { gefuellt = true } }
        }
        // Die Bögen sind für VoiceOver ein Element: Zahlen als Wert, Lumis Satz und Stimmung als Beschriftung.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dein Tag. \(stand.stimmung.beschreibung). \(stand.morgensatz)")
        .accessibilityValue(stand.boegenSatz)
    }

    /// Vor dem Öffnen leer, danach auf dem echten Anteil: die Animation füllt die Bögen.
    private var angezeigt: [BogenWert] {
        stand.boegen.map { BogenWert(id: $0.id, anteil: gefuellt ? $0.anteil : 0, zahl: $0.zahl, beschriftung: $0.beschriftung) }
    }
}

/// Bereit-Score (Idee 12): die Zahl, drei kleine Bögen (Erholung, Belastung, Schlaf) und ein Satz. Ein Tipp öffnet die Formel im Klartext.
struct ScoreKarte: View {
    let score: BereitScore.Ergebnis
    let oeffne: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var schriftGroesse

    var body: some View {
        Button(action: oeffne) {
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    HeuteKartenKopf(symbol: "gauge.with.dots.needle.67percent", titel: "Bereit-Score", zusatz: "Wie sie rechnet")
                    if schriftGroesse.isAccessibilitySize {
                        // Ab den großen Schriftstufen untereinander, damit nichts abgeschnitten wird.
                        VStack(alignment: .leading, spacing: Abstand.m) {
                            zahl
                            teilBogenZeile(.erholung, Datenbereich.erholen, "Erholung")
                            teilBogenZeile(.belastung, Datenbereich.trainieren, "Belastung")
                            teilBogenZeile(.schlaf, Datenbereich.erholen, "Schlaf")
                        }
                    } else {
                        HStack(alignment: .center, spacing: Abstand.l) {
                            zahl
                            Spacer(minLength: 0)
                            teilBogen(.erholung, Datenbereich.erholen, "Erholung")
                            teilBogen(.belastung, Datenbereich.trainieren, "Belastung")
                            teilBogen(.schlaf, Datenbereich.erholen, "Schlaf")
                        }
                    }
                    Text(score.satz).font(.subheadline).foregroundStyle(palette.text2).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Abstand.l)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bereit-Score")
        .accessibilityValue(wert)
        .accessibilityHint("Zeigt, wie der Score gerechnet wird")
        .accessibilityAddTraits(.isButton)
    }

    private var wert: String {
        let teile = BereitScore.Art.allCases.map { art -> String in
            score.teil(art).map { "\(art.titel) \(Int($0.wert.rounded())) von 100" } ?? "\(art.titel) fehlt"
        }
        return (score.punkte.map { "\($0) von 100. " } ?? "Noch keine Zahl. ") + teile.joined(separator: ". ") + ". " + score.satz
    }

    @ViewBuilder
    private var zahl: some View {
        if let p = score.punkte {
            HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                RollZahl(wert: Double(p), format: HeuteFormat.ganz())
                    .heuteHeldenZahl(44)
                    .foregroundStyle(palette.text)
                Text("von 100").font(.footnote.weight(.medium)).foregroundStyle(palette.text2)
            }
        } else {
            Text("–").heuteHeldenZahl(44).foregroundStyle(palette.text2)
        }
    }

    private func teilBogenZeile(_ art: BereitScore.Art, _ bereich: Datenbereich, _ name: String) -> some View {
        HStack(spacing: Abstand.m) {
            HeuteMiniBogen(anteil: (score.teil(art)?.wert ?? 0) / 100, bereich: bereich).frame(width: 40, height: 40)
            Text(name).font(.subheadline).foregroundStyle(palette.text2)
        }
    }

    private func teilBogen(_ art: BereitScore.Art, _ bereich: Datenbereich, _ name: String) -> some View {
        let teil = score.teil(art)
        return VStack(spacing: Abstand.xs) {
            HeuteMiniBogen(anteil: (teil?.wert ?? 0) / 100, bereich: bereich).frame(width: 40, height: 40)
            Text(name).font(.caption.weight(.medium)).foregroundStyle(palette.text2)
        }
    }
}

/// Die Formel und ihre Gründe im Klartext (Blatt).
struct BereitScoreDetail: View {
    let score: BereitScore.Ergebnis
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    Text(score.punkte.map { "\($0) von 100" } ?? "Noch keine Zahl")
                        .heuteHeldenZahl(40).foregroundStyle(palette.text)
                    Text(score.satz).font(.body).foregroundStyle(palette.text)
                    ListenKarte {
                        ForEach(Array(score.teile.enumerated()), id: \.element.id) { index, teil in
                            if index > 0 { Haarlinie() }
                            VStack(alignment: .leading, spacing: Abstand.xs) {
                                HStack {
                                    Text(teil.art.titel).font(.headline)
                                    Spacer()
                                    Text("\(Int(teil.wert.rounded())) von 100").font(.subheadline.monospacedDigit()).foregroundStyle(palette.text2)
                                }
                                Text(teil.detail).font(.subheadline).foregroundStyle(palette.text2)
                            }
                            .padding(Abstand.l)
                            .accessibilityElement(children: .combine)
                        }
                        if !score.fehlend.isEmpty {
                            if !score.teile.isEmpty { Haarlinie() }
                            VStack(alignment: .leading, spacing: Abstand.xs) {
                                Text("Fehlt").font(.headline)
                                Text(score.fehlend.map(\.titel).joined(separator: ", ")).font(.subheadline).foregroundStyle(palette.text2)
                            }
                            .padding(Abstand.l)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        Text("So rechnet Lumen Fit").font(.headline)
                        Text(BereitScore.klartext).font(.subheadline).foregroundStyle(palette.text2)
                    }
                }
                .foregroundStyle(palette.text)
                .padding(Abstand.l)
            }
            .navigationTitle("Bereit-Score")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}
