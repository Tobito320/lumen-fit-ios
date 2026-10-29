// Quelle: Lovea Health/Tracker/BandRegelnBlatt.swift
import SwiftUI

/// Blatt "Band-Vibration": je Quelle an/aus, Pulse und Mindestpause, Ruhezeiten, Akku-Wächter. Alles lokal in UserDefaults (`BandQuelle`, `BandEinstellung`);
/// die Regeln selbst stehen in `BandRegeln`, die Ausgabe in `BandPuls`. Neu im Lumen-Design (Formular, Palette); Quellen ohne Erinnerungen und Wecker.
struct BandRegelnBlatt: View {
    var body: some View {
        Form {
            VerbindenAbschnitt(fuss: "Das Band kennt nur einen Vibrationsbefehl: ein Puls von fester Stärke, je Mal rund 5 bis 10 Sekunden. Einstellbar ist darum, ob es vibriert, wie viele Pulse (1 bis 3) und wie lange die Pause bis zum nächsten Mal ist.") {
                EmptyView()
            }
            ForEach(BandQuelle.allCases) { BandQuelleAbschnitt(quelle: $0) }
            BandRuheAbschnitt()
            BandAkkuAbschnitt()
        }
        .verbindenFormular()
        .navigationTitle("Band-Vibration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Eine Quelle: Schalter, Pulse und Mindestpause; im Gym zusätzlich der Ziel-Puls und beim Pausen-Ende "Ausprobieren".
struct BandQuelleAbschnitt: View {
    let quelle: BandQuelle
    @AppStorage private var an: Bool
    @AppStorage private var staerke: String
    @AppStorage private var pause: Int
    @AppStorage(BandEinstellung.zielPuls) private var zielPuls = BandEinstellung.standardZielPuls
    @Environment(AppUmgebung.self) private var umgebung

    init(quelle: BandQuelle) {
        self.quelle = quelle
        _an = AppStorage(wrappedValue: quelle.standardAn, quelle.anSchluessel)
        _staerke = AppStorage(wrappedValue: quelle.standardStaerke.rawValue, quelle.staerkeSchluessel)
        _pause = AppStorage(wrappedValue: quelle.standardPause, quelle.pauseSchluessel)
    }

    var body: some View {
        VerbindenAbschnitt(fuss: fussText) {
            Toggle(isOn: $an) { Label(quelle.name, systemImage: quelle.symbol) }
            if an { regelZeilen }
        }
    }

    @ViewBuilder
    private var regelZeilen: some View {
        Picker("Pulse", selection: $staerke) {
            ForEach(BandNachrichtRegel.Staerke.allCases) { Text($0.name).tag($0.rawValue) }
        }
        Picker(quelle.pauseName, selection: $pause) {
            ForEach(quelle.pausen, id: \.self) { Text(pauseText($0)).tag($0) }
        }
        if quelle == .gymPuls {
            Picker("Ziel-Puls", selection: $zielPuls) {
                ForEach(BandEinstellung.zielPulse, id: \.self) { Text("\($0) Schläge/Min.").tag($0) }
            }
        }
        if quelle == .gymPause {
            Button("Ausprobieren") { Task { await umgebung.band.vibriere(.pauseEnde) } }
                .frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func pauseText(_ minuten: Int) -> String {
        if minuten == 0 { return "Keine" }
        return minuten == 1 ? "1 Minute" : "\(minuten) Minuten"
    }

    private var fussText: String {
        switch quelle {
        case .partner:
            "Ein Puls, wenn dein Partner etwas teilt (Gym, Ziel, Rekord, Schlaf). Braucht die Verbindung mit Lovea."
        case .wunsch:
            "Wenn dein Partner in Lovea eine Vibration wünscht. Lumen Fit führt sie aus, sobald es läuft; ein Wunsch, der älter als 15 Minuten ist, verfällt."
        case .gymPause:
            "Wenn die Pause im offenen Training abläuft. Mit gesperrtem iPhone bleibt nur die Mitteilung auf dem Handy."
        case .gymPuls:
            "Nur im laufenden Training und nur mit Puls vom Band. Der Puls kommt im Takt der Pulsmessung (alle paar Minuten), nicht sofort."
        }
    }
}

/// Uhrzeit-Zeile für Minuten seit Mitternacht (Berliner Zeit, `Datum.kalender`).
private struct BandZeitZeile: View {
    let titel: String
    @Binding var minute: Int

    var body: some View {
        DatePicker(titel, selection: zeit, displayedComponents: .hourAndMinute)
            .environment(\.timeZone, Datum.kalender.timeZone)
    }

    private var zeit: Binding<Date> {
        Binding(get: { Datum.kalender.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date() },
                set: { minute = BandRegeln.minuteAmTag($0) })
    }
}

/// Ruhezeiten: die Nacht (22 bis 7 Uhr) und frei wählbare Fenster. Partner und Wünsche dürfen durch, wenn die Ausnahme an ist.
private struct BandRuheAbschnitt: View {
    @AppStorage(BandEinstellung.nachtAn) private var nachtAn = true
    @AppStorage(BandEinstellung.ausnahme) private var ausnahme = true
    @State private var fenster = BandEinstellung.fensterListe()

    var body: some View {
        VerbindenAbschnitt(titel: "Ruhezeiten", fuss: "In einer Ruhezeit vibriert das Band nicht. Die Nacht läuft von 22:00 bis 07:00 Uhr.") {
            Toggle(isOn: $nachtAn) { Label("Nachts ruhig", systemImage: "moon.zzz.fill") }
            ForEach(fenster.indices, id: \.self) { i in
                VStack {
                    BandZeitZeile(titel: "Von", minute: binding(i, \.von))
                    BandZeitZeile(titel: "Bis", minute: binding(i, \.bis))
                }
            }
            .onDelete { weg in
                fenster.remove(atOffsets: weg)
                speichern()
            }
            if fenster.count < BandEinstellung.maxFenster {
                Button("Zeitfenster hinzufügen") {
                    fenster.append(BandRegeln.Zeitfenster(von: 12 * 60, bis: 13 * 60))
                    speichern()
                }
                .frame(minHeight: Abstand.tippflaeche)
            }
            Toggle("Partner und Wünsche dürfen durch", isOn: $ausnahme)
        }
    }

    private func binding(_ i: Int, _ pfad: WritableKeyPath<BandRegeln.Zeitfenster, Int>) -> Binding<Int> {
        Binding(get: { i < fenster.count ? fenster[i][keyPath: pfad] : 0 },
                set: { neu in
                    guard i < fenster.count else { return }
                    fenster[i][keyPath: pfad] = neu
                    speichern()
                })
    }

    private func speichern() { BandEinstellung.fensterSpeichern(fenster) }
}

/// Akku-Wächter: unter der Schwelle keine Pulse mehr, damit der Akku des Bands nicht leer vibriert.
private struct BandAkkuAbschnitt: View {
    @AppStorage(BandEinstellung.akkuSchwelle) private var schwelle = BandEinstellung.standardAkkuSchwelle

    var body: some View {
        VerbindenAbschnitt(fuss: "Ist das Band unter der Schwelle, vibriert es nicht mehr. Der Akku-Stand ist der zuletzt gelesene, höchstens zwölf Stunden alt.") {
            Picker(selection: $schwelle) {
                ForEach(BandEinstellung.akkuSchwellen, id: \.self) { Text($0 == 0 ? "Aus" : "Unter \($0) %").tag($0) }
            } label: {
                Label("Akku-Wächter", systemImage: "battery.25percent")
            }
        }
    }
}
