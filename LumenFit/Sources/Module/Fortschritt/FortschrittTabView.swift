import SwiftUI

/// Abschnittstitel der Seite Fortschritt: groß und fett, rechts optional eine Erklärung.
struct FortschrittAbschnitt: View {
    let titel: String
    var detail: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
            Text(titel).font(.title2.weight(.bold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Spacer(minLength: Abstand.s)
            if let detail { Text(detail).font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.trailing) }
        }
    }
}

/// Die Wurzel des Tabs Fortschritt (Aufteilung B): wie es dir geht, wie deine Gewichte steigen, welche Einheiten du gemacht hast.
/// Reihenfolge: Wie geht's dir, Gewichte, Sätze je Muskel, Einheiten (Diagramm, dann nach Wochen), Körper, Medaillen, Mehr.
/// Ohne Training stehen oben nur ein Leerzustand mit einem Knopf; Körper, Medaillen und Mehr bleiben. Die Seite hat keinen eigenen `NavigationStack`
/// (der Tab setzt ihn) und setzt ihren Titel selbst. Sie hängt die Medaillen-Prüfung und den Toast "Neue Medaille" an, wie das alte Segment.
struct FortschrittTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var befragung = false

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                if q.hatTraining { training(q) } else { leer }
                koerper(q)
                medaillen(q)
                VStack(alignment: .leading, spacing: Abstand.s) {
                    FortschrittAbschnitt(titel: "Mehr")
                    FortschrittSegmentView()
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Fortschritt")
        .navigationBarTitleDisplayMode(.large)
        .fortschrittToast()
        .onAppear { FortschrittModul.waechter.pruefeAlles() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ziele", systemImage: "slider.horizontal.3") { befragung = true }
            }
        }
        .sheet(isPresented: $befragung) { ZieleBefragungView().presentationDetents([.large]) }
    }

    private var leer: some View {
        LeerZustand(stimmung: .bereit, satz: "Noch kein Training. Tipp auf Starten, Lumi zählt mit.", handlung: "Training starten") {
            umgebung.router.oeffne(.gym(.training))
        }
        .lumenKartenFlaeche()
    }

    /// Wie geht's dir, Gewichte, Sätze je Muskel, Einheiten.
    @ViewBuilder
    private func training(_ q: FortschrittQuelle) -> some View {
        let heute = q.heute
        let vergleich = FortschrittLogik.vergleich(q.sessions, plan: q.plan, heute: heute, jetzt: q.jetzt)
        let rest = FortschrittLogik.geplantRest(q.plan, sessions: q.sessions, heute: heute)
        VStack(alignment: .leading, spacing: Abstand.s) {
            FortschrittAbschnitt(titel: "Wie geht's dir")
            WieGehtsKarte(vergleich: vergleich, satz: FortschrittLogik.satz(vergleich, geplantRest: rest), letzte: q.letztesTraining)
        }
        GewichteListe(zeilen: FortschrittLogik.gewichte(q.sessions, plan: q.plan, heute: heute))
        VStack(alignment: .leading, spacing: Abstand.s) {
            FortschrittAbschnitt(titel: "Sätze je Muskel", detail: "Diese Woche")
            SaetzeProMuskelKarte(zeilen: SaetzeProMuskel.zeilen(q.sessions, heute: heute, ziele: q.koerper.ziele))
        }
        einheiten(q)
    }

    @ViewBuilder
    private func einheiten(_ q: FortschrittQuelle) -> some View {
        if FortschrittLogik.nachWochen(q.sessions, heute: q.heute, jetzt: q.jetzt).isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                FortschrittAbschnitt(titel: "Einheiten")
                LeerZustand(stimmung: .bereit, satz: "Noch keine beendete Einheit. Nach dem Beenden steht sie hier.").lumenKartenFlaeche()
            }
        } else {
            VStack(alignment: .leading, spacing: Abstand.s) {
                FortschrittAbschnitt(titel: "Einheiten")
                EinheitenKarte(sessions: q.sessions, heute: q.heute, jetzt: q.jetzt)
            }
            VerlaufNachWochen(sessions: q.sessions, heute: q.heute, jetzt: q.jetzt)
        }
    }

    private func koerper(_ q: FortschrittQuelle) -> some View {
        let trend = GewichtVerlauf.trend(werte: q.gewicht, zielKg: q.gewichtZielKg, heute: q.heute)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            FortschrittAbschnitt(titel: "Körper")
            GewichtVerlaufKarte(trend: trend) { umgebung.router.oeffne(.gewichtEintragen) }
            ListenKarte {
                FortschrittLinkZeile(titel: "Messungen", detail: "Gewicht, Umfänge, Körperfett", symbol: "ruler") { PartnerKoerperWeiche { MessungenView() } }
            }
        }
    }

    private func medaillen(_ q: FortschrittQuelle) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            FortschrittAbschnitt(titel: "Medaillen")
            ListenKarte {
                FortschrittLinkZeile(titel: "Alle Medaillen", detail: "\(q.medaillen.count) von \(MeilensteinKatalog.anzahl) erreicht", symbol: "medal.fill") { MeilensteineView() }
            }
        }
    }
}
