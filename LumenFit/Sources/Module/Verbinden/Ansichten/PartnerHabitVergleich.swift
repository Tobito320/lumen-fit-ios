import SwiftUI

/// Eine kleine Zeile unter einer Gewohnheit: wie es beim Partner steht ("Partner: 12 in Folge · 55 % in 30 Tagen"). Nur mit Freigabe gewohnheiten und wenn der
/// Partner dieselbe Gewohnheit hat (gleiche Kennung oder gleicher Name); sonst steht da nichts, auch kein Platzhalter.
struct PartnerHabitVergleich: View {
    let habitID: String
    let name: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    private var text: String? {
        guard let datei = PartnerAnzeige.aktuell(umgebung), let g = PartnerAnzeige.gewohnheit(datei, id: habitID, name: name) else { return nil }
        return "\(datei.profilName): \(g.serie) in Folge · \(g.quote) % in 30 Tagen"
    }

    var body: some View {
        if let text {
            Text(text)
                .font(.caption)
                .foregroundStyle(palette.text2)
                .accessibilityLabel(text)
        }
    }
}
