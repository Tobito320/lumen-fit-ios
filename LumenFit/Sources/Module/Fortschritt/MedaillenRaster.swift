import SwiftUI

/// Idee 37: die Medaillen nach Bereich. Reihen (Gym-Tage, Wochenziel ...) sind eine Karte mit Bronze, Silber, Gold und dem Fortschritt zur nächsten Stufe;
/// einzelne Medaillen stehen im Raster. Erreicht: schwarzer Kreis (im dunklen Modus hell) mit Symbol. Gesperrt: Umriss mit Schloss. Farben folgen dem Thema.
struct MedaillenRaster: View {
    let abschnitte: [MedaillenAbschnitt]
    let erreicht: [String: Date]
    let zahlen: MeilensteinZahlen
    @Environment(\.palette) private var palette

    private let spalten = Array(repeating: GridItem(.flexible(), spacing: Abstand.m, alignment: .top), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.xl) {
            ForEach(abschnitte) { abschnitt in
                VStack(alignment: .leading, spacing: Abstand.m) {
                    Text(abschnitt.gruppe.titel).font(.title3.weight(.bold)).fontDesign(.rounded).foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(abschnitt.eintraege.compactMap(reihe)) { e in
                        if case .reihe(let r, let stufen) = e { reiheKarte(r, stufen) }
                    }
                    let einzeln = abschnitt.eintraege.compactMap(einzel)
                    if !einzeln.isEmpty {
                        LazyVGrid(columns: spalten, spacing: Abstand.l) { ForEach(einzeln) { zelle($0) } }
                    }
                }
            }
        }
    }

    private func reihe(_ e: MedaillenEintrag) -> MedaillenEintrag? { if case .reihe = e { e } else { nil } }
    private func einzel(_ e: MedaillenEintrag) -> Meilenstein? { if case .einzel(let m) = e { m } else { nil } }

    // MARK: Reihe

    private func reiheKarte(_ r: MedaillenReihe, _ stufen: [Meilenstein]) -> some View {
        let geschafft = stufen.filter { erreicht[$0.id] != nil }.count
        let naechste = stufen.first { erreicht[$0.id] == nil }
        return ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HStack {
                    Text(r.titel).font(.headline).foregroundStyle(palette.text)
                    Spacer()
                    Text("\(geschafft) von \(stufen.count)").font(.footnote).foregroundStyle(palette.text2)
                }
                HStack(alignment: .top, spacing: Abstand.m) {
                    ForEach(Array(stufen.enumerated()), id: \.element.id) { i, m in
                        VStack(spacing: Abstand.xs) {
                            MedaillenKreis(meilenstein: m, erreicht: erreicht[m.id] != nil, groesse: 48)
                            Text(MedaillenAnsicht.stufenName(i, von: stufen.count)).font(.caption.weight(.semibold)).foregroundStyle(palette.text)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(r.titel), \(MedaillenAnsicht.stufenName(i, von: stufen.count)), \(erreicht[m.id] != nil ? "erreicht" : "gesperrt")")
                    }
                }
                if let naechste {
                    fortschritt(naechste)
                } else {
                    Text("Alle Stufen erreicht").font(.footnote).foregroundStyle(palette.text2)
                }
            }
            .padding(Abstand.l)
        }
    }

    /// Bedingung der nächsten Stufe und ein Balken "x von y", wenn die Medaille zählbar ist.
    @ViewBuilder
    private func fortschritt(_ m: Meilenstein) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text(m.bedingung).font(.footnote).foregroundStyle(palette.text)
            if let c = LumiPfad.zaehler(m.id, zahlen) {
                let stand = MeilensteinZiel(meilenstein: m, aktuell: c.aktuell, ziel: c.ziel, einheit: c.einheit)
                ProgressView(value: stand.anteil).tint(palette.text)
                Text(stand.text).font(.caption).foregroundStyle(palette.text2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Einzeln

    private func zelle(_ m: Meilenstein) -> some View {
        let datum = erreicht[m.id]
        return VStack(spacing: Abstand.xs) {
            MedaillenKreis(meilenstein: m, erreicht: datum != nil, groesse: 64)
            Text(m.titel).font(.footnote.weight(.semibold)).foregroundStyle(palette.text).multilineTextAlignment(.center)
            if let datum {
                Text(datum, format: .dateTime.day().month(.abbreviated)).font(.caption2).foregroundStyle(palette.text2)
            } else {
                Text(m.bedingung).font(.caption2).foregroundStyle(palette.text2).multilineTextAlignment(.center)
                if let c = LumiPfad.zaehler(m.id, zahlen) {
                    Text(MeilensteinZiel(meilenstein: m, aktuell: c.aktuell, ziel: c.ziel, einheit: c.einheit).text).font(.caption2).foregroundStyle(palette.text2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(datum == nil ? "\(m.titel), gesperrt. \(m.bedingung)" : "\(m.titel), erreicht am \(datum?.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "de_DE"))) ?? "")")
    }
}

/// Der Kreis einer Medaille: erreicht gefüllt mit Symbol und Rand in der Datenfarbe, gesperrt gestrichelt mit Schloss.
private struct MedaillenKreis: View {
    let meilenstein: Meilenstein
    let erreicht: Bool
    let groesse: CGFloat
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        let rand = LumenFarben.tief(meilenstein.bereich, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        ZStack {
            if erreicht {
                Circle().fill(palette.text)
                Circle().stroke(rand, lineWidth: 3)
                Image(systemName: meilenstein.symbol).font(groesse > 56 ? Font.title2 : Font.body).foregroundStyle(palette.grund)
            } else {
                Circle().stroke(palette.rand, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                Image(systemName: "lock.fill").font(groesse > 56 ? Font.title3 : Font.footnote).foregroundStyle(palette.text2)
            }
        }
        .frame(width: groesse, height: groesse)
        .accessibilityHidden(true)
    }
}
