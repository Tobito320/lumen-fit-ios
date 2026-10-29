import SwiftUI

/// Idee 37: alle 25 Medaillen im Raster. Erreicht: schwarzer Kreis (im dunklen Modus hell) mit Symbol, Titel und Datum. Gesperrt: Umriss mit Schloss, Titel und die Bedingung in Worten.
struct MedaillenRaster: View {
    let erreicht: [String: Date]
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    private let spalten = Array(repeating: GridItem(.flexible(), spacing: Abstand.m, alignment: .top), count: 3)

    var body: some View {
        LazyVGrid(columns: spalten, spacing: Abstand.l) {
            ForEach(MeilensteinKatalog.alle) { m in zelle(m) }
        }
    }

    private func zelle(_ m: Meilenstein) -> some View {
        let datum = erreicht[m.id]
        let rand = LumenFarben.tief(m.bereich, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        return VStack(spacing: Abstand.xs) {
            ZStack {
                if datum != nil {
                    Circle().fill(palette.text)
                    Circle().stroke(rand, lineWidth: 3)
                    Image(systemName: m.symbol).font(.title2).foregroundStyle(palette.grund)
                } else {
                    Circle().stroke(palette.rand, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    Image(systemName: "lock.fill").font(.title3).foregroundStyle(palette.text2)
                }
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
            Text(m.titel).font(.footnote.weight(.semibold)).foregroundStyle(palette.text).multilineTextAlignment(.center)
            if let datum {
                Text(datum, format: .dateTime.day().month(.abbreviated)).font(.caption2).foregroundStyle(palette.text2)
            } else {
                Text(m.bedingung).font(.caption2).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(datum == nil ? "\(m.titel), gesperrt. \(m.bedingung)" : "\(m.titel), erreicht am \(datum?.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "de_DE"))) ?? "")")
    }
}
