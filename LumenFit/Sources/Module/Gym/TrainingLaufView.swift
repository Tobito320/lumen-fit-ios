// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Das laufende Training im Look des Entwurfs `live` (Idee 21 bis 25, 28): Kopf mit Einklappen, Name, Tag wechseln, Zahnrad und "Beenden",
/// Kacheln Dauer (Lime, Tipp ändert den Start) / Volumen / Sets, Puls und kcal, Lumi-Zeile, die Pause-Karte, "5 Übungen · 15 Sets" mit
/// "Reihenfolge", jede Übung als Tabelle, "Übung hinzufügen" am Ende und unten "Set fertig". Ein Training geht ohne Zahlen zu tippen.
struct TrainingLaufView: View {
    @Bindable var sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var beenden = false
    @State private var suche = false
    @State private var tagWahl = false
    @State private var einstellungen = false
    @State private var cardioOffen = false
    @State private var cardioIndex = 0
    @State private var startzeit: GymSession?
    @Environment(\.bewegungAus) private var ruhig
    @Environment(\.scenePhase) private var phase
    /// Reihenfolge-Modus (Knopf über den Übungen): die Karten klappen zu und lassen sich ziehen, nach dem Ablegen wieder normal.
    @State private var umordnen = false
    @State private var pausenFrage = false
    /// Erste zwei Wochen (`LaufHilfe.ersteWochen`): Formtipp und "Wie war das Set?". Einmal je Training gerechnet, nicht im Körper.
    @State private var ersteWochen = false
    @AppStorage(GymAnzeige.pausenTimerSchluessel) private var pausenTimer = false
    @AppStorage(GymAnzeige.pausenTimerGefragtSchluessel) private var pausenTimerGefragt = false

    var body: some View {
        let _ = sitzung.pauseEndeZaehler // die Karte baut sich neu, wenn die Pause endet
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.m) {
                kopf
                kacheln
                liveWerte
                lumiZeile
                GymMitlaufZeile()
                if sitzung.pause != nil { NaechsterSatzKarte(sitzung: sitzung) }
                listenKopf
                ForEach(Array(sitzung.liste.enumerated()), id: \.element.id) { i, _ in
                    LaufUebungsKarte(sitzung: sitzung, index: i, kompakt: umordnen, formtipp: formtipp(i), gefuehl: ersteWochen) {
                        withAnimation(ruhig ? nil : Feder.schnell) { umordnen = false }
                    }
                }
                Button { suche = true } label: {
                    Label("Übung hinzufügen", systemImage: "plus").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.bordered)
                .tint(palette.akzent)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.l)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Abstand.s) {
                rueckgaengigLeiste
                satzFertigLeiste
            }
        }
        .animation(ruhig ? nil : Feder.schnell, value: sitzung.rueckgaengig)
        .gymCrewAbruf()
        .sheet(isPresented: $beenden) { TrainingBeendenView(sitzung: sitzung) }
        .sheet(isPresented: $suche) {
            UebungsSucheView(titel: "Übung hinzufügen", auswahl: { sitzung.uebungDazu($0) }, mehrfach: true, wegnehmen: { sitzung.uebungDazuZurueck($0.id) })
        }
        .sheet(isPresented: $tagWahl) { TagWechselBlatt(sitzung: sitzung) }
        .sheet(isPresented: $einstellungen) { GymEinstellungenBlatt(sitzung: sitzung) }
        .sheet(isPresented: $cardioOffen) { CardioAbschlussBlatt(sitzung: sitzung, index: cardioIndex) }
        .sheet(item: $startzeit) { EinheitStartzeitBlatt(session: $0) }
        .lumenToast($sitzung.toast)
        .haptik(.satzFertig, bei: sitzung.hakenZaehler)
        .haptik(.pauseEnde, bei: sitzung.pauseEndeZaehler)
        .haptik(.auswahl, bei: sitzung.hakenZurueckZaehler)
        .task(id: sitzung.sessionId) {
            sitzung.ladeWennNoetig()
            ersteWochen = LaufHilfe.ersteWochen(sitzung.training?.sessions ?? [], jetzt: umgebung.uhr())
        }
        // In den Hintergrund: geänderte Zeilen ohne Haken sofort schreiben, nicht erst nach dem Verzug (iOS kann die App gleich einfrieren).
        .onChange(of: phase) { _, neu in if neu == .background { sitzung.entwurfSenden() } }
        // Pausen-Timer ist Standard aus: beim ersten Haken einmal fragen, danach steht es unter Einstellungen, Präferenzen.
        .onChange(of: sitzung.hakenZaehler) { _, _ in if !pausenTimerGefragt { pausenFrage = true } }
        .alert("Pausen-Timer nutzen?", isPresented: $pausenFrage) {
            Button("Ja") { pausenTimer = true; pausenTimerGefragt = true; sitzung.pauseNachholen() }
            Button("Nein") { pausenTimerGefragt = true }
        } message: {
            Text("Nach jedem Set läuft dann eine Pause mit Haptik am Ende. Du änderst das jederzeit unter Einstellungen, Präferenzen.")
        }
    }

    /// Formtipp nur unter der Übung, die dran ist, und nur in den ersten Wochen.
    private func formtipp(_ i: Int) -> String? {
        guard ersteWochen, sitzung.dran?.uebung == i, sitzung.liste.indices.contains(i) else { return nil }
        return LaufHilfe.formtipp(sitzung.liste[i].planUebung.uebung)
    }

    // MARK: Kopf

    /// Einklappen (zu Heute, dort steht die Leiste "Training läuft"), Name, Tag wechseln, Einstellungen, "Beenden" in Lime.
    private var kopf: some View {
        HStack(spacing: Abstand.xs) {
            Button { umgebung.router.oeffne(.heute) } label: {
                Image(systemName: "chevron.down").font(.body.weight(.semibold)).foregroundStyle(palette.text)
                    .frame(width: 36, height: 36).background(palette.flaeche, in: .circle)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel("Training einklappen")
            .accessibilityHint("Das Training läuft weiter, die Leiste unten führt zurück")
            Text(sitzung.tag.map { $0.name.isEmpty ? String(localized: "Training") : $0.name } ?? String(localized: "Freies Training"))
                .font(.title3.weight(.bold)).foregroundStyle(palette.text).lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if WorkoutLogik.tagWechselbar(sitzung.liste) {
                Button { tagWahl = true } label: { Image(systemName: "arrow.left.arrow.right").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                    .accessibilityLabel("Anderen Trainingstag wählen")
            }
            Button { einstellungen = true } label: { Image(systemName: "gearshape").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                .accessibilityLabel("Einstellungen fürs Training")
            Button("Beenden") { beenden = true }
                .buttonStyle(.lumenHauptknopf)
                .accessibilityHint("Fragt, ob du fertig bist")
        }
        .foregroundStyle(palette.text)
    }

    /// Dauer (Lime, Tipp ändert die Startzeit) / Volumen / Sets.
    @ViewBuilder
    private var kacheln: some View {
        if let s = sitzung.laufende {
            LaufKachelReihe {
                Button { startzeit = s } label: {
                    LaufKachel("Dauer") { Text(s.start, style: .timer).foregroundStyle(palette.akzent) }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Ändert die Startzeit")
                Divider()
                LaufKachel("Volumen") { Text("\(TrainingLogik.kgText(sitzung.volumen.rounded())) kg") }
                Divider()
                LaufKachel("Sets") { Text(sitzung.saetzeZahl, format: .number) }
            }
        }
    }

    /// Puls und kcal vom Sensor (Uhr oder Band), alle 10 s neu gelesen; ohne Sensor steht nichts da.
    private var liveWerte: some View {
        TimelineView(.periodic(from: .now, by: 10)) { _ in
            let teile = [sitzung.puls.puls.map { "\($0) Puls" }, sitzung.puls.kcal.map { "\($0) kcal" }].compactMap { $0 }
            if !teile.isEmpty {
                Label(teile.joined(separator: " · "), systemImage: "heart.fill")
                    .font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).monospacedDigit()
                    .padding(.horizontal, Abstand.xs)
                    .accessibilityLabel(teile.joined(separator: ", "))
            }
        }
    }

    /// Lumi feuert an, atmet in der Pause mit und freut sich, wenn alles abgehakt ist (Lumi-Zustände anfeuern, pause, ziel).
    @ViewBuilder
    private var lumiZeile: some View {
        if sitzung.pause != nil {
            LaufLumiZeile(stimmung: .pause, text: "Atmen, trinken, gleich geht's weiter.")
        } else if sitzung.dran == nil, !sitzung.liste.isEmpty {
            LaufLumiZeile(stimmung: .ziel, text: "Alles geschafft. Beende das Training, wenn du fertig bist.")
        } else if !sitzung.liste.isEmpty {
            LaufLumiZeile(stimmung: .anfeuern, text: "Noch eine Wiederholung. Du schaffst das.")
        }
    }

    /// "5 Übungen · 15 Sets" und der Knopf "Reihenfolge": im Modus klappen die Sätze zu, Ziehen und Ablegen tauscht die Plätze.
    @ViewBuilder
    private var listenKopf: some View {
        let sets = sitzung.liste.reduce(0) { $0 + $1.saetze.count }
        HStack {
            Text(sitzung.liste.count == 1 ? "1 Übung · \(sets) Sets" : "\(sitzung.liste.count) Übungen · \(sets) Sets")
                .font(.footnote).foregroundStyle(palette.text2)
            Spacer(minLength: Abstand.s)
            if sitzung.liste.count > 1 {
                Button { withAnimation(ruhig ? nil : Feder.schnell) { umordnen.toggle() } } label: {
                    Label(umordnen ? "Fertig" : "Reihenfolge", systemImage: umordnen ? "checkmark" : "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(umordnen ? palette.akzent : palette.text)
                .accessibilityHint(umordnen ? "Beendet das Umordnen" : "Übungen ziehen und ablegen, die Sets klappen dabei zu")
            }
        }
        .padding(.horizontal, Abstand.xs)
        .padding(.top, Abstand.s)
    }

    /// "Set 2 gelöscht" mit "Rückgängig": 5 Sekunden, dann gleitet die Leiste weg.
    @ViewBuilder
    private var rueckgaengigLeiste: some View {
        if let r = sitzung.rueckgaengig {
            HStack(spacing: Abstand.m) {
                Text(r.text).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Spacer(minLength: 0)
                Button("Rückgängig") { withAnimation(Feder.schnell) { sitzung.satzRueckgaengigMachen() } }
                    .font(.subheadline.weight(.bold))
                    .frame(minHeight: Abstand.tippflaeche)
            }
            .padding(.horizontal, Abstand.m)
            .lumenKartenFlaeche()
            .overlay(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(palette.rand, lineWidth: 1))
            .padding(.horizontal, Abstand.l)
            .transition(ruhig ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .task(id: r.id) {
                try? await Task.sleep(for: .seconds(SatzRueckgaengigLogik.sekunden))
                guard !Task.isCancelled else { return }
                withAnimation(Feder.schnell) { sitzung.rueckgaengigVergessen() }
            }
        }
    }

    // MARK: Hauptknopf

    /// Unterleiste (Entwurf `liveBar`): "Set fertig", bei Cardio "Cardio eintragen", sind alle durch "Training beenden".
    private var satzFertigLeiste: some View {
        Group {
            if let dran = sitzung.dran {
                // Cardio hat keine Sätze zum Abhaken: der große Knopf öffnet dann die Eingabe, statt still nichts zu tun.
                if sitzung.liste.indices.contains(dran.uebung), sitzung.liste[dran.uebung].planUebung.istCardio {
                    Button {
                        cardioIndex = dran.uebung
                        cardioOffen = true
                    } label: {
                        Text("Cardio eintragen").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.lumenHauptknopf)
                } else {
                    Button { sitzung.satzFertig() } label: {
                        Text("Set fertig").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.lumenHauptknopf)
                }
            } else {
                Button { beenden = true } label: {
                    Label("Training beenden", systemImage: "checkmark").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.lumenHauptknopf)
            }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .lumenLeiste()
    }
}

/// Anderen Plantag wählen, solange nichts abgehakt ist ("heute Beine statt Push", Idee 27).
struct TagWechselBlatt: View {
    let sitzung: GymSitzung
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                if let plan = sitzung.training?.plan {
                    ForEach(plan.tage) { t in
                        Button {
                            sitzung.tagWechseln(zu: t)
                            schliessen()
                        } label: {
                            GymZeile(titel: t.name.isEmpty ? "Training" : t.name, untertitel: ZeitSchaetzung.umfang(t)) {
                                if t.id == sitzung.laufende?.tag { Image(systemName: "checkmark").accessibilityLabel("gewählt") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trainingstag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } } }
        }
        .presentationDetents([.medium])
    }
}
