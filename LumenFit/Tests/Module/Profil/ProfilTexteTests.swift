import XCTest
@testable import LumenFit

final class ProfilTexteTests: XCTestCase {
    private func alles(_ quelle: ProfilTexte.Quelle) -> String { quelle.name + " " + quelle.lizenz + " " + quelle.text }

    func testQuellenNennenBLSUndOpenFoodFactsImWortlaut() {
        let text = ProfilTexte.quellen.map(alles).joined(separator: "\n")
        XCTAssertTrue(text.contains("Open Food Facts"))
        XCTAssertTrue(text.contains("ODbL"))
        XCTAssertTrue(text.contains("Open Database License"))
        XCTAssertTrue(text.contains("Bundeslebensmittelschlüssel"))
        XCTAssertTrue(text.contains("CC BY 4.0"))
        XCTAssertTrue(text.contains("Max Rubner-Institut"))
        XCTAssertTrue(text.contains("Datenstand"))
        XCTAssertTrue(text.contains("Version 4.0"))
        XCTAssertTrue(text.contains("Übungsbilder"))
        XCTAssertTrue(text.contains("Apple-Frameworks"))
        XCTAssertEqual(ProfilTexte.quellen.count, 4)
    }

    func testDatenschutzSagtWasDasGeraetNieVerlaesst() throws {
        let verlaesst = try XCTUnwrap(ProfilTexte.datenschutz(coach: true).first { $0.titel.contains("nie verlässt") })
        for wort in ["Gesundheitsdaten", "Trainings", "Essen", "Gewicht", "kein Konto", "keinen Server"] {
            XCTAssertTrue(verlaesst.text.contains(wort) || verlaesst.text.lowercased().contains(wort.lowercased()), wort)
        }
        XCTAssertTrue(verlaesst.text.contains("selbst teilst"), "Teilen von Hand ist die einzige Ausnahme und steht dabei")
        let titel = ProfilTexte.datenschutz(coach: true).map(\.titel)
        XCTAssertTrue(titel.contains("Was gespeichert wird"))
        XCTAssertTrue(titel.contains("Alles löschen"))
        XCTAssertEqual(Set(titel).count, titel.count, "jeder Abschnitt hat einen eigenen Titel")
    }

    func testOhneCoachNenntDerDatenschutzKeineGespraecheUndDieListeKeinenVerlauf() throws {
        let verlaesst = try XCTUnwrap(ProfilTexte.datenschutz(coach: false).first { $0.titel.contains("nie verlässt") })
        XCTAssertFalse(verlaesst.text.contains("Coach"))
        XCTAssertTrue(verlaesst.text.contains("dein Gewicht. Lumen Fit"))
        XCTAssertFalse(ProfilTexte.loeschliste(einheiten: 1, essenstage: 1, meilensteine: 1, coachNachrichten: 0).map(\.text).contains { $0.contains("Coach") })
    }

    func testLoeschlisteEinzahlUndMehrzahl() {
        let z = ProfilTexte.loeschliste(einheiten: 1, essenstage: 12, meilensteine: 0, coachNachrichten: 3).map(\.text)
        XCTAssertEqual(z, ["1 Training", "12 Tage im Essenstagebuch", "0 Meilensteine", "3 Nachrichten im Coach-Verlauf",
                           "Ziele, Körperdaten, Einstellungen und Gewohnheiten"])
        XCTAssertEqual(ProfilTexte.loeschliste(einheiten: 5, essenstage: 1, meilensteine: 1, coachNachrichten: 1).map(\.text).prefix(4),
                       ["5 Trainings", "1 Tag im Essenstagebuch", "1 Meilenstein", "1 Nachricht im Coach-Verlauf"])
    }
}
