// Quelle: Lovea Health/GymSession.swift (WorkoutRueckblick) und WorkoutView.swift (WorkoutUebungView mit nachtrag; neu im Lumen-Design)
import SwiftUI

/// Eine Einheit zum Nachlesen: Zeiten, Volumen, Sätze, Kalorien, Puls und jeder abgehakte Satz. Eine beendete Einheit lässt sich in den Zeiten und
/// in den Sätzen korrigieren, mit Übungen ergänzen oder löschen (`EinheitZeitenBlatt`, `EinheitSaetzeBlatt`).
struct EinheitNachlesenView: View {
    let sessionId: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeit = false
    @State private var zeiten: GymSession?
    @State private var sucheOffen = false
    @State private var bearbeiten: WorkoutUebung?
    @State private var notizOffen = false
    @State private var notizText = ""
    @State private var hinzugefuegt = 0

    var body: some View {
        if let training = umgebung.daten?.training, let s = training.sessions.first(where: { $0.id == sessionId }) {
            inhalt(s, training: training)
        } else {
            LeerZustand(stimmung: .denkt, satz: "Diese Einheit gibt es nicht mehr.")
                .frame(maxHeight: .infinity)
                .lumenHintergrund()
        }
    }

    private func inhalt(_ s: GymSession, training: TrainingStore) -> some View {
        let jetzt = umgebung.uhr()
        let frueher = training.sessions.filter { $0.start < s.start }
        let liste = WorkoutLogik.uebungen(s, tag: training.tag(id: s.tag), frueher: frueher)
        let bearbeitbar = s.ende != nil
        let volumen = WorkoutLogik.volumen(liste).rounded()
        let saetze = WorkoutLogik.saetzeZahl(liste)
        return ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                kopf(s, volumen: volumen, saetze: saetze)
                if let hinweis = GymTageLogik.leerHinweis(s, eigene: true, jetzt: jetzt) {
                    Text(hinweis).font(.footnote).foregroundStyle(palette.text2).frame(maxWidth: .infinity, alignment: .leading)
                }
                if s.kcal != nil || s.puls != nil || s.notiz != nil { werte(s) }
                ForEach(liste) { u in uebungKarte(u, bearbeitbar: bearbeitbar) }
                if bearbeitbar {
                    Button { sucheOffen = true } label: {
                        Label("Übung hinzufügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle(training.tag(id: s.tag).map { $0.name.isEmpty ? "Training" : $0.name } ?? Datum.anzeige(Datum.text(s.start)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Zeiten ändern", systemImage: "clock") { zeiten = s }
                    Button("Notiz zum Training", systemImage: "note.text") {
                        notizText = s.notiz ?? ""
                        notizOffen = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .accessibilityLabel("Mehr zu dieser Einheit")
            }
        }
        .sheet(item: $zeiten) { EinheitZeitenBlatt(session: $0, jetzt: umgebung.uhr()) }
        .sheet(isPresented: $sucheOffen) {
            UebungsSucheView(titel: "Übung hinzufügen") { hinzufuegen($0, s, training: training) }
        }
        .sheet(item: $bearbeiten) { EinheitSaetzeBlatt(sessionId: sessionId, uebung: $0) }
        .alert("Notiz zum Training", isPresented: $notizOffen) {
            TextField("Notiz", text: $notizText)
            Button("Speichern") { training.notizAendern(s, notizText) }
            Button("Abbrechen", role: .cancel) {}
        }
        .haptik(.erfolg, bei: hinzugefuegt)
    }

    // MARK: Teile

    private func kopf(_ s: GymSession, volumen: Double, saetze: Int) -> some View {
        HeroKarte(platte: true) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(EinheitZeitenLogik.kopfZeit(s)).font(.footnote.weight(.semibold))
                HStack(alignment: .top) {
                    kennzahl("Dauer", Text(s.ende.map { TrainingLogik.dauerText($0.timeIntervalSince(s.start)) } ?? "–"))
                    Spacer()
                    kennzahl("Sätze", RollZahl(wert: Double(saetze), format: .number.precision(.fractionLength(0))))
                    Spacer()
                    kennzahl("Volumen", HStack(spacing: 2) {
                        RollZahl(wert: volumen, format: .number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))
                        Text("kg")
                    })
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func kennzahl<W: View>(_ titel: String, _ wert: W) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.footnote.weight(.semibold)).textCase(.uppercase)
            wert.font(.title2.weight(.bold)).fontDesign(.rounded).monospacedDigit()
        }
    }

    private func werte(_ s: GymSession) -> some View {
        ListenKarte {
            if let kcal = s.kcal { GymZeile(titel: "Aktive Kalorien") { Text("\(kcal) kcal").foregroundStyle(palette.text2).monospacedDigit() } }
            if s.kcal != nil, s.puls != nil || s.notiz != nil { Haarlinie() }
            if let puls = s.puls { GymZeile(titel: "Puls im Schnitt") { Text("\(puls)").foregroundStyle(palette.text2).monospacedDigit() } }
            if s.puls != nil, s.notiz != nil { Haarlinie() }
            if let notiz = s.notiz { GymZeile(titel: "Notiz", untertitel: notiz) }
        }
    }

    private func uebungKarte(_ u: WorkoutUebung, bearbeitbar: Bool) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: u.planUebung.anzeigeName)
            ListenKarte {
                if u.planUebung.istCardio {
                    GymZeile(titel: u.cardioFertig ? "\(u.planUebung.minuten ?? 20) min" : "nicht gemacht")
                } else if u.fertigZahl == 0 {
                    GymZeile(titel: "nicht gemacht")
                } else {
                    ForEach(u.saetze.indices, id: \.self) { i in
                        if u.saetze[i].ok == true {
                            satzZeile(u, i)
                            Haarlinie()
                        }
                    }
                }
                if bearbeitbar, !u.planUebung.istCardio {
                    Button { bearbeiten = u } label: {
                        GymZeile(titel: "Sätze bearbeiten") { Image(systemName: "pencil").accessibilityHidden(true) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Gewicht, Wiederholungen und Haken dieser Übung korrigieren")
                }
            }
        }
    }

    private func satzZeile(_ u: WorkoutUebung, _ i: Int) -> some View {
        let s = u.saetze[i]
        let zeiten = WorkoutLogik.zeitenText(sek: s.sek, pause: s.pause, satzzeit: satzzeit)
        return HStack(spacing: Abstand.m) {
            Text(WorkoutLogik.nummer(u.saetze, i))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(s.kuerzel == nil ? palette.text2 : palette.text)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(WorkoutLogik.satzText(s)).monospacedDigit().foregroundStyle(palette.text)
                if let zeiten { Text(zeiten).font(.caption).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: Abstand.s)
            if let rpe = s.rpe { Text("RPE \(TrainingLogik.kgText(rpe))").font(.subheadline).foregroundStyle(palette.text2) }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
    }

    /// Eine Übung nachtragen: Kraft mit ihren Plan-Sätzen (ohne Haken), Cardio gleich als gemacht.
    private func hinzufuegen(_ k: Uebung, _ s: GymSession, training: TrainingStore) {
        let p = GymEigeneLogik.planUebung(k)
        if p.istCardio { training.fertig(s.id, p, saetze: []) } else { training.saetzeSenden(s.id, p, p.saetze) }
        hinzugefuegt += 1
    }
}

/// Anzeige-Schalter des Trainings (nur auf diesem Gerät, `UserDefaults`): "Satz-Zeit" und die RPE-Spalte.
enum GymAnzeige {
    static let satzzeitSchluessel = "lumen.gym.satzzeit"
    static let rpeSpalteSchluessel = "lumen.gym.rpeSpalte"
}

/// Die Sätze einer Übung in einer beendeten Einheit korrigieren oder nachtragen: Gewicht und Wiederholungen mit Plus und Minus, Haken, Typ, Satz
/// dazu oder löschen. Gesendet wird beim Sichern (ein Op), nicht bei jedem Tipp.
struct EinheitSaetzeBlatt: View {
    let sessionId: String
    let uebung: WorkoutUebung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @State private var saetze: [PlanSatz]
    @State private var gesichert = 0
    @State private var geaendert = 0

    init(sessionId: String, uebung: WorkoutUebung) {
        self.sessionId = sessionId
        self.uebung = uebung
        _saetze = State(initialValue: uebung.saetze)
    }

    var body: some View {
        let gruen = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        let schritt = LetztesMal.kgSchritt(geraet: GymSitzung.von(umgebung).katalog(uebung.planUebung)?.geraet)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    ListenKarte {
                        ForEach(saetze.indices, id: \.self) { i in
                            zeile(i, gruen: gruen, schritt: schritt)
                            if i < saetze.count - 1 { Haarlinie() }
                        }
                    }
                    Button {
                        saetze.append((saetze.last(where: { $0.typ != "w" }) ?? PlanSatz(wdh: 10, kg: nil, failure: false)).alsPlan)
                        geaendert += 1
                    } label: {
                        Label("Satz hinzufügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                    Text("Tipp auf den Kreis setzt oder nimmt den Haken. Nur abgehakte Sätze zählen.")
                        .font(.footnote).foregroundStyle(palette.text2)
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle(uebung.planUebung.anzeigeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() } }
            }
        }
        .haptik(.auswahl, bei: geaendert)
        .haptik(.erfolg, bei: gesichert)
    }

    private func zeile(_ i: Int, gruen: Color, schritt: Double) -> some View {
        let s = saetze[i]
        return HStack(spacing: Abstand.xs) {
            Menu {
                Button("Normaler Satz") { typ(i, "") }
                Button("Aufwärmsatz (zählt nicht)") { typ(i, "w") }
                Button("Dropsatz") { typ(i, "d") }
                Button("Bis zum Versagen") { typ(i, "f") }
                if saetze.count > 1 { Button("Satz löschen", role: .destructive) { loeschen(i) } }
            } label: {
                Text(WorkoutLogik.nummer(saetze, i))
                    .font(.headline.weight(.bold)).fontDesign(.rounded).monospacedDigit()
                    .foregroundStyle(palette.text)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel("Satz \(WorkoutLogik.nummer(saetze, i))")
            .accessibilityHint("Öffnet die Satztypen")
            Spacer(minLength: 0)
            GymSchalter(titel: "Gewicht", wert: s.kg.map { "\(TrainingLogik.kgText($0)) kg" } ?? "– kg",
                        minus: { aendern { LetztesMal.aendereKg($0, i, richtung: -1, schritt: schritt) } },
                        plus: { aendern { LetztesMal.aendereKg($0, i, richtung: 1, schritt: schritt) } })
            GymSchalter(titel: "Wiederholungen", wert: "\(s.wdh)",
                        minus: { aendern { LetztesMal.aendereWdh($0, i, richtung: -1) } },
                        plus: { aendern { LetztesMal.aendereWdh($0, i, richtung: 1) } })
            Button { aendern { WorkoutLogik.hakenNachtrag($0, i) } } label: {
                Image(systemName: s.ok == true ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(s.ok == true ? gruen : palette.text2)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                    .contentShape(.rect)
            }
            .buttonStyle(.federnd)
            .accessibilityLabel(s.ok == true ? "Satz erledigt" : "Satz nicht gemacht")
            .accessibilityHint(s.ok == true ? "Nimmt den Haken zurück" : "Setzt den Haken")
        }
        .padding(.horizontal, Abstand.s)
    }

    private func aendern(_ f: ([PlanSatz]) -> [PlanSatz]) {
        saetze = f(saetze)
        geaendert += 1
    }

    private func typ(_ i: Int, _ t: String) {
        guard saetze.indices.contains(i) else { return }
        saetze[i].setzeTyp(t)
        geaendert += 1
    }

    private func loeschen(_ i: Int) {
        guard saetze.indices.contains(i), saetze.count > 1 else { return }
        saetze.remove(at: i)
        geaendert += 1
    }

    private func sichern() {
        umgebung.daten?.training.saetzeSenden(sessionId, uebung.planUebung, saetze)
        gesichert += 1
        schliessen()
    }
}
