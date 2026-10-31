// Quelle: Lovea Health/Tests/CoachMarkerTests.swift
import XCTest
@testable import LumenFit

/// Health-Coach: Marker am Ende der Antwort trennen und prüfen (`CoachMarker.swift`). Reine Logik.
/// Übernommen sind die Fälle für `weiter`, `gehe` und `merke` samt Grenzfällen; Wecker, Erinnerung, Termin, Tracking und Training
/// gibt es in Lumen Fit nicht: ihre Marker verschwinden wie jeder unbekannte Marker (die gültigen Wecker-Marker prüft `CoachWeckerTests`).
final class CoachMarkerTests: XCTestCase {

    private func zerlegt(_ roh: String) -> CoachMarker.Zerlegt { CoachMarker.zerlegen(roh) }

    // MARK: - Text

    func testTextOhneMarkerBleibtGleich() {
        XCTAssertEqual(zerlegt("Hallo du"), CoachMarker.Zerlegt(text: "Hallo du", marker: []))
    }

    func testMarkerAmEndeWerdenAbgeschnitten() {
        let z = zerlegt("Dein Tag war gut.\n[[weiter: Wie war mein Schlaf? | Was esse ich heute? | Training morgen?]]")
        XCTAssertEqual(z.text, "Dein Tag war gut.")
        XCTAssertEqual(z.folgefragen, ["Wie war mein Schlaf?", "Was esse ich heute?", "Training morgen?"])
    }

    func testDoppelteEckigeKlammernOhneMarkerBleibenText() {
        XCTAssertEqual(zerlegt("Siehe [[1]] und [[2]]").text, "Siehe [[1]] und [[2]]")
        XCTAssertEqual(zerlegt("Um [[10:30 Uhr]] los").text, "Um [[10:30 Uhr]] los")
    }

    func testUnbekannterMarkerVerschwindet() {
        let z = zerlegt("Text [[foo: bar]] weiter")
        XCTAssertEqual(z.text, "Text  weiter")
        XCTAssertTrue(z.marker.isEmpty)
    }

    func testAbgeschnittenerMarkerVerschwindet() {
        XCTAssertEqual(zerlegt("Gut gemacht.\n[[weiter: Wie war | Was es").text, "Gut gemacht.")
        XCTAssertEqual(zerlegt("Gut.\n[[wei").text, "Gut.")
    }

    func testHoechstensVierMarker() {
        let roh = "[[gehe: schritte]][[gehe: training]][[gehe: gewicht]][[gehe: verlauf]][[gehe: schritte]]"
        let z = zerlegt(roh)
        XCTAssertEqual(z.text, "")
        XCTAssertEqual(z.wege.map { $0.ziel }, [.schritte, .training, .gewicht, .verlauf])
    }

    // MARK: - weiter

    func testWeiterNimmtHoechstensDreiUndKeineLeeren() {
        let z = zerlegt("[[weiter: A? |  | B? | C? | D?]]")
        XCTAssertEqual(z.folgefragen, ["A?", "B?", "C?"])
    }

    func testWeiterOhneFragenIstKeinMarker() {
        XCTAssertTrue(zerlegt("[[weiter: | ]]").marker.isEmpty)
    }

    // MARK: - gehe

    func testGeheMitUndOhneBeschriftung() {
        let z = zerlegt("[[gehe: schritte | Schritte öffnen]][[gehe: Training]]")
        XCTAssertEqual(z.wege.map { $0.ziel }, [.schritte, .training])
        XCTAssertEqual(z.wege.map { $0.beschriftung }, ["Schritte öffnen", "Training öffnen"])
    }

    func testGeheKuerztDieBeschriftungAuf24Zeichen() {
        let z = zerlegt("[[gehe: gewicht | 12345678901234567890123456789]]")
        XCTAssertEqual(z.wege.first?.beschriftung, "123456789012345678901234")
    }

    func testGeheMitUnbekanntemZielFaelltWeg() {
        XCTAssertTrue(zerlegt("[[gehe: konto | Konto]]").marker.isEmpty)
        XCTAssertTrue(zerlegt("[[gehe: ]]").marker.isEmpty)
    }

    func testGeheZieleSindEchteRouten() {
        XCTAssertEqual(CoachMarker.Ziel.schritte.route, .heute)
        XCTAssertEqual(CoachMarker.Ziel.training.route, .gym(.training))
        XCTAssertEqual(CoachMarker.Ziel.gewicht.route, .gewichtEintragen)
        XCTAssertEqual(CoachMarker.Ziel.verlauf.route, .verlauf)
        XCTAssertEqual(CoachMarker.Ziel.schlaf.route, .schlaf(.letzteNacht))
        XCTAssertEqual(CoachMarker.Ziel.essen.route, .essen(.heute))
    }

    // MARK: - merke

    func testMerkeNimmtDenGanzenTextAuchMitStrich() {
        XCTAssertEqual(zerlegt("[[merke: Isst kein Schwein | mag Hähnchen]]").marker, [.merke("Isst kein Schwein | mag Hähnchen")])
        XCTAssertEqual(zerlegt("Gut. [[merke:   Trainiert Mo, Mi, Fr  ]]").marker, [.merke("Trainiert Mo, Mi, Fr")])
    }

    func testMerkeLaengeDreiBisZweihundert() {
        XCTAssertTrue(zerlegt("[[merke: ab]]").marker.isEmpty)
        XCTAssertEqual(zerlegt("[[merke: abc]]").marker, [.merke("abc")])
        let genau = String(repeating: "x", count: 200)
        XCTAssertEqual(zerlegt("[[merke: \(genau)]]").marker, [.merke(genau)])
        XCTAssertTrue(zerlegt("[[merke: \(genau)y]]").marker.isEmpty)
        XCTAssertTrue(zerlegt("[[merke:]]").marker.isEmpty)
    }

    func testMerkeMitKlammernOderZeilenumbruchVerschwindet() {
        XCTAssertTrue(zerlegt("[[merke: a [[b]] c]]").marker.isEmpty)
        XCTAssertTrue(zerlegt("[[merke: zwei\nZeilen]]").marker.isEmpty)
    }

    func testMarkerZaehlenZumLimitVonVierUndKaputteNicht() {
        let z = zerlegt("[[merke: ab]][[merke: Mag Fisch]][[merke: Mag Reis]][[merke: Mag Eier]][[merke: Mag Quark]][[merke: Fünfter Eintrag]]")
        XCTAssertEqual(z.marker.count, 4)
        XCTAssertEqual(z.merkeTexte, ["Mag Fisch", "Mag Reis", "Mag Eier", "Mag Quark"])
    }

    func testHalberMerkeMarkerAmEndeVerschwindet() {
        XCTAssertEqual(zerlegt("Notiert.\n[[merke: Mag Hähn").text, "Notiert.")
        XCTAssertEqual(zerlegt("Notiert.\n[[vergiss").text, "Notiert.")
    }

    func testMarkerInDerMitteLassenKeinenRestStehen() {
        let z = zerlegt("Ich merke es mir [[merke: Wiegt morgens]] fertig.")
        XCTAssertEqual(z.text, "Ich merke es mir  fertig.")
        XCTAssertEqual(z.marker, [.merke("Wiegt morgens")])
    }

    // MARK: - Neu für Lumen Fit: gewohnheit und plan

    func testGewohnheitMarker() {
        XCTAssertEqual(zerlegt("Gut. [[gewohnheit: Früher ins Bett]]").marker, [.gewohnheit(name: "Früher ins Bett")])
        XCTAssertTrue(zerlegt("[[gewohnheit: x]]").marker.isEmpty, "mindestens zwei Zeichen")
        XCTAssertTrue(zerlegt("[[gewohnheit: \(String(repeating: "a", count: 41))]]").marker.isEmpty, "höchstens 40 Zeichen")
        XCTAssertTrue(zerlegt("[[gewohnheit: zwei\nZeilen]]").marker.isEmpty)
    }

    func testPlanMarker() {
        XCTAssertEqual(zerlegt("[[plan: morgen leicht]]").marker, [.planMorgenLeicht])
        XCTAssertEqual(zerlegt("[[plan: morgen_leicht]]").marker, [.planMorgenLeicht])
        XCTAssertTrue(zerlegt("[[plan: alles streichen]]").marker.isEmpty)
    }

    func testMarkerWerdenZuChipsMitHandlung() {
        let z = zerlegt("[[weiter: Und mein Schlaf?]][[gehe: schlaf | Schlaf öffnen]][[gewohnheit: Früher ins Bett]][[plan: morgen leicht]]")
        XCTAssertEqual(z.chips.map(\.aktion), [.antworten("Und mein Schlaf?"), .oeffne(.schlaf(.letzteNacht)), .gewohnheitAnlegen(name: "Früher ins Bett"), .planMorgenLeicht])
        XCTAssertEqual(z.chips.map(\.text), ["Und mein Schlaf?", "Schlaf öffnen", "Mach ich", "Morgen leicht"])
        XCTAssertEqual(Set(z.chips.map(\.id)).count, 4, "Ids sind eindeutig")
    }

    // MARK: - Umfang: keine Kalender, kaputte Wecker-Marker

    func testWeckerErinnerungTerminUndErinnernVerschwinden() {
        for roh in ["[[wecker: 2026-10-08 | 07:30]]", "[[erinnerung: 07:30 | Wasser trinken]]", "[[termin: 2026-10-08 | 10:00 | 11:00 | Zahnarzt]]",
                    "[[erinnern: neu | 7:3 | x]]", "[[wecker: neu | 25:00 | einmalig]]"] {
            let z = zerlegt("Okay. \(roh)")
            XCTAssertEqual(z.text, "Okay.", roh)
            XCTAssertTrue(z.marker.isEmpty, roh)
        }
    }

    /// Früher verschwanden die Eintrags- und Training-Marker; jetzt werden sie erkannt (als Vorschlag mit Bestätigung), der Text bleibt ohne sie.
    func testTrackingMarkerWerdenErkanntUndAusDemTextGenommen() {
        for roh in ["[[wasser: 250]]", "[[gewicht: 81,3]]", "[[training: start]]", "[[satz: abc | 60 | 8]]"] {
            let z = zerlegt("Okay. \(roh)")
            XCTAssertEqual(z.text, "Okay.", roh)
            XCTAssertEqual(z.marker.count, 1, roh)
        }
    }
}
