// Quelle: Lovea Health/Ernaehrung/LebensmittelDetail.swift (NutriScoreAbzeichen); neu im Lumen-Design: monochrom, der Buchstabe trägt die Information
import SwiftUI

/// Nutri-Score aus Open Food Facts. Nur "a" bis "e" zählt; "unknown", "not-applicable" und alles andere zeigt kein Abzeichen.
enum EssenNutriScoreLogik {
    static let stufen = ["a", "b", "c", "d", "e"]

    /// Kleinbuchstabe a bis e, sonst nil.
    static func note(_ roh: String?) -> String? {
        guard let t = roh?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), stufen.contains(t) else { return nil }
        return t
    }

    /// 0 für A bis 4 für E.
    static func index(_ note: String) -> Int? { stufen.firstIndex(of: note) }

    static func beschreibung(_ note: String) -> String {
        switch note {
        case "a": "Nutri-Score A, sehr günstige Nährwerte"
        case "b": "Nutri-Score B, günstige Nährwerte"
        case "c": "Nutri-Score C, mittlere Nährwerte"
        case "d": "Nutri-Score D, eher ungünstige Nährwerte"
        default: "Nutri-Score E, ungünstige Nährwerte"
        }
    }
}

/// Fünf Kreise A bis E, der zutreffende ist gefüllt. Ohne Farbe lesbar. `kompakt` zeigt nur den einen Buchstaben.
struct EssenNutriScoreAbzeichen: View {
    let note: String
    var kompakt = false
    @Environment(\.palette) private var palette

    var body: some View {
        if let n = EssenNutriScoreLogik.note(note) {
            Group {
                if kompakt {
                    kreis(n.uppercased(), aktiv: true, groesse: 24)
                } else {
                    HStack(spacing: Abstand.xs) {
                        ForEach(EssenNutriScoreLogik.stufen, id: \.self) { s in kreis(s.uppercased(), aktiv: s == n, groesse: s == n ? 32 : 24) }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(EssenNutriScoreLogik.beschreibung(n))
        }
    }

    private func kreis(_ buchstabe: String, aktiv: Bool, groesse: CGFloat) -> some View {
        Text(buchstabe)
            .font(.caption.weight(.bold))
            .foregroundStyle(aktiv ? palette.aufAkzent : palette.text2)
            .frame(width: groesse, height: groesse)
            .background(aktiv ? palette.akzent : Color.clear, in: .circle)
            .overlay(Circle().stroke(aktiv ? Color.clear : palette.haar, lineWidth: 1))
    }
}
