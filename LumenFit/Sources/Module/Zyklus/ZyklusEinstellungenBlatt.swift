// Quelle: Lovea Zyklus/ZyklusEinstellungenView.swift
import SwiftUI

/// Einstellungen des Zyklus: Modus, Längen, Sperre, Health, Vorhersage, Partner, Export, Löschen, Ausschalten.
struct ZyklusEinstellungenBlatt: View {
    let store: ZyklusStore
    let sperre: ZyklusSperre
    @State private var loeschenFrage = false
    @State private var healthHinweis: String?
    @State private var geaendert = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Abstand.l) {
                    modusKarte
                    laengenKarte
                    privatKarte
                    healthKarte
                    vorhersageKarte
                    datenKarte
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle("Zyklus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .haptik(.auswahl, bei: geaendert)
            .confirmationDialog("Alle Zyklus-Einträge leeren?", isPresented: $loeschenFrage, titleVisibility: .visible) {
                Button("Alle Einträge leeren", role: .destructive) { store.alleTageLeeren(); geaendert += 1 }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die Tage werden leer. Ganz verschwinden die alten Zeilen erst mit \"Alles löschen\" im Profil.")
            }
        }
        .tint(palette.akzent)
    }

    // MARK: Karten

    private var modusKarte: some View {
        ZyklusKarte(titel: "Modus", symbol: "circle.hexagongrid.fill") {
            ZyklusFluss {
                ForEach(ZyklusModus.allCases, id: \.self) { m in
                    Button {
                        var e = store.einstellung
                        e.modus = m
                        store.setzeEinstellung(e)
                        geaendert += 1
                    } label: { ZyklusWahlChip(titel: ZyklusEinstellungenLogik.modusName(m), gewaehlt: store.einstellung.modus == m) }
                        .buttonStyle(.federnd)
                }
            }
        }
    }

    private var laengenKarte: some View {
        ZyklusKarte(titel: "Längen", symbol: "ruler") {
            schritt("Zykluslänge", wert: store.einstellung.zyklusLaenge, einheit: "Tage", grenzen: ZyklusEinstellungenLogik.zyklusGrenzen) {
                var e = store.einstellung; e.zyklusLaenge = $0; store.setzeEinstellung(ZyklusEinstellungenLogik.begrenzt(e))
            }
            schritt("Periodenlänge", wert: store.einstellung.periodenLaenge, einheit: "Tage", grenzen: ZyklusEinstellungenLogik.periodenGrenzen) {
                var e = store.einstellung; e.periodenLaenge = $0; store.setzeEinstellung(ZyklusEinstellungenLogik.begrenzt(e))
            }
            ZyklusLeise("Sobald du Perioden einträgst, rechnet Lumen Fit mit deinen eigenen Werten.")
        }
    }

    private var privatKarte: some View {
        ZyklusKarte(titel: "Privat", symbol: "lock.fill") {
            Toggle("Face ID oder Code vor dem Zyklus", isOn: Binding(get: { sperre.aktiv }, set: { sperre.aktiv = $0; geaendert += 1 }))
                .frame(minHeight: Abstand.tippflaeche)
            Toggle("Hinweise im Training und Heute", isOn: Binding(get: { store.werte.imTraining }, set: { n in store.aendere { $0.imTraining = n }; geaendert += 1 }))
                .frame(minHeight: Abstand.tippflaeche)
            Toggle("Partner sieht Phase und Tag", isOn: Binding(get: { store.werte.partnerZeigen }, set: { n in store.aendere { $0.partnerZeigen = n }; geaendert += 1 }))
                .frame(minHeight: Abstand.tippflaeche)
            ZyklusLeise("Der Partner sieht nur die Phase, den Tag und kurze Hinweise, nie einzelne Einträge. Alles andere bleibt auf diesem Gerät.")
        }
        .toggleStyle(.lumenSchalter)
        .foregroundStyle(palette.text)
    }

    private var healthKarte: some View {
        ZyklusKarte(titel: "Apple Health", symbol: "heart.text.square.fill") {
            Toggle("Periode, Temperatur und Gewicht lesen", isOn: Binding(
                get: { store.werte.healthLesen },
                set: { an in
                    store.aendere { $0.healthLesen = an; if !an { $0.healthStand = nil } }
                    geaendert += 1
                    if an { Task { await healthStarten() } } else { healthHinweis = nil }
                }))
                .toggleStyle(.lumenSchalter)
                .frame(minHeight: Abstand.tippflaeche)
                .foregroundStyle(palette.text)
            ZyklusLeise("Lumen Fit liest nur und füllt leere Tage. Eigene Einträge bleiben. Nichts geht zurück nach Health.")
            if let healthHinweis { ZyklusLeise(healthHinweis) }
        }
    }

    private var vorhersageKarte: some View {
        ZyklusKarte(titel: "Vorhersage", symbol: "calendar.badge.clock") {
            Picker("Breite", selection: Binding(get: { store.werte.zeitraum }, set: { n in store.aendere { $0.zeitraum = n }; geaendert += 1 })) {
                ForEach(ZyklusZeitraum.wahl, id: \.wert) { Text($0.text).tag($0.wert) }
            }
            .pickerStyle(.menu)
            .frame(minHeight: Abstand.tippflaeche)
            .foregroundStyle(palette.text)
            ZyklusLeise(ZyklusZeitraum.keineVerhuetung)
        }
    }

    private var datenKarte: some View {
        ZyklusKarte(titel: "Deine Daten", symbol: "square.and.arrow.up") {
            ShareLink(item: ZyklusEinstellungenLogik.export(tage: store.tage, einstellung: store.einstellung)) {
                Label("Als Text teilen", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            }
            Button(role: .destructive) { loeschenFrage = true } label: {
                Label("Alle Einträge leeren", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            }
            Button {
                store.aendere { $0.aktiv = false }
                dismiss()
            } label: {
                Label("Zyklus ausschalten", systemImage: "power")
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            }
            ZyklusLeise("Ausschalten blendet den Zyklus aus. Die Einträge bleiben, bis du sie leerst.")
        }
        .buttonStyle(.federnd)
        .foregroundStyle(palette.text)
    }

    // MARK: Hilfen

    private func schritt(_ titel: String, wert: Int, einheit: String, grenzen: ClosedRange<Int>, setze: @escaping (Int) -> Void) -> some View {
        Stepper(value: Binding(get: { wert }, set: { setze($0); geaendert += 1 }), in: grenzen) {
            HStack {
                Text(titel)
                Spacer()
                Text("\(wert) \(einheit)").foregroundStyle(palette.text2).monospacedDigit()
            }
        }
        .frame(minHeight: Abstand.tippflaeche)
        .foregroundStyle(palette.text)
        .accessibilityValue("\(wert) \(einheit)")
    }

    private func healthStarten() async {
        do {
            let ok = try await ZyklusHealthImport.anfragen(zyklus: store)
            guard ok else { healthHinweis = "Health ist auf diesem Gerät nicht verfügbar."; return }
            let n = await ZyklusHealthImport.importieren(zyklus: store, leser: umgebung.healthLeser)
            healthHinweis = n > 0 ? "\(n) Tage aus Health übernommen." : "Noch nichts Neues. Prüf unter Einstellungen, Health, Daten und Zugriff, ob Lumen Fit lesen darf."
        } catch {
            healthHinweis = "Health hat nicht geantwortet. Versuch es später noch einmal."
        }
    }
}
