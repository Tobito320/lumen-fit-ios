import SwiftUI

/// "Rekorde der Crew": die neuesten Rekorde der Personen (Übung und Wert), lokal aus den freigegebenen Einheiten berechnet. Ohne Rekord nichts.
struct GymRekordPinnwandView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let jetzt = umgebung.uhr()
        let rekorde = GymRekordPinnwandLogik.pinnwand(eintraege: GymCrewQuelle.eintraege(umgebung), jetzt: jetzt)
        if !rekorde.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Rekorde der Crew").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
                ForEach(rekorde, id: \.self) { r in
                    Text("\(Text(r.name).fontWeight(.semibold).foregroundStyle(palette.text))\(Text(" · \(GymRekordPinnwandLogik.text(r, heute: Datum.text(jetzt)))").foregroundStyle(palette.text2))")
                        .font(.footnote)
                        .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
