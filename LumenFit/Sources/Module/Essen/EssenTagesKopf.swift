// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (TagebuchAnsicht.kopf, kalenderBlatt)
import SwiftUI

/// Tageskopf des Essen-Tabs: "Heute", "Gestern", "Morgen" oder der Tag, darunter die Woche; Tipp öffnet das Datum-Blatt, Pfeile wechseln den Tag.
struct EssenTagesKopf: View {
    let tag: String
    let heute: String
    let vorher: @MainActor () -> Void
    let nachher: @MainActor () -> Void
    let datumOeffnen: @MainActor () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.xs) {
            Button { datumOeffnen() } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(EssenTagebuchLogik.titel(tag: tag, heute: heute))
                        .font(.largeTitle.weight(.black)).fontDesign(.rounded)
                        .foregroundStyle(palette.text)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("Woche \(EssenTagebuchLogik.woche(tag: tag))").font(.subheadline).foregroundStyle(palette.text2)
                }
                .frame(minHeight: Abstand.tippflaeche, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Anderen Tag wählen")
            Spacer(minLength: Abstand.s)
            tagKnopf("chevron.left", "Vorheriger Tag", vorher)
            tagKnopf("chevron.right", "Nächster Tag", nachher)
        }
    }

    private func tagKnopf(_ symbol: String, _ titel: String, _ aktion: @escaping @MainActor () -> Void) -> some View {
        Button { aktion() } label: {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(palette.text)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                .background(palette.flaeche, in: .circle)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(titel)
    }
}

/// Datum-Blatt mit Kalender: "Heute" links, "Fertig" rechts.
struct EssenDatumBlatt: View {
    @Binding var tag: String
    let heute: String
    @Environment(\.dismiss) private var dismiss

    private var datum: Binding<Date> {
        Binding(get: { Datum.datum(tag) }, set: { tag = Datum.text($0) })
    }

    var body: some View {
        NavigationStack {
            DatePicker("Datum", selection: datum, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .padding()
                .navigationTitle("Tag wählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Heute") { tag = heute; dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
