import SwiftUI

/// Die 25 Medaillen (Idee 37). Gesperrte zeigen ihre Bedingung als Text, erreichte das Datum. Beim Öffnen läuft die Prüfung einmal nach.
struct MeilensteineView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let datum = q.medaillenDatum
        let erreicht = MeilensteinKatalog.alle.filter { datum[$0.id] != nil }.count
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                Text("\(erreicht) von \(MeilensteinKatalog.anzahl) Medaillen").font(.title2.weight(.bold)).fontDesign(.rounded).foregroundStyle(palette.text)
                if erreicht == 0 {
                    LeerZustand(stimmung: .bereit, satz: "Noch keine Medaille. Hake einen Satz ab, Lumi holt die erste.", handlung: "Training starten") {
                        umgebung.router.oeffne(.gym(.training))
                    }
                    .lumenKartenFlaeche()
                }
                MedaillenRaster(erreicht: datum)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .navigationTitle("Meilensteine")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .fortschrittToast()
        .onAppear { FortschrittModul.waechter.pruefeAlles() }
    }
}
