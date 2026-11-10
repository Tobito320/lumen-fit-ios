import SwiftUI

/// Montag bis Sonntag mit kleinen Bögen je Tag (Idee 20): außen Schritte, Mitte Gym, innen Schlaf (nur die gewählten Bereiche). Ein Tipp öffnet den Tag. Ohne Partner-Punkte: die gibt es nur in der Woche des Training-Tabs.
/// Seit dem neuen Design (10.11.2026) nur noch auf Heute, wenn Gym aus ist (sonst trägt die Plan-Karte die Woche).
struct WochenStreifen: View {
    let woche: [HeuteWochenTag]
    var bereiche = Einstellungen()
    let oeffne: (String) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HeuteKartenKopf(symbol: "calendar", titel: "Diese Woche")
                HStack(spacing: 0) {
                    ForEach(woche) { tag in
                        Button { oeffne(tag.tag) } label: {
                            VStack(spacing: Abstand.xs) {
                                ZStack {
                                    HeuteMiniBogen(anteil: tag.schritte, bereich: .bewegen, strich: 3)
                                    if bereiche.gymAn { HeuteMiniBogen(anteil: tag.gym, bereich: .trainieren, strich: 3).padding(5) }
                                    if bereiche.schlafAn { HeuteMiniBogen(anteil: tag.schlaf, bereich: .erholen, strich: 3).padding(bereiche.gymAn ? 10 : 5) }
                                }
                                .frame(width: 38, height: 38)
                                Text(tag.kuerzel)
                                    .font(.caption.weight(tag.istHeute ? .bold : .medium))
                                    .foregroundStyle(tag.istHeute ? palette.text : palette.text2)
                                Capsule().fill(tag.istHeute ? palette.text : Color.clear).frame(width: 14, height: 2)
                            }
                            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                            .opacity(tag.zukunft ? 0.45 : 1)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(tag.zukunft)
                        .accessibilityLabel(WochenStreifenLogik.beschreibung(tag, bereiche: bereiche))
                        .accessibilityHint(tag.zukunft ? "" : "Öffnet den Tag")
                    }
                }
            }
            .padding(Abstand.l)
        }
    }
}

/// Das Tag-Blatt (neues Design 10.11.2026, Lückenliste 2.1): öffnet sich aus der Woche der Plan-Karte (und aus dem Kalender in Fortschritt).
/// Oben die Tagwahl, die vorher auf der Startseite stand (Tag davor/danach, Kalender, "Zurück zu heute", waagerecht wischen), darunter der Tag:
/// Ringplatte des Tages, Schritte/Gym/Schlaf/Wasser/Gewicht, Gewohnheiten zum Nachtragen (mit Verwaltung), Gewicht und Stimmung.
/// Eigenes `HeuteModell` auf den gewählten Tag, damit Haken für genau diesen Tag gelten.
struct HeuteTagView: View {
    let tag: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @State private var modell: HeuteModell?
    @State private var kalender = false
    @State private var verwalten = false
    @State private var habitSeite: String?
    @State private var gewechselt = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                if let modell, let s = modell.stand {
                    inhalt(s, modell)
                }
            }
            .navigationTitle(modell?.stand.map { Datum.anzeige($0.tag) } ?? Datum.anzeige(tag))
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .navigationDestination(item: $habitSeite) { HabitDetailView(habitId: $0) }
            .sheet(isPresented: $verwalten) { HabitVerwaltungView() }
            .sheet(isPresented: $kalender) {
                if let s = modell?.stand { HeuteKalenderBlatt(tag: s.tag, heute: heute) { waehle($0) } }
            }
        }
        .haptik(.auswahl, bei: gewechselt)
        .task {
            let m = modell ?? HeuteModell(umgebung: umgebung)
            if modell == nil { m.waehleTag(tag) }
            modell = m
            await m.beobachte()
        }
    }

    private var heute: String { Datum.text(umgebung.uhr()) }

    private func inhalt(_ s: HeuteStand, _ m: HeuteModell) -> some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            HeuteTagLeiste(tag: s.tag, heute: heute, blaettere: { waehle(HeuteTagWahl.schritt(s.tag, tage: $0, heute: heute)) },
                           kalender: { kalender = true }, zuHeute: { waehle(heute) })
            if s.hatTagesdaten {
                if s.hatGesundheit { Ringplatte(stand: s, stufe: umgebung.daten?.meilensteine.stufe ?? 1) }
                if let daten = umgebung.daten { HeuteTagZeilen(tag: s.tag, daten: daten) }
            } else {
                LeerZustand(stimmung: .schlaeft, satz: String(localized: "Keine Daten für diesen Tag."))
            }
            HabitsKarte(habits: s.habits, tag: s.tag, tippe: { m.tippe($0) }, weniger: { m.weniger($0) }, oeffne: { habitSeite = $0.habit.id },
                        verwalte: { verwalten = true })
            if s.hatTagesdaten, s.gewicht.aktuellKg != nil { GewichtKarte(gewicht: s.gewicht) }
            StimmungTagKarte(tag: s.tag)
        }
        .padding(Abstand.l)
        .id(s.tag)
        .transition(.opacity)
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { geste in
            guard let schritt = HeuteTagWahl.wischSchritt(breite: geste.translation.width, hoehe: geste.translation.height) else { return }
            waehle(HeuteTagWahl.schritt(s.tag, tage: schritt, heute: heute))
        })
    }

    private func waehle(_ neu: String) {
        guard let m = modell, m.stand?.tag != HeuteTagWahl.begrenze(neu, heute: heute) else { return }
        gewechselt += 1
        withAnimation(.easeInOut(duration: 0.2)) { m.waehleTag(neu) }
    }
}

/// Schritte, Gym, Schlaf, Wasser und Gewicht eines Tages als Liste (Blatt der Woche und Tagwahl des Heute-Tabs). Ohne Wert steht "keine Daten".
struct HeuteTagZeilen: View {
    let tag: String
    let daten: DatenSatz
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View { zeilen(daten) }

    private func zeilen(_ daten: DatenSatz) -> some View {
        let werte = umgebung.gesundheit.tage[tag]
        let nacht = TagesformQuellen.nacht(tag, daten: daten, gesundheit: umgebung.gesundheit)
        let einheit = GymTageLogik.einheit(am: tag, in: daten.training.sessions)
        let gymHaken = daten.habits.wert(Habit.gym.id, tag) > 0
        let wasser = daten.habits.wert(Habit.wasser.id, tag)
        let gewicht = daten.habits.wert(Habit.gewicht.id, tag)
        let ziele = daten.ziele.ziele
        let bereiche = umgebung.bereicheWirksam
        return ListenKarte {
            zeile("figure.walk", "Schritte", (werte?.schritte).map { $0 > 0 ? "\(HeuteQuellen.zahl($0)) von \(HeuteQuellen.zahl(ziele.schritte))" : "keine Daten" } ?? "keine Daten")
            if bereiche.gymAn {
                Haarlinie()
                zeile("dumbbell.fill", "Gym", einheit != nil ? "Training gespeichert" : (gymHaken ? "abgehakt" : "kein Training"))
            }
            if bereiche.schlafAn {
                Haarlinie()
                zeile("bed.double.fill", "Schlaf", nacht.map { "\(BereitScore.stunden($0.minuten)) von \(BereitScore.stunden(ziele.schlafMinuten))" } ?? "keine Daten")
            }
            Haarlinie()
            zeile("drop.fill", "Wasser", wasser > 0 ? "\(wasser) Gläser" : "nichts eingetragen")
            if gewicht > 0 {
                Haarlinie()
                zeile("scalemass.fill", "Gewicht", GewichtText.anzeige(gewicht))
            }
            if let m = werte, m.distanzMeter > 0 || m.etagen > 0 {
                Haarlinie()
                zeile("figure.stair.stepper", "Distanz und Etagen", "\(String(format: "%.1f", m.distanzMeter / 1000).replacingOccurrences(of: ".", with: ",")) km, \(m.etagen) Etagen")
            }
        }
    }

    private func zeile(_ symbol: String, _ titel: String, _ wert: String) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: symbol).foregroundStyle(palette.text2).frame(width: 24).accessibilityHidden(true)
            Text(titel).font(.body).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            Text(wert).font(.body).foregroundStyle(palette.text2).multilineTextAlignment(.trailing)
        }
        .padding(Abstand.l)
        .accessibilityElement(children: .combine)
    }
}
