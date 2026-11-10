import SwiftUI

/// Die Kraftkurve (Idee 31) als eigene Seite unter "Mehr": Übung wählen, Gewicht, 1RM oder Volumen.
struct KraftKurveSeite: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        ScrollView {
            KraftKurveKarte(sessions: q.sessions, heute: q.heute)
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Kraftkurve")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Die Muskelkarte (Ideen 32 und 33) als eigene Seite unter "Mehr": Wochenleiste, Ziele, Sätze je Körperteil und die Erholungs-Silhouette.
/// Ein Tipp auf Silhouette, Legende oder Feld öffnet das Blatt der Muskelgruppe.
struct MuskelkartenSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var auswahl: KoerperAuswahl?
    @State private var befragung = false
    @State private var tipp = 0

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let koerper = q.koerper
        ScrollView {
            VStack(spacing: Abstand.l) {
                KoerperWochenLeiste(woche: koerper.streifen)
                if !q.zieleGesetzt { ZielFestlegenKarte { befragung = true } }
                SaetzeFelderKarte(daten: koerper) { waehle($0, nil) }
                if q.hatTraining { SilhouetteKarte(daten: koerper, beiGruppe: waehle) }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Muskelkarte")
        .navigationBarTitleDisplayMode(.inline)
        .haptik(.auswahl, bei: tipp)
        .sheet(item: $auswahl) { a in KoerperBlattView(gruppe: a.gruppe, teil: a.teil) }
        .sheet(isPresented: $befragung) { ZieleBefragungView().presentationDetents([.large]) }
    }

    private func waehle(_ gruppe: MuskelGruppe, _ teil: MuskelTeil?) {
        tipp += 1
        auswahl = KoerperAuswahl(gruppe: gruppe, teil: teil)
    }
}

/// Der Vorschlag fürs nächste Training (Idee 34) als eigene Seite unter "Mehr"; "Training starten" öffnet den Tab Training.
struct NaechstesTrainingSeite: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        ScrollView {
            NaechstesTrainingKarte(erholung: q.koerper.erholung, plantag: q.plantagHeute) { umgebung.router.oeffne(.gym(.training)) }
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Nächstes Training")
        .navigationBarTitleDisplayMode(.inline)
    }
}
