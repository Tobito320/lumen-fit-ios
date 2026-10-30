// Quelle: Lovea Health/Ernaehrung/ErnaehrungKoerper.swift (KoerperwerteBlatt)
import SwiftUI

/// Körperwerte eines Tages eintragen: Gewicht (liegt im Gewicht-Habit) und weitere Werte. Einmal pro Woche reicht;
/// leere Felder bleiben unverändert.
struct EssenKoerperwerteBlatt: View {
    let tag: String

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var gewicht = ""
    @State private var werte: [KoerperArt: String] = [:]
    @State private var geladen = false
    @State private var gesichert = 0

    init(tag: String) { self.tag = tag }

    private var essen: EssenStore? { umgebung.daten?.essen }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    karte {
                        EssenZahlFeld(titel: "Gewicht", einheit: "kg", text: $gewicht)
                        Text("Am besten einmal pro Woche, am selben Tag und zur gleichen Uhrzeit.")
                            .font(.footnote).foregroundStyle(palette.text2)
                    }
                    Text("Weitere Körperwerte").font(.headline).foregroundStyle(palette.text)
                    karte {
                        ForEach(KoerperArt.allCases) { art in
                            EssenZahlFeld(titel: art.name, einheit: art.einheit, text: binding(art))
                            if art != KoerperArt.allCases.last { Haarlinie() }
                        }
                    }
                }
                .padding(Abstand.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .fontDesign(.rounded)
            .lumenHintergrund()
            .navigationTitle(Datum.anzeige(tag))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { EssenTastatur.schliessen() } }
            }
            .haptik(.erfolg, bei: gesichert)
            .task { laden() }
        }
        .presentationDetents([.large])
    }

    private func karte<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) { inhalt() }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
    }

    private func binding(_ art: KoerperArt) -> Binding<String> {
        Binding(get: { werte[art] ?? "" }, set: { werte[art] = $0 })
    }

    /// Werte, die für genau diesen Tag schon eingetragen sind.
    private func laden() {
        guard !geladen, let essen else { return }
        geladen = true
        if let g = essen.gewicht(bis: tag), g.datum == tag { gewicht = GewichtText.feld(g.zehntel) }
        for art in KoerperArt.allCases {
            if let w = essen.koerperwert(art, bis: tag), w.datum == tag, w.geloescht != true { werte[art] = ErnaehrungLogik.zahl(w.wert) }
        }
    }

    private func speichern() {
        if let essen {
            if let zehntel = GewichtText.zehntel(gewicht) { essen.gewichtSetzen(zehntel: zehntel, datum: tag) }
            for art in KoerperArt.allCases {
                if let wert = EssenMahlzeitenLogik.koerperwert(werte[art]) { essen.koerperwertSetzen(art, wert, datum: tag) }
            }
        }
        gesichert += 1
        // Kurz warten, damit die Haptik vor dem Schließen auslöst.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            dismiss()
        }
    }
}
