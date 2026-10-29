// Quelle: Lovea Health/Studio/StudioKarte.swift (neu im Lumen-Design; Studio ist ein freies Textfeld, Vorschläge nur aus PrivateDaten.json)
import SwiftUI

/// Die Studio-Zeile der Gym-Seite (Idee 29): Name und Öffnungszeiten, Besuche und Einchecken (Auschecken steht beim laufenden Training). Warnt, wenn die feste Uhrzeit
/// des Profils an einem Trainingstag nicht in die Öffnungszeiten passt.
struct StudioKarte: View {
    let sitzung: GymSitzung
    /// Dasselbe wie der Startknopf der Startseite: Plantag von heute starten oder das gerade beendete Training fortsetzen.
    let einchecken: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var bearbeiten = false

    var body: some View {
        let profil = sitzung.studio?.profil ?? .standard
        let heute = Datum.text(umgebung.uhr())
        let besuche = StudioBesuche.zaehlen(sitzung.training?.sessions ?? [], heute: heute)
        let warnungen = oeffnungsWarnungen(profil)
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: "Studio")
            ListenKarte {
                GymZeile(titel: profil.hatStudio ? profil.anzeigeName : "Kein Studio gewählt",
                         untertitel: profil.hatStudio ? GymOeffnung.kurztext(profil.oeffnung) : "Trag dein Studio ein, dann warnt Lumi dich außerhalb der Öffnungszeiten.") {
                    Button(profil.hatStudio ? "Ändern" : "Eintragen") { bearbeiten = true }
                        .buttonStyle(.bordered).controlSize(.large)
                }
                Haarlinie()
                GymZeile(titel: StudioBesuche.wochenText(besuche),
                         untertitel: "Serie \(besuche.serieWochen) \(besuche.serieWochen == 1 ? "Woche" : "Wochen") · \(besuche.gesamt) insgesamt")
                    .accessibilityElement(children: .combine)
                ForEach(warnungen, id: \.self) { zeile in
                    Haarlinie()
                    Label(zeile, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(palette.text)
                        .padding(Abstand.m)
                }
                Haarlinie()
                GymZeile(titel: "Einchecken", untertitel: "Startet dein Training und zählt den Besuch") {
                    Button("Einchecken", action: einchecken).buttonStyle(.borderedProminent).controlSize(.large)
                }
            }
        }
        .sheet(isPresented: $bearbeiten) { StudioEditorBlatt(sitzung: sitzung) }
    }

    /// Die feste Uhrzeit gegen die Wochentage des Plans.
    private func oeffnungsWarnungen(_ profil: StudioProfil) -> [String] {
        guard let plan = sitzung.training?.plan else { return [] }
        let tage = plan.tage.flatMap(\.wochentage)
        return GymOeffnung.zeilen(GymOeffnung.warnungen(profil.oeffnung, wochentage: tage, start: profil.slotStart, dauer: profil.dauer))
    }
}

/// Studio, Öffnungszeiten und feste Uhrzeit eintragen. Vorschläge aus `PrivateDaten.json` (nur Name und Zeiten), sonst Textfeld.
struct StudioEditorBlatt: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @State private var profil = StudioProfil.standard
    @State private var festeUhrzeit = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Studio") {
                    TextField("Name deines Studios", text: $profil.name)
                    ForEach(StudioVorgaben.vorschlaege(profilName: umgebung.profil.aktiv?.name ?? "")) { v in
                        Button {
                            profil.name = v.name
                            profil.oeffnung = v.oeffnung
                        } label: {
                            Label(v.name, systemImage: "building.2")
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                    }
                }
                Section {
                    Toggle("Rund um die Uhr offen", isOn: $profil.oeffnung.rund)
                    if !profil.oeffnung.rund {
                        fensterZeile("Montag bis Freitag", fenster: $profil.oeffnung.werktage, vorgabe: .init(von: 8 * 60, bis: 22 * 60))
                        fensterZeile("Samstag und Sonntag", fenster: $profil.oeffnung.wochenende, vorgabe: .init(von: 9 * 60, bis: 18 * 60))
                    }
                } header: {
                    Text("Öffnungszeiten")
                } footer: {
                    Text("Ohne Zeiten gilt das Studio als immer offen und Lumi warnt nie.")
                }
                Section {
                    Toggle("Feste Uhrzeit", isOn: $festeUhrzeit)
                    if festeUhrzeit {
                        DatePicker("Beginn", selection: zeitBinding(Binding(get: { profil.slotStart ?? 18 * 60 }, set: { profil.slotStart = $0 })), displayedComponents: .hourAndMinute)
                            .environment(\.timeZone, Datum.zone)
                        Stepper("Dauer \(profil.dauer) min", value: $profil.dauer, in: 15...180, step: 5)
                    }
                } header: {
                    Text("Dein Slot")
                } footer: {
                    Text("Mit fester Uhrzeit schätzt Lumi, ob dein Training in den Slot passt.")
                }
            }
            .navigationTitle("Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var neu = profil
                        if !festeUhrzeit { neu.slotStart = nil }
                        sitzung.studio?.setze(neu)
                        schliessen()
                    }
                }
            }
            .onAppear {
                profil = sitzung.studio?.profil ?? .standard
                festeUhrzeit = profil.slotStart != nil
            }
        }
    }

    @ViewBuilder
    private func fensterZeile(_ titel: String, fenster: Binding<StudioOeffnung.Fenster?>, vorgabe: StudioOeffnung.Fenster) -> some View {
        Toggle(titel, isOn: Binding(get: { fenster.wrappedValue != nil }, set: { fenster.wrappedValue = $0 ? vorgabe : nil }))
        if let f = fenster.wrappedValue {
            DatePicker("von", selection: zeitBinding(Binding(get: { f.von }, set: { fenster.wrappedValue = .init(von: $0, bis: max($0 + 15, f.bis)) })), displayedComponents: .hourAndMinute)
                .environment(\.timeZone, Datum.zone)
            DatePicker("bis", selection: zeitBinding(Binding(get: { f.bis }, set: { fenster.wrappedValue = .init(von: f.von, bis: max($0, f.von + 15)) })), displayedComponents: .hourAndMinute)
                .environment(\.timeZone, Datum.zone)
        }
    }

    /// Minuten seit Mitternacht als Datum (Berlin) für den `DatePicker`.
    private func zeitBinding(_ minuten: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Datum.datum("2026-01-05").addingTimeInterval(Double(minuten.wrappedValue) * 60) },
            set: { minuten.wrappedValue = Datum.minuten(Datum.uhrzeit($0)) ?? minuten.wrappedValue }
        )
    }
}
