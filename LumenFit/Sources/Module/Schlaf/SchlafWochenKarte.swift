import SwiftUI

/// Säulen für Nächte: eine Säule je Tag, Ziellinie gestrichelt. Nächte unter 6 Stunden sind gestreift (nie nur Farbe), fehlende Nächte bleiben leer.
/// Die Säulen wachsen einmal beim Anzeigen (0,38 s), Reduce Motion: sofort da.
struct SchlafSaeulen: View {
    let tage: [WochenVergleich.Tag]
    let zielMinuten: Int
    /// Mit Beschriftung je Säule (Woche) oder ohne (langer Verlauf: nur erster und letzter Tag).
    let beschriftet: Bool
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @Environment(\.bewegungAus) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var schriftGroesse
    @State private var gewachsen = false

    private static let hoehe: CGFloat = 110

    private var hoechster: Double { Double(max(zielMinuten, tage.compactMap(\.minuten).max() ?? 0, 60)) }

    var body: some View {
        let linie = LumenFarben.tief(.erholen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        VStack(spacing: Abstand.xs) {
            GeometryReader { geo in
                let breite = geo.size.width
                let abstand: CGFloat = beschriftet ? Abstand.s : 2
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: abstand) {
                        ForEach(tage) { tag in
                            saeule(tag, linie: linie)
                        }
                    }
                    .frame(width: breite, height: Self.hoehe, alignment: .bottom)
                    if zielMinuten > 0 {
                        Path { pfad in
                            let y = Self.hoehe * (1 - CGFloat(Double(zielMinuten) / hoechster))
                            pfad.move(to: CGPoint(x: 0, y: y))
                            pfad.addLine(to: CGPoint(x: breite, y: y))
                        }
                        .stroke(palette.text2, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
            }
            .frame(height: Self.hoehe)
            if beschriftet {
                HStack(spacing: Abstand.s) {
                    ForEach(tage) { tag in
                        VStack(spacing: 2) {
                            Text(SchlafFormat.wochentagKurz(tag.tag)).font(.caption.weight(.semibold))
                            if !schriftGroesse.isAccessibilitySize {
                                Text(tag.minuten.map { SchlafFormat.stundenMinuten($0) } ?? "–")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(palette.text2)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if let erster = tage.first, let letzter = tage.last {
                HStack {
                    Text(Datum.anzeige(erster.tag)).lineLimit(1)
                    Spacer(minLength: Abstand.s)
                    Text(Datum.anzeige(letzter.tag)).lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(palette.text2)
            }
        }
        .onAppear {
            if reduceMotion { gewachsen = true } else { withAnimation(Feder.weich) { gewachsen = true } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechText)
        .accessibilityChartDescriptor(SchlafDiagrammBeschreibung(
            titel: "Schlaf je Nacht", zusammenfassung: sprechText, achseX: "Tag", reihe: "Schlafdauer",
            punkte: tage.compactMap { t in t.minuten.map { SchlafDiagrammBeschreibung.Punkt(name: Datum.anzeige(t.tag), minuten: Double($0)) } }))
    }

    private var sprechText: String {
        let mit = tage.compactMap { t in t.minuten.map { "\(Datum.anzeige(t.tag)) \(SchlafFormat.sprechDauer($0))" } }
        return mit.isEmpty ? "Keine Nächte" : mit.joined(separator: ", ")
    }

    @ViewBuilder
    private func saeule(_ tag: WochenVergleich.Tag, linie: Color) -> some View {
        if let minuten = tag.minuten {
            let anteil = CGFloat(Double(minuten) / hoechster)
            let kurz = minuten < WochenVergleich.kurzeNachtMinuten
            Canvas { kontext, groesse in
                let rect = CGRect(origin: .zero, size: groesse)
                kontext.fill(Path(roundedRect: rect, cornerSize: CGSize(width: 4, height: 4)), with: .color(kurz ? linie.opacity(0.3) : linie))
                if kurz {
                    kontext.drawLayer { ebene in
                        ebene.clip(to: Path(roundedRect: rect, cornerSize: CGSize(width: 4, height: 4)))
                        ebene.stroke(MusterZeichner.streifen(groesse, winkel: 45, abstand: 5), with: .color(linie), lineWidth: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.hoehe * (gewachsen ? anteil : 0), alignment: .bottom)
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: 1)
        }
    }
}

/// Ideen 56 und 59, Wochenübersicht und Wochen im Vergleich: sieben Säulen, Schnitt, Nächte unter 6 Stunden, diese gegen letzte Woche,
/// Wochenende gegen Werktag.
struct SchlafWochenKarte: View {
    let woche: WochenVergleich
    let zielMinuten: Int
    @Environment(\.palette) private var palette

    private var aussage: String {
        guard let schnitt = woche.diese.schnittMinuten else { return "Diese Woche: noch keine Nacht" }
        return "Im Schnitt \(SchlafFormat.dauer(schnitt)) pro Nacht"
    }

    private var kernzeile: String {
        let n = woche.diese.unterSechsStunden
        switch n {
        case 0: return "Keine Nacht unter 6 Stunden"
        case 1: return "1 Nacht unter 6 Stunden"
        default: return "\(n) Nächte unter 6 Stunden"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            DiagrammKarte(aussage: aussage, kernzeile: kernzeile) {
                SchlafSaeulen(tage: woche.tage, zielMinuten: zielMinuten, beschriftet: true)
                    .padding(.top, Abstand.s)
            }
            if woche.vergleichSatz != nil || woche.wochenendeSatz != nil {
                ListenKarte {
                    if let satz = woche.vergleichSatz {
                        zeile(symbol: vergleichSymbol, text: satz)
                    }
                    if woche.vergleichSatz != nil, woche.wochenendeSatz != nil { Haarlinie() }
                    if let satz = woche.wochenendeSatz {
                        zeile(symbol: "calendar", text: satz)
                    }
                }
            }
        }
    }

    private var vergleichSymbol: String {
        guard let unterschied = woche.unterschiedMinuten, abs(unterschied) >= 5 else { return "arrow.right" }
        return unterschied > 0 ? "arrow.up" : "arrow.down"
    }

    private func zeile(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Abstand.m) {
            Image(systemName: symbol).foregroundStyle(palette.text2).frame(width: 24).accessibilityHidden(true)
            Text(text).font(.subheadline).foregroundStyle(palette.text)
            Spacer(minLength: 0)
        }
        .padding(Abstand.l)
        .accessibilityElement(children: .combine)
    }
}
