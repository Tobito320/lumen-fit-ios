import XCTest
@testable import LumenFit

/// Freigaben je Datenart (Idee 84): Standard keine, jede Art einzeln, und was nicht freigegeben ist, fehlt in `zusammenfassung.json` (auch die Ereignisse).
@MainActor
final class FreigabenTests: XCTestCase {
    private let jetzt = VerbindenTest.jetzt

    private func eingabe(_ frei: Set<FreigabeArt>, ereignisse: [PartnerEreignis] = []) -> ZusammenfassungBauer.Eingabe {
        ZusammenfassungBauer.Eingabe(name: "Beispiel Profil", jetzt: jetzt, freigaben: frei, schritte: 8_000, gymTageWoche: 2, schlafMinuten: 450, kcal: 1_900,
                                     ereignisse: ereignisse)
    }

    private func ereignis(_ art: PartnerEreignisArt, vor: TimeInterval = 600) -> PartnerEreignis {
        PartnerEreignis(id: "\(art.rawValue)-1", art: art, zeit: jetzt.addingTimeInterval(-vor), text: "Text")
    }

    func testStandardIstKeineFreigabe() throws {
        XCTAssertTrue(VerbindungStore().freigaben.isEmpty)
        let datei = ZusammenfassungBauer.baue(eingabe([]))
        XCTAssertTrue(datei.freigaben.isEmpty)
        XCTAssertNil(datei.heute.schritte)
        XCTAssertNil(datei.heute.gymTageWoche)
        XCTAssertNil(datei.heute.schlafMinuten)
        XCTAssertNil(datei.heute.kcal)
        XCTAssertTrue(datei.ereignisse.isEmpty)
        XCTAssertEqual(datei.heute.tag, "2026-10-29")
    }

    func testOhneFreigabeFehlenDieFelderAuchImJSON() throws {
        let daten = try LoveaVertrag.encoder().encode(ZusammenfassungBauer.baue(eingabe([.gym])))
        let heute = try XCTUnwrap((try JSONSerialization.jsonObject(with: daten) as? [String: Any])?["heute"] as? [String: Any])
        XCTAssertEqual(Set(heute.keys), ["tag", "gymTageWoche"])
    }

    func testJedeArtGiltFuerSichAllein() {
        let alle: [FreigabeArt: KeyPath<TagesZusammenfassung, Int?>] = [.schritte: \.schritte, .gym: \.gymTageWoche, .schlaf: \.schlafMinuten, .essen: \.kcal]
        for art in FreigabeArt.allCases {
            let heute = ZusammenfassungBauer.baue(eingabe([art])).heute
            for (andere, feld) in alle {
                XCTAssertEqual(heute[keyPath: feld] != nil, andere == art, "\(art) gibt nur \(art) frei, nicht \(andere)")
            }
        }
    }

    func testAlleFreigegebenGibtAlleWerte() {
        let datei = ZusammenfassungBauer.baue(eingabe(Set(FreigabeArt.allCases)))
        XCTAssertEqual(datei.freigaben, FreigabeArt.allCases)
        XCTAssertEqual(datei.heute, TagesZusammenfassung(tag: "2026-10-29", schritte: 8_000, gymTageWoche: 2, schlafMinuten: 450, kcal: 1_900))
    }

    func testEreignisseBrauchenDieFreigabeIhrerArt() {
        let alle = [ereignis(.gymStart), ereignis(.gymEnde), ereignis(.rekord), ereignis(.ziel), ereignis(.schlafGut)]
        XCTAssertEqual(Set(ZusammenfassungBauer.baue(eingabe([.gym], ereignisse: alle)).ereignisse.map(\.art)), [.gymStart, .gymEnde, .rekord])
        XCTAssertEqual(Set(ZusammenfassungBauer.baue(eingabe([.schritte], ereignisse: alle)).ereignisse.map(\.art)), [.ziel])
        XCTAssertEqual(Set(ZusammenfassungBauer.baue(eingabe([.schlaf], ereignisse: alle)).ereignisse.map(\.art)), [.schlafGut])
        XCTAssertTrue(ZusammenfassungBauer.baue(eingabe([.essen], ereignisse: alle)).ereignisse.isEmpty)
        XCTAssertTrue(ZusammenfassungBauer.baue(eingabe([], ereignisse: alle)).ereignisse.isEmpty)
    }

    func testAlteEreignisseFallenWegUndDieZahlIstBegrenzt() {
        let alt = ereignis(.gymEnde, vor: ZusammenfassungBauer.ereignisFrist + 60)
        XCTAssertTrue(ZusammenfassungBauer.baue(eingabe([.gym], ereignisse: [alt])).ereignisse.isEmpty)
        let viele = (0..<30).map { PartnerEreignis(id: "e\($0)", art: .gymEnde, zeit: jetzt.addingTimeInterval(-Double($0 * 60)), text: "t") }
        let datei = ZusammenfassungBauer.baue(eingabe([.gym], ereignisse: viele))
        XCTAssertEqual(datei.ereignisse.count, ZusammenfassungBauer.ereignisMaximal)
        XCTAssertEqual(datei.ereignisse.last?.id, "e0", "die neuesten bleiben, nach Zeit sortiert")
    }

    // MARK: Speichern

    func testFreigabenWerdenGespeichertUndBleibenNachNeustart() throws {
        let ordner = try tempOrdner()
        let store = VerbindungStore(ordner: ordner)
        store.freigaben = [.schritte, .schlaf]
        XCTAssertEqual(VerbindungStore(ordner: ordner).freigaben, [.schritte, .schlaf])
        store.freigaben = []
        XCTAssertTrue(VerbindungStore(ordner: ordner).freigaben.isEmpty)
    }

    // MARK: Vorschau "das sieht dein Partner"

    func testVorschauZeigtGenauDieZeilenDerFreigaben() {
        let heute = FreigabenVorschau.zeilen(ZusammenfassungBauer.baue(eingabe([.schritte, .schlaf])))
        XCTAssertEqual(heute.map(\.titel), ["Schritte", "Schlaf"])
        XCTAssertTrue(FreigabenVorschau.zeilen(ZusammenfassungBauer.baue(eingabe([]))).isEmpty, "ohne Freigabe sieht der Partner nichts")
        XCTAssertEqual(FreigabenVorschau.zeilen(ZusammenfassungBauer.baue(eingabe(Set(FreigabeArt.allCases)))).map(\.titel),
                       ["Schritte", "Gym diese Woche", "Essen", "Schlaf"])
    }

    func testNamenDerFreigaben() {
        for art in FreigabeArt.allCases { XCTAssertFalse(FreigabenVorschau.name(art).isEmpty); XCTAssertFalse(FreigabenVorschau.erklaerung(art).isEmpty) }
        XCTAssertEqual(Set(FreigabeArt.allCases.map(FreigabenVorschau.name)).count, 4)
    }
}
