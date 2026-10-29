// Quelle: Lovea Health/UebungsSuche.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Der Übungskatalog (Idee 26): 1.333 Übungen auf Deutsch, Suche mit Synonymen (`UebungsKatalog.suchen`), Filter nach Körperteil und Gerät,
/// ganz oben "Zuletzt" und gängige Übungen. Mit `auswahl` wählt ein Tipp die Übung (Sheet), ohne öffnet er die Details (Rekorde, Verlauf).
struct UebungsSucheView: View {
    var titel = "Übungen"
    var auswahl: ((Uebung) -> Void)?
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var text = ""
    @State private var koerper: String?
    @State private var geraet: String?

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
            if text.isEmpty, koerper == nil {
                abschnitt("Zuletzt", zuletzt)
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
            if auswahl != nil { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } } }
        }
    }

    // MARK: Daten

    private var zuletzt: [Uebung] {
        UebungsKatalog.zuletzt(umgebung.daten?.training.sessions ?? [], limit: 6).filter { passt($0) }
    }

    private func passt(_ u: Uebung) -> Bool {
        (koerper == nil || u.koerper == koerper) && UebungsKatalog.passtGeraet(u, wahl: geraet)
    }

    private func gefiltert(_ liste: [Uebung]) -> [Uebung] { liste.filter(passt) }

    private var ergebnis: [Uebung] {
        let rohe = text.trimmingCharacters(in: .whitespaces).isEmpty ? UebungsKatalog.alle.sorted { $0.name < $1.name } : UebungsKatalog.suchen(text)
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
                schliessen()
            } label: { inhaltsZeile(u) }
        } else {
            NavigationLink(value: Route.uebung(id: u.id)) { inhaltsZeile(u) }
        }
    }

    private func inhaltsZeile(_ u: Uebung) -> some View {
        HStack(spacing: Abstand.m) {
            UebungsBild(id: u.id, koerper: u.koerper).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(u.name).font(.body.weight(.medium)).foregroundStyle(palette.text).lineLimit(3)
                Text("\(u.muskel) · \(u.geraet)").font(.footnote).foregroundStyle(palette.text2)
            }
        }
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(UebungsSymbol.beschreibung(u))
    }
}
