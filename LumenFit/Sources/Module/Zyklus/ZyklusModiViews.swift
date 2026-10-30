// Quelle: Lovea Zyklus/ZyklusSchwangerView.swift, ZyklusKinderwunschView.swift, ZyklusPilleView.swift (Erinnerungen weggelassen: Lumen Alarm)
import SwiftUI

/// Tag von heute ändern, wie in den drei Modi: umschalten, speichern.
@MainActor private func heutigerTag(_ store: ZyklusStore, _ aendere: (inout ZyklusTag) -> Void) {
    var tag = store.tage[store.heute] ?? ZyklusTag(id: store.heute)
    aendere(&tag)
    store.setze(tag)
}

// MARK: - Schwanger

/// Schwangerschaft: Woche aus Periodenstart oder Termin, Größenvergleich, Termin, Symptome von heute.
/// Ein Termin vom Arzt hat Vorrang; ohne ihn rechnet die Ansicht 280 Tage ab der letzten Periode.
struct ZyklusSchwangerView: View {
    let store: ZyklusStore
    @Environment(\.palette) private var palette

    private static let symptome: [ZyklusSymptom] = [.uebelkeit, .muedigkeit, .rueckenschmerzen, .heisshunger, .schwindel, .kopfschmerzen, .brustspannen, .verstopfung]

    private var stand: ZyklusModiLogik.SchwangerStand? {
        let termin = store.werte.schwangerTermin
        let start = termin.map { Datum.addTage($0, -ZyklusModiLogik.schwangerschaftsTage) } ?? store.logik().letzterPeriodenStart
        guard let start else { return nil }
        return ZyklusModiLogik.schwangerStand(start: start, termin: termin, heute: store.heute)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Abstand.l) {
                if let stand {
                    ZyklusRingAnsicht(abschnitte: ZyklusRingLogik.einfach(.luteal),
                                      fortschritt: Double(stand.woche * 7 + stand.tag) / Double(ZyklusModiLogik.schwangerschaftsTage),
                                      phase: nil, titel: ZyklusModiLogik.wochenText(stand), untertitel: "\(stand.trimester). Trimester")
                    if let vergleich = ZyklusModiLogik.groessenVergleich(woche: stand.woche) {
                        ZyklusKarte(titel: "So groß wie \(vergleich)", symbol: "leaf.fill") { ZyklusLeise("Dein Baby wächst jeden Tag ein Stück.") }
                    }
                    ZyklusKarte(titel: "Termin: \(Datum.anzeige(stand.termin))", symbol: "calendar") { ZyklusLeise(terminText(stand.tageBisTermin)) }
                } else {
                    ZyklusKarte(titel: "Noch ohne Datum", symbol: "calendar") {
                        ZyklusLeise("Trag deinen ersten Periodentag ein oder nenne den Termin, dann zähle ich die Wochen.")
                    }
                }
                terminWahl
                ZyklusKarte(titel: "Wie geht es dir heute?", symbol: "heart.fill") {
                    ZyklusFluss {
                        ForEach(Self.symptome, id: \.self) { s in
                            let an = store.tage[store.heute]?.symptome.contains(s) == true
                            Button { heutigerTag(store) { if an { $0.symptome.remove(s) } else { $0.symptome.insert(s) } } } label: {
                                ZyklusWahlChip(titel: s.eintragTitel, gewaehlt: an)
                            }
                            .buttonStyle(.federnd)
                        }
                    }
                    .haptik(.auswahl, bei: store.tage[store.heute]?.symptome)
                }
            }
            .padding(Abstand.l)
        }
        .lumenHintergrund()
    }

    private var terminWahl: some View {
        ZyklusKarte(titel: "Termin vom Arzt", symbol: "stethoscope") {
            Toggle("Eigenen Termin verwenden", isOn: Binding(
                get: { store.werte.schwangerTermin != nil },
                set: { an in store.aendere { $0.schwangerTermin = an ? Datum.addTage(store.heute, ZyklusModiLogik.schwangerschaftsTage / 2) : nil } }))
                .toggleStyle(.lumenSchalter)
                .frame(minHeight: Abstand.tippflaeche)
            if let termin = store.werte.schwangerTermin {
                DatePicker("Errechneter Termin", selection: Binding(
                    get: { Datum.datum(termin) },
                    set: { d in store.aendere { $0.schwangerTermin = Datum.text(d) } }), displayedComponents: .date)
                    .environment(\.calendar, Datum.kalender)
                    .frame(minHeight: Abstand.tippflaeche)
            }
        }
        .foregroundStyle(palette.text)
    }

    private func terminText(_ tage: Int) -> String {
        switch tage {
        case ..<0: "Der Termin ist \(-tage) Tage her."
        case 0: "Heute ist der Termin."
        case 1: "Noch 1 Tag."
        default: "Noch \(tage) Tage."
        }
    }
}

// MARK: - Kinderwunsch

/// Kinderwunsch: fruchtbares Fenster, Tests, kurzes Tagebuch (Notiz von heute).
struct ZyklusKinderwunschView: View {
    let store: ZyklusStore
    @State private var notiz = ""
    @State private var gespeichert = 0
    @Environment(\.palette) private var palette

    private var stand: ZyklusModiLogik.KinderwunschStand {
        ZyklusModiLogik.kinderwunschStand(logik: store.logik(), tage: Array(store.tage.values), heute: store.heute)
    }

    var body: some View {
        let s = stand
        ScrollView {
            VStack(spacing: Abstand.l) {
                ZyklusRingAnsicht(abschnitte: ZyklusRingLogik.einfach(s.lage == .eisprung ? .eisprung : .fruchtbar), fortschritt: fortschritt(s),
                                  phase: s.lage == .eisprung ? .eisprung : .fruchtbar, titel: titel(s.lage), untertitel: untertitel(s))
                ZyklusKarte(titel: "Tests in diesem Zyklus", symbol: "testtube.2") {
                    ZyklusLeise("\(s.positiveTests) positiv, \(s.negativeTests) negativ")
                    ZyklusFluss {
                        testKnopf("Eisprungtest positiv", .positiv)
                        testKnopf("Eisprungtest negativ", .negativ)
                    }
                }
                ZyklusKarte(titel: "Tagebuch", symbol: "book.fill") {
                    TextField("Was war heute wichtig?", text: $notiz, axis: .vertical)
                        .lineLimit(2...5)
                        .foregroundStyle(palette.text)
                    Button {
                        let text = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
                        heutigerTag(store) { $0.notiz = text.isEmpty ? nil : text }
                        gespeichert += 1
                    } label: { Label("Speichern", systemImage: "checkmark") }
                        .buttonStyle(.lumenHauptknopf)
                }
            }
            .padding(Abstand.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .lumenHintergrund()
        .haptik(.erfolg, bei: gespeichert)
        .onAppear { notiz = store.tage[store.heute]?.notiz ?? "" }
    }

    private func titel(_ lage: ZyklusModiLogik.KinderwunschStand.Lage) -> String {
        switch lage {
        case .eisprung: "Eisprung"
        case .fruchtbar: "Fruchtbar"
        case .bald(let t): t == 1 ? "Morgen" : "In \(t) Tagen"
        case .vorbei: "Geschafft"
        case .unbekannt: "Hallo"
        }
    }

    private func untertitel(_ s: ZyklusModiLogik.KinderwunschStand) -> String {
        guard let f = s.fenster else { return "Trag deine erste Periode ein" }
        if s.lage == .vorbei { return "Das Fenster ist zu" }
        return "\(Datum.anzeige(f.lowerBound)) bis \(Datum.anzeige(f.upperBound))"
    }

    private func fortschritt(_ s: ZyklusModiLogik.KinderwunschStand) -> Double {
        guard let f = s.fenster else { return 0 }
        let heute = store.heute
        if heute < f.lowerBound { return 0 }
        if heute > f.upperBound { return 1 }
        let gesamt = Double(Datum.tageZwischen(f.lowerBound, f.upperBound) + 1)
        return Double(Datum.tageZwischen(f.lowerBound, heute) + 1) / gesamt
    }

    private func testKnopf(_ titel: String, _ ergebnis: ZyklusTest) -> some View {
        let gewaehlt = store.tage[store.heute]?.eisprungTest == ergebnis
        return Button { heutigerTag(store) { $0.eisprungTest = gewaehlt ? nil : ergebnis } } label: {
            ZyklusWahlChip(titel: titel, gewaehlt: gewaehlt)
        }
        .buttonStyle(.federnd)
        .haptik(.auswahl, bei: gewaehlt)
    }
}

// MARK: - Pille

/// Pille: Einnahme heute, Pausentage, Serie. Packungsart und Start stellt man hier ein. Eine Erinnerung baut Lumen Alarm, nicht diese Ansicht.
struct ZyklusPilleView: View {
    let store: ZyklusStore
    @Environment(\.palette) private var palette

    private var stand: ZyklusModiLogik.PillenStand? {
        let start = ZyklusModiLogik.pillenStart(gesetzt: store.werte.pilleStart, logik: store.logik(), tage: Array(store.tage.values))
        return start.flatMap { ZyklusModiLogik.pillenStand(start: $0, packung: store.werte.pillePackung, heute: store.heute) }
    }

    var body: some View {
        let genommen = ZyklusModiLogik.pilleGenommen(tage: store.tage, heute: store.heute)
        let s = stand
        ScrollView {
            VStack(spacing: Abstand.l) {
                ZyklusRingAnsicht(abschnitte: ZyklusRingLogik.pille(), fortschritt: Double(s?.tagInPackung ?? 0) / Double(ZyklusModiLogik.packungsTage),
                                  phase: nil, titel: s.map { "Tag \($0.tagInPackung)" } ?? "Hallo", untertitel: untertitel(s))
                ZyklusKarte(titel: "Heute", symbol: "pills.fill") {
                    if s?.nehmen == false {
                        ZyklusLeise("Pausentag. Heute keine Tablette.")
                    } else {
                        ZyklusLeise(genommen ? "Genommen. Fein gemacht." : "Noch nicht genommen.")
                        Button {
                            heutigerTag(store) { $0.pille = genommen ? nil : true }
                        } label: {
                            Label(genommen ? "Zurücknehmen" : "Genommen", systemImage: genommen ? "arrow.uturn.backward" : "checkmark")
                        }
                        .buttonStyle(.lumenHauptknopf)
                        .haptik(genommen ? .auswahl : .erfolg, bei: genommen)
                    }
                    let serie = ZyklusModiLogik.pillenSerie(tage: store.tage, heute: store.heute)
                    if serie > 1 { ZyklusLeise("\(serie) Tage in Folge.") }
                }
                packung
            }
            .padding(Abstand.l)
        }
        .lumenHintergrund()
    }

    private var packung: some View {
        ZyklusKarte(titel: "Packung", symbol: "calendar.badge.clock") {
            Picker("Packung", selection: Binding(get: { store.werte.pillePackung }, set: { p in store.aendere { $0.pillePackung = p } })) {
                ForEach(ZyklusModiLogik.Packung.allCases, id: \.self) { Text($0.titel).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(minHeight: Abstand.tippflaeche)
            DatePicker("Erster Tag der Packung", selection: Binding(
                get: { Datum.datum(store.werte.pilleStart ?? ZyklusModiLogik.pillenStart(gesetzt: nil, logik: store.logik(), tage: Array(store.tage.values)) ?? store.heute) },
                set: { d in store.aendere { $0.pilleStart = Datum.text(d) } }), displayedComponents: .date)
                .environment(\.calendar, Datum.kalender)
                .frame(minHeight: Abstand.tippflaeche)
        }
        .foregroundStyle(palette.text)
    }

    private func untertitel(_ s: ZyklusModiLogik.PillenStand?) -> String {
        guard let s else { return "Trag deinen ersten Pillentag ein" }
        if s.pause { return s.nehmen ? "Platzhalter" : "Pause" }
        return s.tageBisPause == 1 ? "Morgen beginnt die Pause" : "Noch \(s.tageBisPause) Tage bis zur Pause"
    }
}
