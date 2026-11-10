import XCTest
@testable import LumenFit

final class LumiPoseTests: XCTestCase {
    func testVierzehnZustaendeUndDieAltenRohwerteBleiben() {
        XCTAssertEqual(LumiZustand.allCases.count, 14)
        let roh = Set(LumiZustand.allCases.map(\.rawValue))
        XCTAssertTrue(["bereit", "muede", "stolz", "schlaeft", "denkt"].allSatisfy(roh.contains), "gespeicherte Werte bleiben lesbar")
    }

    func testJederZustandHatGesichtTextUndSatz() {
        for z in LumiZustand.allCases {
            XCTAssertFalse(LumiPose.fuer(z).gesicht.isEmpty, z.rawValue)
            XCTAssertFalse(z.titel.isEmpty, z.rawValue)
            XCTAssertTrue(z.satz.hasSuffix(".") || z.satz.hasSuffix("!") || z.satz.hasSuffix("?"), z.rawValue)
            XCTAssertTrue(z.beschreibung.hasPrefix("Lumi "), z.rawValue)
        }
    }

    func testNurFreudeZustaendeFeiern() {
        XCTAssertEqual(Set(LumiZustand.allCases.filter { LumiPose.fuer($0).feiert }), [.willkommen, .stolz, .ziel, .serie])
    }

    func testAlleTeileLiegenImRahmen() {
        for z in LumiZustand.allCases {
            let pose = LumiPose.fuer(z)
            for t in pose.hinten + pose.gesicht + pose.vorn {
                guard let (x, y) = punkt(t) else { continue }
                XCTAssertTrue((0...100).contains(x) && (0...104).contains(y), "\(z.rawValue): \(t)")
            }
        }
    }

    func testKleinBleibenGesichtBandUndHauptrequisit() {
        let klein = LumiPose.fuer(.stolz).vorn.filter { !$0.istDeko }
        XCTAssertEqual(klein.count, 2, "die Arme bleiben, die Sterne fallen weg")
        XCTAssertTrue(LumiPose.fuer(.bereit).vorn.allSatisfy { !$0.istDeko }, "die Hantel bleibt")
    }

    func testNurErschoepftUndMuedeSindBlasser() {
        let gold = LumiZustand.bereit.farbsatz.verlauf
        for z in LumiZustand.allCases {
            XCTAssertEqual(z.farbsatz.verlauf == gold, ![.erschoepft, .muede].contains(z), z.rawValue)
        }
    }

    private func punkt(_ t: LumiTeil) -> (Double, Double)? {
        switch t {
        case let .arm(x, y, _, _, _), let .faust(x, y), let .kurzhantel(x, y, _), let .flasche(x, y, _), let .tasse(x, y), let .haken(x, y),
             let .flamme(x, y), let .pflaster(x, y, _), let .tropfen(x, y, _), let .zz(x, y, _), let .stern(x, y, _, _), let .blitz(x, y):
            (x, y)
        case let .langhantel(y): (50, y)
        default: nil
        }
    }
}
