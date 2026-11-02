import SwiftUI

/// Die Wahl, was eine Person von dir sieht: oben "Wenig" oder "Alles", darunter jeder Bereich als Schalter. Passt die Auswahl zu keiner Stufe, ist im Segment nichts aktiv.
/// `einklappbar` nil: die Schalter stehen offen da (Bildschirm "Verbunden mit"); sonst hinter "Einzelne Schalter" (Seite der Person).
struct FreigabeAuswahl: View {
    let an: Set<VerbindungBereich>
    let einklappbar: Binding<Bool>?
    let aendern: (Set<VerbindungBereich>) -> Void

    var body: some View {
        Picker("Wie viel", selection: Binding<FreigabeStufe?>(
            get: { FreigabeStufe.von(an) },
            set: { if let stufe = $0 { aendern(stufe.bereiche) } })) {
            ForEach(FreigabeStufe.allCases, id: \.self) { Text($0.name).tag(Optional($0)) }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: Abstand.tippflaeche)
        if let einklappbar {
            DisclosureGroup("Einzelne Schalter", isExpanded: einklappbar) { schalter }
        } else {
            schalter
        }
    }

    private var schalter: some View {
        ForEach(VerbindungBereich.allCases, id: \.self) { b in
            Toggle(isOn: Binding(get: { an.contains(b) }, set: { aendern(FreigabeStufe.schalte(an, b, ein: $0)) })) { BereichZeile(b) }
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityLabel(b.name)
                .accessibilityHint(b.erklaerung)
        }
    }
}

/// Symbol, Name und auf Wunsch die Erklärung eines Bereichs.
struct BereichZeile: View {
    let bereich: VerbindungBereich
    let erklaerung: Bool
    @Environment(\.palette) private var palette

    init(_ bereich: VerbindungBereich, erklaerung: Bool = true) {
        self.bereich = bereich
        self.erklaerung = erklaerung
    }

    var body: some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: bereich.symbol).frame(width: 28).foregroundStyle(palette.text2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(bereich.name)
                if erklaerung { Text(bereich.erklaerung).font(.footnote).foregroundStyle(palette.text2) }
            }
        }
    }
}
