import SwiftUI

/// Ziele und Körperdaten an einem Ort (Idee 76 und 77): Schritte, Kalorien, Protein, Schlaf, Gym-Tage, Wasser und Gewichtsziel, dazu Größe,
/// Geburtsjahr, Geschlecht (optional, nur für die Formeln) und die Einheit kg oder lb. Vorschläge rechnen aus den Körperdaten (Mifflin-St Jeor).
struct ZieleView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var ziele = Ziele()
    @State private var koerper = Koerperdaten()
    @State private var groesseText = ""
    @State private var geladen = false
    @State private var befragung = false
    @State private var vorschlagGenutzt = 0

    private var einheit: GewichtsEinheit { umgebung.daten?.einstellungen.werte.gewichtsEinheit ?? .kg }
    private var jahr: Int { ProfilZielSpeicher.jahr(umgebung.uhr()) }
    private var gewichtKg: Double? { umgebung.daten?.essen.gewichtKg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                koerperGruppe
                zielGruppe
                tageszieleGruppe
                muskelGruppe
            }
            .padding(Abstand.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Ziele und Körper")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .onAppear(perform: lade)
        .onChange(of: ziele) { _, _ in sichere() }
        .onChange(of: koerper) { _, _ in sichere() }
        .sheet(isPresented: $befragung) { ZieleBefragungView().presentationDetents([.large]) }
        .haptik(.erfolg, bei: vorschlagGenutzt)
    }

    // MARK: - Gruppen

    private var koerperGruppe: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ProfilGruppenKopf(text: "Körperdaten")
            ListenKarte {
                HStack {
                    Text("Größe").font(.body).foregroundStyle(palette.text)
                    Spacer()
                    TextField("cm", text: $groesseText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: groesseText) { _, neu in
                            let zahl = Int(neu.filter(\.isNumber).prefix(3))
                            koerper.groesseCm = (zahl ?? 0) >= 100 && (zahl ?? 0) <= 250 ? zahl : nil
                        }
                        .accessibilityLabel("Größe in Zentimetern")
                    Text("cm").font(.body).foregroundStyle(palette.text2)
                }
                .padding(Abstand.l).frame(minHeight: Abstand.tippflaeche)
                Haarlinie()
                HStack {
                    Text("Geburtsjahr").font(.body).foregroundStyle(palette.text)
                    Spacer()
                    Picker("Geburtsjahr", selection: $koerper.geburtsjahr) {
                        Text("Keine Angabe").tag(Int?.none)
                        ForEach(Array(stride(from: jahr - 10, through: jahr - 90, by: -1)), id: \.self) { Text(String($0)).tag(Int?.some($0)) }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, Abstand.l).frame(minHeight: Abstand.tippflaeche)
                Haarlinie()
                HStack {
                    Text("Geschlecht").font(.body).foregroundStyle(palette.text)
                    Spacer()
                    Picker("Geschlecht", selection: $koerper.geschlecht) {
                        Text("Keine Angabe").tag(Geschlecht?.none)
                        Text("Weiblich").tag(Geschlecht?.some(.weiblich))
                        Text("Männlich").tag(Geschlecht?.some(.maennlich))
                        Text("Divers").tag(Geschlecht?.some(.divers))
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, Abstand.l).frame(minHeight: Abstand.tippflaeche)
                Haarlinie()
                HStack {
                    Text("Gewicht in").font(.body).foregroundStyle(palette.text)
                    Spacer()
                    Picker("Einheit", selection: Binding(
                        get: { einheit },
                        set: { neu in umgebung.daten?.einstellungen.aendere { $0.gewichtsEinheit = neu } })) {
                        Text("kg").tag(GewichtsEinheit.kg)
                        Text("lb").tag(GewichtsEinheit.lb)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .padding(.horizontal, Abstand.l).frame(minHeight: Abstand.tippflaeche)
            }
            Text("Geschlecht und Geburtsjahr brauche ich nur für die Formeln der Vorschläge. Beides ist freiwillig.")
                .font(.footnote).foregroundStyle(palette.text2).padding(.horizontal, Abstand.xs)
        }
    }

    private var zielGruppe: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ProfilGruppenKopf(text: "Ziel")
            Picker("Ziel", selection: $ziele.art) {
                Text("Abnehmen").tag(Zielart.abnehmen)
                Text("Halten").tag(Zielart.halten)
                Text("Aufbauen").tag(Zielart.aufbauen)
            }
            .pickerStyle(.segmented)
            Button {
                let neu = ProfilZielVorschlag.vorschlag(koerper: koerper, art: ziele.art, gymTage: ziele.gymTageProWoche, kg: gewichtKg, jahr: jahr, bisher: ziele)
                ziele = neu
                vorschlagGenutzt += 1
            } label: {
                Label("Vorschläge übernehmen", systemImage: "wand.and.stars").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
            Text(vorschlagHinweis).font(.footnote).foregroundStyle(palette.text2).padding(.horizontal, Abstand.xs)
        }
    }

    private var vorschlagHinweis: String {
        var teile = ["Kalorien und Protein rechne ich nach Mifflin-St Jeor aus Größe, Alter und Gewicht."]
        if let kg = gewichtKg {
            teile.append("Dein Gewicht aus deinen Einträgen: \(gewichtText(kg)).")
        } else {
            teile.append("Ohne Gewicht rechne ich mit einem Durchschnittswert.")
        }
        return teile.joined(separator: " ")
    }

    private var tageszieleGruppe: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ProfilGruppenKopf(text: "Tagesziele")
            ListenKarte {
                zeile("Schritte", Text(ziele.schritte, format: .number), Stepper("", value: $ziele.schritte, in: 1_000...50_000, step: 500))
                Haarlinie()
                zeile("Kalorien", Text("\(ziele.kalorien) kcal"), Stepper("", value: $ziele.kalorien, in: 1_000...6_000, step: 50))
                Haarlinie()
                zeile("Protein", Text("\(ziele.proteinGramm) g"), Stepper("", value: $ziele.proteinGramm, in: 20...350, step: 5))
                Haarlinie()
                zeile("Schlaf", Text(schlafText(ziele.schlafMinuten)), Stepper("", value: $ziele.schlafMinuten, in: 240...720, step: 15))
                Haarlinie()
                zeile("Gym-Tage pro Woche", Text("\(ziele.gymTageProWoche)"), Stepper("", value: $ziele.gymTageProWoche, in: 1...7))
                Haarlinie()
                zeile("Wasser", Text("\(ziele.wasserMl) ml"), Stepper("", value: $ziele.wasserMl, in: 500...6_000, step: 100))
                Haarlinie()
                gewichtsziel
            }
        }
    }

    private var gewichtsziel: some View {
        VStack(spacing: 0) {
            Toggle(isOn: Binding(get: { ziele.gewichtKg != nil }, set: { an in ziele.gewichtKg = an ? (gewichtKg ?? 75).rounded() : nil })) {
                Text("Gewichtsziel").font(.body).foregroundStyle(palette.text)
            }
            .padding(.horizontal, Abstand.l).frame(minHeight: Abstand.tippflaeche)
            if let ziel = ziele.gewichtKg {
                Haarlinie()
                zeile("Zielgewicht", Text(gewichtText(ziel)),
                      Stepper("", value: Binding(get: { ziel }, set: { ziele.gewichtKg = $0 }), in: 30...250, step: 0.5))
            }
        }
    }

    private var muskelGruppe: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ProfilGruppenKopf(text: "Muskeln")
            ListenKarte {
                Button { befragung = true } label: {
                    ProfilZeile(symbol: "figure.strengthtraining.traditional", titel: "Satzziele je Muskel",
                                zeile: muskelZeile)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var muskelZeile: String {
        guard let raum = umgebung.daten?.raum, let prio = ZieleLogik.gespeichert(in: raum) else { return "Drei Fragen, dann rechne ich deine Wochenziele." }
        return "Wichtigste: " + prio.prefix(3).map(\.name).joined(separator: ", ")
    }

    // MARK: - Bausteine

    /// Eine Zeile: Titel links, Wert und Stepper rechts. Der Stepper hat kein eigenes Label, VoiceOver liest Titel und Wert zusammen.
    private func zeile(_ titel: String, _ wert: Text, _ stepper: some View) -> some View {
        HStack {
            Text(titel).font(.body).foregroundStyle(palette.text)
            Spacer()
            wert.font(.body.monospacedDigit()).foregroundStyle(palette.text2)
            stepper.labelsHidden().fixedSize().accessibilityLabel(titel)
        }
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
    }

    private func schlafText(_ minuten: Int) -> String { "\(minuten / 60) h \(String(format: "%02d", minuten % 60)) min" }

    /// 78,4 kg oder 172,8 lb.
    private func gewichtText(_ kg: Double) -> String {
        let wert = einheit == .kg ? kg : kg * 2.20462
        return wert.formatted(.number.precision(.fractionLength(1))) + (einheit == .kg ? " kg" : " lb")
    }

    // MARK: - Laden und Speichern

    private func lade() {
        guard !geladen, let daten = umgebung.daten else { return }
        ziele = daten.ziele.ziele
        koerper = daten.ziele.koerper
        groesseText = koerper.groesseCm.map(String.init) ?? ""
        geladen = true
    }

    /// Speichert nur, was der Mensch geändert hat (nicht schon beim Öffnen), damit die Ernährungsziele nicht von selbst als eingerichtet gelten.
    private func sichere() {
        guard geladen, let daten = umgebung.daten, ziele != daten.ziele.ziele || koerper != daten.ziele.koerper else { return }
        ProfilZielSpeicher.sichere(ziele: ziele, koerper: koerper, in: daten, jahr: jahr)
    }
}
