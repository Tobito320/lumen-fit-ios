import XCTest
@testable import LumenFit

@MainActor
final class ProfilZieleTests: XCTestCase {
    private let mann = Koerperdaten(groesseCm: 178, geburtsjahr: 1998, geschlecht: .maennlich)

    func testVorschlagFuerHaltenRechnetMitMifflinStJeor() {
        // Grundumsatz 10*78 + 6,25*178 - 5*28 + 5 = 1757,5; Aktivität bei 3 Tagen 1,55: 2724 kcal, gerundet auf 10.
        let z = ProfilZielVorschlag.vorschlag(koerper: mann, art: .halten, gymTage: 3, kg: 78, jahr: 2026)
        XCTAssertEqual(z.kalorien, 2_720)
        XCTAssertEqual(z.proteinGramm, 136, "ausgewogen: 20 Prozent der Kalorien")
        XCTAssertEqual(z.gymTageProWoche, 3)
        XCTAssertEqual(z.art, .halten)
        XCTAssertEqual(z.wasserMl, 2_700)
        XCTAssertNil(z.gewichtKg, "ein Gewichtsziel schlägt die App nie vor")
    }

    func testAbnehmenIstWenigerAufbauenIstMehr() {
        let halten = ProfilZielVorschlag.vorschlag(koerper: mann, art: .halten, gymTage: 3, kg: 78, jahr: 2026)
        let abnehmen = ProfilZielVorschlag.vorschlag(koerper: mann, art: .abnehmen, gymTage: 3, kg: 78, jahr: 2026)
        let aufbauen = ProfilZielVorschlag.vorschlag(koerper: mann, art: .aufbauen, gymTage: 3, kg: 78, jahr: 2026)
        XCTAssertLessThan(abnehmen.kalorien, halten.kalorien)
        XCTAssertGreaterThan(aufbauen.kalorien, halten.kalorien)
        XCTAssertGreaterThanOrEqual(aufbauen.proteinGramm, 156, "aufbauen: mindestens 2 g Protein je kg")
        XCTAssertEqual(aufbauen.schritte, 8_000)
        XCTAssertEqual(abnehmen.schritte, 10_000)
    }

    func testGeschlechtIstOptionalUndZaehltNurInDerFormel() {
        let ohne = Koerperdaten(groesseCm: 170, geburtsjahr: 2000, geschlecht: nil)
        let frau = Koerperdaten(groesseCm: 170, geburtsjahr: 2000, geschlecht: .weiblich)
        let divers = Koerperdaten(groesseCm: 170, geburtsjahr: 2000, geschlecht: .divers)
        let a = ProfilZielVorschlag.vorschlag(koerper: ohne, art: .halten, gymTage: 3, kg: 70, jahr: 2026)
        let b = ProfilZielVorschlag.vorschlag(koerper: frau, art: .halten, gymTage: 3, kg: 70, jahr: 2026)
        let c = ProfilZielVorschlag.vorschlag(koerper: divers, art: .halten, gymTage: 3, kg: 70, jahr: 2026)
        XCTAssertLessThan(b.kalorien, a.kalorien)
        XCTAssertEqual(a.kalorien, c.kalorien, "ohne Angabe und divers gilt dieselbe Formel (Mann-Wert wie im Essen-Store)")
    }

    func testOhneKoerperdatenGeltenStandardwerte() {
        XCTAssertNil(ProfilZielVorschlag.alter(geburtsjahr: nil, jahr: 2026))
        XCTAssertNil(ProfilZielVorschlag.alter(geburtsjahr: 1800, jahr: 2026))
        XCTAssertNil(ProfilZielVorschlag.alter(geburtsjahr: 2030, jahr: 2026))
        XCTAssertEqual(ProfilZielVorschlag.alter(geburtsjahr: 1998, jahr: 2026), 28)
        XCTAssertEqual(ProfilZielVorschlag.gewichtOderStandard(nil, geschlecht: .weiblich), 62)
        XCTAssertEqual(ProfilZielVorschlag.gewichtOderStandard(nil, geschlecht: nil), 78)
        XCTAssertEqual(ProfilZielVorschlag.gewichtOderStandard(81.5, geschlecht: .weiblich), 81.5)
        let z = ProfilZielVorschlag.vorschlag(koerper: Koerperdaten(), art: .halten, gymTage: 3, kg: nil, jahr: 2026)
        XCTAssertGreaterThan(z.kalorien, 1_500)
        XCTAssertEqual(z.wasserMl, 2_500, "ohne Gewicht bleibt der Standard")
    }

    func testAktivitaetAusGymTagen() {
        XCTAssertEqual([0, 1, 2, 3, 4, 5, 6, 7].map(ProfilZielVorschlag.aktivitaet), [1, 1, 2, 2, 3, 3, 4, 4])
    }

    func testGymTageBleibenInDerWoche() {
        XCTAssertEqual(ProfilZielVorschlag.vorschlag(koerper: mann, art: .halten, gymTage: 12, kg: 78, jahr: 2026).gymTageProWoche, 7)
        XCTAssertEqual(ProfilZielVorschlag.vorschlag(koerper: mann, art: .halten, gymTage: 0, kg: 78, jahr: 2026).gymTageProWoche, 1)
    }

    func testSpiegelInDieErnaehrungsZiele() {
        var ziele = Ziele()
        ziele.kalorien = 2_400
        ziele.proteinGramm = 150
        ziele.art = .abnehmen
        let e = ProfilZielVorschlag.ernaehrungsZiele(aus: ziele, koerper: Koerperdaten(groesseCm: 165, geburtsjahr: 1990, geschlecht: .weiblich), bisher: ErnaehrungsZiele(), jahr: 2026)
        XCTAssertEqual(e.kcal, 2_400)
        XCTAssertEqual(e.protein, 150)
        XCTAssertEqual(e.fett, 80)
        XCTAssertEqual(e.kohlenhydrate, 270, "Rest der Kalorien: (2400 - 600 - 720) / 4")
        XCTAssertEqual(e.richtung, 0)
        XCTAssertEqual(e.geschlecht, 1)
        XCTAssertEqual(e.groesseCm, 165)
        XCTAssertEqual(e.alter, 36)
    }

    func testSpeichernSchreibtAnBeideOrte() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Mira", passwort: "abcd")
        let daten = try XCTUnwrap(u.daten)
        XCTAssertFalse(daten.essen.ernaehrungsZiele.eingerichtet)
        var ziele = Ziele()
        ziele.kalorien = 2_100
        ziele.proteinGramm = 120
        ProfilZielSpeicher.sichere(ziele: ziele, koerper: mann, in: daten, jahr: 2026)
        XCTAssertEqual(daten.ziele.ziele, ziele)
        XCTAssertEqual(daten.ziele.koerper, mann)
        XCTAssertTrue(daten.essen.ernaehrungsZiele.eingerichtet)
        XCTAssertEqual(daten.essen.ernaehrungsZiele.kcal, 2_100)
        XCTAssertEqual(daten.essen.ernaehrungsZiele.protein, 120)
        XCTAssertEqual(ProfilZielSpeicher.jahr(TestUhr().lesen), 2026)
    }
}
