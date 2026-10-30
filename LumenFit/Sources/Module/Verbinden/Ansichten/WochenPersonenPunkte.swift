// Quelle: Lovea Health/Koerper/KoerperView.swift (Personenpunkte unter einem Tag im Wochenstreifen)
import SwiftUI

/// Die kleinen Punkte unter einem Tag im Wochenstreifen: ein Punkt für dich, einer für den Partner, wenn an dem Tag Gym war.
/// Die Höhe ist immer 5 pt, damit alle Spalten gleich hoch bleiben. `ichGym` kommt vom Streifen (eigene Daten), den Partner liest der Baustein selbst.
struct WochenPersonenPunkte: View {
    let tag: String
    let ichGym: Bool
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    private var partnerName: String? {
        guard let datei = PartnerAnzeige.aktuell(umgebung), PartnerAnzeige.gymTage(datei).contains(tag) else { return nil }
        return datei.profilName
    }

    var body: some View {
        HStack(spacing: 3) {
            if ichGym { Circle().fill(palette.text).frame(width: 5, height: 5) }
            if partnerName != nil { Circle().fill(palette.text2).frame(width: 5, height: 5) }
        }
        .frame(height: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschreibung)
    }

    private var beschreibung: String {
        switch (ichGym, partnerName) {
        case (true, let name?): "Gym: du und \(name)"
        case (true, nil): "Gym: du"
        case (false, let name?): "Gym: \(name)"
        case (false, nil): ""
        }
    }
}
