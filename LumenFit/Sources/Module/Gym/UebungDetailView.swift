// Quelle: Lovea Health/UebungRekorde.swift (`UebungDetail`, neu im Lumen-Design)
import Accessibility
import Charts
import SwiftUI

/// Eine Übung im Detail (Route `.uebung(id:)`, Entwurf `uebung`): oben die Animation, Name und "Muskel · Gerät", darunter drei Reiter.
/// Anleitung (So geht's, Muskeln und Gerät, außerhalb des Trainings "Andere Varianten"), Verlauf (schwerstes Set, Diagramm mit Wahl des Werts, jede Einheit
/// mit ihren Sätzen), Rekorde (persönliche Rekorde). Alles wird aus den Einheiten gerechnet, nichts Neues gespeichert.
/// "Im Vergleich" (Freunde und Alle) im Reiter Rekorde: Baustein `StatsVergleichKarte(uebungID:)` aus Stats.
struct UebungDetailView: View {
    let id: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @State private var reiter: Reiter
    @State private var art = RekordArt.gewicht
    @State private var hinzugefuegt = 0
    @State private var formular = false
    @State private var loeschenFrage = false
    @Environment(\.dismiss) private var schliessen

    private enum Reiter: String, CaseIterable, Identifiable {
        case anleitung, verlauf, rekorde
        var id: String { rawValue }

        var titel: LocalizedStringKey {
            switch self {
            case .anleitung: "Anleitung"
            case .verlauf: "Verlauf"
            case .rekorde: "Rekorde"
            }
        }
    }

    /// `anleitungZuerst`: aus Katalog, Plan und Bild steht die Anleitung offen; aus dem Training ("Rekorde und Verlauf") der Verlauf.
    init(id: String, anleitungZuerst: Bool = false) {
        self.id = id
        _reiter = State(initialValue: anleitungZuerst ? .anleitung : .verlauf)
    }

    var body: some View {
        Group {
            if let u = uebung {
                inhalt(u)
            } else {
                LeerZustand(stimmung: .denkt, satz: String(localized: "Diese Übung gibt es im Katalog nicht (mehr)."))
            }
        }
        .lumenHintergrund()
        .navigationTitle(uebung?.name ?? String(localized: "Übung"))
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
                GymUebungGif(id: u.id, koerper: u.koerper)
                    .aspectRatio(1.4, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text(u.name).font(.title2.bold()).foregroundStyle(palette.text)
                    Text(GymEigeneLogik.istEigene(u.id) ? "\(u.muskel) · \(u.geraet) · \(String(localized: "Eigene"))" : "\(u.muskel) · \(u.geraet)")
                        .font(.subheadline).foregroundStyle(palette.text2)
                }
                .accessibilityElement(children: .combine)
                Picker("Ansicht", selection: $reiter) {
                    ForEach(Reiter.allCases) { Text($0.titel).tag($0) }
                }
                .pickerStyle(.segmented)
                switch reiter {
                case .anleitung:
                    soGehts(u)
                    varianten(u)
                case .verlauf:
                    if tage.isEmpty {
                        LeerZustand(stimmung: .bereit, satz: String(localized: "Noch kein Verlauf. Nach dem ersten Training mit dieser Übung steht hier jeder Satz."))
                    } else {
                        schwerstes(tage)
                        uebersicht(tage)
                        historie(tage)
                    }
                case .rekorde: rekorde(tage)
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
            LeerZustand(stimmung: .bereit, satz: String(localized: "Noch keine Daten. Mach die Übung einmal mit Gewicht, dann steht sie hier."))
        } else {
            let letzter = punkte[punkte.count - 1]
            let wert = RekordLogik.text(letzter.wert, art: art)
            let kern = punkte.count == 1 ? String(localized: "Zuletzt \(wert), 1 Einheit") : String(localized: "Zuletzt \(wert), \(punkte.count) Einheiten")
            DiagrammKarte(aussage: String(localized: "\(art.titel) über die Zeit"), kernzeile: kern) {
                Chart(punkte) { p in
                    LineMark(x: .value("Datum", p.datum), y: .value("Wert", p.wert))
                        .foregroundStyle(gruen)
                    PointMark(x: .value("Datum", p.datum), y: .value("Wert", p.wert))
                        .foregroundStyle(gruen)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
                .accessibilityChartDescriptor(VerlaufBeschreibung(
                    titel: art.titel, einheit: art == .wiederholungen ? String(localized: "Wdh") : "kg",
                    werte: punkte.enumerated().map { (name: String(localized: "\($0.offset + 1). Einheit, \(Datum.anzeige(Datum.text($0.element.datum)))"), wert: $0.element.wert) }))
            }
        }
    }

    /// Verlauf oben: das schwerste Set groß (Gewicht-Rekord), nur mit Gewicht.
    @ViewBuilder
    private func schwerstes(_ tage: [UebungTag]) -> some View {
        if let kg = RekordLogik.rekord(tage, .gewicht) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Schwerstes Set").font(.footnote).foregroundStyle(palette.text2)
                Text(RekordLogik.text(kg)).font(.largeTitle.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Rekorde

    @ViewBuilder
    private func rekorde(_ tage: [UebungTag]) -> some View {
        if tage.isEmpty {
            LeerZustand(stimmung: .bereit, satz: String(localized: "Noch keine Rekorde. Dein erstes Set ist gleich dein erster Rekord."))
        } else {
            ListenKarte {
                ForEach(RekordArt.allCases) { a in
                    GymZeile(titel: a.titel) {
                        Text(RekordLogik.text(RekordLogik.rekord(tage, a), art: a)).font(.body.weight(.semibold)).monospacedDigit()
                    }
                    if a != RekordArt.allCases.last { Haarlinie() }
                }
            }
            if let erste = tage.first {
                Text("Aus \(tage.count) Einheiten seit \(Datum.anzeige(Datum.text(erste.datum)))").font(.footnote).foregroundStyle(palette.text2)
            }
            StatsVergleichKarte(uebungID: id)
        }
    }

    // MARK: Andere Varianten

    /// Außerhalb des Trainings statt "Ersetzen": bis zu drei Übungen für denselben Muskel (`AusweichLogik`).
    @ViewBuilder
    private func varianten(_ u: Uebung) -> some View {
        let liste = GymSitzung.von(umgebung).laufende == nil ? Array(AusweichLogik.alternativen(fuer: u).prefix(3)) : []
        if !liste.isEmpty {
            Text("Andere Varianten").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            ListenKarte {
                ForEach(Array(liste.enumerated()), id: \.element.id) { i, v in
                    if i > 0 { Haarlinie() }
                    NavigationLink { UebungDetailView(id: v.id, anleitungZuerst: true) } label: {
                        GymUebungZeile(id: v.id, koerper: v.koerper, titel: v.name, untertitel: "\(v.muskel) · \(v.geraet)")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Historie

    @ViewBuilder
    private func historie(_ tage: [UebungTag]) -> some View {
        if tage.isEmpty {
            LeerZustand(stimmung: .bereit, satz: String(localized: "Noch nie gemacht. Nach dem ersten Training steht hier jeder Satz."))
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
                anleitungsBlock(String(localized: "Ablauf"), ablauf)
                anleitungsBlock(String(localized: "Typischer Fehler"), fehler)
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
            GymZeile(titel: String(localized: "Zielmuskel")) { Text(u.muskel).foregroundStyle(palette.text2) }
            Haarlinie()
            GymZeile(titel: String(localized: "Gerät")) { Text(u.geraet).foregroundStyle(palette.text2) }
            if !u.neben.isEmpty {
                Haarlinie()
                GymZeile(titel: String(localized: "Hilft mit")) { Text(u.neben.joined(separator: ", ")).foregroundStyle(palette.text2).multilineTextAlignment(.trailing) }
            }
            if let notiz = eigene?.daten(u.id)?.notiz {
                Haarlinie()
                GymZeile(titel: String(localized: "Notiz")) { Text(notiz).foregroundStyle(palette.text2).multilineTextAlignment(.trailing) }
            }
            if !GymEigeneLogik.istEigene(u.id) {
                Haarlinie()
                GymZeile(titel: String(localized: "Englisch")) { Text(u.en.capitalized).foregroundStyle(palette.text2) }
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
        let x = AXCategoricalDataAxisDescriptor(title: String(localized: "Einheit"), categoryOrder: werte.map(\.name))
        let y = AXNumericDataAxisDescriptor(title: titel, range: (zahlen.min() ?? 0)...(zahlen.max() ?? 0), gridlinePositions: []) { "\(TrainingLogik.kgText($0)) \(einheit)" }
        let reihe = AXDataSeriesDescriptor(name: titel, isContinuous: true, dataPoints: werte.map { AXDataPoint(x: $0.name, y: $0.wert) })
        return AXChartDescriptor(title: titel, summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: [reihe])
    }
}
