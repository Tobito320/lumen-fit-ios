import SwiftUI

/// Idee 37 im neuen Design (Entwurf "Erfolge"): alle Medaillen nach Bereich als runde, bunte Abzeichen im Raster. Reihen (Gym-Tage, Wochenziel ...)
/// sind aufgefächert in ihre Stufen Bronze, Silber, Gold, Platin; einzelne Medaillen sind Bronze. Ein Ring zeigt den Fortschritt, gesperrte sind grau.
struct MedaillenRaster: View {
    let abschnitte: [MedaillenAbschnitt]
    let erreicht: [String: Date]
    let zahlen: MeilensteinZahlen
    @Environment(\.palette) private var palette

    private let spalten = Array(repeating: GridItem(.flexible(), spacing: Abstand.s, alignment: .top), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.xl) {
            ForEach(abschnitte) { abschnitt in
                let abzeichen = FortErfolgeLogik.abzeichen(abschnitt)
                VStack(alignment: .leading, spacing: Abstand.m) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(abschnitt.gruppe.titel).font(.title3.weight(.bold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text("\(abzeichen.filter { erreicht[$0.id] != nil }.count) von \(abzeichen.count)").font(.footnote).foregroundStyle(palette.text2)
                    }
                    LazyVGrid(columns: spalten, spacing: Abstand.s) {
                        ForEach(abzeichen) { a in
                            FortAbzeichenZelle(abzeichen: a, datum: erreicht[a.id], ziel: ziel(a.meilenstein))
                        }
                    }
                }
            }
        }
    }

    private func ziel(_ m: Meilenstein) -> MeilensteinZiel? {
        LumiPfad.zaehler(m.id, zahlen).map { MeilensteinZiel(meilenstein: m, aktuell: $0.aktuell, ziel: $0.ziel, einheit: $0.einheit) }
    }
}

/// Ein Abzeichen: Ring (Fortschritt in der Farbe der Stufe), Münze mit Symbol, Titel, darunter Datum, "x von y" oder die Bedingung.
private struct FortAbzeichenZelle: View {
    let abzeichen: FortAbzeichen
    let datum: Date?
    let ziel: MeilensteinZiel?
    @Environment(\.palette) private var palette

    private var anteil: Double { datum != nil ? 1 : ziel?.anteil ?? 0 }

    var body: some View {
        let m = abzeichen.meilenstein
        let farben = Self.farben(abzeichen.stufe)
        VStack(spacing: 2) {
            ZStack {
                Circle().stroke(palette.text.opacity(0.1), lineWidth: 5)
                Circle().trim(from: 0, to: anteil)
                    .stroke(farben.ring, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(LinearGradient(colors: [farben.hell, farben.dunkel], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: m.symbol).font(.title3.weight(.semibold)).foregroundStyle(farben.symbol))
                    .padding(10)
                    .saturation(datum != nil ? 1 : 0)
                    .opacity(datum != nil ? 1 : 0.4)
            }
            .frame(width: 72, height: 72)
            .padding(.bottom, Abstand.xs)
            Text(m.titel).font(.footnote.weight(.semibold)).foregroundStyle(palette.text).multilineTextAlignment(.center).lineLimit(3)
            Group {
                if let datum {
                    Text(datum, format: .dateTime.day().month(.abbreviated))
                } else if let ziel {
                    Text(ziel.text)
                } else {
                    Text(m.bedingung).lineLimit(3)
                }
            }
            .font(.caption).foregroundStyle(palette.text2).multilineTextAlignment(.center)
        }
        .padding(.vertical, Abstand.m)
        .padding(.horizontal, Abstand.xs)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechtext)
    }

    private var sprechtext: String {
        let m = abzeichen.meilenstein
        if let datum { return String(localized: "\(m.titel), erreicht am \(datum.formatted(.dateTime.day().month(.wide)))") }
        if let ziel { return String(localized: "\(m.titel), gesperrt, \(ziel.text). \(m.bedingung)") }
        return String(localized: "\(m.titel), gesperrt. \(m.bedingung)")
    }

    /// Farben des Entwurfs (Bronze, Silber, Gold) und ein kühles Grau-Violett für Platin; kein Blau.
    static func farben(_ s: FortMedaillenStufe) -> (ring: Color, hell: Color, dunkel: Color, symbol: Color) {
        switch s {
        case .bronze: (LumenFarben.farbe(0xD08A45), LumenFarben.farbe(0xF0B47A), LumenFarben.farbe(0xB5712F), .white)
        case .silber: (LumenFarben.farbe(0xAEB9C4), LumenFarben.farbe(0xF2F5F8), LumenFarben.farbe(0x9BA7B4), LumenFarben.farbe(0x33404D))
        case .gold: (LumenFarben.farbe(0xF2C200), LumenFarben.farbe(0xFFE680), LumenFarben.farbe(0xE6A800), LumenFarben.farbe(0x5A3E00))
        case .platin: (LumenFarben.farbe(0xB8B4CC), LumenFarben.farbe(0xF4F2FA), LumenFarben.farbe(0xA9A4C2), LumenFarben.farbe(0x3A3550))
        }
    }
}
