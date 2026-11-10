import SwiftUI

/// Seite eines Trainingstags (Entwurf `tag`): Name, "5 Übungen · ca. 65 min · Donnerstag", die Übungen mit Bild und Sets (Tipp öffnet die Übung).
/// Heute: "Training starten". Ein anderer Tag: "Heute stattdessen" (früher Menü "Anderer Tag") und "Diesen Tag verlegen" (früher "Diese Woche").
struct GymTagSeite: View {
    let sitzung: GymSitzung
    let datum: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var schliessen
    @State private var fehler: String?

    var body: some View {
        ScrollView {
            if let training = sitzung.training, let tag = TrainingLogik.tag(training.plan, datum: datum) {
                inhalt(tag, training: training)
                    .padding(.horizontal, Abstand.l)
                    .padding(.bottom, Abstand.xl)
            } else {
                LeerZustand(stimmung: .ruhetag, satz: String(localized: "An diesem Tag ist Ruhetag."))
            }
        }
        .lumenHintergrund()
        .navigationTitle(titel)
        .navigationBarTitleDisplayMode(.large)
        .alert("Das geht gerade nicht", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
            Button("Verstanden") { fehler = nil }
        } message: {
            Text(fehler ?? "")
        }
    }

    private var titel: String {
        guard let training = sitzung.training, let tag = TrainingLogik.tag(training.plan, datum: datum) else { return String(localized: "Training") }
        return tag.name.isEmpty ? String(localized: "Training") : tag.name
    }

    private func inhalt(_ tag: TrainingsTag, training: TrainingStore) -> some View {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let istHeute = datum == heute
        let wochentage = tag.wochentage.isEmpty ? TrainingLogik.wochentagName[Datum.wochentag(datum) - 1] : TrainingLogik.wochentageText(tag.wochentage)
        let laeuft = training.laufende() != nil
        let heuteTag = training.heutigerTag()
        return VStack(alignment: .leading, spacing: Abstand.l) {
            Text("\(ZeitSchaetzung.umfang(tag)) · \(wochentage)").font(.subheadline).foregroundStyle(palette.text2)
            if tag.uebungen.isEmpty {
                Text("Noch keine Übungen. Füg sie unter Eigener Plan hinzu.").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                ListenKarte {
                    ForEach(Array(tag.uebungen.enumerated()), id: \.element.id) { i, u in
                        if i > 0 { Haarlinie() }
                        zeile(u)
                    }
                }
            }
            // Nicht, solange etwas läuft oder sich fortsetzen lässt: der Tab bietet dann "Weiter" oder "Fortsetzen", sonst entstünde eine zweite Einheit.
            if !laeuft, training.fortsetzbare() == nil {
                if istHeute || tag.id == heuteTag?.id {
                    Button {
                        sitzung.starte(planTag: tag.id)
                        schliessen()
                    } label: {
                        Label("Training starten", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.lumenHauptknopf)
                } else {
                    // Früher "Anderer Tag" im Training-Tab: diesen Plantag heute machen, der Plan bleibt.
                    Button {
                        sitzung.starte(planTag: tag.id)
                        schliessen()
                    } label: {
                        Label("Heute stattdessen", systemImage: "arrow.left.arrow.right").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Startet diesen Tag heute, der Plan bleibt")
                }
            }
            verlegen(training, heute: heute)
        }
    }

    @ViewBuilder
    private func zeile(_ u: PlanUebung) -> some View {
        let katalog = sitzung.katalog(u)
        let muskel = katalog.map { $0.muskel }
        let sets = u.istCardio ? String(localized: "\(u.minuten ?? 0) min") : TrainingLogik.saetzeText(u)
        let untertitel = [muskel, sets].compactMap { $0 }.joined(separator: " · ")
        if katalog != nil {
            NavigationLink { UebungDetailView(id: u.uebung, anleitungZuerst: true) } label: {
                GymUebungZeile(id: u.uebung, koerper: katalog?.koerper, titel: u.anzeigeName, untertitel: untertitel)
            }
            .buttonStyle(.plain)
        } else {
            GymUebungZeile(id: u.uebung, koerper: nil, titel: u.anzeigeName, untertitel: untertitel, pfeil: false)
        }
    }

    /// Verlegen nur diese Woche (`WochenLogik`), "Zurück auf Plan", wenn schon etwas verlegt ist.
    @ViewBuilder
    private func verlegen(_ training: TrainingStore, heute: String) -> some View {
        let ziele = training.verlegeZiele(von: datum)
        let verlegt = WochenLogik.verlegt(training.plan, heute: heute)
        if !ziele.isEmpty || verlegt {
            ListenKarte {
                if !ziele.isEmpty {
                    GymZeile(titel: String(localized: "Diesen Tag verlegen"), untertitel: String(localized: "Nur diese Woche, der Plan bleibt.")) {
                        Menu("Verlegen") {
                            ForEach(ziele, id: \.datum) { z in
                                Button(z.text) { if !training.verlegen(von: datum, auf: z.datum) { fehler = String(localized: "Dieser Tag lässt sich nicht verlegen.") } }
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                    }
                }
                if verlegt {
                    if !ziele.isEmpty { Haarlinie() }
                    GymZeile(titel: String(localized: "Zurück auf Plan"), untertitel: String(localized: "Verlegte Tage gelten wieder wie im Plan.")) {
                        Button("Zurücksetzen") { training.verlegungenLoeschen() }.buttonStyle(.bordered).controlSize(.large)
                    }
                }
            }
        }
    }
}
