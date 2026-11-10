import SwiftUI

/// Die Ringplatte oben im Heute-Tab (neues Design 10.11.2026): links Lumi in drei offenen Bögen (Schritte, Gym-Tage der Woche, Schlaf; nur die gewählten Bereiche),
/// rechts je Bogen Symbol, Zahl und "von Ziel", darunter "Lumi" und ein Satz. Dunkel liegt sie ohne Fläche auf Schwarz, hell als Karte.
/// Ein Tipp auf die Schritte öffnet die Schritte-Seite (statt einer eigenen Schritte-Karte). Die Bögen füllen sich beim ersten Öffnen;
/// Reduce Motion und Stromsparmodus zeigen sie sofort gefüllt. Ab den großen Schriftstufen ersetzt `LumenBalken` die Bögen (auf der schwarzen Platte).
struct Ringplatte: View {
    let stand: HeuteStand
    let stufe: Int
    /// Öffnet die Schritte-Seite; nil = Schritte nicht antippbar (vergangener Tag).
    var schritte: (() -> Void)?
    @State private var gefuellt = false
    @Environment(\.bewegungAus) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var schriftGroesse
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    private static let strich: CGFloat = 11
    private static let abstand: CGFloat = 4

    var body: some View {
        Group {
            if BewegungsRegel.nutztBalken(schriftGroesse) {
                HeroKarte(platte: true) {
                    VStack(alignment: .leading, spacing: Abstand.m) {
                        LumiView(stimmung: stand.stimmung, groesse: 48, stufe: stufe)
                        LumenBalken(werte: angezeigt)
                        if let schritte { Button("Schritte ansehen", action: schritte).buttonStyle(.bordered).tint(.white) }
                        satz(farbig: false)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    HStack(spacing: Abstand.l) {
                        boegen
                        VStack(alignment: .leading, spacing: Abstand.m) {
                            ForEach(stand.boegen) { wert in wertZeile(wert) }
                        }
                        Spacer(minLength: 0)
                    }
                    satz(farbig: true)
                }
                .padding(Abstand.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(schema == .dark ? LumenFarben.ringPlatte : palette.flaeche)
                .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
            }
        }
        .onAppear {
            guard !gefuellt else { return }
            if reduceMotion { gefuellt = true } else { withAnimation(.smooth(duration: 0.9)) { gefuellt = true } }
        }
        // Enthält den Schritte-Knopf, darum kein `.ignore`: VoiceOver liest die Zeilen einzeln.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dein Tag. \(stand.stimmung.beschreibung)")
    }

    private var boegen: some View {
        ZStack {
            ForEach(Array(angezeigt.enumerated()), id: \.element.id) { index, wert in
                HeuteRingBogen(anteil: wert.anteil, farbe: LumenFarben.ring(wert.id, dunkel: schema == .dark), strich: Self.strich)
                    .padding(CGFloat(index) * (Self.strich + Self.abstand) + Self.strich / 2)
            }
            LumiView(stimmung: stand.stimmung, groesse: 50, stufe: stufe)
        }
        .frame(width: 148, height: 148)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func wertZeile(_ wert: BogenWert) -> some View {
        let inhalt = HStack(spacing: Abstand.s) {
            Image(systemName: wert.id.symbolName)
                .foregroundStyle(schema == .dark ? LumenFarben.ring(wert.id, dunkel: true) : LumenFarben.tief(wert.id, dunkel: false, kontrastHoch: kontrast == .increased))
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(wert.zahl).font(.headline.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text)
                Text(wert.beschriftung).font(.caption).foregroundStyle(palette.text2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        if wert.id == .bewegen, let schritte {
            Button(action: schritte) { inhalt.contentShape(.rect) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Öffnet die Schritte")
        } else {
            inhalt.accessibilityElement(children: .combine)
        }
    }

    /// "Lumi" klein und darunter der Satz groß. `farbig` false auf der schwarzen Platte (Schrift weiß von `HeroKarte`).
    private func satz(farbig: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Lumi").font(.footnote.weight(.semibold)).foregroundStyle(farbig ? palette.text2 : Color.white.opacity(0.8))
            Text(stand.lumiSatz.isEmpty ? stand.morgensatz : stand.lumiSatz)
                .font(.title3.weight(.bold))
                .foregroundStyle(farbig ? palette.text : Color.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// Vor dem Öffnen leer, danach auf dem echten Anteil: die Animation füllt die Bögen.
    private var angezeigt: [BogenWert] {
        stand.boegen.map { BogenWert(id: $0.id, anteil: gefuellt ? $0.anteil : 0, zahl: $0.zahl, beschriftung: $0.beschriftung) }
    }
}

/// Spur (voller Bogen, blass) und Wert (Anteil, runde Enden). 270 Grad, Öffnung unten.
private struct HeuteRingBogen: View {
    let anteil: Double
    let farbe: Color
    let strich: CGFloat

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(farbe.opacity(0.22), style: StrokeStyle(lineWidth: strich, lineCap: .round))
            Circle().trim(from: 0, to: 0.75 * min(max(anteil, 0), 1)).stroke(farbe, style: StrokeStyle(lineWidth: strich, lineCap: .round))
        }
        .rotationEffect(.degrees(135))
    }
}
