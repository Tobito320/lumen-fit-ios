// Quelle: Lovea Health/Ernaehrung/ErnaehrungPortionen.swift (Portionsbeispiel, PortionsbeispieleBlatt)
import SwiftUI

/// Richtwerte nach der Handregel des Bundeszentrums für Ernährung.
struct EssenPortionsBeispiel: Identifiable, Equatable, Sendable {
    let name: String
    let gramm: Double
    let kcal: Int
    let symbol: String
    let hand: String
    var id: String { name }

    static let alle: [EssenPortionsBeispiel] = [
        EssenPortionsBeispiel(name: "Gemüse", gramm: 150, kcal: 45, symbol: "carrot.fill", hand: "2 Hände voll"),
        EssenPortionsBeispiel(name: "Obst", gramm: 125, kcal: 65, symbol: "leaf.fill", hand: "1 Hand voll"),
        EssenPortionsBeispiel(name: "Kartoffeln", gramm: 200, kcal: 150, symbol: "circle.grid.2x2.fill", hand: "2 Fäuste"),
        EssenPortionsBeispiel(name: "Nudeln, gekocht", gramm: 180, kcal: 270, symbol: "fork.knife", hand: "2 Hände voll"),
        EssenPortionsBeispiel(name: "Reis, gekocht", gramm: 150, kcal: 195, symbol: "takeoutbag.and.cup.and.straw.fill", hand: "2 Hände voll"),
        EssenPortionsBeispiel(name: "Brot", gramm: 50, kcal: 120, symbol: "square.fill", hand: "1 Scheibe, Handfläche"),
        EssenPortionsBeispiel(name: "Fleisch und Fisch", gramm: 120, kcal: 180, symbol: "fish.fill", hand: "1 Handfläche"),
        EssenPortionsBeispiel(name: "Käse", gramm: 30, kcal: 110, symbol: "triangle.fill", hand: "2 Finger"),
        EssenPortionsBeispiel(name: "Nüsse", gramm: 25, kcal: 160, symbol: "circle.hexagongrid.fill", hand: "1 Handmulde"),
        EssenPortionsBeispiel(name: "Öl und Butter", gramm: 10, kcal: 90, symbol: "drop.fill", hand: "1 Daumenspitze"),
    ]
}

/// Von unten: Richtwerte, wie groß eine Portion ungefähr ist.
struct EssenPortionsBeispieleBlatt: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    Text("Eine Portion ist ungefähr so groß wie deine Hand. Richtwerte.")
                        .font(.subheadline)
                        .foregroundStyle(palette.text2)
                    ListenKarte {
                        ForEach(Array(EssenPortionsBeispiel.alle.enumerated()), id: \.element.id) { i, p in
                            if i > 0 { Haarlinie() }
                            zeile(p)
                        }
                    }
                }
                .padding(Abstand.l)
            }
            .navigationTitle("Portionsbeispiele")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.fraction(0.4), .large])
        .presentationDragIndicator(.visible)
    }

    private func zeile(_ p: EssenPortionsBeispiel) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: p.symbol)
                .foregroundStyle(palette.text2)
                .frame(width: 40, height: 40)
                .background(palette.grund, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Text("1 Portion = \(ErnaehrungLogik.zahl(p.gramm)) g, etwa \(p.kcal) kcal").font(.caption).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            Text(p.hand).font(.caption2).foregroundStyle(palette.text2).multilineTextAlignment(.trailing).frame(maxWidth: 96, alignment: .trailing)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
    }
}
