import SwiftUI

/// "Rekorde der Crew": die neuesten Rekorde der Personen (Übung und Wert), lokal aus den freigegebenen Einheiten berechnet. Ohne Rekord nichts.
struct GymRekordPinnwandView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let jetzt = umgebung.uhr()
        let eintraege = GymCrewQuelle.eintraege(umgebung)
        // Wie `GymRekordPinnwandLogik.pinnwand`, dazu die Person je Rekord für den Respekt-Knopf (Crew).
        let rekorde = CrewLogik.pinnwand(eintraege: eintraege, jetzt: jetzt)
        if !rekorde.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Rekorde der Crew").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
                ForEach(rekorde) { eintrag in
                    let r = eintrag.rekord
                    HStack(spacing: Abstand.s) {
                        Text("\(Text(r.name).fontWeight(.semibold).foregroundStyle(palette.text))\(Text(" · \(GymRekordPinnwandLogik.text(r, heute: Datum.text(jetzt)))").foregroundStyle(palette.text2))")
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        if let person = eintraege.first(where: { $0.id == eintrag.person }) {
                            CrewReaktionKnopf(eintrag: person, art: .respekt, ziel: CrewLogik.zielRekord(tag: r.tag, uebung: r.uebung),
                                              text: "\(r.uebung) \(TrainingLogik.kgText(r.kg)) kg × \(r.wdh)")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
