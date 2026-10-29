import XCTest
@testable import LumenFit

/// Die Liste neben der Körperkarte (Idee 33): jede Gruppe mit Prozent und Wort, nie nur Farbe.
final class SilhouetteTests: XCTestCase {
    /// Dienstag 13.10.2026, 18:00.
    private let jetzt = Datum.datum("2026-10-13").addingTimeInterval(18 * 3600)

    private func u(_ name: String, _ muskel: String) -> Uebung {
        Uebung(id: name, name: name, en: name, muskel: muskel, koerper: "", geraet: "", neben: [])
    }

    private func einheit(stundenVorher: Double, _ uebungen: [(String, Int)]) -> GymSession {
        let ende = jetzt.addingTimeInterval(-stundenVorher * 3600)
        let laeufe = uebungen.map { name, n in
            UebungsLauf(plan: name, uebung: name, start: nil, ende: ende, fertig: true, saetze: (0..<n).map { _ in PlanSatz(wdh: 10, kg: 40, failure: false) })
        }
        return GymSession(id: "s\(stundenVorher)", tag: nil, start: ende.addingTimeInterval(-3600), ende: ende, laeufe: laeufe)
    }

    private func daten(_ sessions: [GymSession]) -> KoerperDaten {
        let katalog = ["Latzug": u("Latzug", "Latissimus"), "Kniebeuge": u("Kniebeuge", "Quadrizeps"), "Bank": u("Bank", "Brust")]
        return KoerperDaten.bauen(sessions: sessions, plan: .leer, jetzt: jetzt, katalog: { katalog[$0] })
    }

    func testJedeGruppeHatEineZeileMitProzent() {
        let d = daten([einheit(stundenVorher: 3, [("Latzug", 4)])])
        let z = SilhouetteZeile.zeilen(d, reihenfolge: MuskelGruppe.allCases)
        XCTAssertEqual(Set(z.map(\.gruppe)), Set(MuskelGruppe.allCases))
        XCTAssertEqual(z.count, MuskelGruppe.allCases.count)
        for zeile in z { XCTAssertTrue((0...100).contains(zeile.prozent), zeile.gruppe.name) }
    }

    func testMuedesZuerstDannErholtDannOhneTraining() {
        let d = daten([einheit(stundenVorher: 3, [("Latzug", 4)]), einheit(stundenVorher: 40, [("Kniebeuge", 3)]), einheit(stundenVorher: 300, [("Bank", 3)])])
        let z = SilhouetteZeile.zeilen(d, reihenfolge: MuskelGruppe.allCases)
        XCTAssertEqual(z.first?.gruppe, .ruecken)
        XCTAssertEqual(z.first?.stufe, .muede)
        XCTAssertEqual(z[1].gruppe, .beine)
        XCTAssertEqual(z[1].stufe, .fast, "40 Stunden nach den Kniebeugen")
        XCTAssertEqual(z[2].gruppe, .brust)
        XCTAssertEqual(z[2].stufe, .erholt)
        XCTAssertTrue(z.dropFirst(3).allSatisfy { $0.stufe == .leer })
        let stufen = z.map(\.stufe)
        XCTAssertEqual(stufen, stufen.sorted { rang($0) < rang($1) }, "nach Stufe geordnet")
    }

    private func rang(_ s: SilhouetteStufe) -> Int { [SilhouetteStufe.muede, .fast, .erholt, .leer].firstIndex(of: s) ?? 3 }

    func testOhneTrainingSteht100ProzentUndKeinTraining() {
        let z = SilhouetteZeile.zeilen(daten([]), reihenfolge: MuskelGruppe.allCases)
        XCTAssertTrue(z.allSatisfy { $0.prozent == 100 && $0.stufe == .leer && $0.teilText == nil && $0.letztes == nil })
        XCTAssertEqual(z.map(\.gruppe), MuskelGruppe.allCases, "ohne Unterschied bleibt die Reihenfolge")
        XCTAssertEqual(z.first?.sprechtext, "Schulter, 100 Prozent, kein Training erfasst")
    }

    func testTeilTextUndLetztesTrainingFuerDenMuedestenTeil() {
        let d = daten([einheit(stundenVorher: 3, [("Latzug", 4)])])
        let ruecken = SilhouetteZeile.zeilen(d, reihenfolge: MuskelGruppe.allCases).first { $0.gruppe == .ruecken }
        XCTAssertEqual(ruecken?.teilText, "Latissimus \(d.erholung[.rLat] ?? -1) Prozent")
        XCTAssertEqual(ruecken?.letztes, "Di 13.10. · Latzug")
        XCTAssertEqual(ruecken?.stufe, .muede)
        XCTAssertTrue(ruecken?.sprechtext.hasPrefix("Rücken, \(d.prozent(.ruecken)) Prozent, müde") == true, ruecken?.sprechtext ?? "")
    }

    func testPrioReihenfolgeBleibtBeiGleicherStufe() {
        let d = daten([])
        let z = SilhouetteZeile.zeilen(d, reihenfolge: [.beine, .brust, .nacken])
        XCTAssertEqual(z.map(\.gruppe), [.beine, .brust, .nacken])
    }

    func testFormenSpiegelnUndPassenInsRechteck() {
        let links = SilhouetteForm.ellipse(CGRect(x: 10, y: 20, width: 20, height: 40))
        guard case .ellipse(let rechts) = links.gespiegelt else { return XCTFail("Ellipse bleibt Ellipse") }
        XCTAssertEqual(rechts.minX, 70)
        XCTAssertEqual(rechts.width, 20)
        XCTAssertEqual(rechts.minY, 20)
        let rahmen = CGRect(x: 0, y: 0, width: 200, height: 400)
        let box = links.pfad(in: rahmen).boundingRect
        XCTAssertEqual(box.minX, 20, accuracy: 0.5, "Faktor 2")
        XCTAssertEqual(box.width, 40, accuracy: 0.5)
        for f in SilhouetteBild.alle {
            let b = f.pfad(in: rahmen).boundingRect
            XCTAssertTrue(rahmen.insetBy(dx: -1, dy: -1).contains(b), f.id)
        }
    }
}
