// Quelle: Lovea Health/Tests/EssenBildTests.swift (neu für Lumen)
import ImageIO
import UIKit
import XCTest
@testable import LumenFit

final class EssenKiBildTests: XCTestCase {
    private func jpeg(breite: Int, hoehe: Int) throws -> Data {
        let bild = UIGraphicsImageRenderer(size: CGSize(width: breite, height: hoehe)).image { c in
            UIColor.green.setFill()
            c.fill(CGRect(x: 0, y: 0, width: breite, height: hoehe))
        }
        return try XCTUnwrap(bild.jpegData(compressionQuality: 0.9))
    }

    private func groesse(_ daten: Data) throws -> (b: Int, h: Int) {
        let quelle = try XCTUnwrap(CGImageSourceCreateWithData(daten as CFData, nil))
        let eig = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any])
        return (eig[kCGImagePropertyPixelWidth] as? Int ?? 0, eig[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    func testGrossesBildWirdAufLaengsteKanteBegrenzt() throws {
        let klein = try XCTUnwrap(EssenKiBild.verkleinern(try jpeg(breite: 3000, hoehe: 2000)))
        let g = try groesse(klein)
        XCTAssertEqual(max(g.b, g.h), 1024)
        XCTAssertLessThan(g.h, g.b, "Seitenverhältnis bleibt")
    }

    func testEigeneMaxKante() throws {
        let klein = try XCTUnwrap(EssenKiBild.verkleinern(try jpeg(breite: 1500, hoehe: 1000), maxKante: 640))
        XCTAssertEqual(max(try groesse(klein).b, try groesse(klein).h), 640)
    }

    func testKeinBildGibtNil() {
        XCTAssertNil(EssenKiBild.verkleinern(Data("kein bild".utf8)))
        XCTAssertNil(EssenKiBild.verkleinern(Data()))
    }
}
