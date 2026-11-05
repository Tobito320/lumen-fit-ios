import SwiftUI

/// Datenschutz in Klartext (Idee 79): was gespeichert wird, was das iPhone nie verlässt, was ins Netz geht.
struct ProfilDatenschutzView: View {
    @Environment(\.palette) private var palette
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                HStack(spacing: Abstand.m) {
                    LumiView(stimmung: .bereit, groesse: 64)
                    Text("Deine Daten gehören dir. Hier steht, was mit ihnen passiert.").font(.title3.bold()).foregroundStyle(palette.text)
                }
                .accessibilityElement(children: .combine)
                ForEach(ProfilTexte.datenschutz()) { abschnitt in
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        Text(abschnitt.titel).font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                        Text(abschnitt.text).font(.body).foregroundStyle(palette.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Abstand.l)
                    .lumenKartenFlaeche()
                }
                Toggle(ProfilTexte.NutzungFrage.schalter, isOn: Binding(
                    get: { umgebung.daten?.einstellungen.werte.nutzungErlaubt ?? false },
                    set: { an in umgebung.daten?.einstellungen.aendere { $0.antworteNutzung(an ? .ja : .nein, tag: Datum.text(umgebung.uhr())) } }))
                    .frame(minHeight: Abstand.tippflaeche)
                    .padding(.horizontal, Abstand.l)
                Text(ProfilTexte.NutzungFrage.schalterFuss)
                    .font(.footnote).foregroundStyle(palette.text2)
                    .padding(.horizontal, Abstand.l)
                if umgebung.konto.schlafBelegAn {
                    Text("Schlaf-Beleg an Entwickler: an").font(.footnote).foregroundStyle(palette.text2).padding(.horizontal, Abstand.l)
                }
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}
