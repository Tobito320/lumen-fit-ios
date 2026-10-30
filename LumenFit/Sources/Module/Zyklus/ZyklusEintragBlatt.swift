// Quelle: Lovea Zyklus/ZyklusEintragBlatt.swift
import SwiftUI

/// Eintrag-Blatt für einen Tag. Änderungen bleiben im Entwurf; erst "Fertig" schreibt in den Speicher.
struct ZyklusEintragBlatt: View {
    let store: ZyklusStore
    let datum: String
    @State private var entwurf: ZyklusEintragEntwurf
    @State private var gespeichert = 0
    private enum Feld { case temperatur, gewicht, notiz }
    @FocusState private var fokus: Feld?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    init(store: ZyklusStore, datum: String) {
        self.store = store
        self.datum = datum
        _entwurf = State(initialValue: ZyklusEintragEntwurf(id: datum, tag: store.tage[datum]))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Abstand.m) {
                    abschnitt("Blutung") {
                        ZyklusEinzelAuswahl(optionen: ZyklusBlutung.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) }, gewaehlt: $entwurf.blutung)
                    }
                    abschnitt("Symptome") {
                        ZyklusMehrfachAuswahl(optionen: ZyklusSymptom.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) }, gewaehlt: $entwurf.symptome)
                    }
                    abschnitt("Stimmung") {
                        ZyklusMehrfachAuswahl(optionen: ZyklusStimmung.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) }, gewaehlt: $entwurf.stimmung)
                    }
                    abschnitt("Ausfluss") {
                        ZyklusEinzelAuswahl(optionen: ZyklusAusfluss.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) }, gewaehlt: $entwurf.ausfluss)
                    }
                    abschnitt("Temperatur") { feld("Morgens, in °C", text: $entwurf.temperaturText, einheit: "°C", als: .temperatur) }
                    abschnitt("Eisprungtest") {
                        ZyklusEinzelAuswahl(optionen: ZyklusTest.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) }, gewaehlt: $entwurf.eisprungTest)
                    }
                    abschnitt("Schwangerschaftstest") {
                        ZyklusEinzelAuswahl(optionen: ZyklusTest.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) }, gewaehlt: $entwurf.schwangerschaftsTest)
                    }
                    abschnitt("Zweisamkeit") {
                        ZyklusEinzelAuswahl(optionen: ZyklusSex.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) }, gewaehlt: $entwurf.sex)
                    }
                    abschnitt("Pille") {
                        ZyklusEinzelAuswahl(optionen: [ZyklusAuswahlOption(wert: true, titel: "Genommen"), ZyklusAuswahlOption(wert: false, titel: "Vergessen")],
                                            gewaehlt: $entwurf.pille)
                    }
                    abschnitt("Wasser") {
                        schrittZeile(wert: $entwurf.wasserMl, schritt: 250, grenze: 6000, name: "Wasser") {
                            String(format: "%.2f l", Double($0) / 1000).replacingOccurrences(of: ".", with: ",")
                        }
                    }
                    abschnitt("Schlaf") {
                        schrittZeile(wert: $entwurf.schlafMin, schritt: 30, grenze: 960, name: "Schlaf") { "\($0 / 60) h \($0 % 60) min" }
                    }
                    abschnitt("Gewicht") { feld("Zum Beispiel 58,5", text: $entwurf.gewichtText, einheit: "kg", als: .gewicht) }
                    abschnitt("Notiz") {
                        TextField("Was war heute noch?", text: $entwurf.notiz, axis: .vertical)
                            .lineLimit(3...6)
                            .focused($fokus, equals: .notiz)
                            .foregroundStyle(palette.text)
                    }
                }
                .padding(Abstand.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .lumenHintergrund()
            .navigationTitle(Datum.anzeige(datum))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        entwurf.speichern(in: store)
                        gespeichert += 1
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { fokus = nil }
                }
            }
            .haptik(.erfolg, bei: gespeichert)
        }
    }

    private func abschnitt<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: @escaping () -> Inhalt) -> some View {
        ZyklusKarte(titel: titel) { inhalt() }
    }

    private func feld(_ hinweis: String, text: Binding<String>, einheit: String, als art: Feld) -> some View {
        HStack {
            TextField(hinweis, text: text)
                .keyboardType(.decimalPad)
                .focused($fokus, equals: art)
                .foregroundStyle(palette.text)
                .padding(.horizontal, Abstand.m)
                .frame(minHeight: Abstand.tippflaeche)
                .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
            Text(einheit).foregroundStyle(palette.text2)
        }
    }

    private func schrittZeile(wert: Binding<Int?>, schritt: Int, grenze: Int, name: String, anzeige: @escaping (Int) -> String) -> some View {
        HStack(spacing: Abstand.m) {
            knopf("minus", "\(name) weniger") { wert.wrappedValue = ZyklusEintragEntwurf.schritt(wert.wrappedValue, delta: -schritt, grenze: grenze) }
            Text(wert.wrappedValue.map(anzeige) ?? "Noch leer")
                .font(.body.weight(.semibold))
                .foregroundStyle(wert.wrappedValue == nil ? palette.text2 : palette.text)
                .frame(maxWidth: .infinity)
            knopf("plus", "\(name) mehr") { wert.wrappedValue = ZyklusEintragEntwurf.schritt(wert.wrappedValue, delta: schritt, grenze: grenze) }
        }
        .haptik(.auswahl, bei: wert.wrappedValue)
    }

    private func knopf(_ symbol: String, _ name: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(palette.aufAkzent)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                .background(palette.akzent, in: .circle)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(name)
    }
}
