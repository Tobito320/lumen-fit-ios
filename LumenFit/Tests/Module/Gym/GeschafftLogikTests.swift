import XCTest
@testable import LumenFit

/// Die Seite "Geschafft" nach dem Beenden: rechnet aus dem gespeicherten Training (nicht aus der Sitzung, die beim Beenden leer wird).
@MainActor
final class GeschafftLogikTests: XCTestCase {
    private func aufbau() throws -> GymTestAufbau {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        return a
    }

    private func stand(_ a: GymTestAufbau) throws -> GeschafftStand {
        let s = try XCTUnwrap(GeschafftLogik.letzte(a.daten.training.sessions))
        return GeschafftLogik.stand(s, tag: a.daten.training.tag(id: s.tag), alle: a.daten.training.sessions,
                                   katalog: { a.sitzung.katalog($0) }, jetzt: a.uhr.lesen)
    }

    func testKachelnRekordeUndMuskelnAusDemGespeichertenTraining() throws {
        let a = try aufbau()
        a.fruehereEinheit(kg: 50, wdh: 8)
        a.sitzung.starte(planTag: "push")
        for (u, n) in [(0, 3), (1, 2)] { for i in 0..<n { a.sitzung.haken(u, i) } }
        a.uhr.vor(sekunden: 47 * 60)
        a.sitzung.beende()

        let g = try stand(a)
        XCTAssertEqual(g.titel, "Push")
        XCTAssertEqual(g.saetze, 5)
        XCTAssertEqual(g.volumen, 3 * 60 * 8 + 2 * 20 * 8)
        XCTAssertEqual(g.sekunden, 47 * 60, accuracy: 1)
        XCTAssertEqual(g.rekorde.count, 1, "nur Übung a hat ein früheres Training, das erste Mal ist kein Rekord")
        XCTAssertEqual(g.rekorde.first?.text, "60 kg × 8")
        XCTAssertEqual(g.rekorde.first?.uebung, UebungsKatalog.nachId["EIeI8Vf"]?.name)
        let haupt = try XCTUnwrap(UebungsKatalog.nachId["EIeI8Vf"].flatMap(KoerperLogik.haupt))
        XCTAssertTrue(g.muskeln.contains(haupt))
        XCTAssertEqual(g.stimmung, .stolz)
    }

    func testOhneRekordZielUndNurAbgehakteUebungenZaehlen() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(1, 0)
        a.sitzung.beende()

        let g = try stand(a)
        XCTAssertEqual(g.saetze, 1)
        XCTAssertTrue(g.rekorde.isEmpty)
        XCTAssertEqual(g.stimmung, .ziel)
        let a0 = try XCTUnwrap(UebungsKatalog.nachId["EIeI8Vf"].flatMap(KoerperLogik.haupt))
        let b0 = try XCTUnwrap(UebungsKatalog.nachId["903mzG8"].flatMap(KoerperLogik.haupt))
        XCTAssertTrue(g.muskeln.contains(b0))
        if a0 != b0 { XCTAssertFalse(g.muskeln.contains(a0), "ohne Haken nicht trainiert") }
    }

    func testLetzteNimmtNurBeendeteTrainings() throws {
        let a = try aufbau()
        XCTAssertNil(GeschafftLogik.letzte(a.daten.training.sessions))
        a.sitzung.starte(planTag: "push")
        XCTAssertNil(GeschafftLogik.letzte(a.daten.training.sessions), "das laufende Training ist noch nicht geschafft")
        a.sitzung.beende()
        XCTAssertEqual(GeschafftLogik.letzte(a.daten.training.sessions)?.tag, "push")
    }
}
