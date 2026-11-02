// Quelle: Lovea Health/Tracker/TrackerSeite.swift
import SwiftUI
import UIKit

/// Messungen am Band: die Dauermessungen (Puls mit Abstand, Blutsauerstoff, Stress, HRV). Die Schalter zeigen immer, was das Band meldet; eine Änderung wird
/// geschickt und danach zurückgelesen, daher springt ein Schalter zurück, wenn das Band sie ablehnt. Nur bei Verbindung änderbar.
struct BandMessungenAbschnitt: View {
    let modell: TrackerModell

    private var pulsAbstand: Int { modell.pulsEinstellung?.intervallMinuten ?? TrackerEnergie.standardMinuten }

    private var pulsAbstandWahl: Binding<Int> {
        Binding(get: { pulsAbstand }, set: { modell.aendern(.puls(an: true, minuten: $0)) })
    }

    private var fuss: String {
        if let hinweis = modell.aenderungsHinweis { return "Achtung: \(hinweis)" }
        if modell.pulsEinstellung == nil && modell.messungen.isEmpty && !modell.abfrageLaeuft {
            return "Verbinde das Band, dann liest Lumen Fit hier ab, was es misst."
        }
        return "Nur bei Verbindung änderbar. Lumen Fit schickt die Änderung und liest sie vom Band zurück. Schreiben am Band ist noch nicht am Gerät getestet."
    }

    var body: some View {
        VerbindenAbschnitt(titel: "Messungen am Band", fuss: fuss) {
            zeile("Puls-Dauermessung", "heart.fill", wert: modell.pulsEinstellung?.an) { modell.aendern(.puls(an: $0, minuten: pulsAbstand)) }
            if modell.pulsEinstellung?.an == true {
                Picker(selection: pulsAbstandWahl) {
                    ForEach(BandAnzeige.abstandsListe(aktuell: pulsAbstand), id: \.self) { Text("\($0) Min.").tag($0) }
                } label: {
                    Label("Abstand", systemImage: "timer")
                }
                .pickerStyle(.menu)
                Text("Je kürzer der Abstand, desto mehr Verlauf und desto schneller ist der Akku leer. Der Modus setzt ihn für dich, hier änderst du ihn einzeln.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(TrackerProtokoll.Dauermessung.allCases, id: \.self) { art in
                zeile(art.name, Self.symbol(art), wert: modell.messungen[art]) { modell.aendern(.messung(art, an: $0)) }
            }
        }
        .disabled(!modell.einstellbar)
    }

    /// Ein Schalter, solange das Band den Wert gemeldet hat; sonst Platzhalter (liest) oder "nicht gelesen".
    @ViewBuilder
    private func zeile(_ titel: String, _ symbol: String, wert: Bool?, setzen: @escaping @MainActor (Bool) -> Void) -> some View {
        if let wert {
            Toggle(isOn: Binding(get: { wert }, set: { neu in MainActor.assumeIsolated { setzen(neu) } })) { Label(titel, systemImage: symbol) }
        } else {
            LabeledContent {
                Text("nicht gelesen").foregroundStyle(.secondary).bandLadend(modell.abfrageLaeuft, label: "wird gelesen")
            } label: {
                Label(titel, systemImage: symbol)
            }
        }
    }

    private static func symbol(_ art: TrackerProtokoll.Dauermessung) -> String {
        switch art {
        case .spo2: "lungs.fill"
        case .stress: "brain.head.profile"
        case .hrv: "waveform.path.ecg"
        }
    }
}

/// Schritte: heute am Band (rollt beim Erscheinen hoch), Strecke, letzte Bewegung, die letzten Tage und der Schalter, ob die Band-Schritte zählen.
struct BandSchritteAbschnitt: View {
    let modell: TrackerModell
    @AppStorage(TrackerModell.schritteSchluessel) private var schritteZaehlen = true
    @Environment(\.palette) private var palette

    private var fruehere: [(tag: String, schritte: Int)] { BandAnzeige.fruehereTage(modell.bandTage.tage, heute: Datum.text(Date())) }

    var body: some View {
        VerbindenAbschnitt(titel: "Schritte", fuss: "Es zählt je Tag der höhere Wert von Band und Apple Health, sie werden nie addiert. Aus: es zählt nur Apple Health. Das Band schreibt nichts in Apple Health, sonst zählt Health dieselben Schritte doppelt. Bereits gemeldete Tage bleiben, wenn du das hier ausschaltest.") {
            heute
            if let stand = modell.bandTage.stand {
                LabeledContent("Zuletzt gelesen") { Text(stand, style: .relative) }
            }
            if !fruehere.isEmpty {
                DisclosureGroup("Letzte Tage") {
                    ForEach(fruehere, id: \.tag) { eintrag in
                        LabeledContent(Datum.anzeige(eintrag.tag), value: eintrag.schritte.formatted())
                    }
                }
            }
            Toggle(isOn: $schritteZaehlen) { Label("Schritte vom Band zählen", systemImage: "figure.walk") }
                .frame(minHeight: Abstand.tippflaeche)
        }
    }

    @ViewBuilder private var heute: some View {
        if let heute = modell.heute {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heute am Band").font(.subheadline).foregroundStyle(palette.text2)
                RollZahl(wert: Double(heute.schritte), format: .number.precision(.fractionLength(0)))
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.vertical, Abstand.xs)
            .accessibilityElement(children: .combine)
            LabeledContent("Strecke", value: BandAnzeige.kilometer(meter: heute.meter))
            if let minute = heute.letzteMinute {
                LabeledContent("Letzte Bewegung", value: "ab \(Datum.uhrzeit(minuten: minute)) Uhr")
            }
        } else if modell.abfrageLaeuft {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heute am Band").font(.subheadline)
                Text("00.000").font(.largeTitle.weight(.bold))
            }
            .padding(.vertical, Abstand.xs)
            .bandLadend(label: "Schritte werden gelesen")
        } else {
            Text("Für heute hat das Band noch nichts geliefert. Das Band antippen, verbinden und auf Jetzt abfragen tippen.").foregroundStyle(palette.text2)
        }
    }
}

/// Funktionen: sofort abfragen, das Band vibrieren lassen (zum Finden), einen Puls messen. Nichts läuft von allein, jede Aktion kommt von einem Tipp.
struct BandFunktionenAbschnitt: View {
    let modell: TrackerModell
    @State private var findenZaehler = 0
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig

    private var verbunden: Bool { modell.zustand == .verbunden }

    private var misst: Bool {
        if case .misst = modell.pulsMessung { true } else { false }
    }

    var body: some View {
        VerbindenAbschnitt(titel: "Funktionen", fuss: "Vibrieren hilft beim Finden. Puls jetzt messen schaltet den Sensor für bis zu 45 Sekunden ein; am Gerät noch nicht geprüft. Der Wecker des Bands gehört zu Lumen Alarm.") {
            Button { modell.abfragen() } label: { Label("Jetzt abfragen", systemImage: "arrow.clockwise") }
                .frame(minHeight: Abstand.tippflaeche)
                .disabled(!verbunden || modell.abfrageLaeuft)
            Button {
                modell.finden()
                findenZaehler += 1
            } label: {
                Label { Text("Band vibrieren lassen") } icon: {
                    Image(systemName: "wave.3.right").symbolEffect(.bounce, value: ruhig ? 0 : findenZaehler)
                }
            }
            .frame(minHeight: Abstand.tippflaeche)
            .disabled(!verbunden)
            Button { modell.pulsMessen() } label: {
                HStack {
                    Label("Puls jetzt messen", systemImage: "heart.circle.fill")
                    if misst { Spacer(); ProgressView() }
                }
            }
            .frame(minHeight: Abstand.tippflaeche)
            .disabled(!verbunden || misst)
            if let text = BandAnzeige.pulsMessungText(modell.pulsMessung) {
                Text(text).font(.footnote).foregroundStyle(palette.text2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Die Vibrationsregeln und (nur im Debug-Bau) das Band-Labor. Die Regeln selbst (Quellen, Ruhezeiten, Akku-Wächter, Sitz-Erinnerung) stehen im Blatt "Band-Vibration".
struct BandVibrationAbschnitt: View {
    let modell: TrackerModell

    var body: some View {
        VerbindenAbschnitt(titel: "Vibration", fuss: "Wann das Band vibriert: Wünsche von Lovea, Partner-Ereignisse, Gym, Sitzen, Ruhezeiten. Anrufe und Mitteilungen anderer Apps sieht Lumen Fit nicht (iOS).") {
            NavigationLink { BandRegelnBlatt() } label: { Label("Band-Vibration", systemImage: "waveform") }
                .frame(minHeight: Abstand.tippflaeche)
            #if DEBUG
            NavigationLink { BandLaborAnsicht(modell: modell) } label: { Label("Band-Labor", systemImage: "waveform.path") }
                .frame(minHeight: Abstand.tippflaeche)
            #endif
        }
    }
}

/// Warnen bei niedrigem Akku: eine Mitteilung bei 15 % oder weniger, einmal je Entladung. Sie kommt nur, wenn Lumen Fit den Akku ohnehin liest.
struct BandAkkuWarnAbschnitt: View {
    @AppStorage(BandAkkuWarnung.schluessel) private var warnen = false
    @State private var mitteilungenAus = false
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        VerbindenAbschnitt(titel: "Akku", fuss: "Eine Mitteilung bei \(TrackerAkkuWarnung.grenze) % oder weniger, einmal je Entladung. Sie kommt nur, wenn Lumen Fit den Akku ohnehin liest (bei jeder Verbindung und im Takt des Modus). Lumen Fit fragt dafür nichts zusätzlich ab.") {
            Toggle(isOn: $warnen) { Label("Warnen bei niedrigem Akku", systemImage: "battery.25percent") }
                .frame(minHeight: Abstand.tippflaeche)
                .onChange(of: warnen) { _, an in
                    guard an else { return }
                    mitteilungenAus = false
                    Task { @MainActor in
                        if await umgebung.mitteiler.erlaubnisHolen() { return }
                        warnen = false
                        mitteilungenAus = true
                    }
                }
            if mitteilungenAus, let url = URL(string: UIApplication.openSettingsURLString) {
                Label("Mitteilungen sind für Lumen Fit aus.", systemImage: "exclamationmark.triangle.fill")
                Link("Mitteilungen in den iOS-Einstellungen erlauben", destination: url).frame(minHeight: Abstand.tippflaeche)
            }
        }
    }
}

/// Hilfe: wenn die Verbindung nicht klappt, die Rohdaten für die Fehlersuche und was Lumen Fit am Band nicht ändert.
struct BandHilfeAbschnitt: View {
    let modell: TrackerModell
    @Environment(\.palette) private var palette

    var body: some View {
        VerbindenAbschnitt(titel: "Hilfe", fuss: nil) {
            DisclosureGroup("Verbindung klappt nicht") {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text("Das Band nimmt nur eine Verbindung an. In QWatch Pro muss es unter Device, Device Binding gelöst sein.")
                    Text("Nach dem Trennen sendet es erst wieder, wenn du es antippst. Lumen Fit verbindet sich dann von selbst, auch im Hintergrund.")
                    Text("Lumen Fit fragt bei jeder Verbindung, beim Öffnen der App und \(TrackerModus.abfrageText(modell.modus)) ab, solange die Verbindung steht.")
                }
                .font(.subheadline)
                .foregroundStyle(palette.text2)
                .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("Rohdaten (Fehlersuche)") {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text(modell.rohLog.isEmpty ? "Noch nichts gelesen." : modell.rohLog.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    if !modell.bandLog.isEmpty {
                        // Wege, Dienste, Uhr stellen ("zeit") und die Schlaf-Rohantwort ("schlaf-roh"): ohne diese Zeilen sieht man nicht, was das Band beantwortet.
                        Text(modell.bandLog.joined(separator: "\n"))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    Text("Akku: Byte 1 = Prozent, Byte 2 = lädt. Ob das Ladebit dieses Band beim Laden setzt, ist nicht belegt. Zeigt die Seite 100 % ohne Blitz, steht hier, was das Band wirklich schickt.")
                        .font(.subheadline)
                        .foregroundStyle(palette.text2)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("Was Lumen Fit am Band nicht ändert") {
                Text("Anzeige, Zifferblatt, Erinnerungen, Ziele, Zurücksetzen und Ausschalten laufen weiter über QWatch Pro. Lumen Fit schickt dem Band nur Lesebefehle, Vibrieren, eine einzelne Pulsmessung, das Ein- und Ausschalten der Messungen und einmal je Verbindung die Uhrzeit (Berliner Zeit, das Band kennt keine Sommerzeit); Letzteres ist am Gerät noch nicht getestet.")
                    .font(.subheadline)
                    .foregroundStyle(palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
