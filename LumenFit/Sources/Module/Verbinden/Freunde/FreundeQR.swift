import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// QR-Code erzeugen (CoreImage) und aus einem Foto lesen (Vision). Der QR trägt den Link `lumenfit://freund?d=...`: die Kamera-App öffnet damit Lumen Fit.
enum FreundeQR {
    /// Das Bild des QR-Codes, scharf vergrößert (ganzzahlig, ohne Glättung). `nil`, wenn CoreImage versagt.
    static func bild(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let klein = filter.outputImage else { return nil }
        let gross = klein.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = CIContext().createCGImage(gross, from: gross.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Der Text des ersten QR-Codes im Bild, sonst `nil`.
    static func text(in bild: UIImage) -> String? {
        guard let cg = bild.cgImage else { return nil }
        let anfrage = VNDetectBarcodesRequest()
        anfrage.symbologies = [.qr]
        try? VNImageRequestHandler(cgImage: cg).perform([anfrage])
        return anfrage.results?.compactMap(\.payloadStringValue).first
    }
}
