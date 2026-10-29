import XCTest
@testable import LumenFit

final class PasswortTests: XCTestCase {
    private func hex(_ daten: Data) -> String { daten.map { String(format: "%02x", $0) }.joined() }

    /// Bekannte Werte für PBKDF2-HMAC-SHA256 (Passwort "password", Salz "salt", 32 Byte).
    func testPBKDF2MitBekanntenTestvektoren() {
        let salz = Data("salt".utf8)
        XCTAssertEqual(hex(Passwort.hash("password", salz: salz, runden: 1)), "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
        XCTAssertEqual(hex(Passwort.hash("password", salz: salz, runden: 2)), "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43")
        XCTAssertEqual(hex(Passwort.hash("password", salz: salz, runden: 4096)), "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
    }

    func testRichtigesPasswortStimmtFalschesNicht() {
        let spur = Passwort.spur(fuer: "geheim-1234", runden: 1_000)
        XCTAssertTrue(Passwort.stimmt("geheim-1234", mit: spur))
        XCTAssertFalse(Passwort.stimmt("geheim-1235", mit: spur))
        XCTAssertFalse(Passwort.stimmt("", mit: spur))
        XCTAssertEqual(spur.runden, 1_000)
        XCTAssertEqual(spur.hash.count, 32)
        XCTAssertEqual(spur.salz.count, 16)
    }

    func testJedeSpurHatEigenesSalzUndDasPasswortStehtNichtDrin() {
        let a = Passwort.spur(fuer: "gleich", runden: 10)
        let b = Passwort.spur(fuer: "gleich", runden: 10)
        XCTAssertNotEqual(a.salz, b.salz)
        XCTAssertNotEqual(a.hash, b.hash)
        XCTAssertFalse(a.hash.elementsEqual(Data("gleich".utf8)))
    }

    func testSpurUeberlebtCodableUndBleibtPruefbar() throws {
        let spur = Passwort.spur(fuer: "abcd", runden: 500)
        let wieder = try JSONDecoder().decode(PasswortSpur.self, from: JSONEncoder().encode(spur))
        XCTAssertEqual(wieder, spur)
        XCTAssertTrue(Passwort.stimmt("abcd", mit: wieder))
    }

    func testVergleichInKonstanterZeitBehandeltLaengenUndLeereWerte() {
        XCTAssertTrue(Passwort.gleich(Data([1, 2, 3]), Data([1, 2, 3])))
        XCTAssertFalse(Passwort.gleich(Data([1, 2, 3]), Data([1, 2, 4])))
        XCTAssertFalse(Passwort.gleich(Data([1, 2, 3]), Data([1, 2])))
        XCTAssertFalse(Passwort.gleich(Data(), Data()), "ein leerer Hash stimmt nie")
    }

    func testStandardwerte() {
        XCTAssertEqual(Passwort.standardRunden, 600_000)
        XCTAssertEqual(Passwort.mindestLaenge, 4)
    }
}
