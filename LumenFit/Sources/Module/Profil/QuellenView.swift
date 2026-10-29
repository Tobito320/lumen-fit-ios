import SwiftUI

/// Quellen und Lizenzen (Idee 78): Open Food Facts (ODbL), BLS (CC BY 4.0, mit Datenstand), Übungsbilder und Apple-Frameworks mit Namensnennung.
struct QuellenView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                Text("Lumen Fit nutzt freie Daten und Apples Frameworks. Danke an alle, die sie pflegen.")
                    .font(.body).foregroundStyle(palette.text2)
                ListenKarte {
                    ForEach(ProfilTexte.quellen) { quelle in
                        VStack(alignment: .leading, spacing: Abstand.s) {
                            HStack {
                                Text(quelle.name).font(.headline).foregroundStyle(palette.text)
                                Spacer(minLength: Abstand.s)
                                Pille(text: quelle.lizenz)
                            }
                            Text(quelle.text).font(.subheadline).foregroundStyle(palette.text2)
                        }
                        .padding(Abstand.l)
                        .accessibilityElement(children: .combine)
                        if quelle.id != ProfilTexte.quellen.last?.id { Haarlinie() }
                    }
                }
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Quellen")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}
