import SwiftUI

/// Was die Seite "Sets je Muskel" zeigt: die Hitzekarte und Liste der Sets oder die Erholung (frühere Seite "Muskelkarte").
private enum FortSetsAnsicht: String, CaseIterable {
    case sets, erholung
}

/// Seite "Sets je Muskel" (Entwurf): Satz "Gut sind 10 bis 20", Figur vorne/hinten als Hitzekarte (0, 1-4, 5-9, 10+), Liste je Muskelgruppe
/// gegen das Wochenziel aus der Befragung. Umschalter "Erholung" zeigt die frühere Muskelkarte (Wochenleiste, Erholungs-Silhouette, Felder) und
/// "Nächstes Training". Oben rechts "Ziele" (Befragung). Tipp auf Figur oder Zeile öffnet das Blatt der Muskelgruppe.
struct FortSetsSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var ansicht = FortSetsAnsicht.sets
    @State private var auswahl: KoerperAuswahl?
    @State private var befragung = false
    @State private var tipp = 0

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let koerper = q.koerper
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                Picker("Ansicht", selection: $ansicht) {
                    Text("Sets").tag(FortSetsAnsicht.sets)
                    Text("Erholung").tag(FortSetsAnsicht.erholung)
                }
                .pickerStyle(.segmented)
                if !q.zieleGesetzt { ZielFestlegenKarte { befragung = true } }
                switch ansicht {
                case .sets: sets(q, koerper: koerper)
                case .erholung: erholung(q, koerper: koerper)
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Sets je Muskel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ziele", systemImage: "slider.horizontal.3") { befragung = true }
            }
        }
        .haptik(.auswahl, bei: tipp)
        .haptik(.auswahl, bei: ansicht)
        .sheet(item: $auswahl) { a in KoerperBlattView(gruppe: a.gruppe, teil: a.teil) }
        .sheet(isPresented: $befragung) { ZieleBefragungView().presentationDetents([.large]) }
    }

    private func waehle(_ gruppe: MuskelGruppe, _ teil: MuskelTeil?) {
        tipp += 1
        auswahl = KoerperAuswahl(gruppe: gruppe, teil: teil)
    }

    @ViewBuilder
    private func sets(_ q: FortschrittQuelle, koerper: KoerperDaten) -> some View {
        let teile = FortSets.teile(q.sessions, heute: q.heute)
        let zeilen = FortSets.zeilen(q.sessions, heute: q.heute, ziele: koerper.ziele)
        Text("Diese Woche. Gut sind 10 bis 20 Sets je Muskel.").font(.subheadline).foregroundStyle(palette.text2).padding(.horizontal, Abstand.xs)
        VStack(spacing: Abstand.m) {
            HStack(alignment: .top, spacing: Abstand.l) {
                ForEach(SilhouetteSeite.allCases, id: \.self) { seite in
                    VStack(spacing: Abstand.xs) {
                        FortSetsFigur(seite: seite, teile: teile) { waehle($0.gruppe, nil) }
                            .frame(maxHeight: 240)
                        (seite == .vorne ? Text("Vorne") : Text("Hinten")).font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            legende
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Körperkarte der Sets diese Woche. Die Liste darunter nennt jede Muskelgruppe.")
        ListenKarte {
            ForEach(Array(zeilen.enumerated()), id: \.element.id) { i, z in
                if i > 0 { Haarlinie() }
                Button { waehle(z.gruppe, nil) } label: { zeile(z) }.buttonStyle(.plain)
            }
        }
        if q.zieleGesetzt {
            let ziele = SaetzeProMuskel.zeilen(q.sessions, heute: q.heute, ziele: koerper.ziele)
            Text("\(SaetzeProMuskel.aussage(ziele)). \(SaetzeProMuskel.kernzeile(ziele))").font(.footnote).foregroundStyle(palette.text2).padding(.horizontal, Abstand.xs)
        }
    }

    private func zeile(_ z: FortSetsZeile) -> some View {
        HStack(spacing: Abstand.m) {
            Text(z.gruppe.name).font(.body).foregroundStyle(palette.text).frame(width: 96, alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.haar)
                    Capsule().fill(palette.akzent).frame(width: geo.size.width * z.anteil)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
            HStack(spacing: 2) {
                if z.erreicht { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(palette.akzent).accessibilityHidden(true) }
                Text(z.ziel > 0 ? "\(VerlaufLogik.zahl(z.saetze))/\(z.ziel)" : VerlaufLogik.zahl(z.saetze)).font(.body.weight(.bold)).monospacedDigit().foregroundStyle(palette.text)
            }
            .frame(minWidth: 44, alignment: .trailing)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(z.ziel > 0 ? "\(z.gruppe.name), \(VerlaufLogik.zahl(z.saetze)) von \(z.ziel) Sets" : "\(z.gruppe.name), \(VerlaufLogik.zahl(z.saetze)) Sets")
        .accessibilityHint("Öffnet die Muskelgruppe")
    }

    private var legende: some View {
        HStack(spacing: Abstand.m) {
            Text("Sets diese Woche").font(.caption).foregroundStyle(palette.text2)
            ForEach(0..<4, id: \.self) { stufe in
                HStack(spacing: Abstand.xs) {
                    RoundedRectangle(cornerRadius: 3).fill(FortSetsFigur.farbe(stufe, palette: palette)).frame(width: 12, height: 12)
                    Text(["0", "1–4", "5–9", "10+"][stufe]).font(.caption).foregroundStyle(palette.text2)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private func erholung(_ q: FortschrittQuelle, koerper: KoerperDaten) -> some View {
        KoerperWochenLeiste(woche: koerper.streifen)
        if q.hatTraining { SilhouetteKarte(daten: koerper, beiGruppe: waehle) }
        SaetzeFelderKarte(daten: koerper) { waehle($0, nil) }
        ListenKarte {
            FortListenZeile("Nächstes Training", wert: String(localized: "Was heute passt"), symbol: "figure.strengthtraining.traditional", farbe: Bereichsfarbe.verlauf) {
                NaechstesTrainingSeite()
            }
        }
    }
}

/// Die Körperkarte einer Seite, eingefärbt nach Sets der Woche (vier Stufen in Lime). Tipp trifft eine Fläche (`SilhouetteTreffer`).
struct FortSetsFigur: View {
    let seite: SilhouetteSeite
    let teile: [MuskelTeil: Double]
    var beiTipp: (SilhouetteFlaeche) -> Void
    @State private var groesse: CGSize = .zero
    @Environment(\.palette) private var palette

    static func farbe(_ stufe: Int, palette: Palette) -> Color {
        switch stufe {
        case 0: palette.haar
        case 1: palette.akzent.opacity(0.35)
        case 2: palette.akzent.opacity(0.65)
        default: palette.akzent
        }
    }

    var body: some View {
        let flaechen = SilhouetteBild.flaechen(seite).map { f in (f, FortSets.stufe(f.teile.reduce(0.0) { $0 + (teile[$1] ?? 0) })) }
        let umriss = palette.rand.opacity(0.5), rand = palette.grund
        let farben = (0..<4).map { Self.farbe($0, palette: palette) }
        Canvas { kontext, groesse in
            let rahmen = CGRect(origin: .zero, size: groesse)
            for form in SilhouetteBild.umriss { kontext.fill(form.pfad(in: rahmen), with: .color(umriss)) }
            for (flaeche, stufe) in flaechen {
                let pfad = flaeche.pfad(in: rahmen)
                kontext.fill(pfad, with: .color(farben[stufe]))
                kontext.stroke(pfad, with: .color(rand), lineWidth: 0.6)
            }
        }
        .aspectRatio(SilhouetteBild.breite / SilhouetteBild.hoehe, contentMode: .fit)
        .onGeometryChange(for: CGSize.self, of: \.size) { groesse = $0 }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tipp in
            guard let treffer = SilhouetteTreffer.flaeche(seite, bei: tipp.location, in: CGRect(origin: .zero, size: groesse)) else { return }
            beiTipp(treffer)
        })
        .accessibilityHidden(true)
    }
}
