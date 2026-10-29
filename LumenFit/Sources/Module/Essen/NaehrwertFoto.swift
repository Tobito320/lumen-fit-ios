// Quelle: Lovea Health/Ernaehrung/NaehrwertFoto.swift (Leser; Foto-Blatt und Kamera sind neu: NaehrwertFotoView)
import CoreGraphics
import Foundation
import ImageIO
import UIKit
import Vision

/// Liest eine Nährwert-Tabelle vom Foto (Vision auf dem Gerät, kein KI-Dienst). Erste Zahl je Zeile = pro 100 g.
enum NaehrwertLeser {
    static func parsen(_ zeilen: [String]) -> Naehrwerte? {
        func zahl(_ s: Substring) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }
        func ersteZahl(_ s: String, vor einheit: String? = nil) -> Double? {
            let re = einheit.map { "([0-9]+(?:[.,][0-9]+)?)\\s*\($0)" } ?? "([0-9]+(?:[.,][0-9]+)?)"
            guard let r = s.range(of: re, options: [.regularExpression, .caseInsensitive]) else { return nil }
            let treffer = s[r]
            guard let zr = treffer.range(of: "[0-9]+(?:[.,][0-9]+)?", options: .regularExpression) else { return nil }
            return zahl(treffer[zr])
        }
        let klein = zeilen.map { $0.lowercased() }
        func wert(_ woerter: [String], ohne: [String] = []) -> Double? {
            for (i, z) in klein.enumerated() where woerter.contains(where: z.contains) && !ohne.contains(where: z.contains) {
                if let x = ersteZahl(z, vor: "g") ?? ersteZahl(z) { return x }
                if i + 1 < klein.count, let x = ersteZahl(klein[i + 1]) { return x }
            }
            return nil
        }
        var kcal: Double?
        for (i, z) in klein.enumerated() {
            if let x = ersteZahl(z, vor: "kcal") { kcal = x; break }
            if i + 1 < klein.count, z.contains("energie") || z.contains("brennwert"), let x = ersteZahl(klein[i + 1], vor: "kcal") { kcal = x; break }
        }
        if kcal == nil, let kj = klein.lazy.compactMap({ ersteZahl($0, vor: "kj") }).first { kcal = kj / 4.184 }
        guard let kcal else { return nil }
        return Naehrwerte(kcal: kcal,
                          protein: wert(["eiweiß", "eiweiss", "protein"]) ?? 0,
                          kohlenhydrate: wert(["kohlenhydrat"]) ?? 0,
                          fett: wert(["fett"], ohne: ["gesättigt", "gesaettigt", "fettsäuren"]) ?? 0,
                          zucker: wert(["zucker"]),
                          ballaststoffe: wert(["ballaststoff"]),
                          salz: wert(["salz"]),
                          gesFett: wert(["gesättigt", "gesaettigt"]))
    }

    /// Texterkennung auf dem Gerät (Vision, kein Server): jede erkannte Zeile. Läuft nicht auf dem Hauptakteur.
    static func erkennen(bildDaten: Data) async -> [String] {
        guard let bild = UIImage(data: bildDaten), let cg = bild.cgImage else { return [] }
        let anfrage = VNRecognizeTextRequest()
        anfrage.recognitionLevel = .accurate
        anfrage.recognitionLanguages = ["de-DE"]
        anfrage.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cg, orientation: ausrichtung(bild.imageOrientation), options: [:])
        do { try handler.perform([anfrage]) } catch { return [] }
        return (anfrage.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    /// Kamerafotos sind oft gedreht gespeichert; Vision muss die Drehung kennen.
    static func ausrichtung(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
