import XCTest
@testable import LumenFit

/// Alle Stores eines Profils gegen echte Ops in einem Temp-Ordner (Naht 1 aus SPEC 11): schreiben, neu starten, wieder lesen.
@MainActor
final class DatenSatzTests: XCTestCase {
    private let uhr = TestUhr()
    private var heute: String { Datum.text(uhr.lesen) }

    private func satz(_ ordner: URL, profil: ProfilID = .testA, kanal: EreignisKanal = EreignisKanal()) -> DatenSatz {
        DatenSatz(profil: profil, ordner: ordner, ereignisse: kanal, uhr: uhr.uhr)
    }

    func testHabitsUeberlebenDenNeustart() throws {
        let ordner = try tempOrdner()
        let erster = satz(ordner)
        erster.habits.setzeWasser(datum: heute, anzahl: 6)
        erster.habits.setzeGym(datum: heute, an: true)
        XCTAssertEqual(erster.habits.wert(Habit.wasser.id, heute), 6)
        XCTAssertTrue(erster.habits.gymAbgehakt(heute))

        let zweiter = satz(ordner)
        XCTAssertEqual(zweiter.habits.wert(Habit.wasser.id, heute), 6)
        XCTAssertTrue(zweiter.habits.gymAbgehakt(heute))
        erster.habits.setzeGym(datum: heute, an: false)
        XCTAssertFalse(erster.habits.gymAbgehakt(heute), "die letzte Op gewinnt")
    }

    func testEigeneHabitAnlegenAusblendenUndLoeschen() throws {
        let satz = satz(try tempOrdner())
        let lesen = Habit(id: "h-lesen", name: "Lesen", symbol: "book.fill", farbe: "indigo", zaehlen: false, tagesziel: nil, haeufigkeit: .taeglich, fuer: "ich")
        satz.habits.anlegen(lesen)
        XCTAssertTrue(satz.habits.sichtbar.contains { $0.id == "h-lesen" })
        satz.habits.ausblenden("h-lesen", true)
        XCTAssertFalse(satz.habits.sichtbar.contains { $0.id == "h-lesen" })
        satz.habits.ausblenden("h-lesen", false)
        XCTAssertTrue(satz.habits.sichtbar.contains { $0.id == "h-lesen" })
        satz.habits.loeschen("h-lesen")
        XCTAssertFalse(satz.habits.sichtbar.contains { $0.id == "h-lesen" })
    }

    func testTrainingAusBeispielOpsErgibtEineAbgeschlosseneEinheit() throws {
        let ordner = try tempOrdner()
        let start = uhr.lesen
        let satz = satz(ordner)
        for op in TestDaten.gymOps(von: .testA, start: start) { satz.raum.einreihen(op) }
        let sessions = satz.training.sessions
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.tag, "push")
        XCTAssertNotNil(sessions.first?.ende)
        XCTAssertEqual(sessions.first?.laeufe.first?.saetze?.count, 2)
        XCTAssertNil(satz.training.laufende(jetzt: start + 7200), "beendet: nichts läuft")

        let neu = self.satz(ordner)
        XCTAssertEqual(neu.training.sessions.map(\.id), sessions.map(\.id), "nach dem Neustart gleich")
    }

    func testTrainingEincheckenStartenUndAuschecken() throws {
        let satz = satz(try tempOrdner())
        let id = satz.training.einchecken(tag: nil)
        XCTAssertNotNil(satz.training.laufende())
        satz.training.auschecken(id)
        XCTAssertNil(satz.training.laufende())
        XCTAssertEqual(satz.training.sessions.count, 1)
    }

    func testEssenAusBeispielOpsRechnetDieSummen() throws {
        let satz = satz(try tempOrdner())
        for op in TestDaten.essenOps(von: .testA, datum: heute, zeit: uhr.lesen) { satz.raum.einreihen(op) }
        XCTAssertEqual(satz.essen.eintraege(heute).count, 1)
        XCTAssertEqual(satz.essen.eintraege(heute, .fruehstueck).count, 1)
        XCTAssertEqual(satz.essen.summe(heute).kcal, 222, accuracy: 0.01, "60 g von 370 kcal je 100 g")
        XCTAssertEqual(satz.essen.summe(heute).protein, 7.8, accuracy: 0.01)
        XCTAssertTrue(satz.essen.tage.contains(heute))
    }

    func testEssenEintragenAendernUndLoeschen() throws {
        let satz = satz(try tempOrdner())
        satz.essen.eintragen(TestDaten.haferflocken, menge: 40, einheit: .g, mahlzeit: .snack, datum: heute, id: "e1")
        XCTAssertEqual(satz.essen.eintraege(heute).first?.menge, 40)
        var eintrag = try XCTUnwrap(satz.essen.eintraege(heute).first)
        eintrag.menge = 80
        satz.essen.aendern(eintrag)
        XCTAssertEqual(satz.essen.eintraege(heute).first?.menge, 80, "die neueste Op gewinnt")
        satz.essen.loeschen(eintrag)
        XCTAssertTrue(satz.essen.eintraege(heute).isEmpty)
    }

    func testProfileSehenNichtDieDatenDesAnderen() throws {
        let wurzel = try tempOrdner()
        let a = satz(wurzel.appendingPathComponent("a"), profil: .testA)
        let b = satz(wurzel.appendingPathComponent("b"), profil: .testB)
        a.habits.setzeWasser(datum: heute, anzahl: 4)
        for op in TestDaten.essenOps(von: .testA, datum: heute, zeit: uhr.lesen) { a.raum.einreihen(op) }
        XCTAssertEqual(b.habits.wert(Habit.wasser.id, heute), 0)
        XCTAssertTrue(b.essen.eintraege(heute).isEmpty)
        XCTAssertEqual(a.habits.wert(Habit.wasser.id, heute), 4)
    }

    func testEinstellungenUndZieleLiegenImProfilordner() throws {
        let ordner = try tempOrdner()
        let erster = satz(ordner)
        erster.einstellungen.aendere { $0.thema = .stahl }
        erster.ziele.setze({ var z = Ziele(); z.schritte = 8_000; return z }())
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("einstellungen.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("ziele.json").path))
        let zweiter = satz(ordner)
        XCTAssertEqual(zweiter.einstellungen.werte.thema, .stahl)
        XCTAssertEqual(zweiter.ziele.ziele.schritte, 8_000)
    }

    func testMeilensteinWirdEinmalGezaehltUndSteigertLumi() throws {
        let satz = satz(try tempOrdner())
        XCTAssertEqual(satz.meilensteine.stufe, 1)
        satz.meilensteine.markiere("erste-einheit")
        satz.meilensteine.markiere("erste-einheit")
        XCTAssertEqual(satz.meilensteine.erreicht.count, 1)
        XCTAssertTrue(satz.meilensteine.istErreicht("erste-einheit"))
        XCTAssertEqual(satz.meilensteine.stufe, 2)
    }
}
