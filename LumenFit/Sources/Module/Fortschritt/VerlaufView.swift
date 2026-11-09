import SwiftUI

/// Der Verlauf (Ideen 35 und 36), oben der Umschalter Woche | Verlauf.
/// Woche: Besuche, Minuten, Sätze, der Start von heute und die Muskelgruppen als Liste mit Balken und Erholungszeichen.
/// Verlauf: Konsistenz-Karte mit Kategorien, Gewichtsverlauf, Rekorde und Plateaus.
/// Tipp auf eine Gruppe oder Übung öffnet ihre Seite; "Besuche ohne Sätze" führt zu den Trainingstagen.
struct VerlaufView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig
    @State private var seite = VerlaufSeite.woche
    @State private var weitereOffen: Bool?
    @State private var ziel: VerlaufZiel?
    @State private var tipp = 0
    @State private var start = 0

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        ScrollView {
            VStack(spacing: Abstand.l) {
                Picker("Ansicht", selection: $seite) {
                    ForEach(VerlaufSeite.allCases) { Text($0.titel).tag($0) }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                switch seite {
                case .woche: woche(q)
                case .verlauf: verlauf(q)
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
            .animation(ruhig ? nil : Feder.schnell, value: seite)
        }
        .navigationTitle("Verlauf")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .fortschrittToast()
        .navigationDestination(item: $ziel) { VerlaufZielAnsicht(ziel: $0) }
        .haptik(.auswahl, bei: tipp)
        .haptik(.start, bei: start)
        .haptik(.auswahl, bei: seite)
    }

    // MARK: Woche

    @ViewBuilder
    private func woche(_ q: FortschrittQuelle) -> some View {
        let laeufe = VerlaufLogik.laeufe(q.sessions)
        let koerper = q.koerper
        let stand = VerlaufLogik.gruppen(laeufe, heute: q.heute)
        let stufen = Self.stufen(koerper)
        let liste = VerlaufWoche.liste(saetze: stand.mapValues(\.woche.saetze), ziele: koerper.ziele.saetze, erholung: stufen, reihenfolge: koerper.ziele.reihenfolge)
        let ohne = VerlaufLogik.ohneSaetze(q.sessions, gym: q.gym, heute: q.heute, jetzt: q.jetzt)
        VStack(alignment: .leading, spacing: Abstand.l) {
            VerlaufZusammenfassung(z: VerlaufWoche.zusammenfassung(q.sessions, laeufe: laeufe, gym: q.gym, heute: q.heute))
            VerlaufStartKnopf(text: startText(q)) { starten(q) }
            if !ohne.isEmpty {
                VerlaufHinweis(tage: ohne) {
                    tipp += 1
                    ziel = .trainingstage
                }
            }
            if laeufe.isEmpty {
                LeerZustand(stimmung: .bereit, satz: "Noch keine Sätze eingetragen. Im Tab Gym hakst du Sätze ab, dann stehen sie hier.")
                    .lumenKartenFlaeche()
            } else {
                gruppen(liste)
            }
        }
    }

    /// Ohne erfasstes Training keine Stufe: fehlende Erholung hieße sonst "erholt".
    static func stufen(_ koerper: KoerperDaten) -> [MuskelGruppe: ErholungsStufe] {
        var stufen: [MuskelGruppe: ErholungsStufe] = [:]
        for g in MuskelGruppe.allCases where koerper.stand(g, teil: nil) != nil { stufen[g] = koerper.stufe(g) }
        return stufen
    }

    private func gruppen(_ l: VerlaufWoche.Liste) -> some View {
        let offen = Binding(get: { weitereOffen ?? l.aktiv.isEmpty }, set: { weitereOffen = $0 })
        return lumenGruppen(l, offen: offen)
    }

    private func lumenGruppen(_ l: VerlaufWoche.Liste, offen: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: "Sätze pro Muskel")
            ListenKarte {
                ForEach(l.aktiv) { zeile in
                    gruppenKnopf(zeile)
                    Haarlinie()
                }
                if !l.weitere.isEmpty {
                    VerlaufKlapp(titel: "Weitere Gruppen (\(l.weitere.count))", offen: offen) {
                        ForEach(l.weitere) { zeile in
                            gruppenKnopf(zeile)
                            Haarlinie()
                        }
                    }
                    .padding(.horizontal, Abstand.l)
                }
            }
        }
    }

    private func gruppenKnopf(_ zeile: VerlaufWoche.Zeile) -> some View {
        Button {
            tipp += 1
            ziel = .gruppe(zeile.gruppe)
        } label: {
            VerlaufGruppenZeile(zeile: zeile)
        }
        .buttonStyle(.federnd)
    }

    /// Wie `GymStartStand.bauen`: läuft eine Einheit, geht es weiter; war eine eben beendet, fortsetzen; sonst starten.
    private func startArt(_ q: FortschrittQuelle) -> VerlaufStartArt {
        if q.sessions.contains(where: { TrainingLogik.laufend($0, jetzt: q.jetzt) }) { return .weiter }
        return TrainingLogik.fortsetzbar(q.sessions, jetzt: q.jetzt) != nil ? .fortsetzen : .starten
    }

    private func startText(_ q: FortschrittQuelle) -> String {
        VerlaufWoche.startText(startArt(q), tagName: daten?.training.heutigerTag()?.name)
    }

    private var daten: DatenSatz? { umgebung.daten }

    private func starten(_ q: FortschrittQuelle) {
        let sitzung = GymSitzung.von(umgebung)
        switch startArt(q) {
        case .weiter: break
        case .fortsetzen: sitzung.fortsetzen()
        case .starten: sitzung.starte(planTag: daten?.training.heutigerTag()?.id)
        }
        start += 1
        umgebung.router.oeffne(.gym(.training))
    }

    // MARK: Verlauf

    @ViewBuilder
    private func verlauf(_ q: FortschrittQuelle) -> some View {
        let trend = GewichtVerlauf.trend(werte: q.gewicht, zielKg: q.gewichtZielKg, heute: q.heute)
        let highlights = VerlaufHighlights.berechnen(VerlaufLogik.laeufe(q.sessions), heute: q.heute)
        VStack(alignment: .leading, spacing: Abstand.l) {
            if q.hatTraining || !q.gym.isEmpty {
                KonsistenzKarte(sessions: q.sessions)
            } else {
                LeerZustand(stimmung: .bereit, satz: "Noch kein Training. Tipp auf Starten, Lumi zählt mit.", handlung: "Training starten") {
                    umgebung.router.oeffne(.gym(.training))
                }
                .lumenKartenFlaeche()
            }
            GewichtVerlaufKarte(trend: trend) { umgebung.router.oeffne(.gewichtEintragen) }
            StimmungVerlaufKarte()
            if !highlights.isEmpty {
                VerlaufHighlightsListe(eintraege: highlights) { id in
                    tipp += 1
                    ziel = .uebung(id)
                }
            }
            Button {
                tipp += 1
                ziel = .trainingstage
            } label: {
                Label("Alle Trainingstage", systemImage: "list.bullet").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
            NavigationLink { RueckblickView() } label: {
                Label("Rückblick ansehen", systemImage: "calendar").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
        }
    }
}
