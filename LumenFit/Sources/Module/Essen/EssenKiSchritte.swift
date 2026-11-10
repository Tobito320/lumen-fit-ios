import SwiftUI

/// Ladeanzeige der Foto-Schätzung: drei Schritte, nach Zeit weitergeschaltet (der Server meldet keinen echten Fortschritt).
struct EssenKiSchritte: View {
    let seit: Date
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus

    private nonisolated static let texte = [String(localized: "Bild wird gesendet"), String(localized: "Essen wird erkannt"), String(localized: "Kalorien werden geschätzt")]

    var body: some View {
        TimelineView(.periodic(from: seit, by: 1)) { zeit in
            let aktuell = EssenKiAuftragLogik.schritt(seit: seit, jetzt: zeit.date)
            VStack(alignment: .leading, spacing: Abstand.m) {
                ForEach(Array(Self.texte.enumerated()), id: \.offset) { i, text in
                    HStack(spacing: Abstand.m) {
                        if i < aktuell {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.akzent)
                        } else if i == aktuell {
                            ProgressView()
                        } else {
                            Image(systemName: "circle").foregroundStyle(palette.text2)
                        }
                        Text(text).foregroundStyle(i <= aktuell ? palette.text : palette.text2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(i < aktuell ? "\(text), fertig" : i == aktuell ? "\(text), läuft" : "\(text), wartet")
                }
            }
            .animation(bewegungAus ? nil : Feder.weich, value: aktuell)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Abstand.l)
            .lumenKartenFlaeche()
        }
    }
}
