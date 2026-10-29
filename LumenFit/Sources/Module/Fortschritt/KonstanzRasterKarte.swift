import SwiftUI

/// Idee 35: das Konstanz-Raster, 18 Wochen mal 7 Tage in vier Stufen. Jede Stufe hat ein Muster (leer, Punkt, Streifen, voll) und eine Zahl in der Legende,
/// auch ohne Farbe lesbar. Tipp auf ein Kästchen nennt den Tag darunter.
struct KonstanzRasterKarte: View {
    let gitter: KonstanzRaster.Gitter
    @State private var gewaehlt: KonstanzRaster.Zelle?
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    nonisolated private static let luecke: CGFloat = 3

    var body: some View {
        DiagrammKarte(aussage: KonstanzRaster.aussage(gitter), kernzeile: KonstanzRaster.kernzeile(gitter)) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                raster
                Text(gewaehlt?.sprechtext ?? "Tipp auf ein Kästchen, dann steht hier der Tag. Links die älteste Woche.")
                    .font(.caption).foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                legende
            }
        }
    }

    /// Kantenlänge eines Kästchens bei der Breite des Zeichenbereichs.
    nonisolated private static func zelle(breite: CGFloat) -> CGFloat {
        max(4, (breite - luecke * CGFloat(KonstanzRaster.wochen - 1)) / CGFloat(KonstanzRaster.wochen))
    }

    private var raster: some View {
        let farbe = LumenFarben.tief(.trainieren, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let leer = palette.haar, linie = palette.text2, streifen = palette.grund
        let spalten = gitter.spalten
        let gewaehlterTag = gewaehlt?.tag
        return GeometryReader { geo in
            let z = Self.zelle(breite: geo.size.width)
            Canvas { kontext, _ in
                for (w, woche) in spalten.enumerated() {
                    for (t, tag) in woche.enumerated() {
                        let rahmen = CGRect(x: CGFloat(w) * (z + Self.luecke), y: CGFloat(t) * (z + Self.luecke), width: z, height: z)
                        let pfad = Path(roundedRect: rahmen, cornerRadius: 2)
                        Self.zeichne(tag, pfad: pfad, rahmen: rahmen, farbe: farbe, leer: leer, streifen: streifen, in: &kontext)
                        if tag.tag == gewaehlterTag {
                            kontext.stroke(Path(roundedRect: rahmen.insetBy(dx: -1.5, dy: -1.5), cornerRadius: 3), with: .color(linie), lineWidth: 1.5)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { punkt in
                let schritt = z + Self.luecke
                let w = Int(punkt.x / schritt), t = Int(punkt.y / schritt)
                gewaehlt = spalten.indices.contains(w) && spalten[w].indices.contains(t) ? spalten[w][t] : nil
            }
        }
        .aspectRatio(CGFloat(KonstanzRaster.wochen) / 7, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Konstanz-Raster, \(KonstanzRaster.aussage(gitter))")
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: "Konstanz-Raster", zusammenfassung: "\(KonstanzRaster.aussage(gitter)). \(KonstanzRaster.kernzeile(gitter))", xTitel: "Tag",
            yTitel: "Stufe von 0 bis 3", einheit: "", stetig: false,
            punkte: gitter.zellen.filter { !$0.zukunft }.map { .init(x: Datum.anzeige($0.tag), y: Double($0.stufe.rawValue)) }))
    }

    /// Ein Kästchen im Muster seiner Stufe.
    nonisolated private static func zeichne(_ z: KonstanzRaster.Zelle, pfad: Path, rahmen: CGRect, farbe: Color, leer: Color, streifen: Color, in kontext: inout GraphicsContext) {
        if z.zukunft {
            kontext.stroke(pfad, with: .color(leer), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            return
        }
        switch z.stufe {
        case .kein:
            kontext.fill(pfad, with: .color(leer.opacity(0.6)))
        case .besuch:
            kontext.fill(pfad, with: .color(farbe.opacity(0.32)))
            kontext.fill(Path(ellipseIn: rahmen.insetBy(dx: rahmen.width * 0.35, dy: rahmen.height * 0.35)), with: .color(farbe))
        case .training:
            kontext.fill(pfad, with: .color(farbe.opacity(0.62)))
            var ausschnitt = kontext
            ausschnitt.clip(to: pfad)
            ausschnitt.stroke(MusterZeichner.streifen(rahmen.size, winkel: 135, abstand: 4).offsetBy(dx: rahmen.minX, dy: rahmen.minY), with: .color(streifen.opacity(0.7)), lineWidth: 1)
        case .stark:
            kontext.fill(pfad, with: .color(farbe))
        }
    }

    /// Die vier Stufen mit Zahl und Wort: "0 kein, 1 Besuch, 2 Training, 3 stark".
    private var legende: some View {
        HStack(spacing: Abstand.m) {
            ForEach(KonstanzRaster.Stufe.allCases, id: \.self) { stufe in
                HStack(spacing: Abstand.xs) {
                    probe(stufe).frame(width: 14, height: 14)
                    Text("\(stufe.rawValue) \(kurz(stufe))").font(.caption2).foregroundStyle(palette.text2).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func kurz(_ s: KonstanzRaster.Stufe) -> String {
        switch s {
        case .kein: "kein"
        case .besuch: "Besuch"
        case .training: "Training"
        case .stark: "stark"
        }
    }

    private func probe(_ stufe: KonstanzRaster.Stufe) -> some View {
        let farbe = LumenFarben.tief(.trainieren, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let leer = palette.haar, streifen = palette.grund
        return Canvas { kontext, groesse in
            let rahmen = CGRect(origin: .zero, size: groesse)
            let beispiel = KonstanzRaster.Zelle(tag: "", stufe: stufe, saetze: 0, zukunft: false)
            Self.zeichne(beispiel, pfad: Path(roundedRect: rahmen, cornerRadius: 2), rahmen: rahmen, farbe: farbe, leer: leer, streifen: streifen, in: &kontext)
        }
    }
}
