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

    func testDatenschutzSagtEhrlichWasDieNutzungsmeldungIst() throws {
        let netz = try XCTUnwrap(ProfilTexte.datenschutz().first { $0.titel == "Was an den Lumen-Server geht" })
        for wort in ["nicht anonym", "Nein oder gar nichts", "90 Tagen", "Absturz", "Kein Gesundheitswert", "Nutzung melden"] {
            XCTAssertTrue(netz.text.contains(wort), wort)
        }
        XCTAssertFalse(netz.text.lowercased().replacingOccurrences(of: "nicht anonym", with: "").contains("anonym"), "nirgends als anonym ausgeben")
        XCTAssertEqual(ProfilTexte.NutzungFrage.ja, "Ja, helfen")
        XCTAssertEqual(ProfilTexte.NutzungFrage.nein, "Nein")
        XCTAssertTrue(ProfilTexte.NutzungFrage.konto.contains("nicht anonym"))
    }

    func testDatenschutzNenntDieStudioSucheBeiApple() throws {
        let netz = try XCTUnwrap(ProfilTexte.datenschutz().first { $0.titel == "Was ins Netz geht" })
        for wort in ["Suchtext", "Apple Karten", "Standort", "nur der Name"] {
            XCTAssertTrue(netz.text.contains(wort), wort)
        }
    }

    func testDatenschutzSagtWasDasGeraetNieVerlaesst() throws {
        let verlaesst = try XCTUnwrap(ProfilTexte.datenschutz().first { $0.titel.contains("nie verlässt") })
        for wort in ["Gesundheitsdaten", "Trainings", "Essen", "Gewicht", "kein Konto", "keinen Server"] {
            XCTAssertTrue(verlaesst.text.contains(wort) || verlaesst.text.lowercased().contains(wort.lowercased()), wort)
        }
        XCTAssertTrue(verlaesst.text.contains("selbst teilst"), "Teilen von Hand ist die einzige Ausnahme und steht dabei")
        let titel = ProfilTexte.datenschutz().map(\.titel)
        XCTAssertTrue(titel.contains("Was gespeichert wird"))
        XCTAssertTrue(titel.contains("Alles löschen"))
        XCTAssertEqual(Set(titel).count, titel.count, "jeder Abschnitt hat einen eigenen Titel")
    }

    func testLoeschlisteEinzahlUndMehrzahl() {
        let z = ProfilTexte.loeschliste(einheiten: 1, essenstage: 12, meilensteine: 0).map(\.text)
        XCTAssertEqual(z, ["1 Training", "12 Tage im Essenstagebuch", "0 Meilensteine",
                           "Ziele, Körperdaten, Einstellungen und Gewohnheiten"])
        XCTAssertEqual(ProfilTexte.loeschliste(einheiten: 5, essenstage: 1, meilensteine: 1).map(\.text).prefix(3),
                       ["5 Trainings", "1 Tag im Essenstagebuch", "1 Meilenstein"])
    }
    func testDatenschutzNenntFotoSchaetzungUndKontoLoeschen() throws {
        let foto = try XCTUnwrap(ProfilTexte.datenschutz().first { $0.titel == "Essen per Foto schätzen" })
        for wort in ["Erlauben", "OpenAI", "USA", "ohne Ort", "speichert weder Foto noch Antwort", "Ohne Zustimmung geht kein Foto raus", "Zurücknehmen"] {
            XCTAssertTrue(foto.text.contains(wort), wort)
        }
        let konto = try XCTUnwrap(ProfilTexte.datenschutz().first { $0.titel == "Konto löschen" })
        for wort in ["Lumen-Server", "Ohne Netz wird nichts gelöscht", "Health"] {
            XCTAssertTrue(konto.text.contains(wort), wort)
        }
    }
}
