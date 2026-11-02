import SwiftUI

/// Die Medaillen (Idee 37) nach Bereich: nur was der Nutzer eingeschaltet hat, Reihen als Stufen, überall der Fortschritt. Beim Öffnen läuft die Prüfung einmal nach.
struct MeilensteineView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let datum = q.medaillenDatum
        let einstellungen = umgebung.router.einstellungen
        let abschnitte = MedaillenAnsicht.abschnitte(zeigt: { einstellungen.zeigt($0) }, erreicht: q.erreichteIds, ohneZiel: MeilensteinPruefung.ohneZiel(essenZielDa: q.essenZielDa))
        let zaehlung = MedaillenAnsicht.zaehlung(abschnitte, erreicht: q.erreichteIds)
        let erreicht = zaehlung.erreicht
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                Text("\(erreicht) von \(zaehlung.gesamt) Medaillen").font(.title2.weight(.bold)).fontDesign(.rounded).foregroundStyle(palette.text)
                if erreicht == 0 {
                    if einstellungen.zeigt(AppBereich.gym) {
                        LeerZustand(stimmung: .bereit, satz: "Noch keine Medaille. Hake einen Satz ab, Lumi holt die erste.", handlung: "Training starten") {
                            umgebung.router.oeffne(.gym(.training))
                        }
                        .lumenKartenFlaeche()
                    } else {
                        LeerZustand(stimmung: .bereit, satz: "Noch keine Medaille. Lumi holt die erste, sobald du ein Ziel erreichst.").lumenKartenFlaeche()
                    }
                }
                MedaillenRaster(abschnitte: abschnitte, erreicht: datum, zahlen: q.zahlen)
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
