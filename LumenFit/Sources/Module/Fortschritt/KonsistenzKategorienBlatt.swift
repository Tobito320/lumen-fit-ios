// Quelle: Lovea Health/Verlauf/KonsistenzKategorienBlatt.swift (neu im Lumen-Design, gespeichert im Profilordner)
import SwiftUI

/// Blatt "Kategorien" der Konsistenz-Karte: anlegen, umbenennen, Farbe, löschen, und welcher Plantag zu welcher Kategorie gehört.
/// Arbeitet auf einer Kopie und speichert beim Schließen (`konsistenz.json` im Profilordner), nicht bei jedem Buchstaben.
struct KonsistenzKategorienBlatt: View {
    let ordner: URL?
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @State private var stand = KonsistenzEinstellung.standard
    @State private var geladen = false
    @State private var neu = 0

    private var plantage: [TrainingsTag] { umgebung.daten?.training.plan.tage ?? [] }

    var body: some View {
        NavigationStack {
            List {
                kategorienAbschnitt
                zuordnungAbschnitt
            }
            .navigationTitle("Kategorien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
        }
        .onAppear {
            guard !geladen else { return }
            geladen = true
            stand = KonsistenzKategorienDatei.lesen(ordner)
        }
        .onDisappear { speichern() }
        .haptik(.auswahl, bei: neu)
        .presentationDetents([.large])
    }

    private var kategorienAbschnitt: some View {
        Section {
            ForEach($stand.kategorien) { $k in
                HStack(spacing: Abstand.m) {
                    ColorPicker("Farbe von \(k.name)", selection: farbe($k), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                    TextField("Name", text: $k.name)
                        .frame(minHeight: Abstand.tippflaeche)
                }
            }
            .onDelete { stand.kategorien.remove(atOffsets: $0) }
            Button {
                neu += 1
                stand.kategorien.append(KonsistenzKategorienLogik.neu(in: stand))
            } label: {
                Label("Neue Kategorie", systemImage: "plus").frame(minHeight: Abstand.tippflaeche)
            }
        } header: {
            Text("Kategorien")
        } footer: {
            Text("Wischen zum Löschen. Training ohne Kategorie bekommt die Hauptfarbe. Trainierst du zwei Kategorien am selben Tag, teilt sich das Kästchen diagonal.")
        }
    }

    @ViewBuilder private var zuordnungAbschnitt: some View {
        if !plantage.isEmpty {
            Section {
                ForEach(plantage) { tag in
                    Picker(tag.name.isEmpty ? "Training" : tag.name, selection: zuordnung(tag)) {
                        Text("Keine").tag("")
                        ForEach(stand.kategorien) { Text($0.name).tag($0.id) }
                    }
                    .frame(minHeight: Abstand.tippflaeche)
                }
            } header: {
                Text("Trainingstage")
            }
        }
    }

    /// Aktuelle Wahl eines Plantags: eigene, sonst die Vorbelegung nach Name.
    private func zuordnung(_ tag: TrainingsTag) -> Binding<String> {
        Binding(
            get: { KonsistenzKategorienLogik.kategorie(tagId: tag.id, name: tag.name, einstellung: stand) ?? "" },
            set: { stand.zuordnung[tag.id] = $0 }
        )
    }

    private func farbe(_ k: Binding<KonsistenzKategorie>) -> Binding<Color> {
        Binding(
            get: { KonsistenzFarbe.kanaele(hex: k.wrappedValue.farbe).map { Color(red: $0.r, green: $0.g, blue: $0.b) } ?? .accentColor },
            set: { k.wrappedValue.farbe = Self.hex($0) }
        )
    }

    private static func hex(_ farbe: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(farbe).getRed(&r, green: &g, blue: &b, alpha: &a)
        return KonsistenzFarbe.hex(r: Double(r), g: Double(g), b: Double(b))
    }

    private func speichern() {
        guard geladen else { return }
        let e = KonsistenzKategorienDatei.bereinigt(stand)
        guard e != KonsistenzKategorienDatei.lesen(ordner) else { return }
        KonsistenzKategorienDatei.sichern(e, in: ordner)
    }
}
