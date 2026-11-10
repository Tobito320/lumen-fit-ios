// Quelle: Lovea Health/Heute/HeuteView.swift (Tag wählen: Pfeile, Monat, Zurück zu heute)
import SwiftUI

/// Die Tagwahl oben im Heute-Tab: Pfeil zum Tag davor, in der Mitte der Tag (Tipp öffnet den Kalender), Pfeil zum Tag danach. Liegt ein anderer Tag
/// als heute offen, steht darunter die Pille "Zurück zu heute". Die Zukunft ist gesperrt (der Pfeil nach rechts ist dann aus).
struct HeuteTagLeiste: View {
    let tag: String
    let heute: String
    let blaettere: (Int) -> Void
    let kalender: () -> Void
    let zuHeute: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Abstand.xs) {
            HStack(spacing: 0) {
                pfeil("chevron.left", -1, String(localized: "Tag davor"), aktiv: HeuteTagWahl.kannZurueck(tag, heute: heute))
                Spacer(minLength: Abstand.s)
                Button(action: kalender) {
                    VStack(spacing: 2) {
                        HStack(spacing: Abstand.xs) {
                            Text(HeuteTagWahl.titel(tag, heute: heute)).font(.headline).foregroundStyle(palette.text)
                            Image(systemName: "calendar").font(.footnote).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                        if let zweite = HeuteTagWahl.untertitel(tag, heute: heute) {
                            Text(zweite).font(.caption).foregroundStyle(palette.text2)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minHeight: Abstand.tippflaeche)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tag wählen, \(Datum.anzeige(tag))")
                .accessibilityHint("Öffnet den Kalender")
                Spacer(minLength: Abstand.s)
                pfeil("chevron.right", 1, String(localized: "Tag danach"), aktiv: HeuteTagWahl.kannVor(tag, heute: heute))
            }
            if tag != heute {
                Button(action: zuHeute) {
                    Pille(text: String(localized: "Zurück zu heute"), symbolName: "arrow.uturn.backward")
                        .frame(minHeight: Abstand.tippflaeche)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Zurück zu heute")
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private func pfeil(_ symbol: String, _ tage: Int, _ beschriftung: String, aktiv: Bool) -> some View {
        Button { blaettere(tage) } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(aktiv ? palette.text : palette.text2.opacity(0.4))
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                .contentShape(Rectangle())
        }
        .buttonStyle(.federnd)
        .disabled(!aktiv)
        .accessibilityLabel(beschriftung)
    }
}

/// Das Kalender-Blatt der Tagwahl: Monat (graphisch), nur Tage von vor einem Jahr bis heute. Ein Tipp wählt den Tag und schließt das Blatt.
struct HeuteKalenderBlatt: View {
    let tag: String
    let heute: String
    let waehle: (String) -> Void
    @State private var auswahl: Date
    @Environment(\.dismiss) private var dismiss

    init(tag: String, heute: String, waehle: @escaping (String) -> Void) {
        self.tag = tag
        self.heute = heute
        self.waehle = waehle
        _auswahl = State(initialValue: Datum.datum(tag))
    }

    var body: some View {
        NavigationStack {
            DatePicker("Tag", selection: $auswahl, in: Datum.datum(HeuteTagWahl.aeltester(heute: heute))...Datum.datum(heute), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.calendar, Datum.kalender)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .padding()
                .navigationTitle("Tag wählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Heute") { waehle(heute); dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                }
                .onChange(of: auswahl) { _, neu in
                    waehle(Datum.text(neu))
                    dismiss()
                }
        }
        .presentationDetents([.medium, .large])
    }
}
