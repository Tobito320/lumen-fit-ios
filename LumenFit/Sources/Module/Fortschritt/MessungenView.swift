// Quelle: Lovea Health/Koerper/Messungen.swift (MessungenView, MessungBlatt)
import Charts
import SwiftUI

/// Messungen wie in Hevy: letzter Wert, Diagramm, Historie, Plus zum Erfassen. Gewicht ist dasselbe Gewicht wie überall in der App (Gewohnheit "gewicht"),
/// Umfänge und Körperfett liegen als Tageswerte unter "mass.<art>" in denselben Gewohnheits-Ops. Alle Werte in Zehnteln.
struct MessungenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @Environment(\.bewegungAus) private var reduceMotion
    @State private var art = MessArt.gewicht
    @State private var erfassen = false
    @State private var toast: ToastInhalt?

    var body: some View {
        let punkte = MessLogik.punkte(umgebung.daten?.habits.werte(art.habitId) ?? [:])
        Group {
            if aufbau == .lovea { loveaListe(punkte) } else { lumenSeite(punkte) }
        }
        .navigationTitle("Messungen")
        .navigationBarTitleDisplayMode(.inline)
        .lumenToast($toast)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Messung erfassen", systemImage: "plus") { erfassen = true }
            }
        }
        .sheet(isPresented: $erfassen) {
            MessungBlatt { gespeichert in
                toast = ToastInhalt(titel: "Gespeichert", zeile: gespeichert.map { "\($0.art.titel) \($0.art.text($0.zehntel))" }.joined(separator: " · "), stimmung: .bereit)
            }
        }
    }

    private func lumenSeite(_ punkte: [MessPunkt]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                ListenKarte {
                    HStack {
                        Text("Messung").font(.body).foregroundStyle(palette.text)
                        Spacer()
                        Picker("Messung", selection: $art) {
                            ForEach(MessArt.allCases) { Text($0.titel).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                }
                .haptik(.auswahl, bei: art)
                if let letzter = punkte.last {
                    karte(punkte, letzter: letzter)
                    historie(punkte)
                } else {
                    LeerZustand(stimmung: .bereit, satz: "Noch kein Wert für \(art.titel). Ein Wert, dann zeichnet Lumi die Kurve.", handlung: "Messung erfassen") { erfassen = true }
                        .lumenKartenFlaeche()
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
    }

    /// Lovea `MessungenView` (Messungen.swift:51-111): Liste mit Messart-Menü, letztem Wert groß, Diagramm (180 pt, ohne eigene Farbe) und Historie.
    /// Der Umschalter Ich/Partner entfällt, Lumen ist eine Person.
    private func loveaListe(_ punkte: [MessPunkt]) -> some View {
        List {
            Section {
                Picker("Messung", selection: $art) {
                    ForEach(MessArt.allCases) { a in Text(a.titel).tag(a) }
                }
                .haptik(.auswahl, bei: art)
            }
            .listRowSeparator(.hidden)
            Section {
                if let letzter = punkte.last {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(art.text(letzter.zehntel)).font(.title.bold().monospacedDigit())
                        Text(Datum.anzeige(letzter.tag)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if punkte.count > 1 {
                        Chart(punkte) { p in
                            LineMark(x: .value("Datum", Datum.datum(p.tag)), y: .value(art.einheit, Double(p.zehntel) / 10))
                            PointMark(x: .value("Datum", Datum.datum(p.tag)), y: .value(art.einheit, Double(p.zehntel) / 10))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                        .accessibilityLabel("\(art.titel) über die Zeit")
                        .accessibilityValue("\(art.titel): \(art.text(letzter.zehntel)), \(punkte.count) Messungen")
                    }
                } else {
                    Text("Noch kein Wert. Tipp oben auf das Plus.").foregroundStyle(.secondary)
                }
            }
            .listRowSeparator(.hidden)
            if !punkte.isEmpty {
                Section("\(art.titel) Historie") {
                    ForEach(punkte.reversed()) { p in
                        LabeledContent(Datum.anzeige(p.tag), value: art.text(p.zehntel))
                    }
                }
            }
        }
    }

    // MARK: Karte

    private func karte(_ punkte: [MessPunkt], letzter: MessPunkt) -> some View {
        let zusatz = MessErfassung.aenderung(punkte, art: art)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Text(art.titel).font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
            HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                RollZahl(wert: Double(letzter.zehntel) / 10, format: .number.precision(.fractionLength(1))).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                Text(art.einheit).font(.title3).foregroundStyle(palette.text2)
            }
            .id(art)
            Text(zusatz.map { "\(Datum.anzeige(letzter.tag)) · \($0)" } ?? Datum.anzeige(letzter.tag)).font(.subheadline).foregroundStyle(palette.text2)
            if punkte.count > 1 { diagramm(punkte) }
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .contain)
    }

    private func diagramm(_ punkte: [MessPunkt]) -> some View {
        let farbe = LumenFarben.tief(.bewegen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let werte = punkte.map { Double($0.zehntel) / 10 }
        let niedrig = (werte.min() ?? 0) - 1, hoch = (werte.max() ?? 1) + 1
        return Chart(punkte) { p in
            LineMark(x: .value("Tag", Datum.datum(p.tag)), y: .value(art.einheit, Double(p.zehntel) / 10))
                .foregroundStyle(farbe)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Tag", Datum.datum(p.tag)), y: .value(art.einheit, Double(p.zehntel) / 10))
                .foregroundStyle(farbe)
                .symbolSize(p.id == punkte.last?.id ? 90 : 28)
        }
        .chartYScale(domain: niedrig...hoch)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(palette.text2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel().foregroundStyle(palette.text2)
            }
        }
        .frame(height: 180)
        .animation(reduceMotion ? nil : Feder.weich, value: art)
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: "\(art.titel) über die Zeit", zusammenfassung: "\(art.titel): \(art.text(punkte.last?.zehntel ?? 0)), \(punkte.count) Messungen",
            xTitel: "Tag", yTitel: art.titel, einheit: art.einheit, stetig: true,
            punkte: punkte.map { .init(x: KoerperLogik.tagMonat($0.tag), y: Double($0.zehntel) / 10) }))
    }

    // MARK: Historie

    private func historie(_ punkte: [MessPunkt]) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("\(art.titel) Historie").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
            ListenKarte {
                ForEach(punkte.reversed()) { p in
                    HStack {
                        Text(Datum.anzeige(p.tag)).font(.body).foregroundStyle(palette.text)
                        Spacer(minLength: Abstand.s)
                        Text(art.text(p.zehntel)).font(.body.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                    .padding(.horizontal, Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                    .accessibilityElement(children: .combine)
                    if p.id != punkte.first?.id { Haarlinie() }
                }
            }
        }
    }
}

/// Mehrere Werte für einen Tag erfassen; leere Felder bleiben unberührt. Gespeichert wird erst, wenn alle ausgefüllten Felder im plausiblen Bereich liegen (Hinweis unter der Liste).
struct MessungBlatt: View {
    /// Wird nach dem Speichern mit den gespeicherten Werten gerufen (die Seite dahinter zeigt den Toast).
    let beiSpeichern: ([MessWert]) -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var datum = Date()
    @State private var texte: [MessArt: String] = [:]
    @State private var pruefen = false
    @FocusState private var fokus: MessArt?

    private var ergebnis: MessErfassung.Ergebnis { MessErfassung.pruefe(texte) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    ListenKarte {
                        DatePicker("Datum", selection: $datum, in: ...Date(), displayedComponents: .date)
                            .padding(.horizontal, Abstand.l)
                            .frame(minHeight: Abstand.tippflaeche)
                            .foregroundStyle(palette.text)
                    }
                    Text("Messungen").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
                    ListenKarte {
                        ForEach(MessArt.allCases) { a in
                            feld(a)
                            if a != MessArt.allCases.last { Haarlinie() }
                        }
                    }
                    if pruefen, !ergebnis.ungueltig.isEmpty {
                        Text("Bitte prüfen, diese Werte passen nicht: \(ergebnis.ungueltig.map(\.titel).joined(separator: ", ")). Gespeichert wird erst, wenn alle stimmen.")
                            .font(.footnote).foregroundStyle(palette.text2)
                    }
                }
                .padding(Abstand.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .lumenHintergrund()
            .navigationTitle("Messung erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() }.disabled(texte.values.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { fokus = nil } }
            }
        }
    }

    private func feld(_ a: MessArt) -> some View {
        HStack {
            Text("\(a.titel) (\(a.einheit))").font(.body).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            TextField("–", text: Binding { texte[a] ?? "" } set: { texte[a] = $0 })
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($fokus, equals: a)
                .foregroundStyle(palette.text)
                .frame(maxWidth: 110)
        }
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(Rectangle())
        .onTapGesture { fokus = a }
    }

    private func speichern() {
        pruefen = true
        let e = ergebnis
        guard e.ungueltig.isEmpty, !e.gueltig.isEmpty else { return }
        let tag = Datum.text(datum)
        for w in e.gueltig { umgebung.daten?.habits.setze(w.art.habitId, datum: tag, wert: w.zehntel) }
        beiSpeichern(e.gueltig)
        dismiss()
    }
}
