import SwiftUI

/// Ein gespeichertes Gericht (eigene Mahlzeit als Favorit, Idee 45): zeigt die Zutaten und trägt sie alle in eine Mahlzeit ein.
/// Die Vorlage bleibt unverändert, jede Zutat lässt sich danach einzeln im Tagebuch ändern.
struct EssenGerichtView: View {
    let vorlage: Rezept
    let tag: String
    let fertig: @MainActor (Bool) -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var mahlzeit: Mahlzeit
    @State private var loeschenFragen = false
    @State private var gesichert = 0

    init(vorlage: Rezept, mahlzeit: Mahlzeit, tag: String, fertig: @escaping @MainActor (Bool) -> Void) {
        self.vorlage = vorlage
        self.tag = tag
        self.fertig = fertig
        _mahlzeit = State(initialValue: mahlzeit)
    }

    private var essen: EssenStore? { umgebung.daten?.essen }
    private var summe: Naehrwerte { ErnaehrungLogik.summe(vorlage) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text(vorlage.name).font(.title2.weight(.bold)).foregroundStyle(palette.text)
                    Text("Dein Gericht, \(vorlage.zutaten.count) \(vorlage.zutaten.count == 1 ? "Zutat" : "Zutaten")").font(.footnote).foregroundStyle(palette.text2)
                }
                HeroKarte {
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                            RollZahl(wert: summe.kcal, format: .number.precision(.fractionLength(0))).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                            Text("kcal").font(.subheadline)
                        }
                        Text("\(Int(summe.protein.rounded())) g Protein, \(Int(summe.kohlenhydrate.rounded())) g Kohlenhydrate, \(Int(summe.fett.rounded())) g Fett")
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                }
                ListenKarte {
                    ForEach(Array(vorlage.zutaten.enumerated()), id: \.element.id) { i, z in
                        if i > 0 { Haarlinie() }
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: Abstand.xs) {
                                Text(z.lebensmittel.anzeigeName).font(.body).foregroundStyle(palette.text)
                                Text(ErnaehrungLogik.mengeText(z.menge, z.einheit, z.lebensmittel)).font(.subheadline).foregroundStyle(palette.text2)
                            }
                            Spacer(minLength: Abstand.s)
                            Text("\(Int(ErnaehrungLogik.naehrwerte(z.lebensmittel, menge: z.menge, einheit: z.einheit).kcal.rounded())) kcal")
                                .font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                        }
                        .padding(Abstand.l)
                        .accessibilityElement(children: .combine)
                    }
                }
                Picker("Mahlzeit", selection: $mahlzeit) {
                    ForEach(Mahlzeit.allCases) { m in Text(essen?.mahlzeitName(m) ?? m.name).tag(m) }
                }
                .pickerStyle(.menu)
                .frame(minHeight: Abstand.tippflaeche)
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Gericht")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { loeschenFragen = true } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Gericht löschen")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                guard gesichert == 0 else { return }
                essen?.mahlzeitEintragen(vorlage, mahlzeit: mahlzeit, datum: tag)
                gesichert += 1
                // Kurz warten, damit die Haptik noch auf der sichtbaren Seite ausgelöst wird, bevor das Blatt schließt.
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    fertig(true)
                }
            } label: {
                Text("Gericht eintragen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.lumenHauptknopf)
            .controlSize(.large)
            .disabled(gesichert > 0)
            .haptik(.erfolg, bei: gesichert)
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
            .lumenLeiste()
        }
        .confirmationDialog("Gericht löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                essen?.rezeptLoeschen(vorlage)
                fertig(false)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Schon eingetragene Mahlzeiten bleiben im Tagebuch.")
        }
    }
}
