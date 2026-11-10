// Quelle: Lovea Health/SchritteDetail.swift
import Charts
import SwiftUI

/// Schritte im Detail (Blatt): T/W/M oben, der große Bogen für den gewählten Tag, die Woche oder den Monat (Pfeile und Wischen blättern, nie in die Zukunft,
/// mit Haptik), Chips für kcal, km, aktive Zeit und Etagen, darunter das Diagramm zum Ziehen oder im Monat ein Mini-Bogen je Tag (Tipp wählt den Tag).
/// Das Plus oben trägt Schritte von Hand ein.
struct SchritteDetailView: View {
    /// Lovea-Aufbau: die Seite liegt im Stapel des Heute-Tabs (Lovea pusht `SchritteDetail`), also ohne eigenen Stapel und ohne "Fertig".
    var eingebettet = false
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var zeitraum: SchritteZeitraum = .tag
    @State private var anker: String?
    @State private var eintragen = false
    @State private var version = 0
    @State private var wechsel = 0
    @State private var grenze = 0
    @State private var roh: Date?

    private var bewegung: Animation? { bewegungAus ? nil : Feder.federnd }

    var body: some View {
        _ = version
        let heute = Datum.text(umgebung.uhr())
        let aktuell = min(anker ?? heute, heute)
        let ziel = umgebung.daten?.ziele.ziele.schritte ?? 10_000
        let stand = SchritteDetailLogik.stand(zeitraum: zeitraum, anker: aktuell, heute: heute, tage: umgebung.gesundheit.tage, ziel: ziel)
        return huelle {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    HeroKarte(platte: true) { bogenZeile(stand, aktuell: aktuell, heute: heute) }
                    chips(stand)
                    verlauf(stand, aktuell: aktuell, heute: heute)
                    kennzahlen(stand)
                    if !stand.beste.isEmpty { beste(stand) }
                }
                .foregroundStyle(palette.text)
                .padding(Abstand.l)
            }
            .navigationTitle("Schritte")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar {
                ToolbarItem(placement: .principal) { zeitraumWahl }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schritte eintragen", systemImage: "plus") { eintragen = true }.labelStyle(.iconOnly)
                }
                if !eingebettet { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            }
            .sheet(isPresented: $eintragen) { SchritteEintragenView { version += 1 } }
            .onChange(of: zeitraum) { _, _ in wechsel += 1 }
            .haptik(.auswahl, bei: wechsel)
            .haptik(.warnung, bei: grenze)
        }
    }

    @ViewBuilder
    private func huelle<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        if eingebettet { inhalt() } else { NavigationStack { inhalt() } }
    }

    // MARK: Oben

    private var zeitraumWahl: some View {
        Picker("Zeitraum", selection: $zeitraum.animation(bewegung)) {
            Text("T").tag(SchritteZeitraum.tag).accessibilityLabel("Tag")
            Text("W").tag(SchritteZeitraum.woche).accessibilityLabel("Woche")
            Text("M").tag(SchritteZeitraum.monat).accessibilityLabel("Monat")
        }
        .pickerStyle(.segmented)
        .frame(width: 168)
    }

    // MARK: Bogen

    private func bogenZeile(_ stand: SchritteDetailStand, aktuell: String, heute: String) -> some View {
        let titel = zeitraum == .tag && aktuell == heute ? String(localized: "Heute") : stand.titel
        return HStack(spacing: 0) {
            pfeil("chevron.left", um: -1, label: String(localized: "Früher"), aktuell: aktuell, heute: heute)
            SchritteBogen(titel: titel, anzahl: stand.summe, ziel: stand.periodenZiel)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { wert in
                    guard abs(wert.translation.width) > abs(wert.translation.height) * 1.5, abs(wert.translation.width) > 50 else { return }
                    wechseln(um: wert.translation.width < 0 ? 1 : -1, aktuell: aktuell, heute: heute)
                })
            pfeil("chevron.right", um: 1, label: String(localized: "Später"), aktuell: aktuell, heute: heute)
        }
    }

    private func pfeil(_ symbol: String, um schritte: Int, label: String, aktuell: String, heute: String) -> some View {
        Button { wechseln(um: schritte, aktuell: aktuell, heute: heute) } label: {
            Image(systemName: symbol).font(.title3.weight(.semibold)).frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .buttonStyle(.federnd)
        .foregroundStyle(.white.opacity(0.8))
        .disabled(SchritteLogik.verschoben(aktuell, zeitraum, um: schritte, heute: heute) == nil)
        .accessibilityLabel(label)
    }

    private func wechseln(um schritte: Int, aktuell: String, heute: String) {
        guard let neu = SchritteLogik.verschoben(aktuell, zeitraum, um: schritte, heute: heute) else {
            grenze += 1
            return
        }
        withAnimation(bewegung) { anker = neu }
        wechsel += 1
    }

    /// Ein Tag im Diagramm oder im Monat: der Bogen zeigt ihn.
    private func waehlen(_ tag: String, heute: String) {
        guard tag <= heute, tag != anker || zeitraum != .tag else { return }
        wechsel += 1
        withAnimation(bewegung) {
            zeitraum = .tag
            anker = tag
        }
    }

    // MARK: Chips

    private func chips(_ s: SchritteDetailStand) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Abstand.m) {
                chip(s.kcal > 0 ? HeuteQuellen.zahl(s.kcal) : nil, "kcal")
                chip(s.distanzKm > 0 ? s.distanzKm.formatted(HeuteFormat.kilo()) : nil, "km")
                chip(s.aktivMinuten > 0 ? SchritteBogenLogik.stundenText(s.aktivMinuten) : nil, String(localized: "h aktiv"))
                chip(s.etagen > 0 ? HeuteQuellen.zahl(s.etagen) : nil, String(localized: "Etagen"))
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func chip(_ wert: String?, _ einheit: String) -> some View {
        VStack(spacing: 0) {
            Text(wert ?? "–").font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit().contentTransition(.numericText())
            Text(einheit).font(.caption).foregroundStyle(palette.text2)
        }
        .frame(minWidth: 76, minHeight: 56)
        .padding(.horizontal, Abstand.m)
        .lumenKartenFlaeche()
        .animation(bewegungAus ? nil : Feder.weich, value: wert)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(einheit == String(localized: "h aktiv") ? String(localized: "Aktive Zeit") : einheit): \(wert.map { "\($0) \(einheit)" } ?? String(localized: "keine Daten"))")
    }

    // MARK: Verlauf

    @ViewBuilder
    private func verlauf(_ s: SchritteDetailStand, aktuell: String, heute: String) -> some View {
        if zeitraum == .monat {
            SchritteMonatBoegen(anker: aktuell, heute: heute, tage: umgebung.gesundheit.tage, ziel: s.ziel) { waehlen($0, heute: heute) }
        } else {
            diagramm(s, aktuell: aktuell, heute: heute)
        }
    }

    private func diagramm(_ s: SchritteDetailStand, aktuell: String, heute: String) -> some View {
        let gewaehlt: String? = zeitraum == .tag ? aktuell : nil
        return DiagrammKarte(aussage: s.zielTage > 0 ? String(localized: "\(s.zielTage) \(s.zielTage == 1 ? String(localized: "Tag") : String(localized: "Tage")) über dem Ziel") : String(localized: "Noch kein Tag über dem Ziel"),
                             kernzeile: s.schnitt.map { String(localized: "Im Schnitt \(HeuteQuellen.zahl($0)) Schritte am Tag") } ?? String(localized: "Keine Werte")) {
            Chart {
                ForEach(s.punkte) { p in
                    BarMark(x: .value("Tag", Datum.datum(p.tag), unit: .day), y: .value("Schritte", p.schritte)).cornerRadius(3)
                        .opacity(gewaehlt == nil || p.tag == gewaehlt ? 1 : 0.4)
                }
                RuleMark(y: .value("Ziel", s.ziel))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(palette.text2)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Ziel \(HeuteQuellen.zahl(s.ziel))").font(.caption.weight(.medium)).foregroundStyle(palette.text2)
                    }
                if let gewaehlt, let wert = s.punkte.first(where: { $0.tag == gewaehlt })?.schritte {
                    RuleMark(x: .value("Tag", Datum.datum(gewaehlt), unit: .day))
                        .foregroundStyle(palette.text.opacity(0.35))
                        .annotation(position: .top, spacing: 2) {
                            Text(HeuteQuellen.zahl(wert)).font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(palette.grund)
                                .padding(.horizontal, Abstand.s).padding(.vertical, 3).background(palette.text, in: .capsule)
                        }
                }
            }
            .foregroundStyle(palette.text)
            .chartYScale(domain: 0...Double(max(s.hoechster, 1)) * 1.3)
            .chartXSelection(value: $roh)
            .onChange(of: roh) { _, neu in if let neu { waehlen(Datum.text(neu), heute: heute) } }
            .environment(\.locale, Datum.anzeigeLocale)
            .frame(height: 190)
            .accessibilityChartDescriptor(HeuteDiagrammBeschreibung(
                titel: String(localized: "Schritte \(s.titel)"), zusammenfassung: s.schnitt.map { String(localized: "Im Schnitt \(HeuteQuellen.zahl($0)) Schritte am Tag, Ziel \(HeuteQuellen.zahl(s.ziel))") } ?? String(localized: "Keine Werte"),
                xTitel: String(localized: "Tag"), yTitel: String(localized: "Schritte"), einheit: String(localized: "Schritte"),
                punkte: s.punkte.map { HeuteDiagrammPunkt(name: SchritteDetailLogik.kurz($0.tag), wert: Double($0.schritte)) }))
        }
    }

    private func kennzahlen(_ s: SchritteDetailStand) -> some View {
        ListenKarte {
            kennzahl(String(localized: "Schnitt pro Tag"), s.schnitt.map { String(localized: "\(HeuteQuellen.zahl($0)) Schritte") } ?? "–")
            Haarlinie()
            kennzahl(String(localized: "Tage mit Schritten"), "\(s.tageMitDaten)")
        }
    }

    private func kennzahl(_ titel: String, _ wert: String) -> some View {
        HStack {
            Text(titel).font(.body)
            Spacer()
            Text(wert).font(.body.monospacedDigit()).foregroundStyle(palette.text2)
        }
        .padding(Abstand.l)
        .accessibilityElement(children: .combine)
    }

    private func beste(_ s: SchritteDetailStand) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Beste Tage").font(.headline).accessibilityAddTraits(.isHeader)
            ListenKarte {
                ForEach(Array(s.beste.enumerated()), id: \.element.id) { index, p in
                    if index > 0 { Haarlinie() }
                    HStack {
                        Text(Datum.anzeige(p.tag)).font(.body)
                        Spacer()
                        Text(HeuteQuellen.zahl(p.schritte)).font(.body.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                    .padding(Abstand.l)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Monatsansicht: ein Mini-Bogen je Tag (voll beim Ziel); ein Tipp zeigt den Tag im großen Bogen.
struct SchritteMonatBoegen: View {
    let anker: String
    let heute: String
    let tage: [String: TagesWerte]
    let ziel: Int
    let waehlen: (String) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        let gitter = HealthLogik.monatsGitter(heute: anker, monateZurueck: 0)
        VStack(spacing: Abstand.s) {
            HStack(spacing: 0) {
                ForEach(HabitLogik.wochentagKuerzel, id: \.self) { k in
                    Text(k).font(.caption2.weight(.semibold)).foregroundStyle(palette.text2).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: Abstand.s) {
                ForEach(Array(gitter.enumerated()), id: \.offset) { _, tag in zelle(tag) }
            }
        }
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }

    @ViewBuilder
    private func zelle(_ tag: String?) -> some View {
        if let tag, tag <= heute {
            let schritte = tage[tag]?.schritte ?? 0
            Button { waehlen(tag) } label: {
                ZStack {
                    HeuteMiniBogen(anteil: Double(schritte) / Double(max(1, ziel)), bereich: .bewegen, strich: 3)
                    Text(HabitRaster.tagesnummer(tag)).font(.caption2).monospacedDigit().foregroundStyle(palette.text)
                }
                .frame(width: 38, height: 38)
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                .contentShape(Rectangle())
            }
            .buttonStyle(.federnd)
            .accessibilityLabel(Datum.anzeige(tag))
            .accessibilityValue(schritte > 0 ? "\(HeuteQuellen.zahl(schritte)) Schritte" : "keine Daten")
        } else if let tag {
            Text(HabitRaster.tagesnummer(tag)).font(.caption2).foregroundStyle(palette.text2.opacity(0.5))
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche).accessibilityHidden(true)
        } else {
            Color.clear.frame(height: Abstand.tippflaeche)
        }
    }
}
