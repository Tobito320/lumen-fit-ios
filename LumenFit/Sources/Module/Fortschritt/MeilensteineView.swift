import SwiftUI

/// Seite "Erfolge" (Entwurf, Besitzer 10.11.2026: "besser so levels usw richtig anziehend"): oben das Level Holz bis Diamant aus den Punkten
/// (`StatsPunkte`: Training +10, Set +1, Rekord +5, aus den Trainings gerechnet, nichts gespeichert), "+N Punkte diese Woche" mit Aufschlüsselung,
/// dann alle Medaillen nach Bereich als bunte Abzeichen (nur eingeschaltete Bereiche), darunter Lumis Pfad (Stufe, nächste Medaille).
/// Der Name bleibt `MeilensteineView` (Link `profil?bereich=meilensteine`). Beim Öffnen läuft die Medaillen-Prüfung einmal nach.
struct MeilensteineView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let einstellungen = umgebung.bereicheWirksam
        let abschnitte = MedaillenAnsicht.abschnitte(zeigt: { einstellungen.zeigt($0) }, erreicht: q.erreichteIds, ohneZiel: MeilensteinPruefung.ohneZiel(essenZielDa: q.essenZielDa))
        let zaehlung = MedaillenAnsicht.zaehlung(abschnitte, erreicht: q.erreichteIds)
        let level = FortErfolgeLogik.level(StatsPunkte.gesamt(q.sessions))
        let woche = StatsPunkte.zahlen(q.sessions, jetzt: q.jetzt)
        let pfad = LumiPfad.stand(erreicht: q.stufenZahl, serieWochen: q.serieWochen)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                FortLevelKarte(level: level, stimmung: q.stimmung)
                wochenKarte(woche)
                HStack(alignment: .firstTextBaseline) {
                    Text("Medaillen").font(.title2.weight(.bold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(zaehlung.erreicht) von \(zaehlung.gesamt)").font(.footnote).foregroundStyle(palette.text2)
                }
                .padding(.top, Abstand.s)
                if zaehlung.erreicht == 0 {
                    if einstellungen.zeigt(AppBereich.gym) {
                        LeerZustand(stimmung: .bereit, satz: String(localized: "Noch keine Medaille. Hake einen Satz ab, Lumi holt die erste."), handlung: String(localized: "Training starten")) {
                            umgebung.router.oeffne(.gym(.training))
                        }
                        .lumenKartenFlaeche()
                    } else {
                        LeerZustand(stimmung: .bereit, satz: String(localized: "Noch keine Medaille. Lumi holt die erste, sobald du ein Ziel erreichst.")).lumenKartenFlaeche()
                    }
                }
                MedaillenRaster(abschnitte: abschnitte, erreicht: q.medaillenDatum, zahlen: q.zahlen)
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text("Lumi").font(.title2.weight(.bold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                    Text("Stufe \(pfad.stufe) von \(LumiStufe.schwellen.count) · \(pfad.serieText). \(pfad.ziel)").font(.subheadline).foregroundStyle(palette.text2)
                }
                .padding(.top, Abstand.s)
                LumiPfadKarte(stand: pfad)
                if let ziel = LumiPfad.naechstesZiel(q.zahlen, schon: q.erreichteIds) { LumiZielKarte(ziel: ziel) }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .navigationTitle("Erfolge")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .fortschrittToast()
        .onAppear { FortschrittModul.waechter.pruefeAlles() }
    }

    /// "+57 Punkte diese Woche" und "3 Trainings +30 · 22 Sets +22 · 1 Rekord +5".
    private func wochenKarte(_ z: StatsZahlen) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text("+\(z.punkte) Punkte diese Woche").font(.headline).foregroundStyle(palette.akzent)
            Text(Self.aufschluesselung(z)).font(.subheadline).foregroundStyle(palette.text2)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .combine)
    }

    static func aufschluesselung(_ z: StatsZahlen) -> String {
        let trainings = z.trainings == 1 ? String(localized: "1 Training") : String(localized: "\(z.trainings) Trainings")
        let rekorde = z.rekorde == 1 ? String(localized: "1 Rekord") : String(localized: "\(z.rekorde) Rekorde")
        return "\(trainings) +\(z.trainings * StatsPunkte.jeTraining) · \(String(localized: "\(z.sets) Sets")) +\(z.sets * StatsPunkte.jeSet) · \(rekorde) +\(z.rekorde * StatsPunkte.jeRekord)"
    }
}

/// Karte "Level": Lumi, "Level 3", "Eisen", Punkte, Balken zum nächsten Level, "Noch N Punkte bis Stahl", die sechs Stufen als Punkte.
struct FortLevelKarte: View {
    let level: FortLevel
    let stimmung: LumiStimmung
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            HStack(spacing: Abstand.m) {
                LumiView(stimmung: level.index > 0 ? .ziel : stimmung, groesse: 64).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Level \(level.nummer)").font(.footnote).foregroundStyle(palette.text2)
                    Text(level.name).font(.largeTitle.weight(.heavy)).foregroundStyle(palette.text)
                    Text("\(level.punkte.formatted()) Punkte").font(.subheadline.weight(.medium)).foregroundStyle(palette.text2)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.text.opacity(0.1))
                    Capsule().fill(LinearGradient(colors: [palette.akzentFlaeche, LumenFarben.farbe(0x2EC4B6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(12, geo.size.width * level.anteil))
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)
            if let naechster = level.naechsterName {
                Text("Noch \(level.rest.formatted()) Punkte bis **\(naechster)**").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                Text("Höchstes Level erreicht").font(.subheadline).foregroundStyle(palette.text2)
            }
            HStack {
                ForEach(0..<FortErfolgeLogik.schwellen.count, id: \.self) { i in
                    VStack(spacing: 5) {
                        Circle()
                            .fill(i <= level.index ? (i == level.index ? palette.akzentFlaeche : palette.akzent) : palette.text.opacity(0.15))
                            .frame(width: 10, height: 10)
                            .padding(4)
                            .background(i == level.index ? palette.akzentFlaeche.opacity(0.3) : .clear, in: .circle)
                        Text(FortErfolgeLogik.name(i)).font(.caption2.weight(i == level.index ? .bold : .medium))
                            .foregroundStyle(i == level.index ? palette.text : i < level.index ? palette.text2 : palette.text2.opacity(0.7))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [palette.akzentFlaeche.opacity(0.32), .clear], startPoint: .topLeading, endPoint: .center),
                    in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .lumenKartenFlaeche()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.naechsterName.map { String(localized: "Level \(level.nummer), \(level.name), \(level.punkte) Punkte, noch \(level.rest) bis \($0)") }
                            ?? String(localized: "Level \(level.nummer), \(level.name), \(level.punkte) Punkte"))
    }
}
