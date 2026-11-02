import XCTest
@testable import LumenFit

/// Stimmung und Gewohnheiten (Freigaben `stimmung`, `gewohnheiten`): Bauer, Zuschnitt, Anzeige, Vergleich und der Stand einer QR-Person.
final class GewohnheitenVergleichTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
    private let lesen = GewohnheitStand(id: "lesen", name: "Lesen", symbol: "book", serie: 12, quote: 55, heute: false)
    private let gym = GewohnheitStand(id: "gym", name: "Gym", symbol: "dumbbell.fill", serie: 3, quote: 80, heute: true)

    private func datei(_ freigaben: [FreigabeArt]) -> ZusammenfassungDatei {
        var h = TagesZusammenfassung(tag: "2026-10-29", schritte: 1)
        h.stimmung = 4
        h.stimmungWoche = ["2026-10-29": 4]
        h.gewohnheiten = [gym, lesen]
        return ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Person", freigaben: freigaben, heute: h, ereignisse: [])
    }

    func testBauerGibtStimmungUndGewohnheitenNurMitFreigabe() {
        var e = ZusammenfassungBauer.Eingabe(name: "Ich", jetzt: jetzt, freigaben: [.schritte], schritte: 1, gymTageWoche: nil, schlafMinuten: nil, kcal: nil, ereignisse: [])
        e.stimmung = 4; e.gewohnheiten = [gym]
        XCTAssertNil(ZusammenfassungBauer.baue(e).heute.stimmung)
        XCTAssertNil(ZusammenfassungBauer.baue(e).heute.gewohnheiten)
        e.freigaben = [.stimmung]
        XCTAssertEqual(ZusammenfassungBauer.baue(e).heute.stimmung, 4)
        XCTAssertNil(ZusammenfassungBauer.baue(e).heute.stimmungWoche)
        XCTAssertNil(ZusammenfassungBauer.baue(e).heute.gewohnheiten)
        e.freigaben = [.gewohnheiten]
        XCTAssertEqual(ZusammenfassungBauer.baue(e).heute.gewohnheiten, [gym])
        XCTAssertNil(ZusammenfassungBauer.baue(e).heute.stimmung)
    }

    func testBegrenzenKenntDieNeuenBereiche() {
        let nur = VerbindungenLogik.begrenze(datei([.stimmung, .gewohnheiten]), auf: [.stimmung])
        XCTAssertEqual(nur.heute.stimmung, 4)
        XCTAssertNil(nur.heute.gewohnheiten)
        XCTAssertNil(nur.heute.schritte)
    }

    func testAlteDateiOhneDieFelderBleibtLesbar() throws {
        let json = #"{"version":1,"geschrieben":"2026-10-29T10:00:00.000Z","profilName":"A","freigaben":["schritte","irgendwasNeues"],"heute":{"tag":"2026-10-29","schritte":5},"ereignisse":[]}"#
        let d = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: Data(json.utf8))
        XCTAssertNil(d.heute.stimmung)
        XCTAssertNil(d.heute.gewohnheiten)
        XCTAssertEqual(d.freigaben, [.schritte])
    }

    func testAnzeigeZeigtStimmungUndGewohnheitenNurMitFreigabe() {
        XCTAssertTrue(PartnerAnzeige.zeilen(datei([]), bereich: .heute).isEmpty)
        let zeilen = PartnerAnzeige.zeilen(datei([.stimmung, .gewohnheiten]), bereich: .heute)
        XCTAssertEqual(zeilen.first { $0.titel == "Stimmung" }?.wert, "Gut")
        XCTAssertEqual(zeilen.first { $0.titel == "Gewohnheiten" }?.wert, "1 von 2 heute")
        XCTAssertEqual(PartnerAnzeige.stimmungText(1), "Schwer")
        XCTAssertEqual(PartnerAnzeige.stimmungText(5), "Top")
    }

    func testVergleichFindetDieGewohnheitBeiKennungOderName() {
        let d = datei([.gewohnheiten])
        XCTAssertEqual(PartnerAnzeige.gewohnheit(d, id: "gym", name: "egal"), gym)
        XCTAssertEqual(PartnerAnzeige.gewohnheit(d, id: "abc-123", name: "lesen"), lesen, "eigene Gewohnheiten haben andere Kennungen: der Name entscheidet")
        XCTAssertNil(PartnerAnzeige.gewohnheit(d, id: "x", name: "Yoga"))
        XCTAssertNil(PartnerAnzeige.gewohnheit(datei([]), id: "gym", name: "Gym"), "ohne Freigabe nichts")
    }

    func testStandEinerQRPerson() {
        var e = VerbindungEintrag(id: "q", name: "Ben", daten: datei([.plan]))
        XCTAssertEqual(e.stand(jetzt: jetzt), .verbunden(datei([.plan])))
        XCTAssertEqual(e.stand(jetzt: jetzt.addingTimeInterval(LoveaVertrag.frist + 60)), .veraltet(datei([.plan])))
        e.daten = nil
        XCTAssertEqual(e.stand(jetzt: jetzt), .nichtVerbunden)
        var neu = VerbindungEintrag(id: "q", name: "Ben", daten: datei([]))
        neu.daten?.version = 2
        XCTAssertEqual(neu.stand(jetzt: jetzt), .unbekannteVersion)
        XCTAssertEqual(VerbindungEintrag(id: "w", name: "Cem", status: .anfrageEingehend, daten: datei([])).stand(jetzt: jetzt), .nichtVerbunden)
    }

    func testEinstiegeJeBereichFuerEssenUndGym() {
        var d = datei([.plan, .verlauf, .tagebuch])
        d.heute.plan = PartnerPlan(name: "P", tage: [PartnerPlanTag(name: "A", wochentage: [1], uebungen: [])], ruhetage: nil)
        d.heute.tagebuch = [PartnerTagebuchTag(tag: "2026-10-29", kcal: 1, protein: 1, kohlenhydrate: 1, fett: 1, mahlzeiten: [])]
        XCTAssertEqual(PartnerAnsichtLogik.einstiege(d, jetzt: jetzt, bereich: .essen).map(\.art), [.tagebuch])
        XCTAssertEqual(PartnerAnsichtLogik.einstiege(d, jetzt: jetzt, bereich: .gym).map(\.art), [.plan])
        XCTAssertEqual(PartnerAnsichtLogik.einstiege(d, jetzt: jetzt, bereich: .schlaf).map(\.art), [])
    }
}
