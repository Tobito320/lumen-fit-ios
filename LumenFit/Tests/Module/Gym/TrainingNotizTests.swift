import XCTest
@testable import LumenFit

/// Notiz je Training (Idee 28): beim Beenden mitgeschickt, später änderbar und löschbar, ohne Zeiten anzufassen; alte Einheiten ohne Notiz bleiben lesbar.
@MainActor
final class TrainingNotizTests: XCTestCase {
    private let uhr = TestUhr()

    private func satz(_ ordner: URL) -> DatenSatz {
        DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: uhr.uhr)
    }

    func testDieNotizBeimBeendenStehtAmTrainingUndUeberlebtDenNeustart() throws {
        let ordner = try tempOrdner()
        let erster = satz(ordner)
        let id = erster.training.einchecken(tag: nil)
        erster.training.auschecken(id, notiz: "  Schulter zwickt, nächstes Mal leichter  ")
        XCTAssertEqual(erster.training.sessions.first?.notiz, "Schulter zwickt, nächstes Mal leichter")
        XCTAssertNotNil(erster.training.sessions.first?.ende)
        XCTAssertEqual(satz(ordner).training.sessions.first?.notiz, "Schulter zwickt, nächstes Mal leichter")
    }

    func testEineSpaetereAenderungLaesstDieZeitenStehenUndLeerLoeschtDieNotiz() throws {
        let satz = satz(try tempOrdner())
        let id = satz.training.einchecken(tag: nil)
        satz.training.auschecken(id, notiz: "alt")
        let vorher = try XCTUnwrap(satz.training.sessions.first)

        uhr.vor(sekunden: 60) // zwei Ops mit gleicher Zeit hätten keine feste Reihenfolge; im echten Gebrauch liegt immer Zeit dazwischen
        satz.training.notizAendern(vorher, "neu")
        let danach = try XCTUnwrap(satz.training.sessions.first)
        XCTAssertEqual(danach.notiz, "neu")
        XCTAssertEqual(danach.start, vorher.start)
        XCTAssertEqual(danach.ende, vorher.ende, "ein Checkout nur mit Notiz ändert keine Zeit")

        uhr.vor(sekunden: 60)
        satz.training.notizAendern(danach, "   ")
        XCTAssertNil(satz.training.sessions.first?.notiz, "leer löscht")
    }

    func testOhneNotizUndMitAltenOpsBleibtAllesWieEs() throws {
        let satz = satz(try tempOrdner())
        for op in TestDaten.gymOps(von: .testA, start: uhr.lesen) { satz.raum.einreihen(op) }
        XCTAssertNil(satz.training.sessions.first?.notiz)
        XCTAssertNotNil(satz.training.sessions.first?.ende)
    }

    func testDieNotizWirdBereinigtUndGekuerzt() {
        XCTAssertNil(TrainingLogik.notiz(nil))
        XCTAssertNil(TrainingLogik.notiz(" \n "))
        XCTAssertEqual(TrainingLogik.notiz(" ok "), "ok")
        XCTAssertEqual(TrainingLogik.notiz(String(repeating: "a", count: 900))?.count, 500)
    }
}
