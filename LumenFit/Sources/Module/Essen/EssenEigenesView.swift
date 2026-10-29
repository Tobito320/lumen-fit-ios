import SwiftUI

/// Ein Lebensmittel von Hand anlegen: für einen Barcode, den Open Food Facts nicht kennt, oder mit Werten vom Etikett-Foto.
/// Die Werte gelten je 100 g (oder 100 ml). Mit Barcode findet der nächste Scan das Lebensmittel auch ohne Netz.
struct EssenEigenesView: View {
    let barcode: String?
    let hinweis: String?
    let fertig: @MainActor (Lebensmittel) -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var name = ""
    @State private var marke = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var kohlenhydrate = ""
    @State private var fett = ""
    @State private var zucker = ""
    @State private var ballaststoffe = ""
    @State private var salz = ""
    @State private var portion = ""
    @State private var fluessig = false
    @State private var fotoOffen = false

    init(barcode: String?, vorlage: Naehrwerte? = nil, hinweis: String? = nil, fertig: @escaping @MainActor (Lebensmittel) -> Void) {
        self.barcode = barcode
        self.hinweis = hinweis
        self.fertig = fertig
        if let v = vorlage {
            _kcal = State(initialValue: MengenRad.feldText(v.kcal))
            _protein = State(initialValue: MengenRad.feldText(v.protein))
            _kohlenhydrate = State(initialValue: MengenRad.feldText(v.kohlenhydrate))
            _fett = State(initialValue: MengenRad.feldText(v.fett))
            _zucker = State(initialValue: v.zucker.map { MengenRad.feldText($0) } ?? "")
            _ballaststoffe = State(initialValue: v.ballaststoffe.map { MengenRad.feldText($0) } ?? "")
            _salz = State(initialValue: v.salz.map { MengenRad.feldText($0) } ?? "")
        }
    }

    /// nil, solange Name oder Kalorien fehlen.
    private var ergebnis: Lebensmittel? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let k = ErnaehrungLogik.eingabe(kcal) else { return nil }
        let werte = Naehrwerte(kcal: k, protein: ErnaehrungLogik.eingabe(protein) ?? 0, kohlenhydrate: ErnaehrungLogik.eingabe(kohlenhydrate) ?? 0,
                               fett: ErnaehrungLogik.eingabe(fett) ?? 0, zucker: ErnaehrungLogik.eingabe(zucker),
                               ballaststoffe: ErnaehrungLogik.eingabe(ballaststoffe), salz: ErnaehrungLogik.eingabe(salz))
        let portionsMenge = ErnaehrungLogik.eingabe(portion).flatMap { $0 > 0 ? $0 : nil }
        let m = marke.trimmingCharacters(in: .whitespacesAndNewlines)
        return Lebensmittel(id: "eigen-\(UUID().uuidString)", name: n, marke: m.isEmpty ? nil : m, barcode: barcode, fluessig: fluessig, pro100: werte,
                            portionMenge: portionsMenge, portionName: portionsMenge == nil ? nil : "Portion")
    }

    var body: some View {
        Form {
            if let hinweis {
                Section { Label(hinweis, systemImage: "info.circle").foregroundStyle(palette.text) }
            }
            Section("Produkt") {
                TextField("Name", text: $name).accessibilityLabel("Name")
                TextField("Marke (freiwillig)", text: $marke).accessibilityLabel("Marke")
                if let barcode { LabeledContent("Barcode", value: barcode) }
                Toggle("Getränk (Werte je 100 ml)", isOn: $fluessig)
            }
            Section("Nährwerte pro 100 \(fluessig ? "ml" : "g")") {
                EssenZahlFeld(titel: "Energie", einheit: "kcal", text: $kcal)
                EssenZahlFeld(titel: "Eiweiß", einheit: "g", text: $protein)
                EssenZahlFeld(titel: "Kohlenhydrate", einheit: "g", text: $kohlenhydrate)
                EssenZahlFeld(titel: "Fett", einheit: "g", text: $fett)
                EssenZahlFeld(titel: "Zucker", einheit: "g", text: $zucker)
                EssenZahlFeld(titel: "Ballaststoffe", einheit: "g", text: $ballaststoffe)
                EssenZahlFeld(titel: "Salz", einheit: "g", text: $salz)
            }
            Section("Portion (freiwillig)") {
                EssenZahlFeld(titel: "Eine Portion wiegt", einheit: fluessig ? "ml" : "g", text: $portion)
            }
            Section {
                Button { fotoOffen = true } label: {
                    Label("Nährwerttabelle fotografieren", systemImage: "camera.fill").frame(minHeight: Abstand.tippflaeche)
                }
            } footer: {
                Text("Die Zahlen liest dein Gerät selbst, nichts wird verschickt. Du prüfst sie, bevor du speicherst.")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(barcode == nil ? "Von Hand" : "Neues Lebensmittel")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { speichern() }.disabled(ergebnis == nil)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { EssenTastatur.schliessen() }
            }
        }
        .sheet(isPresented: $fotoOffen) {
            NaehrwertFotoView { werte in
                kcal = MengenRad.feldText(werte.kcal)
                protein = MengenRad.feldText(werte.protein)
                kohlenhydrate = MengenRad.feldText(werte.kohlenhydrate)
                fett = MengenRad.feldText(werte.fett)
                zucker = werte.zucker.map { MengenRad.feldText($0) } ?? ""
                ballaststoffe = werte.ballaststoffe.map { MengenRad.feldText($0) } ?? ""
                salz = werte.salz.map { MengenRad.feldText($0) } ?? ""
                fotoOffen = false
            }
        }
    }

    private func speichern() {
        guard let l = ergebnis, let essen = umgebung.daten?.essen else { return }
        essen.eigenesSichern(l)
        fertig(l)
    }
}

enum EssenTastatur {
    /// Schließt die Zifferntastatur (sie hat keine Eingabetaste).
    @MainActor static func schliessen() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
