// Quelle: Lovea Health/Tracker/TrackerSeite.swift
import SwiftUI
import UIKit

/// Der Kopf der Band-Seite: eine Hero-Karte mit Status und Akku. Der Akku rollt beim Erscheinen hoch, der Balken zieht nach; die Suche dreht einen Ring.
/// Bewegung nur bei Ereignissen und nie unter "Bewegung reduzieren" oder im Stromsparmodus (`bewegungAus`).
struct BandKopfAbschnitt: View {
    let modell: TrackerModell
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig

    var body: some View {
        let status = BandAnzeige.status(modell.zustand, gekoppelt: modell.gekoppelt, abfrageLaeuft: modell.abfrageLaeuft)
        Section {
            HeroKarte {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    HStack(spacing: Abstand.s) {
                        if status.arbeitet {
                            ProgressView().tint(palette.aufAkzent)
                        } else {
                            Image(systemName: status.symbol)
                                .font(.title3.weight(.semibold))
                                .contentTransition(.symbolEffect(.replace))
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(status.titel).font(.headline)
                            if let name = modell.name { Text(name).font(.subheadline).opacity(0.8) }
                        }
                    }
                    if let akku = modell.akku { akkuBlock(akku) }
                    if modell.akkuNiedrig {
                        Label("Akku niedrig: bald laden", systemImage: "battery.25percent").font(.subheadline.weight(.semibold))
                    }
                }
            }
            .animation(ruhig ? nil : Feder.weich, value: status)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func akkuBlock(_ akku: TrackerProtokoll.Akku) -> some View {
        let veraltet = modell.akkuGelesen.map { TrackerAkkuLog.veraltet(gelesen: $0, verbunden: modell.zustand == .verbunden, jetzt: Date(), grenze: 2 * modell.abfrageAbstand) } ?? false
        return VStack(alignment: .leading, spacing: Abstand.s) {
            HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                RollZahl(wert: Double(akku.prozent), format: .number.precision(.fractionLength(0)))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(akku.laedt ? (modell.ladenVermutet ? "% lädt vermutlich" : "% lädt") : "%").font(.title3.weight(.semibold))
                Spacer(minLength: Abstand.s)
                Image(systemName: BandAnzeige.akkuSymbol(prozent: akku.prozent, laedt: akku.laedt))
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            ProgressView(value: BandAnzeige.akkuAnteil(akku.prozent))
                .tint(palette.aufAkzent)
                .animation(ruhig ? nil : Feder.weich, value: akku.prozent)
            if veraltet, let gelesen = modell.akkuGelesen {
                Text("zuletzt gelesen vor \(gelesen, style: .relative)").font(.caption).opacity(0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Akku")
        .accessibilityValue(BandAnzeige.akkuSprechtext(prozent: akku.prozent, laedt: akku.laedt, vermutet: modell.ladenVermutet, veraltet: veraltet))
    }
}

/// Verbindung: Hilfe zum Zustand, die Aktion, die jetzt passt (Suchen, Verbinden, Abbrechen, Bluetooth erlauben), "Automatisch verbinden" und Vergessen mit Rückfrage.
struct BandVerbindungAbschnitt: View {
    let modell: TrackerModell
    let dienst: BandDienstImpl?
    @State private var fragtVergessen = false
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let status = BandAnzeige.status(modell.zustand, gekoppelt: modell.gekoppelt, abfrageLaeuft: modell.abfrageLaeuft)
        VerbindenAbschnitt(titel: "Verbindung", fuss: fuss) {
            if let hilfe = status.hilfe {
                Label(hilfe, systemImage: status.warnung ? "exclamationmark.triangle.fill" : "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(status.warnung ? palette.text : palette.text2)
            }
            aktion
            if modell.gekoppelt {
                Toggle("Automatisch verbinden", isOn: Binding(
                    get: { modell.automatischVerbinden },
                    set: { an in Task { if an { await dienst?.verbinde() } else { await dienst?.trenne() } } }))
                    .frame(minHeight: Abstand.tippflaeche)
                Button("Band vergessen", role: .destructive) { fragtVergessen = true }
                    .frame(minHeight: Abstand.tippflaeche)
                    .confirmationDialog("Band vergessen?", isPresented: $fragtVergessen, titleVisibility: .visible) {
                        Button("Vergessen", role: .destructive) { modell.vergessen() }
                    } message: {
                        Text("Lumen Fit löscht die gespeicherten Band-Tage auf diesem iPhone. Zum Wiederverbinden suchst du das Band neu.")
                    }
            }
        }
    }

    private var fuss: String {
        if modell.gekoppelt {
            return modell.automatischVerbinden
                ? "Lumen Fit verbindet sich von selbst wieder, auch im Hintergrund, sobald das Band sendet."
                : "Aus: Lumen Fit hält keine Verbindung offen, bis du auf Verbinden tippst."
        }
        return umgebung.konto.loveaErlaubt ? "Das Band kann nur eine App gleichzeitig halten. Hält Lovea es noch, lass es dort verbunden und das hier aus." : "Das Band kann nur eine App gleichzeitig halten."
    }

    @ViewBuilder private var aktion: some View {
        switch modell.zustand {
        case .sucht, .wartet:
            Button("Abbrechen") { Task { await dienst?.trenne() } }.frame(minHeight: Abstand.tippflaeche)
        case .nichtErlaubt:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Bluetooth in den iOS-Einstellungen erlauben", destination: url).frame(minHeight: Abstand.tippflaeche)
            }
        case .getrennt, .nichtGefunden, .fehler:
            Button(modell.gekoppelt ? "Verbinden" : "Band suchen") { Task { await dienst?.verbinde() } }.frame(minHeight: Abstand.tippflaeche)
        case .verbunden:
            Button("Trennen") { Task { await dienst?.trenne() } }.frame(minHeight: Abstand.tippflaeche)
        case .bluetoothAus, .nichtVerfuegbar:
            EmptyView()
        }
    }
}

/// Am Arm: ob das Band getragen wird (aus dem Pulsverlauf), wie oft es den Puls misst und der letzte Puls.
struct BandArmAbschnitt: View {
    let modell: TrackerModell

    private var arm: (titel: String, symbol: String) {
        switch modell.armZustand {
        case .amArm: ("Am Arm", "checkmark.circle.fill")
        case .abgelegt: ("Abgelegt", "minus.circle.fill")
        case .unbekannt: ("Unbekannt", "questionmark.circle")
        }
    }

    /// Solange die erste Abfrage läuft und noch kein Pulsverlauf da ist, steht ein Platzhalter da.
    private var armLaedt: Bool { modell.abfrageLaeuft && modell.pulsGelesen == nil }

    var body: some View {
        VerbindenAbschnitt(titel: "Am Arm", fuss: fuss) {
            LabeledContent {
                Text(arm.titel)
            } label: {
                Label("Band", systemImage: arm.symbol)
            }
            .bandLadend(armLaedt, label: "Band wird geprüft")
            LabeledContent("Puls gemessen") {
                if let puls = modell.pulsEinstellung {
                    Text(puls.an ? "alle \(puls.intervallMinuten) Min." : "aus")
                } else {
                    Text("nicht gelesen").foregroundStyle(.secondary).bandLadend(modell.abfrageLaeuft, label: "wird gelesen")
                }
            }
            LabeledContent("Letzter Puls") {
                if let puls = modell.letzterPuls {
                    Text("\(puls.wert) · vor \(puls.zeit, style: .relative)").multilineTextAlignment(.trailing)
                } else if modell.pulsGelesen != nil {
                    Text("heute keiner")
                } else {
                    Text("nicht gelesen").foregroundStyle(.secondary).bandLadend(modell.abfrageLaeuft, label: "wird gelesen")
                }
            }
        }
    }

    private var fuss: String {
        modell.pulsEinstellung?.an == false
            ? "Die Puls-Dauermessung ist aus. Ohne sie kann Lumen Fit nicht erkennen, ob das Band am Arm ist."
            : "Misst das Band zwei Abstände lang keinen Puls, liegt es vermutlich nicht am Arm. Lumen Fit liest dafür bei jeder Abfrage den Pulsverlauf von heute. Am Gerät noch nicht geprüft."
    }
}

/// Der Modus (Sparen oder Viele Daten): setzt Puls-Abstand und Dauermessungen in einem Rutsch und bestimmt, wie oft abgefragt wird.
struct BandModusAbschnitt: View {
    let modell: TrackerModell

    private var wahl: Binding<TrackerModus?> {
        Binding(get: { modell.modus }, set: { neu in if let neu { modell.modusWaehlen(neu) } })
    }

    private var zeile: String {
        modell.modus?.erklaerung
            ?? "Sparen: lange Akkulaufzeit, Kernfunktionen bleiben. Viele Daten: dichte Messung, mehr Verlauf, der Akku hält kürzer."
    }

    private var fuss: String {
        let status = TrackerModus.status(modus: modell.modus, offen: modell.modusOffen, verbunden: modell.zustand == .verbunden,
                                         gelesen: modell.pulsEinstellung != nil, abweichungen: modell.modusAbweichungen)
        guard let akku = modell.modus?.akkuSatz else { return status }
        return status + " " + akku
    }

    var body: some View {
        VerbindenAbschnitt(titel: "Modus", fuss: fuss) {
            Picker("Modus", selection: wahl) {
                ForEach(TrackerModus.allCases) { Text($0.name).tag(Optional($0)) }
            }
            .pickerStyle(.segmented)
            Text(zeile).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
