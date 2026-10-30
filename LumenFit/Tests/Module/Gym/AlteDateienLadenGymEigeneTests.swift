import XCTest
@testable import LumenFit

/// Alte Dateien laden weiter: ein Log ohne die neue Op-Art, eine Op ohne die optionalen Felder, eine Op mit einem Feld, das es später gibt.
@MainActor
final class AlteDateienLadenGymEigeneTests: XCTestCase {
    private func op(_ json: String, art: String = GymEigeneLogik.art) -> Op {
        Op(id: UUID().uuidString, art: art, von: .testA, zeit: Date(), d: Data(json.utf8))
    }

    func testLogOhneEigeneUebungenLaedtLeer() throws {
        let ordner = try tempOrdner()
        let raum = LokalerRaum(ordner: ordner, profil: .testA)
        raum.einreihen(Op(id: "1", art: "gym.checkin", von: .testA, zeit: Date(), d: Data("{}".utf8)))
        let store = GymEigeneStore(raum: raum)
        XCTAssertTrue(store.liste.isEmpty)
        XCTAssertEqual(store.alle.count, UebungsKatalog.alle.count)
    }

    func testOpNurMitPflichtfeldernLaedt() {
        let alt = op(#"{"id":"lv-eigen-1","name":"Kabel-Fly","muskel":"Brust","koerper":"Brust","geraet":"Kabelzug"}"#)
        let stand = GymEigeneLogik.falten(ops: [alt])
        XCTAssertEqual(stand.count, 1)
        XCTAssertNil(stand.first?.notiz)
        XCTAssertNil(stand.first?.angelegt)
        XCTAssertNil(stand.first?.neben)
        XCTAssertNotEqual(stand.first?.geloescht, true)
        XCTAssertEqual(GymEigeneLogik.uebung(stand[0]).neben, [])
    }

    func testOpMitUnbekanntemFeldLaedtWeiter() {
        let neuer = op(#"{"id":"lv-eigen-2","name":"Seil-Zug","muskel":"Rücken","koerper":"Rücken","geraet":"Seil","bild":"x.png","geloescht":false}"#)
        XCTAssertEqual(GymEigeneLogik.falten(ops: [neuer]).map(\.name), ["Seil-Zug"])
    }

    func testPlanDateiMitEigenerUebungOhneNamenFaelltAufUebungZurueck() {
        // Ein alter Planeintrag der Form `eigen` bleibt gültig und trägt seinen Namen weiter.
        let p = PlanUebung.eigene("Mein Zug")
        XCTAssertEqual(p.anzeigeName, "Mein Zug")
        XCTAssertFalse(GymEigeneLogik.istEigene(p.uebung))
    }
}
