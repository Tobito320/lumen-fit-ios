import SwiftUI

/// Idee 40: der FitPassport, die Langzeitkarte mit Kraft, Schlaf und Konstanz. Nur eigene Werte. Auch die Vorlage für das geteilte Bild.
struct FitPassportBild: View {
    let daten: FitPassportDaten
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            HStack(spacing: Abstand.m) {
                LumiView(stimmung: daten.gymTage > 0 ? .stolz : .bereit, groesse: 56, stufe: daten.stufe)
                VStack(alignment: .leading, spacing: 2) {
                    Text(daten.titel).font(.title3.weight(.bold)).fontDesign(.rounded)
                    if let name = daten.name { Text(name).font(.footnote).foregroundStyle(palette.text2) }
                }
            }
            abschnitt("Kraft", daten.kraft.isEmpty ? "Noch kein Satz mit Gewicht." : daten.kraft.map { "\($0.name): \($0.e1rmKg) kg (1RM)" }.joined(separator: "\n"))
            abschnitt("Schlaf", daten.schlafSchnitt.map { "Im Schnitt \(Rueckblick.dauer($0)) in \(daten.schlafNaechte) Nächten" } ?? "Noch keine Nacht erfasst.")
            abschnitt("Konstanz", "\(daten.aktiveWochen) von \(KonstanzRaster.wochen) Wochen mit Training, Serie \(daten.serieWochen) \(daten.serieWochen == 1 ? "Woche" : "Wochen")")
            abschnitt("Medaillen", "\(daten.medaillen) von \(MeilensteinKatalog.anzahl)")
            Text("Lumen Fit").font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(daten.sprechtext)
    }

    private func abschnitt(_ titel: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
            Text(text).font(.subheadline).monospacedDigit()
        }
    }
}

struct FitPassportKarte: View {
    let daten: FitPassportDaten

    var body: some View {
        TeilbareKarte(titel: "FitPassport", schluessel: daten.sprechtext) { FitPassportBild(daten: daten) }
    }
}
