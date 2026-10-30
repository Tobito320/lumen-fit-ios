import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import LumenFit

/// Die Wiedergabe-Entscheidung der Übungs-Schleife (spielt oder steht) und die Dekodierung einer GIF-Folge.
@MainActor
final class GymGifTests: XCTestCase {
    // MARK: Entscheidung

    private func spielt(hatFolge: Bool = true, sichtbar: Bool = true, vorn: Bool = true, reduziert: Bool = false, spar: Bool = false, angehalten: Bool = false) -> Bool {
        GymGifLogik.spielt(hatFolge: hatFolge, sichtbar: sichtbar, imVordergrund: vorn, reduzierteBewegung: reduziert, stromsparmodus: spar, angehalten: angehalten)
    }

    func testSpieltNurWennAllesStimmt() {
        XCTAssertTrue(spielt())
    }

    func testStehtOhneFolge() { XCTAssertFalse(spielt(hatFolge: false)) }
    func testStehtWennNichtSichtbar() { XCTAssertFalse(spielt(sichtbar: false)) }
    func testStehtImHintergrund() { XCTAssertFalse(spielt(vorn: false)) }
    func testStehtBeiReduceMotion() { XCTAssertFalse(spielt(reduziert: true)) }
    func testStehtImStromsparmodus() { XCTAssertFalse(spielt(spar: true)) }
    func testStehtWennAngehalten() { XCTAssertFalse(spielt(angehalten: true)) }

    func testAlleKombinationenSpielenNurEinmal() {
        var spielende = 0
        for bits in 0..<64 {
            let b = (0..<6).map { bits & (1 << $0) != 0 }
            if spielt(hatFolge: b[0], sichtbar: b[1], vorn: b[2], reduziert: b[3], spar: b[4], angehalten: b[5]) { spielende += 1 }
        }
        XCTAssertEqual(spielende, 1)
    }

    func testDekodierenNurOhneReduceMotionUndStromsparmodus() {
        XCTAssertTrue(GymGifLogik.darfAbspielen(reduzierteBewegung: false, stromsparmodus: false))
        XCTAssertFalse(GymGifLogik.darfAbspielen(reduzierteBewegung: true, stromsparmodus: false))
        XCTAssertFalse(GymGifLogik.darfAbspielen(reduzierteBewegung: false, stromsparmodus: true))
        XCTAssertFalse(GymGifLogik.darfAbspielen(reduzierteBewegung: true, stromsparmodus: true))
    }

    // MARK: Verzögerung

    func testVerzoegerungNimmtUngeklemmteZuerst() {
        XCTAssertEqual(GymGifLogik.verzoegerung(unbegrenzt: 0.05, begrenzt: 0.1), 0.05, accuracy: 0.0001)
    }

    func testVerzoegerungFaelltAufGeklemmteZurueck() {
        XCTAssertEqual(GymGifLogik.verzoegerung(unbegrenzt: nil, begrenzt: 0.07), 0.07, accuracy: 0.0001)
        XCTAssertEqual(GymGifLogik.verzoegerung(unbegrenzt: 0, begrenzt: 0.07), 0.07, accuracy: 0.0001)
    }

    func testZuKurzeOderFehlendeVerzoegerungWirdZehntelsekunde() {
        XCTAssertEqual(GymGifLogik.verzoegerung(unbegrenzt: 0.01, begrenzt: nil), 0.1, accuracy: 0.0001)
        XCTAssertEqual(GymGifLogik.verzoegerung(unbegrenzt: nil, begrenzt: nil), 0.1, accuracy: 0.0001)
        XCTAssertEqual(GymGifLogik.verzoegerung(unbegrenzt: nil, begrenzt: 0.02), 0.02, accuracy: 0.0001)
    }

    // MARK: Dekodieren

    private func gif(bilder: Int, verzoegerung: Double) -> Data? {
        let daten = NSMutableData()
        guard let ziel = CGImageDestinationCreateWithData(daten, UTType.gif.identifier as CFString, bilder, nil) else { return nil }
        CGImageDestinationSetProperties(ziel, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        for i in 0..<bilder {
            let bild = renderer.image { ctx in
                UIColor(white: CGFloat(i % 2), alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
            guard let cg = bild.cgImage else { return nil }
            CGImageDestinationAddImage(ziel, cg, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: verzoegerung]] as CFDictionary)
        }
        return CGImageDestinationFinalize(ziel) ? daten as Data : nil
    }

    func testDekodiertEineFolgeMitBilderzahlUndDauer() throws {
        let daten = try XCTUnwrap(gif(bilder: 3, verzoegerung: 0.04))
        let folge = try XCTUnwrap(GymGifLogik.dekodiere(daten))
        XCTAssertEqual(folge.bilder.count, 3)
        XCTAssertEqual(folge.dauer, 0.12, accuracy: 0.001)
    }

    func testEinzelbildUndMuellGebenKeineFolge() throws {
        XCTAssertNil(GymGifLogik.dekodiere(try XCTUnwrap(gif(bilder: 1, verzoegerung: 0.04))))
        XCTAssertNil(GymGifLogik.dekodiere(Data("kein bild".utf8)))
        XCTAssertNil(GymGifLogik.dekodiere(Data()))
    }

    func testZuLangeFolgeBleibtStandbild() throws {
        let daten = try XCTUnwrap(gif(bilder: GymGifLogik.maxBilder + 1, verzoegerung: 0.04))
        XCTAssertNil(GymGifLogik.dekodiere(daten))
        let genau = try XCTUnwrap(gif(bilder: GymGifLogik.maxBilder, verzoegerung: 0.04))
        XCTAssertEqual(GymGifLogik.dekodiere(genau)?.bilder.count, GymGifLogik.maxBilder)
    }
}
