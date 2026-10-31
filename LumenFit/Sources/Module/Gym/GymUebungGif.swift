// Quelle: Lovea Health/WorkoutView.swift (`UebungDetail` mit `UebungGif`), Lovea Chat/Medien/AnimiertesGif.swift (Idee des Spielers; hier mit Halte-Regeln für den Akku)
import ImageIO
import SwiftUI
import UIKit

/// Alle Bilder einer Übungs-GIF und die Dauer eines Durchlaufs. Nur im Speicher, solange die Detailansicht offen ist.
struct GymGifFolge: Sendable {
    let bilder: [UIImage]
    let dauer: TimeInterval
}

/// Regeln und Dekodierung des Übungs-GIFs. Die GIF-Datei kommt aus dem Cache von `UebungsMedien` (SPEC Annahme 14: geladen, nie gebündelt);
/// hier wird nichts Neues bezogen.
enum GymGifLogik {
    /// Längere Folgen bleiben ein Standbild (Speicher: alle Bilder liegen dekodiert im Speicher).
    nonisolated static let maxBilder = 150
    /// Vom Browser-Brauch übernommen: Verzögerungen unter 20 ms zählen als 100 ms.
    nonisolated static let kleinsteVerzoegerung = 0.02
    nonisolated static let ersatzVerzoegerung = 0.1

    /// Soll die Folge überhaupt dekodiert werden? Bei "Bewegung reduzieren" und im Stromsparmodus bleibt es beim Standbild.
    static func darfAbspielen(reduzierteBewegung: Bool, stromsparmodus: Bool) -> Bool {
        !reduzierteBewegung && !stromsparmodus
    }

    /// Läuft die Schleife gerade? Nur mit Folge, sichtbarer Ansicht, App im Vordergrund, ohne Reduce Motion, ohne Stromsparmodus und nicht angehalten.
    static func spielt(hatFolge: Bool, sichtbar: Bool, imVordergrund: Bool, reduzierteBewegung: Bool, stromsparmodus: Bool, angehalten: Bool) -> Bool {
        hatFolge && sichtbar && imVordergrund && !angehalten && darfAbspielen(reduzierteBewegung: reduzierteBewegung, stromsparmodus: stromsparmodus)
    }

    /// Die Anzeigedauer eines Bildes: die ungeklemmte Zeit, sonst die geklemmte, unter 20 ms oder ohne Angabe 100 ms.
    static func verzoegerung(unbegrenzt: Double?, begrenzt: Double?) -> Double {
        let roh = unbegrenzt.flatMap { $0 > 0 ? $0 : nil } ?? begrenzt ?? 0
        return roh < kleinsteVerzoegerung ? ersatzVerzoegerung : roh
    }

    /// nil = keine Folge (kein GIF, nur ein Bild, zu viele Bilder, kaputt): dann bleibt das Standbild.
    static func dekodiere(_ daten: Data) -> GymGifFolge? {
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil) else { return nil }
        let anzahl = CGImageSourceGetCount(quelle)
        guard anzahl > 1, anzahl <= maxBilder else { return nil }
        var bilder: [UIImage] = []
        var dauer = 0.0
        for i in 0..<anzahl {
            guard let bild = CGImageSourceCreateImageAtIndex(quelle, i, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
            bilder.append(UIImage(cgImage: bild))
            let eigenschaften = CGImageSourceCopyPropertiesAtIndex(quelle, i, nil) as? [CFString: Any]
            let gif = eigenschaften?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            dauer += verzoegerung(unbegrenzt: gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double, begrenzt: gif?[kCGImagePropertyGIFDelayTime] as? Double)
        }
        return GymGifFolge(bilder: bilder, dauer: dauer)
    }
}

/// Das Bild einer Übung in der Detailansicht: eine Schleife der GIF-Bilder, wo sie erlaubt ist, sonst das Standbild (`UebungsBild`).
/// Kein Timer von uns: die Schleife läuft in `UIImageView` und steht, sobald die Ansicht verschwindet, aus dem Bild gescrollt ist,
/// die App nicht mehr vorn ist oder die Person sie anhält. Ein Tipp hält an und startet wieder.
struct GymUebungGif: View {
    let id: String
    var koerper: String?
    /// Lovea-Aufbau: weiße Kachel wie in Lovea (`UebungGif`), ohne Anpassung an Hell und Dunkel.
    var weisserGrund = false
    @State private var folge: GymGifFolge?
    @State private var erschienen = false
    @State private var imBild = true
    @State private var angehalten = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduziert
    @Environment(\.stromsparmodus) private var stromsparmodus
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    private struct Schluessel: Hashable {
        let id: String
        let erlaubt: Bool
    }

    private var erlaubt: Bool { GymGifLogik.darfAbspielen(reduzierteBewegung: reduziert, stromsparmodus: stromsparmodus) }

    private var spielt: Bool {
        GymGifLogik.spielt(hatFolge: folge != nil, sichtbar: erschienen && imBild, imVordergrund: phase == .active,
                           reduzierteBewegung: reduziert, stromsparmodus: stromsparmodus, angehalten: angehalten)
    }

    var body: some View {
        ZStack {
            if let folge {
                Button { angehalten.toggle() } label: {
                    ZStack {
                        if weisserGrund { Color.white } else { palette.grund }
                        // Wie das Standbild: die Bilder haben weißen Grund, hell mit multiply, dunkel invertiert mit screen.
                        if weisserGrund {
                            GymGifAnsicht(folge: folge, spielt: spielt)
                        } else if schema == .dark {
                            GymGifAnsicht(folge: folge, spielt: spielt).colorInvert().hueRotation(.degrees(180)).blendMode(.screen)
                        } else {
                            GymGifAnsicht(folge: folge, spielt: spielt).blendMode(.multiply)
                        }
                    }
                    .clipShape(.rect(cornerRadius: Rundung.klein, style: .continuous))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(angehalten ? "Animation abspielen" : "Animation anhalten")
                .accessibilityHint("Zeigt die Bewegung der Übung")
            } else {
                UebungsBild(id: id, koerper: koerper)
            }
        }
        .onAppear { erschienen = true }
        .onDisappear { erschienen = false }
        .onScrollVisibilityChange(threshold: 0.2) { imBild = $0 }
        .task(id: Schluessel(id: id, erlaubt: erlaubt)) { await lade() }
    }

    private func lade() async {
        folge = nil
        guard erlaubt, UebungsKatalog.hatVideo(id), let url = await UebungsMedien.datei(id) else { return }
        let geladen = await Task.detached(priority: .userInitiated) { () -> GymGifFolge? in
            guard let daten = try? Data(contentsOf: url) else { return nil }
            return GymGifLogik.dekodiere(daten)
        }.value
        guard !Task.isCancelled else { return }
        folge = geladen
    }
}

/// `UIImageView` mit `animationImages`; Start und Stopp nur über `spielt`.
private struct GymGifAnsicht: UIViewRepresentable {
    let folge: GymGifFolge
    let spielt: Bool

    func makeUIView(context: Context) -> UIImageView {
        let ansicht = UIImageView(image: folge.bilder.first)
        ansicht.contentMode = .scaleAspectFit
        ansicht.clipsToBounds = true
        ansicht.animationImages = folge.bilder
        ansicht.animationDuration = folge.dauer
        ansicht.setContentHuggingPriority(.defaultLow, for: .horizontal)
        ansicht.setContentHuggingPriority(.defaultLow, for: .vertical)
        ansicht.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        ansicht.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return ansicht
    }

    func updateUIView(_ ansicht: UIImageView, context: Context) {
        if spielt {
            if !ansicht.isAnimating { ansicht.startAnimating() }
        } else if ansicht.isAnimating {
            ansicht.stopAnimating()
        }
    }

    static func dismantleUIView(_ ansicht: UIImageView, coordinator: ()) {
        ansicht.stopAnimating()
        ansicht.animationImages = nil
    }

    /// Ein bloßes `UIImageView` meldet die Pixelgröße des GIFs; SwiftUI soll aber die angebotene Größe nehmen.
    func sizeThatFits(_ vorschlag: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        let bild = folge.bilder.first?.size ?? CGSize(width: 1, height: 1)
        let breite = vorschlag.width.flatMap { $0.isFinite ? $0 : nil } ?? bild.width
        let hoehe = vorschlag.height.flatMap { $0.isFinite ? $0 : nil } ?? bild.height
        return CGSize(width: breite, height: hoehe)
    }
}
