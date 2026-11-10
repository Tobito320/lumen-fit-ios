// Quelle: Lovea Health/GymNeu/SplitBibliothekView (neu im Lumen-Design)
import SwiftUI

/// Die Split-Bibliothek (Entwurf `splits`, Idee 27) als Seite: Satz, Tage-Chips (2–3, 4, 5+), dazu Suche und die Ziel-Filter (Für dich, 45 Minuten, Aufbauen …),
/// je Split eine Karte mit Stufe, Tagen, Dauer, Woche und "Ansehen". "Geführt erstellen" bleibt oben. Die Splits stehen in `splits.json` (Grundgerüst).
struct SplitBibliothekView: View {
    let sitzung: GymSitzung
    /// Nach "Diesen Plan nehmen" oder "Nur diese Woche testen"; nil = diese Seite schließt sich selbst.
    var fertig: (() -> Void)? = nil
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var suche = ""
    @State private var art: String?
    @State private var tage: GymTabLogik.TageChip?
    /// Minuten je Split, einmal gerechnet (nicht im `body`).
    @State private var minuten: [String: Int] = [:]

    var body: some View {
        let geschlecht = umgebung.daten?.ziele.koerper.geschlecht
        let treffer = SplitLogik.treffer(SplitLogik.fuer(geschlecht), art: art, tage: nil, suche: suche).filter { v in tage.map { $0.passt(v.tage) } ?? true }
        let aktiv = sitzung.training?.plan.splitName
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Abstand.m) {
                Text("Fertige Pläne. Schau sie dir an, bevor du wechselst.").font(.subheadline).foregroundStyle(palette.text2)
                filter
                ListenKarte {
                    NavigationLink { SplitGefuehrtView(sitzung: sitzung, fertig: beendet) } label: {
                        GymSymbolZeile(symbol: "wand.and.stars", farbe: Bereichsfarbe.splits, titel: String(localized: "Geführt erstellen"),
                                       untertitel: String(localized: "Drei Fragen, dann ein Vorschlag"))
                    }
                    .buttonStyle(.plain)
                }
                Text(treffer.isEmpty ? String(localized: "Nichts gefunden") : String(localized: "\(treffer.count) Splits"))
                    .font(.footnote.weight(.semibold)).textCase(.uppercase).foregroundStyle(palette.text2)
                if treffer.isEmpty {
                    Text("Stell den Filter auf Alle oder such ein anderes Wort, zum Beispiel einen Muskel.").font(.subheadline).foregroundStyle(palette.text2)
                }
                ForEach(treffer) { v in karte(v, aktiv: v.name == aktiv) }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle("Split-Bibliothek")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $suche, prompt: "Name, Muskel oder Übung")
        .task {
            guard minuten.isEmpty else { return }
            minuten = Dictionary(SplitKatalog.alle.map { ($0.id, GymTabLogik.splitMinuten($0)) }, uniquingKeysWith: { a, _ in a })
        }
    }

    private func beendet() { if let fertig { fertig() } else { schliessen() } }

    private var filter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Abstand.s) {
                GymChip(text: String(localized: "Alle"), aktiv: tage == nil && art == nil) { tage = nil; art = nil }
                ForEach(GymTabLogik.TageChip.allCases, id: \.self) { t in GymChip(text: t.titel, aktiv: tage == t) { tage = tage == t ? nil : t } }
                Divider().frame(height: 24)
                ForEach(Array(SplitLogik.artWahl.enumerated()), id: \.offset) { _, a in
                    GymChip(text: a.text, aktiv: art == a.id) { art = art == a.id ? nil : a.id }
                }
            }
        }
    }

    /// Karte je Split: Name mit "Aktiv"/"Für dich", "Einsteiger · 3 Tage · ca. 65 min · Muskeln aufbauen", Woche, Tagesnamen, "Ansehen".
    private func karte(_ v: SplitVorlage, aktiv: Bool) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            HStack {
                Text(v.name).font(.headline).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.s)
                if aktiv {
                    Pille(text: String(localized: "Aktiv"), symbolName: "checkmark")
                } else if SplitLogik.istEigen(v) {
                    Pille(text: String(localized: "Für dich"))
                }
            }
            Text(SplitLogik.kopfzeile(v, minuten: minuten[v.id])).font(.footnote).foregroundStyle(palette.text2)
            GymSplitWoche(vorlage: v)
            Text(v.einheiten.map(\.name).joined(separator: " · ")).font(.footnote).foregroundStyle(palette.text2).lineLimit(2)
            NavigationLink { SplitDetailView(sitzung: sitzung, vorlage: v, fertig: beendet) } label: {
                Text("Ansehen").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    .background(palette.grund, in: .capsule)
                    .overlay(Capsule().stroke(palette.haar, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
        .overlay(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(aktiv ? palette.akzent : Color.clear, lineWidth: 1.5))
        .accessibilityElement(children: .contain)
    }
}

extension SplitLogik {
    /// "Einsteiger · 3 Tage · ca. 65 min · Muskeln aufbauen" (ohne Minuten, solange sie nicht gerechnet sind).
    static func kopfzeile(_ v: SplitVorlage, minuten: Int?) -> String {
        let ziel = ziele.first { $0.id == v.ziel }?.text ?? v.ziel
        let tage = String(localized: "\(v.tage) Tage")
        let dauer = minuten.map { String(localized: "ca. \($0) min") }
        return [levelText(v), tage, dauer, ziel].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Die Woche eines Splits: Kreis je Tag, an Trainingstagen der Anfangsbuchstabe der Einheit auf Lime.
struct GymSplitWoche: View {
    let vorlage: SplitVorlage
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.xs) {
            ForEach(1...7, id: \.self) { w in
                let einheit = vorlage.einheiten.first { $0.wochentage.contains(w) }
                VStack(spacing: 2) {
                    Text(einheit.map { String($0.name.prefix(1)).uppercased() } ?? "")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.aufAkzentFlaeche)
                        .frame(width: 26, height: 26)
                        .background(einheit != nil ? palette.akzentFlaeche : palette.flaeche, in: .circle)
                        .overlay(Circle().stroke(palette.haar, lineWidth: einheit == nil ? 1 : 0))
                    Text(HabitLogik.wochentagKuerzel[w - 1]).font(.caption2).foregroundStyle(palette.text2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(TrainingLogik.wochentagName[w - 1]): \(einheit?.name ?? String(localized: "frei"))")
            }
        }
    }
}

/// Ein Split im Detail (Entwurf `splitv`): Kopfzeile, Woche, je Einheit die Übungen mit Bild und Sets (Tipp öffnet die Übung),
/// unten "Diesen Plan nehmen" (mit Rückfrage, wenn schon ein Plan da ist) oder "Das ist dein aktueller Plan", dazu "Nur diese Woche testen".
struct SplitDetailView: View {
    let sitzung: GymSitzung
    let vorlage: SplitVorlage
    let fertig: () -> Void
    @Environment(\.palette) private var palette
    @State private var ersetzen = false
    @State private var meldung: String?
    @State private var erfolg = 0
    /// Minuten je Einheit, einmal gerechnet.
    @State private var minuten: [Int] = []

    var body: some View {
        let aktiv = sitzung.training?.plan.splitName == vorlage.name
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Abstand.m) {
                Text(SplitLogik.kopfzeile(vorlage, minuten: minuten.max().map(GymTabLogik.rund))).font(.footnote).foregroundStyle(palette.text2)
                GymSplitWoche(vorlage: vorlage)
                    .padding(Abstand.m)
                    .lumenKartenFlaeche()
                ForEach(vorlage.einheiten.indices, id: \.self) { i in einheit(i) }
                knoepfe(aktiv: aktiv)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle(vorlage.name)
        .navigationBarTitleDisplayMode(.inline)
        .haptik(.erfolg, bei: erfolg)
        .task {
            guard minuten.isEmpty else { return }
            minuten = SplitLogik.alsPlan(vorlage, neueId: { "x" }).tage.map { ZeitSchaetzung.minuten($0) }
        }
        .confirmationDialog("Deinen Plan ersetzen?", isPresented: $ersetzen, titleVisibility: .visible) {
            Button("Ersetzen", role: .destructive) { uebernehmen() }
        } message: {
            Text("Dein jetziger Plan wird durch diesen Split ersetzt. Alte Trainings bleiben.")
        }
        .alert("Das geht gerade nicht", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("Verstanden") { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
    }

    private func einheit(_ i: Int) -> some View {
        let e = vorlage.einheiten[i]
        let dauer = minuten.indices.contains(i) ? String(localized: " · ca. \(GymTabLogik.rund(minuten[i])) min") : ""
        return VStack(alignment: .leading, spacing: Abstand.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(e.name).font(.title3.weight(.bold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                Spacer(minLength: Abstand.s)
                Text("\(TrainingLogik.wochentageText(e.wochentage))\(dauer)").font(.footnote).foregroundStyle(palette.text2)
            }
            ListenKarte {
                ForEach(e.uebungen.indices, id: \.self) { k in
                    if k > 0 { Haarlinie() }
                    zeile(e.uebungen[k])
                }
            }
        }
        .padding(.top, Abstand.s)
    }

    @ViewBuilder
    private func zeile(_ z: SplitVorlage.Zeile) -> some View {
        let u = UebungsKatalog.nachId[z.uebung]
        let text = [u?.muskel, SplitLogik.wdhText(z), z.supersatz == true ? String(localized: "Supersatz") : nil].compactMap { $0 }.joined(separator: " · ")
        if let u {
            NavigationLink { UebungDetailView(id: u.id, anleitungZuerst: true) } label: {
                GymUebungZeile(id: u.id, koerper: u.koerper, titel: u.name, untertitel: text)
            }
            .buttonStyle(.plain)
        } else {
            GymUebungZeile(id: z.uebung, koerper: nil, titel: String(localized: "Übung"), untertitel: text, pfeil: false)
        }
    }

    @ViewBuilder
    private func knoepfe(aktiv: Bool) -> some View {
        VStack(spacing: Abstand.s) {
            if aktiv {
                Text("Das ist dein aktueller Plan.").font(.footnote).foregroundStyle(palette.text2).frame(maxWidth: .infinity)
            } else {
                Button {
                    if (sitzung.training?.plan.tage.isEmpty ?? true) { uebernehmen() } else { ersetzen = true }
                } label: {
                    Text("Diesen Plan nehmen").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.lumenHauptknopf)
            }
            Button {
                if sitzung.training?.testwocheStarten(vorlage) == true { erfolg += 1; fertig() } else { meldung = String(localized: "In dieser Woche ist kein Tag mehr übrig. Probier es am Montag.") }
            } label: {
                Text("Nur diese Woche testen").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
            Text("Testen ändert nur die laufende Woche, ab Montag gilt wieder dein Plan.").font(.footnote).foregroundStyle(palette.text2)
        }
        .padding(.top, Abstand.m)
    }

    private func uebernehmen() {
        sitzung.training?.planSichern(SplitLogik.alsPlan(vorlage))
        erfolg += 1
        fertig()
    }
}

/// Ein eigener Split ohne Vorlage (Idee 27): Name, 1 bis 6 Tage, jeder Tag mit eigenem Namen. Die Übungen kommen danach im Plan.
struct SplitFreiBlatt: View {
    let sitzung: GymSitzung
    @Environment(\.dismiss) private var schliessen
    @State private var name = ""
    @State private var anzahl = 3
    @State private var namen = Array(repeating: "", count: SplitFrei.tageBereich.upperBound)
    @State private var ersetzen = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Mein Split", text: $name) }
                Section {
                    Stepper(anzahl == 1 ? String(localized: "1 Tag pro Woche") : String(localized: "\(anzahl) Tage pro Woche"), value: $anzahl, in: SplitFrei.tageBereich)
                    ForEach(0..<anzahl, id: \.self) { i in
                        TextField(SplitFrei.standardName(i + 1), text: $namen[i])
                    }
                } header: {
                    Text("Tage")
                } footer: {
                    Text("Die Wochentage verteilt Lumi gleichmäßig. Du änderst sie danach im Plan.")
                }
            }
            .navigationTitle("Eigener Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") {
                        if sitzung.training?.plan.tage.isEmpty ?? true { anlegen() } else { ersetzen = true }
                    }
                }
            }
            .confirmationDialog("Deinen Plan ersetzen?", isPresented: $ersetzen, titleVisibility: .visible) {
                Button("Ersetzen", role: .destructive) { anlegen() }
            } message: {
                Text("Dein jetziger Plan wird durch den neuen Split ersetzt. Alte Trainings bleiben.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func anlegen() {
        sitzung.training?.planSichern(SplitFrei.anlegen(name: name, tage: Array(namen.prefix(anzahl))))
        schliessen()
    }
}
