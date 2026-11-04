import SwiftUI
import UIKit

/// SF-Symbol je Körperteil: der Rückfall, wenn es kein Bild gibt (eigene Übungen, offline ohne Cache).
enum UebungsSymbol {
    static func name(koerper: String?) -> String {
        switch koerper {
        case "Cardio": "figure.run"
        case "Beine": "figure.strengthtraining.functional"
        case "Bauch": "figure.core.training"
        default: "figure.strengthtraining.traditional"
        }
    }

    /// "Face Pull, Schultern, Kabelzug" für VoiceOver, wenn ein Bild oder Symbol dasteht.
    static func beschreibung(_ u: Uebung) -> String { "\(u.name), \(u.muskel), \(u.geraet)" }
}

/// Das Bild einer Übung (Idee 26): einmal aus dem Netz geholt und im Cache gehalten (`UebungsMedien`), nur das erste Bild, keine
/// Dauer-Animation (Akku). Ohne Bild, offline oder bei eigenen Übungen steht ein Symbol da, nie ein leeres Feld.
struct UebungsBild: View {
    let id: String
    var koerper: String?
    @State private var bild: UIImage?
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        ZStack {
            palette.grund
            if let bild {
                // Die Bilder haben weißen Grund: hell mit multiply, dunkel invertiert (Farbton zurückgedreht) mit screen, sonst steht ein weißer Kasten auf der Seite.
                if schema == .dark {
                    Image(uiImage: bild).resizable().scaledToFit().colorInvert().hueRotation(.degrees(180)).blendMode(.screen)
                } else {
                    Image(uiImage: bild).resizable().scaledToFit().blendMode(.multiply)
                }
            } else {
                Image(systemName: UebungsSymbol.name(koerper: koerper))
                    .font(.title2)
                    .foregroundStyle(palette.text2)
            }
        }
        .clipShape(.rect(cornerRadius: Rundung.klein, style: .continuous))
        .task(id: id) { await lade() }
        .accessibilityHidden(true)
    }

    /// `UIImage(contentsOfFile:)` nimmt von einem GIF das erste Bild. Lesen und Dekodieren abseits des Hauptakteurs: in der Übungssuche
    /// lief sonst je Zeile ein Dateizugriff und ein GIF-Dekodieren auf dem Hauptthread (Ruckeln beim Scrollen).
    private func lade() async {
        bild = nil
        guard UebungsKatalog.hatVideo(id), let url = await UebungsMedien.datei(id) else { return }
        let geladen = await Task.detached(priority: .userInitiated) { UIImage(contentsOfFile: url.path)?.preparingForDisplay() }.value
        guard !Task.isCancelled else { return }
        bild = geladen
    }
}
