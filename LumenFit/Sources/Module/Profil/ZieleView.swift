import SwiftUI

/// Ziele und Körperdaten an einem Ort (Idee 76 und 77, eine Ebene unter Präferenzen): Schritte, Kalorien, Protein, Schlaf, Wasser und Gewichtsziel
/// (die Gym-Tage stehen seit 10.11.2026 unter Präferenzen > Tage pro Woche), dazu Größe,
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
        List {
            zielGruppe
            tageszieleGruppe
            mehrGruppe
        }
        .profilListe()
        .navigationTitle("Ziele und Körper")
        .onAppear(perform: lade)
        .onChange(of: ziele) { _, _ in sichere() }
        .onChange(of: koerper) { _, _ in sichere() }
        .sheet(isPresented: $befragung) { ZieleBefragungView().presentationDetents([.large]) }
        .haptik(.erfolg, bei: vorschlagGenutzt)
    }

    // MARK: - Gruppen

    private var zielGruppe: some View {
        ProfilAbschnitt(fuss: vorschlagHinweis) {
            Picker("Ziel", selection: $ziele.art) {
                Text("Abnehmen").tag(Zielart.abnehmen)
                Text("Halten").tag(Zielart.halten)
                Text("Aufbauen").tag(Zielart.aufbauen)
            }
            .pickerStyle(.menu)
            Button {
                let neu = ProfilZielVorschlag.vorschlag(koerper: koerper, art: ziele.art, gymTage: ziele.gymTageProWoche, kg: gewichtKg, jahr: jahr, bisher: ziele)
                ziele = neu
                vorschlagGenutzt += 1
            } label: {
                Label("Vorschläge übernehmen", systemImage: "wand.and.stars")
            }
        }
    }

    /// Ein Satz: woraus die Vorschläge rechnen.
    private var vorschlagHinweis: String {
        if let kg = gewichtKg { return "Vorschläge nach Mifflin-St Jeor, mit deinem Gewicht \(gewichtText(kg))." }
        return "Vorschläge nach Mifflin-St Jeor, ohne Gewicht mit einem Durchschnittswert."
    }

    private var tageszieleGruppe: some View {
        ProfilAbschnitt("Tagesziele") {
            zeile("Schritte", ziele.schritte.formatted(.number), $ziele.schritte, 1_000...50_000, schritt: 500)
            zeile("Kalorien", "\(ziele.kalorien) kcal", $ziele.kalorien, 1_000...6_000, schritt: 50)
            zeile("Protein", "\(ziele.proteinGramm) g", $ziele.proteinGramm, 20...350, schritt: 5)
            zeile("Schlaf", schlafText(ziele.schlafMinuten), $ziele.schlafMinuten, 240...720, schritt: 15)
            zeile("Wasser", "\(ziele.wasserMl) ml", $ziele.wasserMl, 500...6_000, schritt: 100)
            Toggle(isOn: Binding(get: { ziele.gewichtKg != nil }, set: { an in ziele.gewichtKg = an ? (gewichtKg ?? 75).rounded() : nil })) {
                ProfilListenZeile("Gewichtsziel")
            }
            if let ziel = ziele.gewichtKg {
                zeile("Zielgewicht", gewichtText(ziel), Binding(get: { ziel }, set: { ziele.gewichtKg = $0 }), Koerpermasse.gewichtKg, schritt: 0.5)
            }
        }
    }

    /// Selten Gebrauchtes eine Ebene tiefer: Körperdaten und die Satzziele je Muskel.
    private var mehrGruppe: some View {
        ProfilAbschnitt {
            NavigationLink {
                ZieleKoerperSeite(koerper: $koerper, groesseText: $groesseText, jahr: jahr)
            } label: {
                ProfilListenZeile("Körperdaten", symbol: "figure.stand", wert: koerperWert)
            }
            Button { befragung = true } label: {
                ProfilListenZeile("Satzziele je Muskel", symbol: "figure.strengthtraining.traditional", wert: muskelWert)
            }
        }
    }

    /// "180 cm, 1990" oder "Keine Angabe".
    private var koerperWert: String {
        let teile: [String] = [koerper.groesseCm.map { "\($0) cm" }, koerper.geburtsjahr.map { String($0) }].compactMap { $0 }
        return teile.isEmpty ? "Keine Angabe" : teile.joined(separator: ", ")
    }

    private var muskelWert: String {
        guard let raum = umgebung.daten?.raum, let prio = ZieleLogik.gespeichert(in: raum), let erste = prio.first else { return "Offen" }
        return erste.name
    }

    // MARK: - Bausteine

    /// Eine Zeile: Titel links, Wert und Stepper rechts. VoiceOver liest Titel und Wert.
    private func zeile<Wert: Strideable>(_ titel: String, _ wert: String, _ bindung: Binding<Wert>, _ bereich: ClosedRange<Wert>,
                                         schritt: Wert.Stride) -> some View {
        Stepper(value: bindung, in: bereich, step: schritt) {
            LabeledContent {
                Text(wert).monospacedDigit().foregroundStyle(palette.text2).lineLimit(1).minimumScaleFactor(0.8)
            } label: {
                Text(titel).foregroundStyle(palette.text).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityValue(wert)
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

/// Körperdaten (eine Ebene unter "Ziele und Körper"): Größe, Geburtsjahr, Geschlecht und die Einheit kg oder lb. Speichern macht `ZieleView` über die Bindungen.
private struct ZieleKoerperSeite: View {
    @Binding var koerper: Koerperdaten
    @Binding var groesseText: String
    let jahr: Int
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    private var einheit: GewichtsEinheit { umgebung.daten?.einstellungen.werte.gewichtsEinheit ?? .kg }

    var body: some View {
        List {
            ProfilAbschnitt(fuss: "Geschlecht und Geburtsjahr sind freiwillig und nur für die Formeln der Vorschläge.") {
                LabeledContent {
                    HStack(spacing: Abstand.xs) {
                        TextField("cm", text: $groesseText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                            .onChange(of: groesseText) { _, neu in
                                let zahl = Int(neu.filter(\.isNumber).prefix(3))
                                koerper.groesseCm = (zahl ?? 0) >= 100 && (zahl ?? 0) <= 250 ? zahl : nil
                            }
                            .accessibilityLabel("Größe in Zentimetern")
                        Text("cm").foregroundStyle(palette.text2)
                    }
                } label: {
                    Text("Größe").foregroundStyle(palette.text)
                }
                Picker("Geburtsjahr", selection: $koerper.geburtsjahr) {
                    Text("Keine Angabe").tag(Int?.none)
                    ForEach(Array(stride(from: jahr - 10, through: jahr - 90, by: -1)), id: \.self) { Text(String($0)).tag(Int?.some($0)) }
                }
                .pickerStyle(.menu)
                Picker("Geschlecht", selection: $koerper.geschlecht) {
                    Text("Keine Angabe").tag(Geschlecht?.none)
                    Text("Weiblich").tag(Geschlecht?.some(.weiblich))
                    Text("Männlich").tag(Geschlecht?.some(.maennlich))
                    Text("Divers").tag(Geschlecht?.some(.divers))
                }
                .pickerStyle(.menu)
                Picker("Gewicht in", selection: Binding(
                    get: { einheit },
                    set: { neu in umgebung.daten?.einstellungen.aendere { $0.gewichtsEinheit = neu } })) {
                    Text("kg").tag(GewichtsEinheit.kg)
                    Text("lb").tag(GewichtsEinheit.lb)
                }
                .pickerStyle(.menu)
            }
        }
        .profilListe()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Körperdaten")
    }
}
