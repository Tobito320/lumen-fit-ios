import SwiftUI
import UIKit

/// Abschnitt "Analysen" im Essen-Tab: laufende, fertige und fehlgeschlagene Foto-Schätzungen. Erscheint nur, wenn es welche gibt.
/// Übernommen wird erst nach Prüfen im Blatt; "Verwerfen" lässt sechs Sekunden "Rückgängig" zu.
struct EssenKiAnalysenAbschnitt: View {
    /// Name der übernommenen Mahlzeit, für die Bestätigung.
    let fertig: @MainActor (String) -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var offen: EssenKiAuftrag?

    var body: some View {
        Group {
            if let store = EssenKiModul.store(umgebung), !store.auftraege.isEmpty || store.verworfen != nil {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text("Analysen").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                    ListenKarte {
                        ForEach(store.auftraege) { a in
                            EssenKiAnalyseKarte(auftrag: a, store: store) { offen = a }
                            Haarlinie()
                        }
                        if let v = store.verworfen {
                            HStack {
                                Text("\(umgebung.daten?.essen.mahlzeitName(v.mahlzeit) ?? v.mahlzeit.name) verworfen").foregroundStyle(palette.text2)
                                Spacer()
                                Button("Rückgängig") { store.rueckgaengig() }
                                    .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
                            }
                            .padding(.horizontal, Abstand.l)
                        }
                    }
                }
            }
        }
        .sheet(item: $offen) { a in
            EssenKiFotoBlatt(auftrag: a, fertig: fertig, vonHand: {})
        }
        .task { await EssenKiModul.freigabe(umgebung).pruefen() }
    }
}

/// Eine Karte: Vorschaubild, Titel, Zustand, Knöpfe je nach Zustand.
private struct EssenKiAnalyseKarte: View {
    let auftrag: EssenKiAuftrag
    let store: EssenKiAuftragStore
    let oeffnen: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var vorschau: UIImage?

    private var zustand: (text: String, symbol: String) {
        switch auftrag.status {
        case .laeuft: (String(localized: "Wird geschätzt"), "hourglass")
        case .fertig:
            if let a = auftrag.analyse, EssenKiFotoLogik.keinEssen(a) { (String(localized: "Kein Essen erkannt"), "fork.knife") } else { (String(localized: "Bereit zum Prüfen"), "checkmark.circle") }
        case .fehler: (EssenKiAuftragLogik.anzeige(auftrag)?.titel ?? String(localized: "Fehlgeschlagen"), "exclamationmark.triangle")
        case .unterbrochen: (String(localized: "Unterbrochen"), "pause.circle")
        }
    }

    var body: some View {
        let z = zustand
        let name = umgebung.daten?.essen.mahlzeitName(auftrag.mahlzeit) ?? auftrag.mahlzeit.name
        VStack(alignment: .leading, spacing: Abstand.s) {
            Button(action: oeffnen) {
                HStack(spacing: Abstand.m) {
                    Group {
                        if let vorschau {
                            Image(uiImage: vorschau).resizable().scaledToFill()
                        } else {
                            Image(systemName: "photo").foregroundStyle(palette.text2)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: Rundung.klein, style: .continuous))
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Abstand.xs) {
                        Text(name).font(.headline).foregroundStyle(palette.text)
                        Pille(text: z.text, symbolName: z.symbol)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name), \(z.text)")
            .accessibilityHint("Öffnet die Analyse")
            HStack(spacing: Abstand.m) {
                if auftrag.status == .fehler || auftrag.status == .unterbrochen {
                    Button("Nochmal") { store.nochmal(auftrag.id) }.frame(minHeight: Abstand.tippflaeche)
                }
                if auftrag.status == .laeuft {
                    Button("Abbrechen", role: .destructive) { store.abbrechen(auftrag.id) }.frame(minHeight: Abstand.tippflaeche)
                } else {
                    Button("Verwerfen", role: .destructive) { store.verwerfen(auftrag.id) }.frame(minHeight: Abstand.tippflaeche)
                }
            }
        }
        .padding(Abstand.l)
        .task(id: store.bildStand) {
            let url = store.bildURL(auftrag.id)
            let daten = await Task.detached { try? Data(contentsOf: url) }.value
            vorschau = daten.flatMap { UIImage(data: $0) }
        }
    }
}
