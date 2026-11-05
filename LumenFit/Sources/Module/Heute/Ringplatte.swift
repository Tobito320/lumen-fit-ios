import SwiftUI

/// Die eine mutige Karte des Heute-Tabs (Idee 11): schwarze Platte mit Streifen, drei Lumen-Bögen (Schritte, Gym der Woche, Schlaf), Lumi in der Mitte
/// und darunter Lumis Satz (Idee 13). Die Bögen füllen sich beim ersten Öffnen; Reduce Motion und Stromsparmodus zeigen sie sofort gefüllt.
/// Ab den großen Schriftstufen (Bedienungshilfen) ersetzt `LumenBalken` die Bögen, denn Bogen und Zahlen passen dann nicht mehr nebeneinander.
struct Ringplatte: View {
    let stand: HeuteStand
    let stufe: Int
    @State private var gefuellt = false
    @Environment(\.bewegungAus) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var schriftGroesse

    var body: some View {
        HeroKarte(platte: true) {
            VStack(alignment: .leading, spacing: Abstand.m) {
                if BewegungsRegel.nutztBalken(schriftGroesse) {
                    LumiView(stimmung: stand.stimmung, groesse: 48, stufe: stufe)
                    LumenBalken(werte: angezeigt)
                } else {
                    LumenBogen(werte: angezeigt, mitte: LumiView(stimmung: stand.stimmung, groesse: 60, stufe: stufe))
                }
                Text(stand.morgensatz)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            guard !gefuellt else { return }
            if reduceMotion { gefuellt = true } else { withAnimation(.smooth(duration: 0.9)) { gefuellt = true } }
        }
        // Die Bögen sind für VoiceOver ein Element: Zahlen als Wert, Lumis Satz und Stimmung als Beschriftung.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dein Tag. \(stand.stimmung.beschreibung). \(stand.morgensatz)")
        .accessibilityValue(stand.boegenSatz)
    }

    /// Vor dem Öffnen leer, danach auf dem echten Anteil: die Animation füllt die Bögen.
    private var angezeigt: [BogenWert] {
        stand.boegen.map { BogenWert(id: $0.id, anteil: gefuellt ? $0.anteil : 0, zahl: $0.zahl, beschriftung: $0.beschriftung) }
    }
}
