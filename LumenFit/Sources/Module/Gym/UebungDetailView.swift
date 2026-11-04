// Quelle: Lovea Health/UebungRekorde.swift (`UebungDetail`, neu im Lumen-Design)
import Accessibility
import Charts
import SwiftUI

/// Eine Übung im Detail (Route `.uebung(id:)`): oben das Bild, darunter drei Reiter. Übersicht (Diagramm und persönliche Rekorde),
/// Historie (jede Einheit mit ihren Sätzen), So geht's (Muskeln und Gerät). Alles wird aus den Einheiten gerechnet, nichts Neues gespeichert.
struct UebungDetailView: View {
    let id: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @State private var reiter: Reiter
    @State private var art = RekordArt.gewicht
    @State private var hinzugefuegt = 0
    @State private var formular = false
    @State private var loeschenFrage = false
    @Environment(\.dismiss) private var schliessen

    private enum Reiter: String, CaseIterable, Identifiable {
        case uebersicht = "Übersicht", historie = "Historie", sogehts = "So geht's"
        var id: String { rawValue }
    }

    /// `anleitungZuerst`: vom Tipp aufs Übungsbild, dann steht gleich "So geht's" offen.
    init(id: String, anleitungZuerst: Bool = false) {
        self.id = id
        _reiter = State(initialValue: anleitungZuerst ? .sogehts : .uebersicht)
    }

    var body: some View {
        Group {
            if let u = uebung {
                inhalt(u)
            } else {
                LeerZustand(stimmung: .denkt, satz: "Diese Übung gibt es im Katalog nicht (mehr).")
            }
        }
        .lumenHintergrund()
        .navigationTitle(uebung?.name ?? "Übung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Nur mit laufendem Training: die Übung kommt ans Ende der Liste (wie "Übung hinzufügen" im Training).
            if let u = uebung, GymSitzung.von(umgebung).laufende != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        GymSitzung.von(umgebung).uebungDazu(u)
                        hinzugefuegt += 1
                    } label: {
                        Label(hinzugefuegt > 0 ? "Hinzugefügt" : "Zum Training", systemImage: hinzugefuegt > 0 ? "checkmark.circle.fill" : "plus.circle")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityHint("Fügt die Übung dem laufenden Training hinzu")
                }
            }
        }
        .toolbar {
            if let eigene, eigene.istEigene(id) {
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button("Bearbeiten", systemImage: "pencil") { formular = true }
                        Button("Löschen", systemImage: "trash", role: .destructive) { loeschenFrage = true }
                    } label: {
                        Label("Eigene Übung", systemImage: "ellipsis.circle").frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
                    }
                }
            }
        }
        .sheet(isPresented: $formular) {
            if let eigene { GymEigenesFormular(store: eigene, bearbeiten: eigene.daten(id)) { _ in } }
        }
        .confirmationDialog("Diese Übung löschen?", isPresented: $loeschenFrage, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                eigene?.loeschen(id)
                schliessen()
            }
        } message: {
            Text("Sie verschwindet aus Suche und Auswahl. Pläne und Trainings behalten sie mit ihrem Namen.")
        }
        .haptik(.auswahl, bei: hinzugefuegt)
    }

    private var eigene: GymEigeneStore? { GymSitzung.von(umgebung).eigene }
    private var uebung: Uebung? { eigene?.finde(id) ?? UebungsKatalog.nachId[id] }

    private func inhalt(_ u: Uebung) -> some View {
        let tage = RekordLogik.tage(katalogId: u.id, in: umgebung.daten?.training.sessions ?? [])
        return ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                // Schleife der GIF-Bilder nur hier, nur sichtbar, nicht bei Reduce Motion und Stromsparmodus (`GymGifLogik`).
                if aufbau == .lovea {
                    UebungLoveaGif(id: u.id, name: u.name, koerper: u.koerper)
                } else {
                    GymUebungGif(id: u.id, koerper: u.koerper)
                        .aspectRatio(1.4, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text(u.name).font(.title2.bold()).foregroundStyle(palette.text)
                    Text(GymEigeneLogik.istEigene(u.id) ? "Primär: \(u.muskel) · Eigene" : "Primär: \(u.muskel)").font(.subheadline).foregroundStyle(palette.text2)
                }
                .accessibilityElement(children: .combine)
                Picker("Ansicht", selection: $reiter) {
                    ForEach(Reiter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                switch reiter {
                case .uebersicht: uebersicht(tage)
                case .historie: historie(tage)
                case .sogehts: soGehts(u)
                }
            }
            .padding(Abstand.l)
        }
    }

    // MARK: Übersicht

    private struct Punkt: Identifiable {
        var id: String
        var datum: Date
        var wert: Double
    }

    @ViewBuilder
    private func uebersicht(_ tage: [UebungTag]) -> some View {
        let punkte = tage.compactMap { t in RekordLogik.wert(t.saetze, art).map { Punkt(id: t.id, datum: t.datum, wert: $0) } }
        let gruen = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        Picker("Wert im Diagramm", selection: $art) {
            ForEach(RekordArt.allCases) { Text($0.titel).tag($0) }
        }
        .pickerStyle(.menu)
        .frame(minHeight: Abstand.tippflaeche)
        if punkte.isEmpty {
            LeerZustand(stimmung: .bereit, satz: "Noch keine Daten. Mach die Übung einmal mit Gewicht, dann steht sie hier.")
        } else {
            let letzter = punkte[punkte.count - 1]
            DiagrammKarte(aussage: "\(art.titel) über die Zeit", kernzeile: "Zuletzt \(RekordLogik.text(letzter.wert, art: art)), \(punkte.count) \(punkte.count == 1 ? "Einheit" : "Einheiten")") {
                Chart(punkte) { p in
                    LineMark(x: .value("Datum", p.datum), y: .value("Wert", p.wert))
                        .foregroundStyle(gruen)
                    PointMark(x: .value("Datum", p.datum), y: .value("Wert", p.wert))
                        .foregroundStyle(gruen)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
                .accessibilityChartDescriptor(VerlaufBeschreibung(
                    titel: art.titel, einheit: art == .wiederholungen ? "Wdh" : "kg",
                    werte: punkte.enumerated().map { (name: "\($0.offset + 1). Einheit, \(Datum.anzeige(Datum.text($0.element.datum)))", wert: $0.element.wert) }))
            }
        }
        Label("Persönliche Rekorde", systemImage: "medal.fill")
            .font(.headline).foregroundStyle(palette.text)
        ListenKarte {
            ForEach(RekordArt.allCases) { a in
                GymZeile(titel: a.titel) {
                    Text(RekordLogik.text(RekordLogik.rekord(tage, a), art: a)).font(.body.weight(.semibold)).monospacedDigit()
                }
                if a != RekordArt.allCases.last { Haarlinie() }
            }
        }
    }

    // MARK: Historie

    @ViewBuilder
    private func historie(_ tage: [UebungTag]) -> some View {
        if tage.isEmpty {
            LeerZustand(stimmung: .bereit, satz: "Noch nie gemacht. Nach dem ersten Training steht hier jeder Satz.")
        }
        ForEach(tage.reversed()) { t in
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(Datum.anzeige(Datum.text(t.datum))).font(.headline).foregroundStyle(palette.text)
                ForEach(t.saetze.indices, id: \.self) { i in
                    HStack(spacing: Abstand.m) {
                        Text(WorkoutLogik.nummer(t.saetze, i)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text2).frame(width: 24, alignment: .leading)
                        Text(WorkoutLogik.satzText(t.saetze[i])).monospacedDigit().foregroundStyle(palette.text)
                        Spacer(minLength: Abstand.s)
                        if let rpe = t.saetze[i].rpe {
                            Text("RPE \(TrainingLogik.kgText(rpe))").font(.subheadline).foregroundStyle(palette.text2)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lumenKartenFlaeche()
        }
    }

    // MARK: So geht's

    private func soGehts(_ u: Uebung) -> some View {
        VStack(spacing: Abstand.m) {
            if let a = UebungsAnleitungen.finden(u.id) {
                anleitung(ablauf: a.ablauf, fehler: a.fehler, unsicher: false)
            } else if let h = EinstellHinweise.finden(name: u.name) {
                anleitung(ablauf: h.anleitung, fehler: h.fehler, unsicher: h.unsicher)
            }
            muskelnUndGeraet(u)
        }
    }

    /// Ablauf und typischer Fehler (eigene Erklärung, sonst `EinstellHinweis`); dessen "Einstellen" bleibt weg, es verweist auf das gespeicherte Gerät, das es nicht mehr gibt.
    private func anleitung(ablauf: String, fehler: String, unsicher: Bool) -> some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                anleitungsBlock("Ablauf", ablauf)
                anleitungsBlock("Typischer Fehler", fehler)
                if unsicher {
                    Label("Unsicher, selbst prüfen", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
                }
            }
            .padding(Abstand.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func anleitungsBlock(_ titel: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
            Text(text).font(.subheadline).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func muskelnUndGeraet(_ u: Uebung) -> some View {
        ListenKarte {
            GymZeile(titel: "Zielmuskel") { Text(u.muskel).foregroundStyle(palette.text2) }
            Haarlinie()
            GymZeile(titel: "Gerät") { Text(u.geraet).foregroundStyle(palette.text2) }
            if !u.neben.isEmpty {
                Haarlinie()
                GymZeile(titel: "Hilft mit") { Text(u.neben.joined(separator: ", ")).foregroundStyle(palette.text2).multilineTextAlignment(.trailing) }
            }
            if let notiz = eigene?.daten(u.id)?.notiz {
                Haarlinie()
                GymZeile(titel: "Notiz") { Text(notiz).foregroundStyle(palette.text2).multilineTextAlignment(.trailing) }
            }
            if !GymEigeneLogik.istEigene(u.id) {
                Haarlinie()
                GymZeile(titel: "Englisch") { Text(u.en.capitalized).foregroundStyle(palette.text2) }
            }
        }
    }
}

/// Die Sprachausgabe des Diagramms: jede Einheit mit ihrem Wert (die Kernzeile steht schon in der Karte darüber).
private struct VerlaufBeschreibung: AXChartDescriptorRepresentable {
    let titel: String
    let einheit: String
    let werte: [(name: String, wert: Double)]

    func makeChartDescriptor() -> AXChartDescriptor {
        let zahlen = werte.map(\.wert)
        let x = AXCategoricalDataAxisDescriptor(title: "Einheit", categoryOrder: werte.map(\.name))
        let y = AXNumericDataAxisDescriptor(title: titel, range: (zahlen.min() ?? 0)...(zahlen.max() ?? 0), gridlinePositions: []) { "\(TrainingLogik.kgText($0)) \(einheit)" }
        let reihe = AXDataSeriesDescriptor(name: titel, isContinuous: true, dataPoints: werte.map { AXDataPoint(x: $0.name, y: $0.wert) })
        return AXChartDescriptor(title: titel, summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: [reihe])
    }
}
