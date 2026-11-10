// Quelle: Lovea Health/Ernaehrung/ErnaehrungEigene.swift (RezeptEditor, ZutatMengeBlatt, ZutatSucheBlatt)
import SwiftUI

/// Reine Regeln des Rezept- und Mahlzeit-Editors.
enum EssenRezeptLogik {
    /// Name und mindestens eine Zutat.
    static func kannSichern(name: String, zutaten: [Zutat]) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !zutaten.isEmpty
    }

    static func startPortionen(start: Rezept?, art: RezeptArt) -> Int { start?.portionen ?? (art == .mahlzeit ? 1 : 4) }

    /// Rezept: Werte pro Portion. Mahlzeit: Summe aller Zutaten.
    static func naehrwerte(art: RezeptArt, portionen: Int, zutaten: [Zutat]) -> Naehrwerte {
        if art == .mahlzeit { return ErnaehrungLogik.summe(Rezept(id: "neu", name: "", portionen: 1, zutaten: zutaten, art: art)) }
        let rezept = Rezept(id: "neu", name: "", portionen: max(portionen, 1), zutaten: zutaten, art: art)
        return ErnaehrungLogik.naehrwerte(ErnaehrungLogik.alsLebensmittel(rezept), menge: 1, einheit: .portion)
    }

    /// Das Rezept zum Speichern; mit `start` bleibt die ID. Eine Mahlzeit hat immer eine Portion und keine Anleitung.
    static func rezept(start: Rezept?, art: RezeptArt, name: String, portionen: Int, zutaten: [Zutat], anleitung: String, id: String = UUID().uuidString) -> Rezept {
        let text = anleitung.trimmingCharacters(in: .whitespacesAndNewlines)
        return Rezept(id: start?.id ?? id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), portionen: art == .mahlzeit ? 1 : max(portionen, 1),
                      zutaten: zutaten, geloescht: nil, art: art, anleitung: art == .mahlzeit || text.isEmpty ? nil : text)
    }

    static func titel(start: Rezept?, art: RezeptArt) -> String {
        switch (start != nil, art) {
        case (true, .mahlzeit): String(localized: "Mahlzeit bearbeiten")
        case (true, .rezept): String(localized: "Rezept bearbeiten")
        case (false, .mahlzeit): String(localized: "Neue Mahlzeit")
        case (false, .rezept): String(localized: "Neues Rezept")
        }
    }

    /// Zutaten, bei denen eine neue Menge eine bestehende ersetzt.
    static func ersetzen(_ zutaten: [Zutat], id: String, menge: Double, einheit: Einheit) -> [Zutat] {
        zutaten.map { z in
            guard z.id == id else { return z }
            var neu = z
            neu.menge = menge
            neu.einheit = einheit
            return neu
        }
    }
}

/// Eigenes Rezept oder eigene Mahlzeit: Name, Portionen, Zutaten suchen oder scannen, Mengen, Nährwerte live.
struct EssenRezeptEditor: View {
    let start: Rezept?
    let art: RezeptArt
    let fertig: @MainActor () -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var name: String
    @State private var portionen: Int
    @State private var zutaten: [Zutat]
    @State private var anleitung: String
    @State private var zutatSucheOffen = false
    @State private var mengeFuer: Lebensmittel?
    /// In der Suche gewählt; das Mengen-Blatt geht erst auf, wenn die Suche ganz zu ist.
    @State private var gewaehlt: Lebensmittel?
    @State private var bearbeiteZutat: Zutat?
    @State private var loeschenFragen = false
    @State private var scannerOffen = false
    @State private var gescannt: String?
    @State private var scanLaedt = false
    @State private var scanHinweis: String?
    @State private var vorschlaege: (name: String, liste: [Lebensmittel])?
    @State private var gesichert = 0

    init(start: Rezept? = nil, art: RezeptArt = .rezept, fertig: @escaping @MainActor () -> Void = {}) {
        self.start = start
        self.art = start?.art ?? art
        self.fertig = fertig
        _name = State(initialValue: start?.name ?? "")
        _portionen = State(initialValue: EssenRezeptLogik.startPortionen(start: start, art: start?.art ?? art))
        _zutaten = State(initialValue: start?.zutaten ?? [])
        _anleitung = State(initialValue: start?.anleitung ?? "")
    }

    private var essen: EssenStore? { umgebung.daten?.essen }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).accessibilityLabel("Name")
                    if art == .rezept {
                        Stepper("Portionen: \(portionen)", value: $portionen, in: 1...20)
                    }
                }
                if art == .rezept {
                    Section {
                        TextField("Anleitung (freiwillig)", text: $anleitung, axis: .vertical).lineLimit(3...8).accessibilityLabel("Anleitung")
                    }
                }
                Section("Zutaten") {
                    ForEach(zutaten) { z in zutatZeile(z) }
                        .onDelete { zutaten.remove(atOffsets: $0) }
                    Button { zutatSucheOffen = true } label: { Label("Zutat suchen", systemImage: "magnifyingglass").frame(minHeight: Abstand.tippflaeche) }
                    Button { scannerOffen = true } label: { Label("Barcode scannen", systemImage: "barcode.viewfinder").frame(minHeight: Abstand.tippflaeche) }
                    if scanLaedt { ProgressView("Ich suche das Produkt …") }
                    if let scanHinweis { Text(scanHinweis).font(.footnote).foregroundStyle(palette.text2) }
                }
                if !zutaten.isEmpty {
                    Section(art == .mahlzeit ? "Summe der Mahlzeit" : "Pro Portion") { naehrwerteListe }
                }
                if start != nil {
                    Section {
                        Button(role: .destructive) { loeschenFragen = true } label: { Label("Löschen", systemImage: "trash").frame(minHeight: Abstand.tippflaeche) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(EssenRezeptLogik.titel(start: start, art: art))
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .haptik(.erfolg, bei: gesichert)
            .haptik(.auswahl, bei: zutaten.count)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }.disabled(!EssenRezeptLogik.kannSichern(name: name, zutaten: zutaten) || gesichert > 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { EssenTastatur.schliessen() }
                }
            }
            .sheet(isPresented: $zutatSucheOffen, onDismiss: {
                mengeFuer = gewaehlt
                gewaehlt = nil
            }) {
                EssenZutatSucheBlatt { l in gewaehlt = l }
            }
            .sheet(isPresented: $scannerOffen, onDismiss: scannerZu) {
                EssenCodeBlatt { code in gescannt = code }
            }
            .sheet(isPresented: Binding(get: { vorschlaege != nil }, set: { if !$0 { vorschlaege = nil } }), onDismiss: {
                mengeFuer = gewaehlt
                gewaehlt = nil
            }) {
                if let v = vorschlaege {
                    EssenMehrtrefferBlatt(name: v.name, treffer: v.liste, auswahl: { l in gewaehlt = l },
                                          keinesDavon: { scanHinweis = String(localized: "Nicht gefunden. Such die Zutat per Name.") })
                }
            }
            .sheet(item: $mengeFuer) { l in
                let startMenge = ErnaehrungLogik.startMenge(l)
                EssenZutatMengeBlatt(lebensmittel: l, menge: startMenge.menge, einheit: startMenge.einheit) { menge, einheit in
                    zutaten.append(Zutat(id: UUID().uuidString, lebensmittel: l, menge: menge, einheit: einheit))
                }
            }
            .sheet(item: $bearbeiteZutat) { z in
                EssenZutatMengeBlatt(lebensmittel: z.lebensmittel, menge: z.menge, einheit: z.einheit) { menge, einheit in
                    zutaten = EssenRezeptLogik.ersetzen(zutaten, id: z.id, menge: menge, einheit: einheit)
                }
            }
            .confirmationDialog(art == .mahlzeit ? "Mahlzeit löschen?" : "Rezept löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let r = start { essen?.rezeptLoeschen(r) }
                    dismiss()
                    fertig()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Schon eingetragene Mahlzeiten bleiben im Tagebuch.")
            }
        }
    }

    /// Gescannter Code: Speicher, dann Open Food Facts; ein Treffer geht direkt zur Menge.
    private func scannerZu() {
        guard let code = gescannt else { return }
        gescannt = nil
        scanHinweis = nil
        Task {
            scanLaedt = true
            let ergebnis = await EssenModul.suche(umgebung).barcode(code)
            scanLaedt = false
            switch ergebnis {
            case .gefunden(let l): mengeFuer = l
            case .vorschlaege(let n, let liste, _): vorschlaege = (n, liste)
            case .unbekannt: scanHinweis = String(localized: "Produkt nicht gefunden. Such die Zutat per Name.")
            case .offline: scanHinweis = String(localized: "Kein Netz. Versuche es später noch einmal.")
            case .limit(_, let s): scanHinweis = String(localized: "Open Food Facts erlaubt 15 Abfragen in der Minute. In etwa \(s) Sekunden geht es wieder.")
            case .fehler: scanHinweis = String(localized: "Open Food Facts antwortet gerade nicht. Versuche es gleich noch einmal.")
            }
        }
    }

    private func zutatZeile(_ z: Zutat) -> some View {
        Button { bearbeiteZutat = z } label: {
            HStack {
                Text(z.lebensmittel.anzeigeName).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.s)
                Text(ErnaehrungLogik.mengeText(z.menge, z.einheit, z.lebensmittel)).foregroundStyle(palette.text2)
            }
            .frame(minHeight: Abstand.tippflaeche)
            .contentShape(.rect)
        }
        .accessibilityHint("Menge ändern")
    }

    private var naehrwerteListe: some View {
        let n = EssenRezeptLogik.naehrwerte(art: art, portionen: portionen, zutaten: zutaten)
        return Group {
            LabeledContent("Kalorien") { RollZahl(wert: n.kcal, format: .number.precision(.fractionLength(0))).monospacedDigit(); Text(" kcal") }
            LabeledContent("Eiweiß", value: "\(ErnaehrungLogik.zahl(n.protein)) g")
            LabeledContent("Kohlenhydrate", value: "\(ErnaehrungLogik.zahl(n.kohlenhydrate)) g")
            LabeledContent("Fett", value: "\(ErnaehrungLogik.zahl(n.fett)) g")
        }
    }

    private func sichern() {
        guard EssenRezeptLogik.kannSichern(name: name, zutaten: zutaten), gesichert == 0 else { return }
        let r = EssenRezeptLogik.rezept(start: start, art: art, name: name, portionen: portionen, zutaten: zutaten, anleitung: anleitung)
        essen?.rezeptSichern(r)
        gesichert += 1
        // Kurz warten, damit die Haptik noch auf der sichtbaren Seite ausgelöst wird, bevor sie schließt.
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            dismiss()
            fertig()
        }
    }
}

/// Menge und Einheit für eine Zutat, neu oder zum Ändern.
private struct EssenZutatMengeBlatt: View {
    let lebensmittel: Lebensmittel
    let uebernehmen: @MainActor (Double, Einheit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var einheit: Einheit

    init(lebensmittel: Lebensmittel, menge: Double, einheit: Einheit, uebernehmen: @escaping @MainActor (Double, Einheit) -> Void) {
        self.lebensmittel = lebensmittel
        self.uebernehmen = uebernehmen
        _text = State(initialValue: MengenRad.feldText(menge))
        _einheit = State(initialValue: einheit)
    }

    private var zahl: Double? { ErnaehrungLogik.eingabe(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section(lebensmittel.anzeigeName) {
                    HStack {
                        TextField("Menge", text: $text).keyboardType(.decimalPad).accessibilityLabel("Menge")
                        Picker("Einheit", selection: $einheit) {
                            ForEach(ErnaehrungLogik.einheiten(lebensmittel), id: \.self) { e in
                                Text(ErnaehrungLogik.einheitName(e, lebensmittel)).tag(e)
                            }
                        }
                    }
                    .frame(minHeight: Abstand.tippflaeche)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Menge")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        if let zahl, zahl > 0 { uebernehmen(zahl, einheit) }
                        dismiss()
                    }
                    .disabled((zahl ?? 0) <= 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { EssenTastatur.schliessen() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Zutat wählen: Zuletzt und Eigene, beim Tippen BLS, Eigenes und der Lumen-Server.
private struct EssenZutatSucheBlatt: View {
    let gewaehlt: @MainActor (Lebensmittel) -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var text = ""

    private var suche: LebensmittelSuche { EssenModul.suche(umgebung) }
    private var essen: EssenStore? { umgebung.daten?.essen }
    private var vorne: [Lebensmittel] { (essen?.favoriten ?? []) + (essen?.zuletzt ?? []) + (essen?.eigene ?? []) }
    private var leer: Bool { text.trimmingCharacters(in: .whitespaces).count < 2 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    if leer {
                        liste(String(localized: "Zuletzt"), essen?.zuletzt ?? [])
                        liste(String(localized: "Eigene"), essen?.eigene ?? [])
                    } else {
                        liste(nil, suche.stand.sichtbar)
                        EssenOnlineHinweis(zustand: suche.online)
                    }
                }
                .padding(Abstand.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .searchable(text: $text, prompt: "Zutat suchen")
            .navigationTitle("Zutat")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .task(id: text) {
                LebensmittelIndex.shared.laden()
                try? await Task.sleep(for: .milliseconds(text.isEmpty ? 0 : 200))
                for _ in 0..<20 where !Task.isCancelled && !LebensmittelIndex.shared.bereit { try? await Task.sleep(for: .milliseconds(150)) }
                guard !Task.isCancelled else { return }
                suche.eingabe(text, vorne: vorne)
                await suche.serverSuchen()
            }
        }
    }

    @ViewBuilder
    private func liste(_ titel: String?, _ eintraege: [Lebensmittel]) -> some View {
        if let titel, !eintraege.isEmpty { Text(titel).font(.headline).foregroundStyle(palette.text) }
        if eintraege.isEmpty, titel == nil {
            Text("Nichts gefunden.").font(.subheadline).foregroundStyle(palette.text2)
        } else if !eintraege.isEmpty {
            ListenKarte {
                ForEach(Array(eintraege.enumerated()), id: \.element.id) { i, l in
                    if i > 0 { Haarlinie() }
                    Button { dismiss(); gewaehlt(l) } label: { EssenLebensmittelZeile(lebensmittel: l).padding(.horizontal, Abstand.l) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Barcode für eine Zutat: Kamera, wo es sie gibt, sonst der getippte Code. Meldet den Code und schließt sich.
private struct EssenCodeBlatt: View {
    let gefunden: @MainActor (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var code = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Abstand.l) {
                if EssenBarcodeKamera.verfuegbar {
                    EssenBarcodeKamera { wert in melden(wert) }
                        .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .accessibilityLabel("Kamera für den Barcode")
                } else {
                    LeerZustand(stimmung: .bereit, satz: String(localized: "Die Kamera ist nicht verfügbar. Tippe den Code von der Packung ein."))
                }
                Spacer(minLength: 0)
                TextField("Code eintippen", text: $code)
                    .keyboardType(.numberPad)
                    .padding(Abstand.m)
                    .frame(minHeight: Abstand.tippflaeche)
                    .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                    .accessibilityLabel("Barcode eintippen")
                Button { melden(code) } label: { Text("Suchen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                    .buttonStyle(.lumenHauptknopf)
                    .disabled(!BarcodeLogik.istBarcodeEingabe(BarcodeLogik.normal(code)))
            }
            .padding(Abstand.l)
            .navigationTitle("Barcode scannen")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { EssenTastatur.schliessen() }
                }
            }
        }
    }

    private func melden(_ wert: String) {
        gefunden(wert)
        dismiss()
    }
}
