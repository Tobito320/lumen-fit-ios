// Quelle: Lovea Health/Ernaehrung/ErnaehrungEigene.swift (EigenesLebensmittelEditor: Bearbeiten, Löschen, gesättigte Fette, Portionsname, Packung)
import SwiftUI

/// Felder des Formulars "Lebensmittel von Hand" als Text, so wie sie getippt werden.
struct EssenEigenesEingabe: Equatable, Sendable {
    var name = ""
    var marke = ""
    var kcal = ""
    var protein = ""
    var kohlenhydrate = ""
    var fett = ""
    var gesFett = ""
    var zucker = ""
    var ballaststoffe = ""
    var salz = ""
    var portion = ""
    var portionName = ""
    var packung = ""
    var fluessig = false
}

enum EssenEigenesLogik {
    /// Felder aus einem vorhandenen Lebensmittel (Bearbeiten). Dreistellig genau, damit 0,02 g Salz nicht zu 0 werden.
    static func eingabe(_ l: Lebensmittel) -> EssenEigenesEingabe {
        func f(_ x: Double?) -> String { x.map { MengenRad.feldText($0) } ?? "" }
        let n = l.pro100
        return EssenEigenesEingabe(name: l.name, marke: l.marke ?? "", kcal: f(n.kcal), protein: f(n.protein), kohlenhydrate: f(n.kohlenhydrate), fett: f(n.fett),
                                   gesFett: f(n.gesFett), zucker: f(n.zucker), ballaststoffe: f(n.ballaststoffe), salz: f(n.salz),
                                   portion: f(l.portionMenge), portionName: l.portionName ?? "", packung: f(l.packungMenge), fluessig: l.fluessig)
    }

    /// Felder aus den Werten eines Etikett-Fotos.
    static func eingabe(werte v: Naehrwerte) -> EssenEigenesEingabe {
        func f(_ x: Double?) -> String { x.map { MengenRad.feldText($0) } ?? "" }
        return EssenEigenesEingabe(kcal: f(v.kcal), protein: f(v.protein), kohlenhydrate: f(v.kohlenhydrate), fett: f(v.fett),
                                   gesFett: f(v.gesFett), zucker: f(v.zucker), ballaststoffe: f(v.ballaststoffe), salz: f(v.salz))
    }

    /// nil, solange Name oder Kalorien fehlen. Mit `start` bleibt die ID und alles, was das Formular nicht zeigt (Vitamine, Zutaten, Portionen,
    /// Nutri-Score), erhalten; sonst entsteht ein neues Lebensmittel mit `id`.
    static func lebensmittel(_ e: EssenEigenesEingabe, barcode: String?, start: Lebensmittel?, id: String) -> Lebensmittel? {
        let n = e.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let k = ErnaehrungLogik.eingabe(e.kcal) else { return nil }
        var werte = Naehrwerte(kcal: k, protein: ErnaehrungLogik.eingabe(e.protein) ?? 0, kohlenhydrate: ErnaehrungLogik.eingabe(e.kohlenhydrate) ?? 0,
                               fett: ErnaehrungLogik.eingabe(e.fett) ?? 0, zucker: ErnaehrungLogik.eingabe(e.zucker),
                               ballaststoffe: ErnaehrungLogik.eingabe(e.ballaststoffe), salz: ErnaehrungLogik.eingabe(e.salz),
                               gesFett: ErnaehrungLogik.eingabe(e.gesFett))
        werte.mikro = start?.pro100.mikro
        let portionsMenge = ErnaehrungLogik.eingabe(e.portion).flatMap { $0 > 0 ? $0 : nil }
        let packungsMenge = ErnaehrungLogik.eingabe(e.packung).flatMap { $0 > 0 ? $0 : nil }
        let portionsName = e.portionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = e.marke.trimmingCharacters(in: .whitespacesAndNewlines)
        var l = start ?? Lebensmittel(id: id, name: n, pro100: werte)
        l.name = n
        l.marke = m.isEmpty ? nil : m
        l.barcode = barcode ?? start?.barcode
        l.fluessig = e.fluessig
        l.pro100 = werte
        l.portionMenge = portionsMenge
        l.portionName = portionsMenge == nil ? nil : (portionsName.isEmpty ? "Portion" : portionsName)
        l.packungMenge = packungsMenge
        return l
    }
}

/// Ein Lebensmittel von Hand anlegen oder bearbeiten: für einen Barcode, den Open Food Facts nicht kennt, oder mit Werten vom Etikett-Foto.
/// Die Werte gelten je 100 g (oder 100 ml). Mit Barcode findet der nächste Scan das Lebensmittel auch ohne Netz. Mit `start` ändert es ein
/// eigenes Lebensmittel (gleiche ID, kein Duplikat) und kann es löschen.
struct EssenEigenesView: View {
    let barcode: String?
    let hinweis: String?
    let start: Lebensmittel?
    let fertig: @MainActor (Lebensmittel) -> Void
    /// Nur beim Bearbeiten: nach dem Löschen.
    let geloescht: @MainActor () -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var eingabe: EssenEigenesEingabe
    @State private var neueId = "eigen-\(UUID().uuidString)"
    @State private var fotoOffen = false
    @State private var loeschenFragen = false
    @State private var gesichert = 0

    init(barcode: String?, vorlage: Naehrwerte? = nil, hinweis: String? = nil, start: Lebensmittel? = nil,
         fertig: @escaping @MainActor (Lebensmittel) -> Void, geloescht: @escaping @MainActor () -> Void = {}) {
        self.barcode = barcode
        self.hinweis = hinweis
        self.start = start
        self.geloescht = geloescht
        self.fertig = fertig
        if let start {
            _eingabe = State(initialValue: EssenEigenesLogik.eingabe(start))
        } else if let vorlage {
            _eingabe = State(initialValue: EssenEigenesLogik.eingabe(werte: vorlage))
        } else {
            _eingabe = State(initialValue: EssenEigenesEingabe())
        }
    }

    private var code: String? { barcode ?? start?.barcode }
    private var ergebnis: Lebensmittel? { EssenEigenesLogik.lebensmittel(eingabe, barcode: barcode, start: start, id: neueId) }

    var body: some View {
        Form {
            if let hinweis {
                Section { Label(hinweis, systemImage: "info.circle").foregroundStyle(palette.text) }
            }
            Section("Produkt") {
                TextField("Name", text: $eingabe.name).accessibilityLabel("Name")
                TextField("Marke (freiwillig)", text: $eingabe.marke).accessibilityLabel("Marke")
                if let code { LabeledContent("Barcode", value: code) }
                Toggle("Getränk (Werte je 100 ml)", isOn: $eingabe.fluessig)
            }
            Section("Nährwerte pro 100 \(eingabe.fluessig ? "ml" : "g")") {
                EssenZahlFeld(titel: String(localized: "Energie"), einheit: "kcal", text: $eingabe.kcal)
                EssenZahlFeld(titel: String(localized: "Eiweiß"), einheit: "g", text: $eingabe.protein)
                EssenZahlFeld(titel: String(localized: "Kohlenhydrate"), einheit: "g", text: $eingabe.kohlenhydrate)
                EssenZahlFeld(titel: String(localized: "davon Zucker"), einheit: "g", text: $eingabe.zucker)
                EssenZahlFeld(titel: String(localized: "Fett"), einheit: "g", text: $eingabe.fett)
                EssenZahlFeld(titel: String(localized: "davon gesättigt"), einheit: "g", text: $eingabe.gesFett)
                EssenZahlFeld(titel: String(localized: "Ballaststoffe"), einheit: "g", text: $eingabe.ballaststoffe)
                EssenZahlFeld(titel: String(localized: "Salz"), einheit: "g", text: $eingabe.salz)
            }
            Section("Portion (freiwillig)") {
                EssenZahlFeld(titel: String(localized: "Eine Portion wiegt"), einheit: eingabe.fluessig ? "ml" : "g", text: $eingabe.portion)
                TextField("Name der Portion (z. B. Scheibe)", text: $eingabe.portionName).accessibilityLabel("Name der Portion")
            }
            Section("Packung (freiwillig)") {
                EssenZahlFeld(titel: String(localized: "Packungsgröße"), einheit: eingabe.fluessig ? "ml" : "g", text: $eingabe.packung)
            }
            Section {
                Button { fotoOffen = true } label: {
                    Label("Nährwerttabelle fotografieren", systemImage: "camera.fill").frame(minHeight: Abstand.tippflaeche)
                }
            } footer: {
                Text("Die Zahlen liest dein Gerät selbst, nichts wird verschickt. Du prüfst sie, bevor du speicherst.")
            }
            if start != nil {
                Section {
                    Button(role: .destructive) { loeschenFragen = true } label: {
                        Label("Löschen", systemImage: "trash").frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(start != nil ? "Lebensmittel bearbeiten" : (barcode == nil ? "Von Hand" : "Neues Lebensmittel"))
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .haptik(.erfolg, bei: gesichert)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { speichern() }.disabled(ergebnis == nil || gesichert > 0)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { EssenTastatur.schliessen() }
            }
        }
        .sheet(isPresented: $fotoOffen) {
            NaehrwertFotoView { werte in
                // Name, Marke und Portion bleiben stehen; nur die Nährwerte kommen vom Foto.
                let neu = EssenEigenesLogik.eingabe(werte: werte)
                eingabe.kcal = neu.kcal
                eingabe.protein = neu.protein
                eingabe.kohlenhydrate = neu.kohlenhydrate
                eingabe.fett = neu.fett
                eingabe.gesFett = neu.gesFett
                eingabe.zucker = neu.zucker
                eingabe.ballaststoffe = neu.ballaststoffe
                eingabe.salz = neu.salz
                fotoOffen = false
            }
        }
        .confirmationDialog("Lebensmittel löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let start { umgebung.daten?.essen.eigenesLoeschen(start) }
                geloescht()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Schon eingetragene Mahlzeiten bleiben im Tagebuch.")
        }
    }

    private func speichern() {
        guard let l = ergebnis, gesichert == 0, let essen = umgebung.daten?.essen else { return }
        essen.eigenesSichern(l)
        gesichert += 1
        // Kurz warten, damit die Haptik noch auf der sichtbaren Seite ausgelöst wird, bevor sie weitergeht.
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            fertig(l)
        }
    }
}

enum EssenTastatur {
    /// Schließt die Zifferntastatur (sie hat keine Eingabetaste).
    @MainActor static func schliessen() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
