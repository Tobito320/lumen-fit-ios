// Quelle: Lovea Health/Ernaehrung/ErnaehrungMahlzeit.swift (MahlzeitView, MahlzeitKopf, EssenZeile, EintragSeite)
import SwiftUI

/// Eine Mahlzeit eines Tages: Summenkopf, die Einträge (Tipp öffnet sie zum Ändern, Wischen löscht), Hinzufügen unten,
/// im Menü "Von gestern übernehmen" und "Als Gericht speichern".
struct EssenMahlzeitSeite: View {
    let mahlzeit: Mahlzeit
    let tag: String

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var offen: EssenEintragZiel?
    @State private var neuOffen = false
    @State private var geloescht = 0
    @State private var uebernommen = 0
    @State private var gerichtName = ""
    @State private var gerichtAlert = false
    @State private var toast: ToastInhalt?

    init(mahlzeit: Mahlzeit, tag: String) {
        self.mahlzeit = mahlzeit
        self.tag = tag
    }

    private var essen: EssenStore? { umgebung.daten?.essen }
    private var heute: String { Datum.text(umgebung.uhr()) }

    var body: some View {
        let liste = essen?.eintraege(tag, mahlzeit) ?? []
        List {
            Section {
                kopf(ErnaehrungLogik.summe(liste))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Abstand.s, trailing: 0))
            }
            Section {
                if liste.isEmpty {
                    Text("Noch nichts eingetragen. Scanne einfach die Packung.")
                        .foregroundStyle(palette.text2)
                        .listRowBackground(palette.flaeche)
                }
                ForEach(liste) { e in
                    EssenMahlzeitZeile(eintrag: e) { offen = EssenEintragZiel(id: e.id) }
                        .listRowBackground(palette.flaeche)
                        .listRowInsets(EdgeInsets(top: 0, leading: Abstand.l, bottom: 0, trailing: Abstand.l))
                        .swipeActions(allowsFullSwipe: false) {
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                essen?.loeschen(e)
                                geloescht += 1
                            }
                        }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .fontDesign(.rounded)
        .lumenHintergrund()
        .navigationTitle(essen?.mahlzeitName(mahlzeit) ?? mahlzeit.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { menue(liste) }
        .safeAreaInset(edge: .bottom) { hinzufuegenKnopf }
        .navigationDestination(item: $offen) { ziel in eintragSeite(ziel.id) }
        .sheet(isPresented: $neuOffen) {
            EssenHinzufuegenView(mahlzeit: mahlzeit, tag: tag, start: .suche, vorgewaehlt: nil) { gespeichert in
                neuOffen = false
                if gespeichert { toast = ToastInhalt(titel: "Eingetragen", zeile: nil, stimmung: .ziel) }
            }
        }
        .alert("Als Gericht speichern", isPresented: $gerichtAlert) {
            TextField("Name", text: $gerichtName)
            Button("Speichern") { gerichtSpeichern() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Du findest das Gericht danach bei den Favoriten und kannst es mit einem Tipp noch einmal eintragen.")
        }
        .lumenToast($toast)
        .haptik(.stopp, bei: geloescht)
        .haptik(.erfolg, bei: uebernommen)
        .animation(bewegungAus ? nil : Feder.weich, value: liste.count)
    }

    // MARK: - Teile

    private func kopf(_ summe: Naehrwerte) -> some View {
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                Text(EssenMahlzeitenLogik.tagTitel(tag, heute: heute)).font(.subheadline.weight(.semibold))
                HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                    RollZahl(wert: summe.kcal, format: .number.precision(.fractionLength(0)))
                        .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    Text("kcal").font(.subheadline)
                }
                HStack(spacing: 0) {
                    makro(summe.kohlenhydrate, "Kohlenhydrate")
                    makro(summe.protein, "Eiweiß")
                    makro(summe.fett, "Fett")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func makro(_ gramm: Double, _ titel: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(ErnaehrungLogik.zahl(gramm)) g").font(.headline.weight(.bold)).monospacedDigit()
            Text(titel).font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ToolbarContentBuilder
    private func menue(_ liste: [EssenEintrag]) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Von gestern übernehmen", systemImage: "arrow.uturn.backward") {
                    essen?.kopieren(von: Datum.addTage(tag, -1), nach: tag, mahlzeit: mahlzeit)
                    uebernommen += 1
                }
                if !liste.isEmpty {
                    Button("Als Gericht speichern", systemImage: "star") { gerichtName = ""; gerichtAlert = true }
                }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel("Mehr")
        }
    }

    private var hinzufuegenKnopf: some View {
        Button { neuOffen = true } label: {
            Label("Hinzufügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.lumenHauptknopf)
        .padding(.horizontal, Abstand.l)
        .padding(.bottom, Abstand.s)
    }

    @ViewBuilder
    private func eintragSeite(_ id: String) -> some View {
        if let e = essen?.eintraege(tag).first(where: { $0.id == id }) {
            EssenDetailView(lebensmittel: e.lebensmittel, mahlzeit: e.mahlzeit, tag: e.datum, bearbeiten: e) { _ in offen = nil }
        } else {
            LeerZustand(stimmung: .bereit, satz: "Dieser Eintrag ist gelöscht.")
        }
    }

    /// Eine ganze Mahlzeit als Gericht (Rezept der Art `mahlzeit`) und als Favorit speichern; die Vorlage ändert sich später nicht mit dem Tagebuch.
    private func gerichtSpeichern() {
        guard let essen else { return }
        let eintraege = essen.eintraege(tag, mahlzeit)
        guard !eintraege.isEmpty else { return }
        let name = gerichtName.trimmingCharacters(in: .whitespacesAndNewlines)
        let zutaten = eintraege.map { Zutat(id: UUID().uuidString, lebensmittel: $0.lebensmittel, menge: $0.menge, einheit: $0.einheit) }
        let rezept = Rezept(id: UUID().uuidString, name: name.isEmpty ? essen.mahlzeitName(mahlzeit) : name, portionen: 1, zutaten: zutaten, art: .mahlzeit)
        essen.rezeptSichern(rezept)
        essen.favoritSetzen(ErnaehrungLogik.alsLebensmittel(rezept), an: true)
        toast = ToastInhalt(titel: "Gericht gespeichert", zeile: "Bei den Favoriten", stimmung: .ziel)
    }
}

/// Ziel für die Seite eines gespeicherten Eintrags (`EssenEintrag` selbst ist nicht Hashable).
struct EssenEintragZiel: Hashable, Identifiable {
    let id: String
}

/// Name, Menge, kcal; Tipp öffnet den Eintrag. Wird auch von der Mahlzeiten-Übersicht benutzt.
struct EssenMahlzeitZeile: View {
    let eintrag: EssenEintrag
    let oeffnen: @MainActor () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button { oeffnen() } label: {
            HStack(spacing: Abstand.m) {
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text(eintrag.lebensmittel.anzeigeName).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                    Text(ErnaehrungLogik.mengeText(eintrag.menge, eintrag.einheit, eintrag.lebensmittel))
                        .font(.footnote).foregroundStyle(palette.text2)
                }
                Spacer(minLength: Abstand.s)
                Text("\(EssenMahlzeitenLogik.zahl(Int(eintrag.naehrwerte.kcal.rounded()))) kcal")
                    .font(.body.weight(.semibold)).foregroundStyle(palette.text).monospacedDigit()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
            .frame(minHeight: Abstand.tippflaeche)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet den Eintrag zum Ändern")
    }
}
