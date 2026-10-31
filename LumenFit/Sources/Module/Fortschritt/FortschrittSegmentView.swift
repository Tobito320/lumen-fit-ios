import SwiftUI

/// Das Segment "Fortschritt" im Tab Gym (Ideen 31 bis 34): Wochenleiste, nächstes Training, Kraftkurve, Sätze je Muskel (Felder und Balken), Erholungs-Silhouette
/// und die Wege zu Verlauf, Messungen, Rückblick, Meilensteinen und Lumi. Ein Tipp auf Silhouette, Legende oder Feld öffnet das Blatt der Muskelgruppe;
/// "Ziele" in der Leiste öffnet die Befragung. Die Seite bringt ihren eigenen Hintergrund und kein Navigationstitel mit, der Tab Gym setzt ihn.
struct FortschrittSegmentView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @State private var auswahl: KoerperAuswahl?
    @State private var befragung = false
    @State private var tipp = 0

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let koerper = q.koerper
        ScrollView {
            VStack(spacing: Abstand.l) {
                if aufbau == .lovea {
                    // Lovea-Aufbau (Lovea `KoerperView.swift:431-492`): Streifen, Bilanz, Figur, Ziel-Karte, Felder, Nächstes; danach die Lumen-Karten.
                    KoerperLoveaSeite(daten: koerper, zieleGesetzt: q.zieleGesetzt, beiGruppe: waehle, beiZiele: { befragung = true },
                                      beiTraining: { umgebung.router.oeffne(.gym(.training)) })
                    if q.hatTraining {
                        NaechstesTrainingKarte(erholung: koerper.erholung, plantag: q.plantagHeute) { umgebung.router.oeffne(.gym(.training)) }
                        KraftKurveKarte(sessions: q.sessions, heute: q.heute)
                        SaetzeProMuskelKarte(zeilen: SaetzeProMuskel.zeilen(q.sessions, heute: q.heute, ziele: koerper.ziele))
                        SilhouetteKarte(daten: koerper, beiGruppe: waehle)
                    }
                } else {
                    KoerperWochenLeiste(woche: koerper.streifen)
                    if q.hatTraining {
                        NaechstesTrainingKarte(erholung: koerper.erholung, plantag: q.plantagHeute) { umgebung.router.oeffne(.gym(.training)) }
                        KraftKurveKarte(sessions: q.sessions, heute: q.heute)
                    } else {
                        LeerZustand(stimmung: .bereit, satz: "Noch kein Training. Tipp auf Starten, Lumi zählt mit.", handlung: "Training starten") {
                            umgebung.router.oeffne(.gym(.training))
                        }
                        .lumenKartenFlaeche()
                    }
                    if !q.zieleGesetzt { ZielFestlegenKarte { befragung = true } }
                    SaetzeFelderKarte(daten: koerper) { waehle($0, nil) }
                    if q.hatTraining {
                        SaetzeProMuskelKarte(zeilen: SaetzeProMuskel.zeilen(q.sessions, heute: q.heute, ziele: koerper.ziele))
                        SilhouetteKarte(daten: koerper, beiGruppe: waehle)
                    }
                }
                links(stufe: q.stufe, medaillen: q.medaillen.count)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .fortschrittToast()
        .onAppear { FortschrittModul.waechter.pruefeAlles() }
        .haptik(.auswahl, bei: tipp)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ziele", systemImage: "slider.horizontal.3") { befragung = true }
            }
        }
        .sheet(item: $auswahl) { a in KoerperBlattView(gruppe: a.gruppe, teil: a.teil) }
        .sheet(isPresented: $befragung) { ZieleBefragungView().presentationDetents([.large]) }
    }

    private func waehle(_ gruppe: MuskelGruppe, _ teil: MuskelTeil?) {
        tipp += 1
        auswahl = KoerperAuswahl(gruppe: gruppe, teil: teil)
    }

    private func links(stufe: Int, medaillen: Int) -> some View {
        ListenKarte {
            zeile("Verlauf", detail: "Konstanz und Gewicht", symbol: "chart.xyaxis.line") { VerlaufView() }
            Haarlinie()
            zeile("Messungen", detail: "Gewicht, Umfänge, Körperfett", symbol: "ruler") { PartnerKoerperWeiche { MessungenView() } }
            Haarlinie()
            zeile("Rückblick", detail: "Woche und Monat teilen", symbol: "calendar") { RueckblickView() }
            Haarlinie()
            zeile("Meilensteine", detail: "\(medaillen) von \(MeilensteinKatalog.anzahl) Medaillen", symbol: "medal.fill") { MeilensteineView() }
            Haarlinie()
            zeile("Lumi", detail: "Stufe \(stufe) von \(LumiStufe.schwellen.count)", symbol: "sparkles") { LumiSeiteView() }
        }
    }

    private func zeile<Ziel: View>(_ titel: String, detail: String, symbol: String, @ViewBuilder ziel: () -> Ziel) -> some View {
        NavigationLink {
            ziel()
        } label: {
            HStack(spacing: Abstand.m) {
                Image(systemName: symbol).frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.headline)
                    Text(detail).font(.footnote).foregroundStyle(palette.text2)
                }
                Spacer(minLength: Abstand.s)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, Abstand.l)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
