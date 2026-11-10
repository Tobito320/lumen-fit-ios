import SwiftUI

/// "Rekorde deiner Freunde": die neuesten Rekorde der Personen (Übung und Wert), lokal aus den freigegebenen Einheiten berechnet. Ohne Rekord nichts.
struct GymRekordPinnwandView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let jetzt = umgebung.uhr()
        let eintraege = GymCrewQuelle.eintraege(umgebung)
        // Wie `GymRekordPinnwandLogik.pinnwand`, je Rekord mit der Person (Crew). Likes gibt es seit Build 19 nicht mehr (W-034).
        let rekorde = CrewLogik.pinnwand(eintraege: eintraege, jetzt: jetzt)
        if !rekorde.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Rekorde deiner Freunde").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
                ForEach(rekorde) { eintrag in
                    let r = eintrag.rekord
                    Text("\(Text(r.name).fontWeight(.semibold).foregroundStyle(palette.text))\(Text(" · \(GymRekordPinnwandLogik.text(r, heute: Datum.text(jetzt)))").foregroundStyle(palette.text2))")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
                        .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
