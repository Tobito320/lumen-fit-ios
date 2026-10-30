// Quelle: Lovea Health/UebungsSuche.swift (Alert "Eigene Übung"; hier ein Formular mit Muskel, Gerät und Notiz)
import SwiftUI

/// Eigene Übung anlegen oder ändern: Name, Körperteil, Muskel, Gerät, Notiz. `fertig` bekommt die gesicherte Übung.
struct GymEigenesFormular: View {
    let store: GymEigeneStore
    /// nil = neue Übung.
    let bearbeiten: String?
    let fertig: (Uebung) -> Void
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig
    @State private var name: String
    @State private var koerper: String
    @State private var muskel: String
    @State private var geraet: String
    @State private var notiz: String
    @State private var fehler: GymEigeneFehler?
    @State private var gesichert = 0

    init(store: GymEigeneStore, bearbeiten: GymEigeneUebungD? = nil, vorname: String = "", fertig: @escaping (Uebung) -> Void) {
        self.store = store
        self.bearbeiten = bearbeiten?.id
        self.fertig = fertig
        let teil = bearbeiten?.koerper ?? "Brust"
        _name = State(initialValue: bearbeiten?.name ?? vorname)
        _koerper = State(initialValue: teil)
        _muskel = State(initialValue: bearbeiten?.muskel ?? GymEigeneLogik.muskel(koerper: teil, aktuell: ""))
        _geraet = State(initialValue: bearbeiten?.geraet ?? (UebungsKatalog.geraete.contains("Kurzhantel") ? "Kurzhantel" : (UebungsKatalog.geraete.first ?? "")))
        _notiz = State(initialValue: bearbeiten?.notiz ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .frame(minHeight: Abstand.tippflaeche)
                        .accessibilityLabel("Name der Übung")
                        .onChange(of: name) { _, _ in fehler = nil }
                } header: {
                    Text("Name")
                } footer: {
                    if let fehler {
                        Label(fehler.text, systemImage: "exclamationmark.circle").foregroundStyle(palette.text)
                    }
                }
                Section("Wofür") {
                    Picker("Körperteil", selection: $koerper) {
                        ForEach(UebungsKatalog.koerperteile, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(minHeight: Abstand.tippflaeche)
                    if koerper != "Cardio" {
                        Picker("Muskel", selection: $muskel) {
                            ForEach(GymEigeneLogik.muskeln(koerper: koerper), id: \.self) { Text($0).tag($0) }
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                    }
                    Picker("Gerät", selection: $geraet) {
                        ForEach(UebungsKatalog.geraete, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(minHeight: Abstand.tippflaeche)
                }
                Section {
                    TextField("Notiz (zum Beispiel Einstellung)", text: $notiz, axis: .vertical)
                        .lineLimit(1...4)
                        .frame(minHeight: Abstand.tippflaeche)
                } header: {
                    Text("Notiz")
                } footer: {
                    Text("Gezählt wird: \(GymEigeneLogik.einheitText(koerper: koerper)). Die Übung bekommt kein Bild, nur ein Symbol.")
                }
            }
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationTitle(bearbeiten == nil ? "Eigene Übung" : "Übung ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(GymEigeneLogik.bereinigt(name).isEmpty)
                }
            }
            .onChange(of: koerper) { _, neu in muskel = GymEigeneLogik.muskel(koerper: neu, aktuell: muskel) }
            .haptik(.erfolg, bei: gesichert)
        }
        .presentationDetents([.large])
    }

    private func sichern() {
        switch store.sichern(id: bearbeiten, name: name, koerper: koerper, muskel: muskel, geraet: geraet, notiz: notiz) {
        case .success(let u):
            gesichert += 1
            fertig(u)
            schliessen()
        case .failure(let f):
            withAnimation(ruhig ? nil : Feder.schnell) { fehler = f }
        }
    }
}
