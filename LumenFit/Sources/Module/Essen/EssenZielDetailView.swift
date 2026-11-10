// Quelle: Lovea Health/Ernaehrung/ErnaehrungZiele.swift
import SwiftUI

/// Reine Regeln der Ziele-Seite: Vorschau-Gewicht, ob eigene Werte gelten, was gespeichert wird, flexible Tage.
enum EssenZielDetailLogik {
    /// Annahme für die Vorschau, wenn weder ein Gewicht eingetragen noch gespeichert ist.
    static let standardKg: Double = 75

    /// Eingetragenes neues Gewicht, sonst das gespeicherte, sonst 75 kg als Annahme.
    static func vorschauKg(eingabe: String, gespeichert: Double?) -> Double {
        if let zehntel = GewichtText.zehntel(eingabe) { return Double(zehntel) / 10 }
        return gespeichert ?? standardKg
    }

    static func ohneGewicht(eingabe: String, gespeichert: Double?) -> Bool {
        GewichtText.zehntel(eingabe) == nil && gespeichert == nil
    }

    /// Eigene Werte sind an, wenn die Ziele schon eingerichtet sind und von der Rechnung abweichen.
    static func eigeneWerteAn(_ start: ErnaehrungsZiele, kg: Double) -> Bool {
        start.eingerichtet && start.kcal != ErnaehrungLogik.berechnet(start, kg: kg).kcal
    }

    /// Das, was gespeichert wird: bei eigenen Werten die Eingabe, sonst die frisch berechneten Ziele.
    static func zuSichern(_ z: ErnaehrungsZiele, eigeneWerte: Bool, kg: Double) -> ErnaehrungsZiele {
        eigeneWerte ? z : ErnaehrungLogik.berechnet(z, kg: kg)
    }

    /// Zehntel-kg, die beim Sichern ins Gewicht gehen: nur eine gültige Eingabe, die vom gespeicherten Wert abweicht (sonst entstünde ein Eintrag ohne Änderung).
    static func gewichtZumSchreiben(eingabe: String, gespeichert: Double?) -> Int? {
        guard let zehntel = GewichtText.zehntel(eingabe) else { return nil }
        if let gespeichert, Int((gespeichert * 10).rounded()) == zehntel { return nil }
        return zehntel
    }

    /// Schaltet einen Wochentag (1 = Montag bis 7 = Sonntag) in der Bitmaske um. Andere Zahlen ändern nichts.
    static func extraTageUmgeschaltet(_ maske: Int, wochentag: Int) -> Int {
        guard (1...7).contains(wochentag) else { return maske }
        return maske ^ (1 << (wochentag - 1))
    }

    /// "+300 kcal" oder "-200 kcal".
    static func extraText(_ extraKcal: Int) -> String { extraKcal >= 0 ? "+\(extraKcal) kcal" : "\(extraKcal) kcal" }

    /// Ausgeschriebene Tage für VoiceOver: "Montag, Samstag" oder "kein Tag".
    static func tageText(_ maske: Int) -> String {
        let namen = [String(localized: "Montag"), String(localized: "Dienstag"), String(localized: "Mittwoch"), String(localized: "Donnerstag"), String(localized: "Freitag"), String(localized: "Samstag"), String(localized: "Sonntag")]
        let an = (0..<7).filter { maske & (1 << $0) != 0 }.map { namen[$0] }
        return an.isEmpty ? String(localized: "kein Tag") : an.joined(separator: ", ")
    }
}

/// Ziele einrichten oder ändern: Körperdaten, Aktivität, Richtung und Tempo, Makro-Profil, Vorschau der berechneten Werte,
/// eigene Werte und flexible Tage (zum Beispiel am Wochenende mehr kcal). Wird in einen NavigationStack gepusht.
struct EssenZielDetailView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var z = ErnaehrungsZiele()
    @State private var gewichtText = ""
    @State private var eigeneWerte = false
    @State private var geladen = false
    @State private var erfolgZaehler = 0
    @State private var tagZaehler = 0
    @FocusState private var tippt: Bool

    init() {}

    private var essen: EssenStore? { umgebung.daten?.essen }
    private var gespeichertKg: Double? { essen?.gewichtKg }
    private var vorschauKg: Double { EssenZielDetailLogik.vorschauKg(eingabe: gewichtText, gespeichert: gespeichertKg) }
    private var vorschau: ErnaehrungsZiele { ErnaehrungLogik.berechnet(z, kg: vorschauKg) }

    var body: some View {
        Group {
            if essen != nil {
                formular
            } else {
                LeerZustand(stimmung: .bereit, satz: String(localized: "Lege zuerst ein Profil an, dann rechne ich dir deine Ziele."))
            }
        }
        .navigationTitle("Ziele")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .haptik(.erfolg, bei: erfolgZaehler)
        .haptik(.auswahl, bei: tagZaehler)
        .onAppear(perform: laden)
    }

    private func laden() {
        guard !geladen, let essen else { return }
        geladen = true
        let start = essen.ernaehrungsZiele
        let kg = essen.gewichtKg ?? EssenZielDetailLogik.standardKg
        z = start
        gewichtText = ErnaehrungLogik.zahl(kg)
        eigeneWerte = EssenZielDetailLogik.eigeneWerteAn(start, kg: kg)
    }

    private var formular: some View {
        Form {
            Section {
                Picker("Geschlecht", selection: $z.geschlecht) {
                    Text("Mann").tag(0)
                    Text("Frau").tag(1)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Stepper("Alter: \(z.alter)", value: $z.alter, in: 14...100)
                Stepper("Größe: \(z.groesseCm) cm", value: $z.groesseCm, in: 120...230)
            }
            gewichtSektion
            aktivitaetSektion
            richtungSektion
            Section {
                Picker("Makro-Profil", selection: $z.makroProfil) {
                    ForEach(ErnaehrungLogik.makroProfile.indices, id: \.self) { i in
                        Text(ErnaehrungLogik.makroProfile[i].name).tag(i)
                    }
                }
            }
            vorschauSektion
            eigeneWerteSektion
            flexibleTageSektion
            Section {
                Button {
                    sichern()
                } label: {
                    Text("Sichern").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.lumenHauptknopf)
                .listRowBackground(Color.clear)
                .accessibilityHint("Speichert deine Ziele")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .fontDesign(.rounded)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { tippt = false }
            }
        }
    }

    private var gewichtSektion: some View {
        Section {
            if let aktuell = gespeichertKg {
                LabeledContent("Aktuelles Gewicht", value: "\(ErnaehrungLogik.zahl(aktuell)) kg")
            }
            TextField("Neues Gewicht in kg", text: $gewichtText)
                .keyboardType(.decimalPad)
                .focused($tippt)
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityLabel("Neues Gewicht in Kilogramm")
        }
    }

    private var aktivitaetSektion: some View {
        Section {
            Picker("Aktivität", selection: $z.aktivitaet) {
                ForEach(ErnaehrungLogik.aktivitaeten.indices, id: \.self) { i in
                    Text(ErnaehrungLogik.aktivitaeten[i].name).tag(i)
                }
            }
        } footer: {
            let i = min(max(z.aktivitaet, 0), ErnaehrungLogik.aktivitaeten.count - 1)
            Text(ErnaehrungLogik.aktivitaeten[i].text)
        }
    }

    private var richtungSektion: some View {
        Section {
            Picker("Ziel", selection: $z.richtung) {
                Text("Abnehmen").tag(0)
                Text("Halten").tag(1)
                Text("Zunehmen").tag(2)
            }
            .pickerStyle(.segmented)
            if z.richtung != 1 {
                Picker("Tempo", selection: $z.tempo) {
                    Text("250 g/Woche").tag(250)
                    Text("500 g/Woche").tag(500)
                    Text("750 g/Woche").tag(750)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var vorschauSektion: some View {
        let v = vorschau
        return Section {
            LabeledContent("Kalorien", value: "\(v.kcal) kcal")
            LabeledContent("Protein", value: "\(v.protein) g")
            LabeledContent("Kohlenhydrate", value: "\(v.kohlenhydrate) g")
            LabeledContent("Fett", value: "\(v.fett) g")
        } header: {
            Text("Vorschau")
        } footer: {
            if EssenZielDetailLogik.ohneGewicht(eingabe: gewichtText, gespeichert: gespeichertKg) {
                Text("Ohne Gewicht wird mit \(Int(EssenZielDetailLogik.standardKg)) kg gerechnet.")
            }
        }
    }

    private var eigeneWerteSektion: some View {
        Section {
            Toggle("Eigene Werte", isOn: $eigeneWerte)
            if eigeneWerte {
                eigenesFeld(String(localized: "Kalorien"), einheit: "kcal", wert: $z.kcal)
                eigenesFeld(String(localized: "Protein"), einheit: "g", wert: $z.protein)
                eigenesFeld(String(localized: "Kohlenhydrate"), einheit: "g", wert: $z.kohlenhydrate)
                eigenesFeld(String(localized: "Fett"), einheit: "g", wert: $z.fett)
            }
        }
    }

    private func eigenesFeld(_ titel: String, einheit: String, wert: Binding<Int>) -> some View {
        LabeledContent(titel) {
            TextField(einheit, value: wert, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($tippt)
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityLabel("\(titel) in \(einheit == "g" ? "Gramm" : "Kilokalorien")")
        }
    }

    /// Wochenend-Kalorien: an gewählten Wochentagen mehr (oder weniger) kcal, die Makros wachsen im selben Verhältnis.
    private var flexibleTageSektion: some View {
        Section {
            Stepper(value: $z.extraKcal, in: -1000...1500, step: 50) {
                LabeledContent("An diesen Tagen", value: EssenZielDetailLogik.extraText(z.extraKcal))
            }
            HStack(spacing: Abstand.s) {
                ForEach(1...7, id: \.self) { tag in tagKnopf(tag) }
            }
            .listRowInsets(EdgeInsets(top: Abstand.s, leading: Abstand.l, bottom: Abstand.s, trailing: Abstand.l))
        } header: {
            Text("Flexible Tage")
        } footer: {
            Text("Zum Beispiel am Wochenende 300 kcal mehr. Die Makros wachsen im selben Verhältnis.")
        }
    }

    private func tagKnopf(_ tag: Int) -> some View {
        let an = z.istExtraTag(tag)
        let kuerzel = HabitLogik.wochentagKuerzel[tag - 1]
        return Button {
            z.extraTage = EssenZielDetailLogik.extraTageUmgeschaltet(z.extraTage, wochentag: tag)
            tagZaehler += 1
        } label: {
            Text(kuerzel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(an ? palette.aufAkzent : palette.text)
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                .background(an ? palette.akzent : palette.flaeche, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Rundung.klein, style: .continuous).stroke(palette.haar, lineWidth: an ? 0 : 1))
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(EssenZielDetailLogik.tageText(1 << (tag - 1)))
        .accessibilityValue(an ? "an" : "aus")
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    // MARK: - Sichern

    private func sichern() {
        guard let essen else { return }
        let kg = vorschauKg
        essen.zieleSichern(EssenZielDetailLogik.zuSichern(z, eigeneWerte: eigeneWerte, kg: kg))
        if let zehntel = EssenZielDetailLogik.gewichtZumSchreiben(eingabe: gewichtText, gespeichert: gespeichertKg) {
            essen.gewichtSetzen(zehntel: zehntel, datum: Datum.text(umgebung.uhr()))
        }
        tippt = false
        erfolgZaehler += 1
        // Kurz warten, damit die Haptik noch auf dieser Seite auslöst, bevor sie zurückgeht.
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            dismiss()
        }
    }
}
