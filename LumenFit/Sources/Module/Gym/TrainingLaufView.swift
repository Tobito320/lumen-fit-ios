// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Das laufende Training (Idee 21 bis 25, 28): die Karte "Als Nächstes" oder die Pause, jede Übung mit ihren Satzzeilen, der große Knopf
/// "Satz fertig". Ein Training geht von Einchecken bis Beenden ohne Zahlen zu tippen.
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

    var body: some View {
        let _ = sitzung.pauseEndeZaehler // die Karte baut sich neu, wenn die Pause endet
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                kopf
                GymMitlaufZeile()
                NaechsterSatzKarte(sitzung: sitzung)
                ForEach(sitzung.liste.indices, id: \.self) { i in
                    UebungsKarte(sitzung: sitzung, index: i)
                }
                Button { suche = true } label: {
                    Label("Übung hinzufügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.bordered)
                // Sind alle Sätze durch, ist "Training beenden" schon der große Knopf unten: dann nicht noch einmal.
                if sitzung.dran != nil {
                    Button(role: .destructive) { beenden = true } label: {
                        Label("Training beenden", systemImage: "stop.fill").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                    .gymTipp(.trainingBeenden, tippKontext)
                }
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
            UebungsSucheView(titel: "Übung hinzufügen", auswahl: { sitzung.uebungDazu($0) }, mehrfach: true)
        }
        .sheet(isPresented: $tagWahl) { TagWechselBlatt(sitzung: sitzung) }
        .sheet(isPresented: $einstellungen) { GymEinstellungenBlatt(sitzung: sitzung) }
        .sheet(isPresented: $cardioOffen) { CardioAbschlussBlatt(sitzung: sitzung, index: cardioIndex) }
        .sheet(item: $startzeit) { EinheitStartzeitBlatt(session: $0) }
        .lumenToast($sitzung.toast)
        .haptik(.satzFertig, bei: sitzung.hakenZaehler)
        .haptik(.pauseEnde, bei: sitzung.pauseEndeZaehler)
        .haptik(.auswahl, bei: sitzung.hakenZurueckZaehler)
        .task { sitzung.ladeWennNoetig() }
    }

    // MARK: Kopf

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sitzung.tag.map { $0.name.isEmpty ? "Training" : $0.name } ?? "Freies Training")
                    .font(.title3.weight(.bold)).foregroundStyle(palette.text)
                if let s = sitzung.laufende {
                    HStack(spacing: Abstand.xs) {
                        Button { startzeit = s } label: {
                            HStack(spacing: Abstand.xs) {
                                Text(s.start, style: .timer).monospacedDigit()
                                Image(systemName: "pencil").font(.caption).accessibilityHidden(true)
                            }
                            .frame(minHeight: Abstand.tippflaeche)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dauer des Trainings")
                        .accessibilityHint("Ändert die Startzeit")
                        Text("· \(sitzung.saetzeZahl) Sätze")
                        if sitzung.volumen > 0 { Text("· \(TrainingLogik.kgText(sitzung.volumen.rounded())) kg").monospacedDigit().gymTipp(.volumen, tippKontext) }
                    }
                    .font(.subheadline).foregroundStyle(palette.text2)
                    liveWerte
                }
            }
            Spacer()
            if WorkoutLogik.tagWechselbar(sitzung.liste) {
                Button { tagWahl = true } label: { Image(systemName: "arrow.left.arrow.right").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                    .accessibilityLabel("Anderen Trainingstag wählen")
                    .gymTipp(.trainingstagWechseln, tippKontext)
            }
            Button { einstellungen = true } label: { Image(systemName: "gearshape").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                .accessibilityLabel("Einstellungen fürs Training")
        }
    }

    /// Was die Hinweise (`GymTippRegeln`) vom laufenden Training wissen müssen.
    private var tippKontext: GymTippKontext {
        GymTippKontext(trainingLaeuft: true, volumen: sitzung.volumen, tagWechselbar: WorkoutLogik.tagWechselbar(sitzung.liste))
    }

    /// Puls und kcal vom Sensor (Uhr oder Band), alle 10 s neu gelesen; ohne Sensor steht nichts da.
    private var liveWerte: some View {
        TimelineView(.periodic(from: .now, by: 10)) { _ in
            let teile = [sitzung.puls.puls.map { "\($0) Puls" }, sitzung.puls.kcal.map { "\($0) kcal" }].compactMap { $0 }
            if !teile.isEmpty {
                Label(teile.joined(separator: " · "), systemImage: "heart.fill")
                    .font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).monospacedDigit()
                    .accessibilityLabel(teile.joined(separator: ", "))
            }
        }
    }

    /// "Satz 2 gelöscht" mit "Rückgängig": 5 Sekunden, dann gleitet die Leiste weg.
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
                        Text("Satz fertig").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.lumenHauptknopf)
                }
            } else {
                Button { beenden = true } label: {
                    Text("Training beenden").font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
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
