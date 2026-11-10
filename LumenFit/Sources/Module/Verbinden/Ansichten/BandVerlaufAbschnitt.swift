// Quelle: Lovea Health/Tracker/TrackerVerlaufKarten.swift
import Charts
import SwiftUI

/// Verlauf-Karten auf der Band-Seite: was das Band geliefert hat, als kompakte Karten mit Mini-Diagramm. Nur Werte, die ankamen: eine Karte ohne Daten gibt es
/// nicht. Puls und Schritte kommen aus den Abfragen, die Lumen Fit ohnehin macht, der Schlaf aus der Band-Nacht (`TrackerSchlaf`), der Akku aus dem Verlauf
/// (`TrackerAkkuVerlauf`), Stress und HRV aus ihrem Tagesverlauf (nur bei eingeschalteter Messung). Kein Timer, keine eigene Abfrage.
struct BandVerlaufAbschnitt: View {
    let modell: TrackerModell
    @Environment(\.palette) private var palette

    private var reihen: BandReihen { modell.reihen.fuer(Datum.text(Date())) }

    private var schritte: [TrackerVerlauf.Stunde] {
        guard let heute = modell.heute else { return [] }
        return TrackerVerlauf.schritteJeStunde(heute)
    }

    private var schritteSumme: Int { schritte.reduce(0) { $0 + $1.schritte } }
    private var akkuPunkte: [TrackerAkkuVerlauf.Punkt] { modell.akkuVerlauf.punkte }

    private var leer: Bool {
        reihen.puls.count < 2 && reihen.stress.count < 2 && reihen.hrv.count < 2 && schritteSumme == 0
            && modell.letzteBandNacht == nil && akkuPunkte.count < 2
    }

    var body: some View {
        VerbindenAbschnitt(titel: String(localized: "Verlauf"), fuss: String(localized: "Nur Werte, die das Band geliefert hat. Puls, Schlaf, Stress und HRV sind am Gerät noch nicht geprüft. Den Verlauf von Blutsauerstoff liest Lumen Fit noch nicht.")) {
            if leer {
                Text("Noch keine Verlaufsdaten. Sie erscheinen, sobald das Band verbunden ist und gelesen wurde.").foregroundStyle(palette.text2)
            }
            pulsKarte
            schritteKarte
            stressKarte
            hrvKarte
            schlafKarte
            akkuKarte
        }
    }

    // MARK: Puls

    @ViewBuilder private var pulsKarte: some View {
        let punkte = reihen.puls
        if punkte.count >= 2, let statistik = TrackerVerlauf.pulsStatistik(punkte) {
            BandVerlaufKarte(titel: String(localized: "Puls heute"), symbol: "heart.fill", wert: "\(statistik.letzter) bpm",
                             unterzeile: String(localized: "Tief \(statistik.niedrig) · Hoch \(statistik.hoch) · \(statistik.anzahl) Messungen"),
                             beschreibung: String(localized: "Zuletzt \(statistik.letzter), niedrigster \(statistik.niedrig), höchster \(statistik.hoch), \(statistik.anzahl) Messungen")) {
                Chart(punkte) { p in
                    LineMark(x: .value("Stunde", Double(p.minute) / 60), y: .value("Puls", p.wert))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(palette.akzent)
                }
                .chartXScale(domain: 0.0...24.0)
                .chartYScale(domain: .automatic(includesZero: false))
            }
        }
    }

    // MARK: Schritte

    @ViewBuilder private var schritteKarte: some View {
        if schritteSumme > 0 {
            BandVerlaufKarte(titel: String(localized: "Schritte heute"), symbol: "figure.walk", wert: schritteSumme.formatted(),
                             unterzeile: String(localized: "Je Stunde laut Band"),
                             beschreibung: String(localized: "\(schritteSumme) Schritte heute, verteilt auf die Stunden des Tages")) {
                Chart(schritte) { s in
                    BarMark(x: .value("Stunde", s.stunde), y: .value("Schritte", s.schritte), width: .fixed(6))
                        .foregroundStyle(palette.akzent)
                }
                .chartXScale(domain: 0...24)
            }
        }
    }

    // MARK: Stress und HRV

    @ViewBuilder private var stressKarte: some View {
        let punkte = reihen.stress
        if punkte.count >= 2, let letzter = punkte.max(by: { $0.minute < $1.minute }) {
            BandVerlaufKarte(titel: String(localized: "Stress heute"), symbol: "brain.head.profile", wert: "\(letzter.wert)",
                             unterzeile: String(localized: "Alle 30 Minuten. Bis 29 entspannt, ab 80 hoch."),
                             beschreibung: String(localized: "Zuletzt \(letzter.wert) von 100, \(punkte.count) Messungen heute")) {
                Chart(punkte) { p in
                    LineMark(x: .value("Stunde", Double(p.minute) / 60), y: .value("Stress", p.wert)).foregroundStyle(palette.akzent)
                    PointMark(x: .value("Stunde", Double(p.minute) / 60), y: .value("Stress", p.wert)).foregroundStyle(palette.akzent).symbolSize(18)
                }
                .chartXScale(domain: 0.0...24.0)
                .chartYScale(domain: 0...100)
            }
        }
    }

    @ViewBuilder private var hrvKarte: some View {
        let punkte = reihen.hrv
        if punkte.count >= 2, let letzter = punkte.max(by: { $0.minute < $1.minute }) {
            BandVerlaufKarte(titel: String(localized: "HRV heute"), symbol: "waveform.path.ecg", wert: "\(letzter.wert) ms",
                             unterzeile: String(localized: "Alle 30 Minuten, in Millisekunden. Höher heißt meist erholter."),
                             beschreibung: String(localized: "Zuletzt \(letzter.wert) Millisekunden, \(punkte.count) Messungen heute")) {
                Chart(punkte) { p in
                    LineMark(x: .value("Stunde", Double(p.minute) / 60), y: .value("HRV", p.wert)).foregroundStyle(palette.akzent)
                    PointMark(x: .value("Stunde", Double(p.minute) / 60), y: .value("HRV", p.wert)).foregroundStyle(palette.akzent).symbolSize(18)
                }
                .chartXScale(domain: 0.0...24.0)
                .chartYScale(domain: .automatic(includesZero: false))
            }
        }
    }

    // MARK: Schlaf

    @ViewBuilder private var schlafKarte: some View {
        if let nacht = modell.letzteBandNacht, let leiste = TrackerSchlaf.diagramm(nacht) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Schlaf letzte Nacht", systemImage: "bed.double.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: Abstand.s)
                    Text(EnergieLogik.dauer(nacht.minuten))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                SchlafNachtDiagramm(nacht: leiste)
                Text("Nacht auf \(Datum.anzeige(nacht.tag)), Phasen vom Band.").font(.caption).foregroundStyle(palette.text2)
            }
            .padding(.vertical, Abstand.xs)
        }
    }

    // MARK: Akku

    @ViewBuilder private var akkuKarte: some View {
        if akkuPunkte.count >= 2 { BandAkkuVerlauf(punkte: akkuPunkte).listRowInsets(EdgeInsets()) }
    }
}

/// Eine Karte: Titel und aktueller Wert oben, Mini-Diagramm darunter, eine Zeile Erklärung. Das Diagramm ist für VoiceOver stumm, die Karte spricht `beschreibung`.
/// Das Diagramm zeichnet sich beim Erscheinen von links ein, nicht unter "Bewegung reduzieren" und im Stromsparmodus.
struct BandVerlaufKarte<Inhalt: View>: View {
    let titel: String
    let symbol: String
    let wert: String
    let unterzeile: String
    let beschreibung: String
    let inhalt: Inhalt
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig
    @State private var sichtbar = false

    init(titel: String, symbol: String, wert: String, unterzeile: String, beschreibung: String, @ViewBuilder inhalt: () -> Inhalt) {
        self.titel = titel
        self.symbol = symbol
        self.wert = wert
        self.unterzeile = unterzeile
        self.beschreibung = beschreibung
        self.inhalt = inhalt()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            HStack(alignment: .firstTextBaseline) {
                Label(titel, systemImage: symbol).font(.subheadline.weight(.semibold))
                Spacer(minLength: Abstand.s)
                Text(wert).font(.title3.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            }
            inhalt
                .frame(height: 80)
                .mask(alignment: .leading) {
                    GeometryReader { geo in Rectangle().frame(width: ruhig || sichtbar ? geo.size.width : 0) }
                }
                .accessibilityHidden(true)
            Text(unterzeile).font(.caption).foregroundStyle(palette.text2)
        }
        .padding(.vertical, Abstand.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titel)
        .accessibilityValue(beschreibung)
        .onAppear {
            guard !ruhig else { return }
            withAnimation(.easeOut(duration: 0.7)) { sichtbar = true }
        }
    }
}
