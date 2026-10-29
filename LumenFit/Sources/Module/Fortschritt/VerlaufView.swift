import SwiftUI

/// Der Verlauf (Ideen 35 und 36): Konstanz-Raster, Gewichtsverlauf mit Prognose, Rekorde und Plateaus der Woche, Hinweis auf Besuche ohne Sätze.
struct VerlaufView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var mehrOffen = false

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let heute = q.heute
        let gitter = KonstanzRaster.gitter(q.sessions, gym: q.gym, heute: heute)
        let trend = GewichtVerlauf.trend(werte: q.gewicht, zielKg: q.gewichtZielKg, heute: heute)
        let laeufe = VerlaufLogik.laeufe(q.sessions)
        let highlights = VerlaufHighlights.kappen(VerlaufHighlights.berechnen(laeufe, heute: heute))
        let ohne = VerlaufLogik.ohneSaetze(q.sessions, gym: q.gym, heute: heute, jetzt: q.jetzt)
        ScrollView {
            VStack(spacing: Abstand.l) {
                if q.hatTraining || !q.gym.isEmpty {
                    KonstanzRasterKarte(gitter: gitter)
                } else {
                    LeerZustand(stimmung: .bereit, satz: "Noch kein Training. Tipp auf Starten, Lumi zählt mit.", handlung: "Training starten") {
                        umgebung.router.oeffne(.gym(.training))
                    }
                    .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                }
                GewichtVerlaufKarte(trend: trend) { umgebung.router.oeffne(.gewichtEintragen) }
                if !highlights.offen.isEmpty { highlightKarte(highlights) }
                if !ohne.isEmpty { ohneSaetzeKarte(ohne) }
                NavigationLink { RueckblickView() } label: {
                    Label("Rückblick ansehen", systemImage: "calendar").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .navigationTitle("Verlauf")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .fortschrittToast()
    }

    private func highlightKarte(_ h: (offen: [VerlaufHighlights.Eintrag], mehr: [VerlaufHighlights.Eintrag])) -> some View {
        let sichtbar = mehrOffen ? h.offen + h.mehr : h.offen
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Rekorde und Plateaus").font(.headline).foregroundStyle(palette.text)
            ForEach(sichtbar) { e in
                HStack(spacing: Abstand.m) {
                    Image(systemName: e.art == .rekord ? "medal.fill" : "equal.circle.fill").frame(width: 28).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.uebung.name).font(.subheadline.weight(.semibold))
                        Text(e.art == .rekord ? "Neuer Rekord: \(VerlaufLogik.zahl(e.e1rm)) kg (1RM)" : "Plateau bei \(VerlaufLogik.zahl(e.e1rm)) kg (1RM), seit drei Einheiten nicht gesteigert")
                            .font(.caption).foregroundStyle(palette.text2)
                    }
                }
                .foregroundStyle(palette.text)
                .accessibilityElement(children: .combine)
            }
            if !h.mehr.isEmpty && !mehrOffen {
                Button("Mehr (\(h.mehr.count))") { mehrOffen = true }.frame(minHeight: Abstand.tippflaeche)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
    }

    private func ohneSaetzeKarte(_ tage: [VerlaufLogik.TagOhneSaetze]) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Label(VerlaufWoche.ohneSaetzeText(tage.count), systemImage: "info.circle").font(.subheadline.weight(.semibold))
            ForEach(tage, id: \.tag) { t in
                Text("\(Datum.anzeige(t.tag)): \(VerlaufLogik.grund(t.art))").font(.caption).foregroundStyle(palette.text2)
            }
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
