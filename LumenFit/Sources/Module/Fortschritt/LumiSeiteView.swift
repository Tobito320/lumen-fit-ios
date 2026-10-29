import SwiftUI

/// Lumi (Idee 38): die Stufe 1 bis 9, der Pfad dorthin, die Serie in Wochen, die nächste Stufe und die nächste Medaille mit Balken.
struct LumiSeiteView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let stand = LumiPfad.stand(erreicht: q.medaillen.count, serieWochen: q.serieWochen)
        let ziel = LumiPfad.naechstesZiel(q.zahlen, schon: q.erreichteIds)
        ScrollView {
            VStack(spacing: Abstand.l) {
                hero(stand, stimmung: q.stimmung)
                if q.medaillen.isEmpty {
                    LeerZustand(stimmung: .bereit, satz: "Hake deinen ersten Satz ab, dann wächst Lumi.", handlung: "Training starten") {
                        umgebung.router.oeffne(.gym(.training))
                    }
                    .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                }
                pfad(stand)
                if let ziel { zielKarte(ziel) }
                NavigationLink { MeilensteineView() } label: {
                    Label("Alle Medaillen", systemImage: "medal.fill").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .navigationTitle("Lumi")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .fortschrittToast()
        .onAppear { FortschrittModul.waechter.pruefeAlles() }
    }

    private func hero(_ stand: LumiPfadStand, stimmung: LumiStimmung) -> some View {
        HeroKarte {
            VStack(spacing: Abstand.m) {
                LumiView(stimmung: stimmung, groesse: 120, stufe: stand.stufe)
                Text("Stufe \(stand.stufe) von \(LumiStufe.schwellen.count)").font(.title2.weight(.bold)).fontDesign(.rounded)
                Text(stand.serieText).font(.subheadline)
                VStack(spacing: Abstand.xs) {
                    ProgressView(value: stand.anteil).tint(palette.aufAkzent)
                    Text(stand.ziel).font(.footnote)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    /// Neun Knoten, drei Reihen: erreicht mit Haken und gefüllt, die übrigen mit der Zahl der Medaillen, ab der sie gelten.
    private func pfad(_ stand: LumiPfadStand) -> some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Dein Pfad").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Abstand.m), count: 3), spacing: Abstand.m) {
                ForEach(stand.knoten) { k in
                    VStack(spacing: Abstand.xs) {
                        ZStack {
                            if k.erreicht {
                                Circle().fill(palette.text)
                                Image(systemName: "checkmark").font(.headline).foregroundStyle(palette.grund)
                            } else {
                                Circle().stroke(palette.rand, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                Text("\(k.stufe)").font(.headline).foregroundStyle(palette.text2)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                        Text("Stufe \(k.stufe)").font(.footnote.weight(.semibold))
                        Text(k.ab == 0 ? "Start" : "ab \(k.ab) \(k.ab == 1 ? "Medaille" : "Medaillen")").font(.caption2).foregroundStyle(palette.text2)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Stufe \(k.stufe), \(k.erreicht ? "erreicht" : "ab \(k.ab) Medaillen")")
                }
            }
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
    }

    private func zielKarte(_ ziel: MeilensteinZiel) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Nächste Medaille").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
            Label(ziel.meilenstein.titel, systemImage: ziel.meilenstein.symbol).font(.headline)
            ProgressView(value: ziel.anteil).tint(palette.text)
            Text(ziel.text).font(.footnote).foregroundStyle(palette.text2)
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
