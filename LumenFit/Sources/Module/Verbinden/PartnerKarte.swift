import SwiftUI

/// Die Partner-Karte (Idee 82): Heute und Schlaf betten sie ein. Sie zeigt nur, was die verbundene Person freigibt und die Datei enthält.
/// Nicht verbunden, veraltet, falsche Version, nichts freigegeben: gar nichts, nicht einmal einen Platzhalter oder eine Fehlermeldung.
struct PartnerKarte: View {
    let bereich: PartnerBereich
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    private var stand: PartnerStand {
        VerbindenDemo.partner ?? umgebung.daten?.verbindung.partner ?? .nichtVerbunden
    }

    var body: some View {
        if let datei = PartnerAnzeige.zusammenfassung(stand) {
            let zeilen = PartnerAnzeige.zeilen(datei, bereich: bereich)
            if !zeilen.isEmpty { karte(datei.profilName, zeilen) }
        }
    }

    private func karte(_ name: String, _ zeilen: [PartnerAnzeige.Zeile]) -> some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: 0) {
                Text("Partner")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.text2)
                Text(name)
                    .font(.headline)
                    .foregroundStyle(palette.text)
            }
            .padding(Abstand.l)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(zeilen) { zeile in
                Haarlinie()
                HStack(spacing: Abstand.m) {
                    Image(systemName: zeile.symbol)
                        .frame(width: 28)
                        .foregroundStyle(palette.text2)
                        .accessibilityHidden(true)
                    Text(zeile.titel)
                        .foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.m)
                    Text(zeile.wert)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.text)
                }
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
