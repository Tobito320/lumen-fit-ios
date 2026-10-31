// Quelle: Lovea Health/Coach/CoachAntwortTeile.swift (Diagramm, Fortschritt, Schlaf-Nacht, Aufgabe, Weg, Ziel, Karte "Eingetragen")
import Charts
import SwiftUI

// Bausteine unter einer Antwort des Coachs: Diagramm (Balken oder Linie, Tipp zeigt den Wert), Fortschrittsring mit "Mehr dazu", Schlaf-Nacht,
// abhakbare Aufgabe, Weg in die App, Ziel merken und die Karte "Eintragen?" mit Bestätigen und Rückgängig. Alles hier zeichnet nur, was
// `CoachMarker` schon geprüft hat. Jede Tippfläche hat mindestens 44 pt, jedes Symbol ein Label, Bewegung folgt `bewegungAus`. Kein Timer.

// MARK: - Diagramm

/// VoiceOver beschreibt das Diagramm Punkt für Punkt, wie die Charts im Essen-Modul.
struct CoachDiagrammBeschreibung: AXChartDescriptorRepresentable {
    let titel: String
    let namen: [String]
    let punkte: [CoachMarker.Punkt]

    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXCategoricalDataAxisDescriptor(title: "Zeit", categoryOrder: namen)
        let hoechster = max(1, punkte.map(\.wert).max() ?? 1)
        let y = AXNumericDataAxisDescriptor(title: titel, range: 0...hoechster, gridlinePositions: []) { wert in CoachAnzeige.zahl(wert) }
        let reihe = AXDataSeriesDescriptor(name: titel, isContinuous: false, dataPoints: zip(namen, punkte).map { AXDataPoint(x: $0, y: $1.wert) })
        return AXChartDescriptor(title: titel, summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: [reihe])
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

/// Rein: die Spalten eines Diagramms. Gleiche Beschriftungen würden im Diagramm auf einen Balken fallen; ein unsichtbares Zeichen trennt sie.
enum CoachDiagrammLogik {
    static func spalten(_ punkte: [CoachMarker.Punkt]) -> [String] {
        var gesehen: [String: Int] = [:]
        return punkte.map { punkt in
            let bisher = gesehen[punkt.label, default: 0]
            gesehen[punkt.label] = bisher + 1
            return punkt.label + String(repeating: "\u{200B}", count: bisher)
        }
    }

    /// Balken fangen bei 0 an, die Linie zoomt auf ihre Werte (ein Gewicht von 78 bis 80 kg wäre sonst eine Gerade).
    static func wertebereich(_ punkte: [CoachMarker.Punkt], linie: Bool) -> ClosedRange<Double> {
        let hoch = max(punkte.map(\.wert).max() ?? 0, 1)
        guard linie, let tief = punkte.map(\.wert).min() else { return 0...(hoch * 1.25) }
        let rand = max((hoch - tief) * 0.3, hoch * 0.01, 0.5)
        return (tief - rand)...(hoch + rand)
    }
}

struct CoachDiagramm: View {
    let titel: String
    let punkte: [CoachMarker.Punkt]
    /// Linie mit Punkten statt Balken (`[[linie: ...]]`): für Verläufe über Zeit.
    var linie = false

    /// Die getippte Spalte (`spalten`-Name), `nil` = keine.
    @State private var auswahl: String?
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @Environment(\.bewegungAus) private var reduceMotion

    /// Was nicht getippt ist, tritt zurück, solange eine Spalte gewählt ist.
    private func deckkraft(_ name: String) -> Double { auswahl == nil || auswahl == name ? 1 : 0.35 }

    private func beschriftung(_ wert: Double) -> String {
        wert >= 1000 ? CoachFormat.zahl(Int(min(wert, 1_000_000_000))) : CoachAnzeige.zahl(wert)
    }

    var body: some View {
        let namen = CoachDiagrammLogik.spalten(punkte)
        let gewaehlt = auswahl.flatMap { namen.firstIndex(of: $0) }.map { punkte[$0] }
        DiagrammKarte(aussage: titel, kernzeile: gewaehlt.map { "\($0.label): \(CoachAnzeige.zahl($0.wert))" } ?? "Tippe auf einen Wert, um ihn zu sehen.") {
            Chart {
                ForEach(Array(punkte.enumerated()), id: \.offset) { index, punkt in
                    if linie {
                        LineMark(x: .value("Zeit", namen[index]), y: .value("Wert", punkt.wert))
                            .foregroundStyle(aufbau.farbe(LoveaDaten.coachMint, sonst: palette.akzent))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Zeit", namen[index]), y: .value("Wert", punkt.wert))
                            .foregroundStyle(aufbau.farbe(LoveaDaten.coachMint, sonst: palette.akzent))
                            .symbolSize(auswahl == namen[index] ? 110 : 45)
                            .opacity(deckkraft(namen[index]))
                            .annotation(position: .top, spacing: 3) {
                                Text(beschriftung(punkt.wert)).font(.caption2).monospacedDigit().foregroundStyle(palette.text2)
                            }
                    } else {
                        BarMark(x: .value("Zeit", namen[index]), y: .value("Wert", punkt.wert))
                            .foregroundStyle(aufbau.farbe(LoveaDaten.coachMint, sonst: palette.akzent))
                            .cornerRadius(4)
                            .opacity(deckkraft(namen[index]))
                            .annotation(position: .top, spacing: 3) {
                                Text(beschriftung(punkt.wert)).font(.caption2).monospacedDigit().foregroundStyle(palette.text2)
                            }
                    }
                }
            }
            .chartXSelection(value: $auswahl)
            .chartYScale(domain: CoachDiagrammLogik.wertebereich(punkte, linie: linie))
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 150)
            .accessibilityChartDescriptor(CoachDiagrammBeschreibung(titel: titel, namen: namen, punkte: punkte))
        }
        .animation(reduceMotion ? nil : Feder.schnell, value: auswahl)
        .haptik(.auswahl, bei: auswahl ?? "")
    }
}

// MARK: - Fortschritt

/// Ein Ring mit "von" und "Mehr dazu", wenn es die Seite dazu gibt. Der Ring läuft beim Erscheinen ein (nicht mit "Bewegung reduzieren").
struct CoachFortschritt: View {
    let label: String
    let aktuell: Double
    let ziel: Double
    /// Die Seite zum Wert; `nil` = kein "Mehr dazu".
    var weg: Route?

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @Environment(\.bewegungAus) private var reduceMotion
    @State private var gezeigt: Double = 0

    var body: some View {
        let anteil = CoachLokal.anteil(aktuell: aktuell, ziel: ziel)
        // Eine flache Karte: die eine mutige Karte des Tabs bleibt der Morgen-Check.
        HStack(spacing: Abstand.l) {
            ZStack {
                Circle().stroke(palette.haar, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: gezeigt)
                    .stroke(aufbau.farbe(LoveaDaten.coachMint, sonst: palette.akzent), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((anteil * 100).rounded())) %").font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Text(label).font(.headline).foregroundStyle(palette.text)
                Text("\(CoachAnzeige.zahl(aktuell)) von \(CoachAnzeige.zahl(ziel))").font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                if let weg {
                    Button { umgebung.router.oeffne(weg) } label: {
                        Label("Mehr dazu", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.text)
                            .frame(minHeight: Abstand.tippflaeche, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.federnd)
                    .accessibilityHint("Öffnet die Seite dazu")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(label): \(CoachAnzeige.zahl(aktuell)) von \(CoachAnzeige.zahl(ziel))")
        .onAppear {
            if reduceMotion { gezeigt = anteil } else { withAnimation(.smooth(duration: 0.8)) { gezeigt = anteil } }
        }
    }
}

// MARK: - Schlaf-Nacht

/// Nacht-Diagramm unter einer Antwort (`[[schlaf: JJJJ-MM-TT]]`), gezeichnet aus den Gesundheitsdaten (derselbe Baustein wie im Schlaf-Tab).
/// Keine Daten: gar nichts, kein Fehler. Tippen öffnet den Schlaf-Tab.
struct CoachSchlafKarte: View {
    let tag: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        if let nacht = umgebung.gesundheit.naechte[tag] {
            Button { umgebung.router.oeffne(.schlaf(.letzteNacht)) } label: {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Schlaf").font(.subheadline.weight(.semibold))
                            Text("Nacht auf \(Datum.anzeige(tag))").font(.caption).foregroundStyle(palette.text2)
                        }
                        Spacer(minLength: Abstand.s)
                        Text(CoachGesundheit.dauer(minuten: nacht.schlafMinuten)).font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                    SchlafNachtDiagramm(nacht: nacht)
                }
                .foregroundStyle(palette.text)
                .padding(Abstand.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lumenKartenFlaeche()
                .contentShape(.rect)
            }
            .buttonStyle(.federnd)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(nacht.beschreibung)
            .accessibilityHint("Öffnet den Schlaf")
        }
    }
}

// MARK: - Aufgabe zum Abhaken

struct CoachAufgabeZeile: View {
    let text: String
    let erledigt: Bool
    let umschalten: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: umschalten) {
            HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                Image(systemName: erledigt ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(erledigt ? palette.akzent : palette.text2)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                Text(CoachText.inline(text))
                    .font(.body)
                    .strikethrough(erledigt)
                    .foregroundStyle(erledigt ? palette.text2 : palette.text)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CoachAnzeige.klartext(text))
        .accessibilityValue(erledigt ? "Erledigt" : "Offen")
    }
}

// MARK: - Weg und Ziel

/// Link in einen Bereich der App.
struct CoachWeg: View {
    let route: Route
    let beschriftung: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        Button { umgebung.router.oeffne(route) } label: {
            HStack(spacing: Abstand.xs) {
                Text(beschriftung).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).accessibilityHidden(true)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, Abstand.m)
            .frame(minHeight: Abstand.tippflaeche)
            .contentShape(.capsule)
        }
        .buttonStyle(.federnd)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// "Als Ziel merken" unter einer Antwort mit `[[ziel: ...]]`. Das Ziel steht danach im Menü unter "Mein Ziel".
struct CoachZielKnopf: View {
    let text: String
    let modell: CoachModell
    @Environment(\.palette) private var palette

    var body: some View {
        let gemerkt = modell.ziel == CoachEinstellungen.zielBereinigen(text)
        Button {
            guard !gemerkt else { return }
            modell.setzeZiel(text)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(gemerkt ? "Als Ziel gemerkt" : "Als Ziel merken", systemImage: gemerkt ? "flag.fill" : "flag")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(text).font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.leading)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, Abstand.m)
            .padding(.vertical, Abstand.s)
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            .lumenKartenFlaeche()
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .accessibilityHint(gemerkt ? "" : "Speichert den Satz als dein Ziel")
    }
}

// MARK: - Karte "Eintragen?" und "Eingetragen"

/// Unten über der Eingabe: ein offener Vorschlag mit Eintragen und Verwerfen, oder das, was eingetragen wurde, mit Rückgängig.
struct CoachEintragsKarte: View {
    let modell: CoachModell
    let gedaechtnisOeffnen: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let bestaetigt = modell.bestaetigt
        let vorschlag = modell.vorschlagZeilen
        VStack(alignment: .leading, spacing: Abstand.s) {
            if !bestaetigt.isEmpty || modell.nichtGeklappt {
                Text(modell.nichtGeklappt ? "Nicht geklappt" : "Eingetragen").font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
                ForEach(Array(bestaetigt.enumerated()), id: \.offset) { _, zeile in zeilenAnsicht(zeile) }
                HStack {
                    if modell.kannRueckgaengig {
                        Button("Rückgängig") { modell.eintragRueckgaengig() }
                            .buttonStyle(.bordered)
                            .accessibilityHint("Nimmt den Eintrag zurück")
                    }
                    Button("Schließen") { modell.karteSchliessen() }
                        .buttonStyle(.borderless)
                }
                .frame(minHeight: Abstand.tippflaeche)
            }
            if !vorschlag.isEmpty {
                Text("Eintragen?").font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
                ForEach(Array(vorschlag.enumerated()), id: \.offset) { _, zeile in
                    Label(zeile.text, systemImage: zeile.symbol).font(.footnote).foregroundStyle(palette.text)
                }
                HStack {
                    Button("Eintragen") { modell.vorschlagBestaetigen() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Trägt das ein. Danach kannst du es zurücknehmen")
                    Button("Verwerfen") { modell.vorschlagVerwerfen() }
                        .buttonStyle(.bordered)
                }
                .frame(minHeight: Abstand.tippflaeche)
            }
        }
        .padding(Abstand.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func zeilenAnsicht(_ zeile: CoachTracking.Zeile) -> some View {
        if let route = zeile.route {
            Button { umgebung.router.oeffne(route) } label: { inhalt(zeile, knopf: true) }
                .buttonStyle(.federnd)
                .accessibilityHint("Öffnet die Seite dazu")
        } else if zeile.oeffnetGedaechtnis {
            Button(action: gedaechtnisOeffnen) { inhalt(zeile, knopf: true) }
                .buttonStyle(.federnd)
                .accessibilityHint("Öffnet das Gedächtnis")
        } else {
            inhalt(zeile, knopf: false)
        }
    }

    private func inhalt(_ zeile: CoachTracking.Zeile, knopf: Bool) -> some View {
        HStack(spacing: Abstand.s) {
            Label(zeile.text, systemImage: zeile.symbol).font(.footnote).multilineTextAlignment(.leading)
            Spacer(minLength: Abstand.s)
            if knopf { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(palette.text2).accessibilityHidden(true) }
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, minHeight: knopf ? Abstand.tippflaeche : nil, alignment: .leading)
        .contentShape(.rect)
    }
}
