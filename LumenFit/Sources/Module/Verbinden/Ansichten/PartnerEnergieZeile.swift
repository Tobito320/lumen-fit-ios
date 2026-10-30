// Quelle: Lovea Health/EnergieKarte.swift (partnerZeile)
import SwiftUI

/// Eine Zeile mit dem Energie-Rat des Partners: "Normale Energie, Gym ja". Steht in der Partner-Karte (innerhalb einer `ListenKarte`) und überall, wo ein Rat passt.
/// Ohne Freigabe schlaf oder ohne Stufe in der Datei: nichts.
struct PartnerEnergieZeile: View {
    let datei: ZusammenfassungDatei
    @Environment(\.palette) private var palette

    var body: some View {
        if let satz = PartnerAnzeige.energieSatz(datei) {
            HStack(spacing: Abstand.m) {
                Image(systemName: "bolt.fill")
                    .frame(width: 28)
                    .foregroundStyle(palette.text2)
                    .accessibilityHidden(true)
                Text(satz)
                    .font(.subheadline)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
            .frame(minHeight: Abstand.tippflaeche)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(datei.profilName): \(satz)")
        }
    }
}
