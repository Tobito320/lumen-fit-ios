// Quelle: Lovea Health/UebungsSuche.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Der Übungskatalog (Idee 26): 1.333 Übungen auf Deutsch, Suche mit Synonymen (`UebungsKatalog.suchen`), Filter nach Körperteil und Gerät,
/// ganz oben "Zuletzt" und gängige Übungen. Mit `auswahl` wählt ein Tipp die Übung (Sheet), ohne öffnet er die Details (Rekorde, Verlauf).
struct UebungsSucheView: View {
    var titel = "Übungen"
    var auswahl: ((Uebung) -> Void)?
    /// true = das Blatt bleibt offen, jeder Tipp fügt eine Übung hinzu (Plus wird zum Haken), "Fertig" schließt.
    var mehrfach = false
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var text = ""
    @State private var koerper: String?
    @State private var geraet: String?
    @State private var muskel: String?
    @State private var filterBlatt = false
    @State private var hinzugefuegt: [String] = []
    @State private var eigenesOffen = false
    @State private var eigenerName = ""
    @Environment(\.bewegungAus) private var ruhig

    private static let anzeigeLimit = 120

    var body: some View {
        if auswahl != nil {
            NavigationStack { inhalt }
        } else {
            inhalt
        }
    }

    private var inhalt: some View {
        List {
            Section { filter }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            if eigene != nil { eigenAnlegen }
            if text.isEmpty, koerper == nil {
                abschnitt("Zuletzt", zuletzt)
                abschnitt("Eigene", gefiltert(eigene?.uebungen ?? []))
                abschnitt("Gängig", UebungsKatalog.vorschlaege(in: gefiltert(UebungsKatalog.alle)))
            }
            let treffer = ergebnis
            Section(treffer.isEmpty ? "Nichts gefunden" : "\(treffer.count) \(treffer.count == 1 ? "Übung" : "Übungen")") {
                if treffer.isEmpty {
                    Text("Versuch ein anderes Wort, zum Beispiel Muskel oder Gerät. Oder stell oben den Filter auf Alle Geräte.")
                        .font(.subheadline).foregroundStyle(palette.text2)
                }
                ForEach(treffer.prefix(Self.anzeigeLimit)) { zeile($0) }
                if treffer.count > Self.anzeigeLimit {
                    Text("Es gibt mehr Treffer. Tipp genauer, um sie einzugrenzen.").font(.footnote).foregroundStyle(palette.text2)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .lumenHintergrund()
        .navigationTitle(titel)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $text, prompt: "Name, Muskel oder Gerät")
        .toolbar {
            if auswahl != nil { ToolbarItem(placement: .cancellationAction) { Button(mehrfach ? "Fertig" : "Abbrechen") { schliessen() } } }
            ToolbarItem(placement: .primaryAction) {
                Button { filterBlatt = true } label: {
                    let n = UebungsFilterLogik.anzahl(koerper: koerper, muskel: muskel, geraet: geraet)
                    Label(n > 0 ? "Filter (\(n))" : "Filter", systemImage: n > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter nach Muskel und Gerät")
                .accessibilityValue(UebungsFilterLogik.anzahl(koerper: koerper, muskel: muskel, geraet: geraet) == 0 ? "aus" : "\(UebungsFilterLogik.anzahl(koerper: koerper, muskel: muskel, geraet: geraet)) aktiv")
            }
        }
        .sheet(isPresented: $filterBlatt) { UebungsFilterBlatt(koerper: $koerper, muskel: $muskel, geraet: $geraet) }
        .sheet(isPresented: $eigenesOffen) {
            if let eigene { GymEigenesFormular(store: eigene, vorname: eigenerName) { nachErstellen($0) } }
        }
        .haptik(.auswahl, bei: hinzugefuegt.count)
    }

    // MARK: Daten

    private var eigene: GymEigeneStore? { GymSitzung.von(umgebung).eigene }

    private var zuletzt: [Uebung] {
        UebungsKatalog.zuletzt(umgebung.daten?.training.sessions ?? [], in: eigene?.nachId ?? UebungsKatalog.nachId, limit: 6).filter { passt($0) }
    }

    private func passt(_ u: Uebung) -> Bool {
        (koerper == nil || u.koerper == koerper) && (muskel == nil || u.muskel == muskel) && UebungsKatalog.passtGeraet(u, wahl: geraet)
    }

    private func gefiltert(_ liste: [Uebung]) -> [Uebung] { liste.filter(passt) }

    private var ergebnis: [Uebung] {
        let alle = eigene?.alle ?? UebungsKatalog.alle
        let rohe = text.trimmingCharacters(in: .whitespaces).isEmpty ? alle.sorted { $0.name < $1.name } : UebungsKatalog.suchen(text, in: alle)
        return gefiltert(rohe)
    }

    // MARK: Teile

    private var filter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Abstand.s) {
                Menu {
                    Button(UebungsKatalog.standardTitel) { geraet = nil }
                    Button(UebungsKatalog.alleGeraete) { geraet = UebungsKatalog.alleGeraete }
                    Divider()
                    ForEach(UebungsKatalog.geraete, id: \.self) { g in Button(g) { geraet = g } }
                } label: {
                    Pille(text: geraet ?? UebungsKatalog.standardTitel, symbolName: "dumbbell.fill")
                        .frame(minHeight: Abstand.tippflaeche)
                }
                .accessibilityLabel("Gerätefilter, \(geraet ?? UebungsKatalog.standardTitel)")
                chip("Alle", aktiv: koerper == nil) { koerper = nil }
                ForEach(UebungsKatalog.koerperteile, id: \.self) { teil in
                    chip(teil, aktiv: koerper == teil) { koerper = teil }
                }
            }
            .padding(.horizontal, Abstand.l)
        }
    }

    private func chip(_ name: String, aktiv: Bool, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Pille(text: name, symbolName: aktiv ? "checkmark" : nil)
                .frame(minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    /// Loveas "Erstellen", hier als erste Zeile; der Suchtext wird zum Namen.
    private var eigenAnlegen: some View {
        Section {
            Button {
                eigenerName = text.trimmingCharacters(in: .whitespacesAndNewlines)
                eigenesOffen = true
            } label: {
                Label("Eigene Übung erstellen", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            }
            .accessibilityHint("Öffnet ein Formular mit Name, Muskel und Gerät")
        }
    }

    /// Mit Auswahl wird die neue Übung gleich gewählt (wie bei Loveas "Hinzufügen"), sonst steht sie in der Liste.
    private func nachErstellen(_ u: Uebung) {
        guard let auswahl else { return }
        auswahl(u)
        if mehrfach {
            withAnimation(ruhig ? nil : Feder.schnell) { hinzugefuegt.append(u.id) }
        } else {
            schliessen()
        }
    }

    @ViewBuilder
    private func abschnitt(_ name: String, _ liste: [Uebung]) -> some View {
        if !liste.isEmpty {
            Section(name) { ForEach(liste) { zeile($0) } }
        }
    }

    @ViewBuilder
    private func zeile(_ u: Uebung) -> some View {
        if let auswahl {
            Button {
                auswahl(u)
                if mehrfach {
                    withAnimation(ruhig ? nil : Feder.schnell) { hinzugefuegt.append(u.id) }
                } else {
                    schliessen()
                }
            } label: {
                HStack {
                    inhaltsZeile(u)
                    if mehrfach {
                        let da = hinzugefuegt.contains(u.id)
                        Image(systemName: da ? "checkmark.circle.fill" : "plus.circle")
                            .font(.title3).foregroundStyle(da ? palette.akzent : palette.text2)
                            .contentTransition(.symbolEffect(.replace))
                            .accessibilityLabel(da ? "Hinzugefügt" : "Hinzufügen")
                    }
                }
            }
        } else {
            NavigationLink(value: Route.uebung(id: u.id)) { inhaltsZeile(u) }
        }
    }

    private func inhaltsZeile(_ u: Uebung) -> some View {
        HStack(spacing: Abstand.m) {
            UebungsBild(id: u.id, koerper: u.koerper).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(u.name).font(.body.weight(.medium)).foregroundStyle(palette.text).lineLimit(3)
                Text(GymEigeneLogik.istEigene(u.id) ? "\(u.muskel) · \(u.geraet) · Eigene" : "\(u.muskel) · \(u.geraet)").font(.footnote).foregroundStyle(palette.text2)
            }
        }
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(GymEigeneLogik.istEigene(u.id) ? "\(UebungsSymbol.beschreibung(u)), eigene Übung" : UebungsSymbol.beschreibung(u))
    }
}

/// Wie viele Filter aktiv sind (für den Zähler am Knopf) und welche Muskeln zu einem Körperteil gehören.
enum UebungsFilterLogik {
    /// Körperteil, Muskel und ein gewähltes Gerät zählen; "Hanteln & Maschinen" (nil) ist der Standard und zählt nicht.
    static func anzahl(koerper: String?, muskel: String?, geraet: String?) -> Int {
        [koerper, muskel, geraet].compactMap { $0 }.count
    }

    /// Die Muskeln der Übungen eines Körperteils (alle ohne Körperteil), sortiert, ohne Doppelte.
    static func muskeln(koerper: String?, in liste: [Uebung] = UebungsKatalog.alle) -> [String] {
        Array(Set(liste.filter { koerper == nil || $0.koerper == koerper }.map(\.muskel))).sorted()
    }
}

/// Das Filterblatt: Körperteil, Muskel und Gerät auf einmal, mit "Zurücksetzen".
struct UebungsFilterBlatt: View {
    @Binding var koerper: String?
    @Binding var muskel: String?
    @Binding var geraet: String?
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            Form {
                Section("Körperteil") {
                    Picker("Körperteil", selection: Binding(get: { koerper ?? "" }, set: { koerper = $0.isEmpty ? nil : $0; muskel = nil })) {
                        Text("Alle").tag("")
                        ForEach(UebungsKatalog.koerperteile, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Muskel") {
                    Picker("Muskel", selection: Binding(get: { muskel ?? "" }, set: { muskel = $0.isEmpty ? nil : $0 })) {
                        Text("Alle").tag("")
                        ForEach(UebungsFilterLogik.muskeln(koerper: koerper), id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Gerät") {
                    Picker("Gerät", selection: Binding(get: { geraet ?? "" }, set: { geraet = $0.isEmpty ? nil : $0 })) {
                        Text(UebungsKatalog.standardTitel).tag("")
                        Text(UebungsKatalog.alleGeraete).tag(UebungsKatalog.alleGeraete)
                        ForEach(UebungsKatalog.geraete, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section {
                    Button("Zurücksetzen", role: .destructive) { koerper = nil; muskel = nil; geraet = nil }
                        .frame(minHeight: Abstand.tippflaeche)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
