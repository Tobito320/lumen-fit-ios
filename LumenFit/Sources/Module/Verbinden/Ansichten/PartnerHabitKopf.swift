// Quelle: Lovea Health/HabitsSektion.swift (Figur des Partners an einer erledigten Gewohnheit)
import SwiftUI

/// Der kleine Kopf neben einer Gewohnheit, wenn der Partner sie heute schon erledigt hat. `habitID` ist die eingebaute Kennung (`gym`, `wasser`);
/// für alle anderen und ohne Freigabe der Art erscheint nichts. Er federt ein und aus (Reduce Motion: überblenden).
struct PartnerHabitKopf: View {
    let habitID: String
    var groesse: CGFloat = 28
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus

    private var fertigBei: String? {
        guard let datei = PartnerAnzeige.aktuell(umgebung), PartnerAnzeige.habitFertig(datei, id: habitID) else { return nil }
        return datei.profilName
    }

    var body: some View {
        ZStack {
            if let name = fertigBei {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: groesse * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.aufAkzent)
                    .frame(width: groesse, height: groesse)
                    .background(palette.text2, in: .circle)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: groesse * 0.4))
                            .foregroundStyle(palette.text, palette.grund)
                    }
                    .transition(bewegungAus ? .opacity : .scale.combined(with: .opacity))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(name) hat heute erledigt")
            }
        }
        .animation(bewegungAus ? nil : Feder.federnd, value: fertigBei)
    }
}
