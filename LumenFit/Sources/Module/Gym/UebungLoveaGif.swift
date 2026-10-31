// Quelle: Lovea Health/UebungsSuche.swift (UebungGif :227), UebungRekorde.swift (UebungDetail :99)
import SwiftUI

/// Das Bild einer Übung im Lovea-Aufbau wie `UebungGif`: weiße Kachel mit Ecken 20, darin die Schleife; ohne Video "Kein Video für diese Übung", ohne Netz
/// und ohne Kopie "Video lädt, sobald du Netz hast", beim Laden ein Platzhalter. Die GIF-Dateien kommen aus dem Cache von `UebungsMedien` (geladen, nie
/// gebündelt); die Schleife selbst ist `GymUebungGif` mit den Akku-Regeln (nicht bei Bewegung reduzieren und im Stromsparmodus: Standbild).
struct UebungLoveaGif: View {
    let id: String
    let name: String
    var koerper: String?
    @State private var fehlt = false
    @State private var geladen = false

    var body: some View {
        ZStack {
            Color.white
            if !UebungsKatalog.hatVideo(id) {
                Label("Kein Video für diese Übung", systemImage: "figure.strengthtraining.traditional")
                    .font(.footnote).foregroundStyle(Color.gray).padding()
            } else if fehlt {
                Label("Video lädt, sobald du Netz hast", systemImage: "wifi.slash")
                    .font(.footnote).foregroundStyle(Color.gray).padding()
            } else if geladen {
                GymUebungGif(id: id, koerper: koerper, weisserGrund: true)
            } else {
                ProgressView().tint(Color.gray)
            }
        }
        .aspectRatio(1.4, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Animation: \(name)")
        .task(id: id) {
            geladen = false
            fehlt = false
            guard UebungsKatalog.hatVideo(id) else { return }
            fehlt = await UebungsMedien.datei(id) == nil
            geladen = !fehlt
        }
    }
}
