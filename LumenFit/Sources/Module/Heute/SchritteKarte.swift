import Charts
import SwiftUI

/// Schritte heute (Idee 18, Teil 1): die Zahl, der Fortschritt zum Ziel, Distanz und Etagen. Ein Tipp öffnet das Detail mit Tag, Woche und Monat.
struct SchritteKarte: View {
    let schritte: HeuteSchritte
    let oeffne: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: oeffne) {
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    HeuteKartenKopf(symbol: "figure.walk", titel: "Schritte", zusatz: "Ziel \(HeuteQuellen.zahl(schritte.ziel))")
                    RollZahl(wert: Double(schritte.schritte), format: HeuteFormat.ganz())
                        .heuteHeldenZahl(40).foregroundStyle(palette.text)
                    ProgressView(value: schritte.anteil).tint(palette.text)
                    Text(unterzeile).font(.footnote.weight(.medium)).foregroundStyle(palette.text2)
                }
                .padding(Abstand.l)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schritte")
        .accessibilityValue("\(HeuteQuellen.zahl(schritte.schritte)) von \(HeuteQuellen.zahl(schritte.ziel)). \(unterzeile)")
        .accessibilityHint("Zeigt Tag, Woche und Monat")
        .accessibilityAddTraits(.isButton)
    }

    private var unterzeile: String {
        let km = String(format: "%.1f", schritte.distanzKm).replacingOccurrences(of: ".", with: ",")
        return "\(km) km, \(schritte.etagen) Etagen"
    }
}
