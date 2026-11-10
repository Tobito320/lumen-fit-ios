import SwiftUI

/// Seite nach dem Beenden (Entwurf `geschafft`, Route `.gym(.geschafft)` auf Heute): Lumi, Kacheln Dauer / Sets / Volumen, neue Rekorde,
/// trainierte Muskeln vorne und hinten, als Bild teilen. "Fertig" führt zurück zu Heute. Rechnet aus dem gespeicherten Training.
struct GeschafftView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var stand: GeschafftStand?

    var body: some View {
        ScrollView {
            if let stand {
                inhalt(stand).padding(.horizontal, Abstand.l).padding(.bottom, Abstand.xl)
            } else {
                LeerZustand(stimmung: .denkt, satz: String(localized: "Noch kein beendetes Training. Beende eins, dann steht es hier."))
                    .padding(Abstand.l)
            }
        }
        .lumenHintergrund()
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { umgebung.router.oeffne(.heute) }
                    .buttonStyle(.lumenHauptknopf)
            }
        }
        // Nicht im Körper: `GymSitzung.von` setzt den Port; das Training kommt aus dem Store, die Sitzung ist nach dem Beenden leer.
        .task {
            guard let d = umgebung.daten, let s = GeschafftLogik.letzte(d.training.sessions) else { return }
            let sitzung = GymSitzung.von(umgebung)
            stand = GeschafftLogik.stand(s, tag: d.training.tag(id: s.tag), alle: d.training.sessions,
                                         katalog: { sitzung.katalog($0) }, jetzt: umgebung.uhr())
        }
    }

    @ViewBuilder
    private func inhalt(_ g: GeschafftStand) -> some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            TeilbareKarte(titel: String(localized: "Geschafft!"), schluessel: "\(g.datum.timeIntervalSince1970)") {
                kopf(g)
            }
            if !g.rekorde.isEmpty { rekorde(g) }
            if !g.muskeln.isEmpty { muskeln(g) }
        }
    }

    private func kopf(_ g: GeschafftStand) -> some View {
        VStack(spacing: Abstand.m) {
            LumiView(stimmung: g.stimmung, groesse: 120).accessibilityHidden(true)
            Text("Geschafft!").font(.largeTitle.weight(.heavy)).fontDesign(.rounded).foregroundStyle(palette.text)
            Text("\(g.titel) · \(g.datum.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
                .font(.subheadline).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            LaufKachelReihe {
                LaufKachel("Dauer") { Text(TrainingLogik.dauerText(g.sekunden)) }
                Divider()
                LaufKachel("Sets") { Text(g.saetze, format: .number) }
                Divider()
                LaufKachel("Volumen") { Text("\(TrainingLogik.kgText(g.volumen.rounded())) kg") }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func rekorde(_ g: GeschafftStand) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text(g.rekorde.count == 1 ? "Neuer Rekord" : "\(g.rekorde.count) neue Rekorde").font(.headline).foregroundStyle(palette.text)
            ListenKarte {
                ForEach(Array(g.rekorde.prefix(3).enumerated()), id: \.offset) { i, r in
                    if i > 0 { Haarlinie() }
                    HStack(spacing: Abstand.m) {
                        Image(systemName: "trophy.fill").font(.subheadline).foregroundStyle(.orange)
                            .frame(width: 36, height: 36).background(Color.orange.opacity(0.18), in: .circle)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.uebung).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                            Text(r.text).font(.footnote).foregroundStyle(palette.text2).monospacedDigit()
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Abstand.m)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func muskeln(_ g: GeschafftStand) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Trainiert").font(.headline).foregroundStyle(palette.text)
            HStack(spacing: Abstand.l) {
                ForEach(SilhouetteSeite.allCases, id: \.self) { seite in
                    VStack(spacing: Abstand.xs) {
                        GeschafftFigur(seite: seite, muskeln: g.muskeln).frame(height: 180)
                        Text(seite.name).font(.footnote).foregroundStyle(palette.text2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(Abstand.m)
            .lumenKartenFlaeche()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Trainiert: \(Set(g.muskeln.map(\.gruppe.name)).sorted().joined(separator: ", "))"))
        }
    }
}

/// Körper vorne oder hinten, trainierte Muskeln in Lime, der Rest als Umriss (eigene kleine Zeichnung: `SilhouetteAnsicht` hängt an der Erholung).
private struct GeschafftFigur: View {
    let seite: SilhouetteSeite
    let muskeln: Set<MuskelTeil>
    @Environment(\.palette) private var palette

    var body: some View {
        let flaechen = SilhouetteBild.flaechen(seite)
        let an = palette.akzent, umriss = palette.haar, rand = palette.text2
        let muskeln = self.muskeln
        Canvas { kontext, groesse in
            let rahmen = CGRect(origin: .zero, size: groesse)
            for form in SilhouetteBild.umriss { kontext.fill(form.pfad(in: rahmen), with: .color(umriss)) }
            for f in flaechen {
                let pfad = f.pfad(in: rahmen)
                if f.teile.contains(where: { muskeln.contains($0) }) {
                    kontext.fill(pfad, with: .color(an))
                } else {
                    kontext.stroke(pfad, with: .color(rand.opacity(0.5)), lineWidth: 0.75)
                }
            }
        }
        .aspectRatio(SilhouetteBild.breite / SilhouetteBild.hoehe, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
