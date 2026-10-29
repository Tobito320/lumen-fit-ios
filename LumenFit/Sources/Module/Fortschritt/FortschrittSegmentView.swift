import SwiftUI

/// Das Segment "Fortschritt" im Tab Gym (Ideen 31 bis 34): nächstes Training, Kraftkurve, Sätze je Muskel, Erholungs-Silhouette und die Wege zu Verlauf,
/// Rückblick, Meilensteinen und Lumi. Die Seite bringt ihren eigenen Hintergrund und kein Navigationstitel mit, der Tab Gym setzt ihn.
struct FortschrittSegmentView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        ScrollView {
            VStack(spacing: Abstand.l) {
                if q.hatTraining {
                    NaechstesTrainingKarte(erholung: q.koerper.erholung, plantag: q.plantagHeute) { umgebung.router.oeffne(.gym(.training)) }
                    KraftKurveKarte(sessions: q.sessions, heute: q.heute)
                    SaetzeProMuskelKarte(zeilen: SaetzeProMuskel.zeilen(q.sessions, heute: q.heute, ziele: q.koerper.ziele))
                    SilhouetteKarte(daten: q.koerper)
                } else {
                    LeerZustand(stimmung: .bereit, satz: "Noch kein Training. Tipp auf Starten, Lumi zählt mit.", handlung: "Training starten") {
                        umgebung.router.oeffne(.gym(.training))
                    }
                    .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                }
                links(stufe: q.stufe, medaillen: q.medaillen.count)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .fortschrittToast()
        .onAppear { FortschrittModul.waechter.pruefeAlles() }
    }

    private func links(stufe: Int, medaillen: Int) -> some View {
        ListenKarte {
            zeile("Verlauf", detail: "Konstanz und Gewicht", symbol: "chart.xyaxis.line") { VerlaufView() }
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
