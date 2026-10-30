// Quelle: Lovea Health/Koerper/KoerperView.swift (Feld, zielKarte, felder)
import SwiftUI

/// Die Regeln der Felder, ohne Oberfläche: wie voll ein Pegel ist und wie stark er sich färbt.
enum SaetzeFelderLogik {
    /// Anteil der Sätze am Wochenziel, 0 bis 1; ohne Ziel (oder Ziel 0) 0.
    nonisolated static func anteil(saetze: Double, ziel: Int?) -> Double {
        guard let ziel, ziel > 0 else { return 0 }
        return min(1, max(0, saetze / Double(ziel)))
    }

    /// Wie dicht der Pegel gefüllt ist: je müder der Muskel, desto dichter. Ohne Training (`nil`) gar nicht. Das Wort im Feld trägt die Stufe, nicht die Dichte.
    nonisolated static func dichte(_ stufe: ErholungsStufe?) -> Double {
        switch stufe {
        case .erholt?: 0.10
        case .fast?: 0.18
        case .muede?: 0.28
        case nil: 0
        }
    }

    /// Die Verzögerung der Füllung im Feld `index`: die Felder füllen sich nacheinander.
    nonisolated static func verzoegerung(_ index: Int) -> Double { Double(index) * 0.035 }
}

/// Karte im Stil der großen Handlung: "Ziele festlegen", solange die Befragung fehlt. Ein heller Knopf auf der Akzentfläche.
struct ZielFestlegenKarte: View {
    let beiStart: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                Label("Wochenziele", systemImage: "target").font(.footnote.weight(.semibold))
                Text("Ziele festlegen").font(.title2.weight(.bold)).fontDesign(.rounded)
                Text("Drei Fragen. Danach füllen sich die Felder bis zu deinen eigenen Zielen.").font(.subheadline)
                Button(action: beiStart) {
                    Text("Befragung starten").font(.headline).foregroundStyle(palette.akzent).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.aufAkzent)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Die neun Felder "Sätze diese Woche" (3 x 3, Prio zuerst): jedes füllt sich bis zum Wochenziel, versetzt von Feld zu Feld. Ein Tipp öffnet das Blatt der Gruppe.
struct SaetzeFelderKarte: View {
    let daten: KoerperDaten
    let beiGruppe: (MuskelGruppe) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        let reihe = daten.ziele.reihenfolge
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Sätze diese Woche").font(.title3.weight(.semibold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Grid(horizontalSpacing: Abstand.s, verticalSpacing: Abstand.s) {
                ForEach(0..<3, id: \.self) { zeile in
                    GridRow {
                        ForEach(0..<3, id: \.self) { spalte in
                            let i = zeile * 3 + spalte
                            if i < reihe.count {
                                SaetzeFeld(daten: daten, gruppe: reihe[i], nummer: daten.ziele.prio.firstIndex(of: reihe[i]).map { $0 + 1 }, index: i) {
                                    beiGruppe(reihe[i])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Eins der neun Felder: füllt sich von unten bis zum Wochenziel (federnd, Reduce Motion: sofort).
private struct SaetzeFeld: View {
    let daten: KoerperDaten
    let gruppe: MuskelGruppe
    let nummer: Int?
    let index: Int
    let aktion: () -> Void
    @State private var geladen = false
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion

    private var ziel: Int? { daten.ziele.saetze[gruppe] }
    private var anteil: Double { SaetzeFelderLogik.anteil(saetze: daten.saetze(gruppe), ziel: ziel) }
    private var stufe: ErholungsStufe? { daten.stand(gruppe, teil: nil) == nil ? nil : daten.stufe(gruppe) }
    private var label: String {
        let von = ziel.map { " von \($0)" } ?? ""
        return "\(gruppe.name), \(KoerperLogik.komma(daten.saetze(gruppe)))\(von) Sätze, \(daten.wort(gruppe))"
    }

    var body: some View {
        Button(action: aktion) { inhalt }
            .buttonStyle(.federnd)
            .accessibilityLabel(label)
            .accessibilityHint("Öffnet die Details")
            .onAppear { geladen = true }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(gruppe.name).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                if let nummer { Text("\(nummer)").font(.caption2.weight(.semibold)).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                RollZahl(wert: daten.saetze(gruppe), format: .number.precision(.fractionLength(0...1))).font(.title3.weight(.bold)).fontDesign(.rounded)
                Text(ziel.map { "/\($0)" } ?? " Sätze").font(.caption).foregroundStyle(palette.text2)
                Spacer(minLength: 2)
                Text(daten.wort(gruppe)).font(.caption2).foregroundStyle(palette.text2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, Abstand.m)
        .padding(.vertical, Abstand.s)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .background(alignment: .bottom) { pegel }
        .background(palette.flaeche)
        .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
        .contentShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
    }

    private var pegel: some View {
        let dichte = SaetzeFelderLogik.dichte(stufe)
        return GeometryReader { g in
            Rectangle()
                .fill(palette.text.opacity(max(dichte, anteil > 0 ? 0.08 : 0)))
                .overlay(alignment: .top) { if anteil > 0 { Rectangle().fill(palette.text.opacity(0.55)).frame(height: 1.5) } }
                .frame(height: g.size.height * (geladen ? anteil : 0))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(reduceMotion ? nil : Feder.weich.delay(SaetzeFelderLogik.verzoegerung(index)), value: geladen)
        }
        .accessibilityHidden(true)
    }
}
