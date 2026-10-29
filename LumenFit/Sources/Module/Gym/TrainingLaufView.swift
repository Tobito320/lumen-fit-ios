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

    var body: some View {
        let _ = sitzung.pauseEndeZaehler // die Karte baut sich neu, wenn die Pause endet
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                kopf
                NaechsterSatzKarte(sitzung: sitzung)
                ForEach(sitzung.liste.indices, id: \.self) { i in
                    UebungsKarte(sitzung: sitzung, index: i)
                }
                Button { suche = true } label: {
                    Label("Übung hinzufügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) { beenden = true } label: {
                    Label("Training beenden", systemImage: "stop.fill").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.l)
        }
        .safeAreaInset(edge: .bottom) { satzFertigLeiste }
        .sheet(isPresented: $beenden) { TrainingBeendenView(sitzung: sitzung) }
        .sheet(isPresented: $suche) {
            UebungsSucheView(titel: "Übung hinzufügen") { sitzung.uebungDazu($0) }
        }
        .sheet(isPresented: $tagWahl) { TagWechselBlatt(sitzung: sitzung) }
        .sheet(isPresented: $einstellungen) { GymEinstellungenBlatt(sitzung: sitzung) }
        .sheet(isPresented: $cardioOffen) { CardioAbschlussBlatt(sitzung: sitzung, index: cardioIndex) }
        .lumenToast($sitzung.toast)
        .haptik(.satzFertig, bei: sitzung.hakenZaehler)
        .haptik(.pauseEnde, bei: sitzung.pauseEndeZaehler)
        .alert("Hinweis zum Studio", isPresented: Binding(get: { sitzung.studioHinweis != nil }, set: { if !$0 { sitzung.hinweisGelesen() } })) {
            Button("OK") { sitzung.hinweisGelesen() }
        } message: {
            Text(sitzung.studioHinweis ?? "")
        }
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
                        Text(s.start, style: .timer).monospacedDigit()
                        Text("· \(sitzung.saetzeZahl) Sätze")
                    }
                    .font(.subheadline).foregroundStyle(palette.text2)
                    .accessibilityElement(children: .combine)
                }
            }
            Spacer()
            if WorkoutLogik.tagWechselbar(sitzung.liste) {
                Button { tagWahl = true } label: { Image(systemName: "arrow.left.arrow.right").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                    .accessibilityLabel("Anderen Trainingstag wählen")
            }
            Button { einstellungen = true } label: { Image(systemName: "gearshape").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                .accessibilityLabel("Einstellungen fürs Training")
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
        .background(.bar)
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
