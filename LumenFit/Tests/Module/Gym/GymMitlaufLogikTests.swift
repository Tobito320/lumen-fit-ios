import XCTest
@testable import LumenFit

/// Mitlauf: der letzte Satz einer Person, die gerade im Gym ist (nur mit Freigabe gym und verlauf).
final class GymMitlaufLogikTests: XCTestCase {
    private typealias T = CrewTestDaten

    private func satz(_ d: ZusammenfassungDatei) -> MitlaufSatz? { GymMitlaufLogik.letzterSatz(d, jetzt: T.jetzt) }

    private func lauf(_ uebungen: [(String, [PartnerSatzKurz])], geschrieben: Date = T.jetzt.addingTimeInterval(-60)) -> ZusammenfassungDatei {
        T.datei(freigaben: [.gym, .verlauf], geschrieben: geschrieben, verlauf: T.imGym(einheiten: [T.einheit(T.heute, uebungen)]))
    }

    func testLaeuftZeigtLetztenSatzDerLetztenUebung() {
        let d = lauf([("Kniebeuge", [T.satz(5, 1000)]), ("Bankdrücken", [T.satz(10, 600, "w"), T.satz(8, 800), T.satz(8, 800), T.satz(8, 825)])])
        XCTAssertEqual(satz(d), MitlaufSatz(uebung: "Bankdrücken", satzNr: 3, kg: 82.5, wdh: 8, vorSekunden: 60))
    }

    func testAufwaermsatzWirdUebersprungenUndNichtGezaehlt() {
        let d = lauf([("Rudern", [T.satz(10, 400, "w"), T.satz(10, 600), T.satz(12, 300, "w")])])
        XCTAssertEqual(satz(d)?.satzNr, 1)
        XCTAssertEqual(satz(d)?.kg, 60)
    }

    func testNurAufwaermsaetzeInDerLetztenUebungGibtDieVorherige() {
        let d = lauf([("Kniebeuge", [T.satz(5, 1000)]), ("Rudern", [T.satz(10, 400, "w")])])
        XCTAssertEqual(satz(d)?.uebung, "Kniebeuge")
    }

    func testLaeuftNicht() {
        let v = PartnerVerlauf(trainings: [])
        XCTAssertNil(satz(T.datei(freigaben: [.gym, .verlauf], verlauf: v)))
        var aus = T.imGym(einheiten: [T.einheit(T.heute, [("Rudern", [T.satz(10, 600)])])])
        aus.imGym = false
        XCTAssertNil(satz(T.datei(freigaben: [.gym, .verlauf], verlauf: aus)))
    }

    func testImGymZuAltGiltNichtMehr() {
        let v = T.imGym(seitMinuten: 4 * 60, einheiten: [T.einheit(T.heute, [("Rudern", [T.satz(10, 600)])])])
        XCTAssertNil(satz(T.datei(freigaben: [.gym, .verlauf], verlauf: v)))
    }

    func testOhneFreigabeGymUndVerlaufNichts() {
        let v = T.imGym(einheiten: [T.einheit(T.heute, [("Rudern", [T.satz(10, 600)])])])
        XCTAssertNil(satz(T.datei(freigaben: [.verlauf], verlauf: v)))
        XCTAssertNil(satz(T.datei(freigaben: [.gym], verlauf: v)))
        XCTAssertNil(satz(T.datei(freigaben: [.gym, .verlauf], verlauf: T.imGym(einheiten: nil))), "ältere App ohne Sätze")
    }

    func testNurEinheitVonHeuteZaehlt() {
        let gestern = Datum.addTage(T.heute, -1)
        XCTAssertNil(satz(T.datei(freigaben: [.gym, .verlauf], verlauf: T.imGym(einheiten: [T.einheit(gestern, [("Rudern", [T.satz(10, 600)])])]))))
        XCTAssertNil(satz(lauf([("Rudern", [])])), "heute, aber noch kein Satz")
    }

    func testOhneGewichtUndZehntelKg() {
        XCTAssertNil(satz(lauf([("Klimmzüge", [T.satz(8, nil)])]))?.kg)
        XCTAssertEqual(satz(lauf([("Curl", [T.satz(12, 125)])]))?.kg, 12.5)
    }

    func testVorSekundenKommtAusGeschrieben() {
        XCTAssertEqual(satz(lauf([("Curl", [T.satz(12, 125)])], geschrieben: T.jetzt.addingTimeInterval(-185)))?.vorSekunden, 185)
        XCTAssertEqual(satz(lauf([("Curl", [T.satz(12, 125)])], geschrieben: T.jetzt.addingTimeInterval(30)))?.vorSekunden, 0, "Uhr geht vor: nie negativ")
    }

    func testText() {
        func text(_ s: MitlaufSatz) -> String { GymMitlaufLogik.text(s) }
        XCTAssertEqual(text(MitlaufSatz(uebung: "Bankdrücken", satzNr: 3, kg: 80, wdh: 8, vorSekunden: 70)), "Bankdrücken · Satz 3 · 80 kg × 8 · vor 1 min")
        XCTAssertEqual(text(MitlaufSatz(uebung: "Curl", satzNr: 1, kg: 12.5, wdh: 12, vorSekunden: 20)), "Curl · Satz 1 · 12,5 kg × 12 · gerade eben")
        XCTAssertEqual(text(MitlaufSatz(uebung: "Klimmzüge", satzNr: 2, kg: nil, wdh: 8, vorSekunden: 600)), "Klimmzüge · Satz 2 · 8 Wdh · vor 10 min")
    }
}
