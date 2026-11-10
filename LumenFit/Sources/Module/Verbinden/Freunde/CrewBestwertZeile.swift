import SwiftUI

/// "Crew-Bestwert: Beispiel Freund A 80 kg × 8" unter dem Übungsnamen im Training; ohne Wert (keine Freigabe gym und verlauf) nichts.
struct CrewBestwertZeile: View {
    let uebung: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        if let b = CrewLogik.bestwert(uebung: uebung, eintraege: GymCrewQuelle.eintraege(umgebung)) {
            Label(CrewLogik.bestwertText(b), systemImage: "person.2.fill")
                .font(.footnote)
                .foregroundStyle(palette.text2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}
