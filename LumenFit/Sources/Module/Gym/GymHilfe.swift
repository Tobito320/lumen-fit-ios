import SwiftUI

/// Blatt "Hilfe?" (Entwurf `sheet hilfe`): "Was mache ich für …?" mit einer Pille je Muskelgruppe; ein Tipp öffnet die Muskel-Seite im Blatt.
struct GymHilfeBlatt: View {
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    Text("Was mache ich für …?").font(.headline).foregroundStyle(palette.text)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Abstand.s)], alignment: .leading, spacing: Abstand.s) {
                        ForEach(GymMuskelHilfe.gruppen, id: \.self) { g in
                            NavigationLink { GymMuskelSeite(gruppe: g) } label: {
                                Text(g.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.text)
                                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                                    .background(palette.flaeche, in: .capsule)
                                    .overlay(Capsule().stroke(palette.haar, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle("Hilfe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Muskel-Seite (Entwurf `muskel`): Figur mit der Gruppe, ein Erklärsatz, "Diese Woche N Sets", dann alle Übungen der Gruppe mit Geräte-Chips.
struct GymMuskelSeite: View {
    let gruppe: MuskelGruppe
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var koerper: KoerperDaten?
    @State private var geraet: String?

    /// Geräte-Chips wie im Entwurf; nil = alle.
    private static let geraete: [String] = ["Maschine", "Kabelzug", "Kurzhantel", "Langhantel", "Körpergewicht"]

    var body: some View {
        let alle = GymMuskelHilfe.uebungen(gruppe)
        let liste = geraet.map { g in alle.filter { $0.geraet == g } } ?? alle
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                kopf
                GymAbschnitt(titel: String(localized: "Alle Übungen · \(liste.count)"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Abstand.s) {
                        GymChip(text: String(localized: "Alle"), aktiv: geraet == nil) { geraet = nil }
                        ForEach(Self.geraete, id: \.self) { g in GymChip(text: g, aktiv: geraet == g) { geraet = g } }
                    }
                }
                if liste.isEmpty {
                    Text("Keine Übung mit diesem Gerät.").font(.subheadline).foregroundStyle(palette.text2)
                } else {
                    ListenKarte {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(liste.enumerated()), id: \.element.id) { i, u in
                                if i > 0 { Haarlinie() }
                                NavigationLink { UebungDetailView(id: u.id, anleitungZuerst: true) } label: {
                                    GymUebungZeile(id: u.id, koerper: u.koerper, titel: u.name, untertitel: "\(u.muskel) · \(u.geraet)")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle(gruppe.name)
        .navigationBarTitleDisplayMode(.large)
        .task { koerper = FortschrittQuelle(umgebung: umgebung).koerper }
    }

    private var kopf: some View {
        HStack(alignment: .center, spacing: Abstand.l) {
            if let koerper {
                SilhouetteAnsicht(seite: GymMuskelHilfe.vonHinten(gruppe) ? .hinten : .vorne, daten: koerper, fokus: gruppe)
                    .frame(width: 90)
            }
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(GymMuskelHilfe.satz(gruppe)).font(.subheadline).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
                let n = Int((koerper?.saetze(gruppe) ?? 0).rounded())
                Pille(text: String(localized: "Diese Woche \(n) Sets"), symbolName: n > 0 ? "checkmark" : nil)
            }
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
    }
}

/// Blatt "Anderen Plan wählen" (Entwurf `sheet plaene`): der jetzige Plan oben, darunter die empfohlenen Splits; ein Tipp zeigt den Split zuerst an
/// ("Diesen Plan nehmen" mit Rückfrage), nichts wird ohne Blick ersetzt. Unten der Weg in die ganze Bibliothek.
struct GymPlanWahlBlatt: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette

    var body: some View {
        let geschlecht = umgebung.daten?.ziele.koerper.geschlecht
        let eigene = SplitLogik.treffer(SplitLogik.fuer(geschlecht), art: "fuerdich", tage: nil, suche: "")
        // Nicht jede Gruppe hat Empfehlungen (`istEigen`): dann alle Splits der Gruppe.
        let empfohlen = eigene.isEmpty ? SplitLogik.fuer(geschlecht) : eigene
        let aktuell = sitzung.training?.plan.splitName
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    if let aktuell {
                        Text("Jetzt: \(aktuell)").font(.subheadline).foregroundStyle(palette.text2)
                    }
                    GymAbschnitt(titel: String(localized: "Für dich"))
                    ListenKarte {
                        ForEach(Array(empfohlen.enumerated()), id: \.element.id) { i, v in
                            if i > 0 { Haarlinie() }
                            NavigationLink { SplitDetailView(sitzung: sitzung, vorlage: v, fertig: { schliessen() }) } label: {
                                GymZeile(titel: v.name, untertitel: SplitLogik.unterzeile(v)) {
                                    HStack(spacing: Abstand.xs) {
                                        if v.name == aktuell { Pille(text: String(localized: "Aktiv")) }
                                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ListenKarte {
                        NavigationLink { SplitBibliothekView(sitzung: sitzung, fertig: { schliessen() }) } label: {
                            GymSymbolZeile(symbol: "square.grid.2x2.fill", farbe: Bereichsfarbe.splits, titel: String(localized: "Alle Splits"),
                                           untertitel: String(localized: "Suche, Ziel und Tage"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle("Plan wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { schliessen() } } }
        }
        .presentationDragIndicator(.visible)
    }
}
