import XCTest
@testable import LumenFit

/// Die Crew-Zeilen im Gym-Tab: wer steht da, mit welchem Zustand, in welcher Reihenfolge.
final class GymCrewLogikTests: XCTestCase {
    private typealias T = CrewTestDaten

    private func zeilen(_ e: [VerbindungEintrag], datum: String? = nil) -> [CrewZeile] {
        GymCrewLogik.zeilen(eintraege: e, datum: datum ?? T.heute, heute: T.heute, jetzt: T.jetzt)
    }

    private var imGym: ZusammenfassungDatei { T.datei(verlauf: T.imGym()) }
    private var heuteDa: ZusammenfassungDatei {
        T.datei(verlauf: PartnerVerlauf(trainings: [PartnerTrainingKurz(tag: T.heute, name: nil, minuten: 54, saetze: 27, uebungen: 6, kcal: nil)]))
    }
    private var noch: ZusammenfassungDatei { T.datei(verlauf: PartnerVerlauf(trainings: [])) }

    func testLeerUndNichtAktivGibtNichts() {
        XCTAssertEqual(zeilen([]), [])
        var anfrage = T.eintrag("a", daten: imGym)
        anfrage.statusText = VerbindungStatus.anfrageEingehend.rawValue
        XCTAssertEqual(zeilen([anfrage]), [])
    }

    func testZustaendeUndStatustext() {
        let z = zeilen([T.eintrag("a", daten: imGym), T.eintrag("b", daten: heuteDa), T.eintrag("c", daten: noch)])
        XCTAssertEqual(z.map(\.zustand), [.imGym, .heuteDa, .noch])
        XCTAssertEqual(z.map(\.status), ["gerade im Gym", "54 min · 27 Sätze", "noch nicht"])
    }

    func testGeplantAnEinemSpaeterenTag() {
        let alle = Array(1...7)
        let plan = PartnerPlan(name: nil, tage: [PartnerPlanTag(name: "Push", wochentage: alle, uebungen: [])], ruhetage: nil)
        let d = T.datei(verlauf: PartnerVerlauf(trainings: []), plan: plan)
        let z = zeilen([T.eintrag("a", daten: d)], datum: Datum.addTage(T.heute, 1))
        XCTAssertEqual(z.first?.zustand, .geplant)
        XCTAssertEqual(z.first?.status, "geplant: Push")
    }

    func testReihenfolgeImGymHeuteDaGeplantRest() {
        let plan = PartnerPlan(name: nil, tage: [PartnerPlanTag(name: "Pull", wochentage: Array(1...7), uebungen: [])], ruhetage: nil)
        let geplant = T.datei(verlauf: PartnerVerlauf(trainings: []), plan: plan)
        let morgen = Datum.addTage(T.heute, 1)
        XCTAssertEqual(zeilen([T.eintrag("rest", daten: noch), T.eintrag("plan", daten: geplant)], datum: morgen).map(\.id), ["plan", "rest"])
        let alle = [T.eintrag("rest", daten: noch), T.eintrag("da", daten: heuteDa), T.eintrag("gym", daten: imGym), T.eintrag("rest2", daten: noch)]
        XCTAssertEqual(zeilen(alle).map(\.id), ["gym", "da", "rest", "rest2"], "gleicher Rang bleibt in der Reihenfolge der Liste")
    }

    func testLoveaPersonNurEinmal() {
        let z = zeilen([T.eintrag("a", name: "Partner", lovea: true, daten: heuteDa), T.eintrag("b", name: "Partner", lovea: true, daten: heuteDa), T.eintrag("a", daten: noch)])
        XCTAssertEqual(z.map(\.id), ["a"])
    }

    func testOhneDatenOderOhneFreigabeWegGelassen() {
        XCTAssertEqual(zeilen([T.eintrag("a", daten: nil)]), [])
        XCTAssertEqual(zeilen([T.eintrag("a", daten: T.datei(freigaben: [.schritte, .schlaf], verlauf: T.imGym()))]), [])
        XCTAssertEqual(zeilen([T.eintrag("a", daten: T.datei(freigaben: [.plan], plan: nil))]).count, 1, "nur Plan freigegeben: Zeile bleibt")
    }

    func testPauseGibtPausiertAuchOhneDaten() {
        let z = zeilen([T.eintrag("a", pause: true, daten: nil), T.eintrag("b", pause: true, daten: imGym)])
        XCTAssertEqual(z.map(\.zustand), [.pausiert, .pausiert])
        XCTAssertEqual(z.map(\.status), ["pausiert", "pausiert"])
        XCTAssertNil(z.last?.mitlauf, "pausiert: auch kein Mitlauf")
    }

    func testVeraltetNachZweiTagenMitTagen() {
        func alt(_ stunden: Double) -> ZusammenfassungDatei { T.datei(geschrieben: T.jetzt.addingTimeInterval(-stunden * 3600), verlauf: T.imGym()) }
        XCTAssertEqual(zeilen([T.eintrag("a", daten: alt(47))]).first?.zustand, .imGym)
        let z = zeilen([T.eintrag("a", daten: alt(49)), T.eintrag("b", daten: alt(24 * 5 + 2))])
        XCTAssertEqual(z.map(\.zustand), [.veraltet, .veraltet])
        XCTAssertEqual(z.map(\.status), ["zuletzt vor 2 Tagen", "zuletzt vor 5 Tagen"])
        XCTAssertNil(z.first?.mitlauf)
    }

    func testNameMitUmlautenUndEigenerName() {
        var e = T.eintrag("a", name: "Freund Ö", daten: noch)
        XCTAssertEqual(zeilen([e]).first?.name, "Freund Ö")
        e.ich.name = "Freund Ü"
        XCTAssertEqual(zeilen([e]).first?.name, "Freund Ü", "mein Name für die Person gilt")
        XCTAssertEqual(zeilen([T.eintrag("b", name: "", daten: T.datei(name: "Freund Ä", verlauf: T.imGym()))]).first?.name, "Freund Ä", "ohne Servername der Profilname")
    }

    func testMitlaufNurBeiImGymMitSaetzen() {
        let d = T.datei(verlauf: T.imGym(einheiten: [T.einheit(T.heute, [("Rudern", [T.satz(10, 600)])])]))
        XCTAssertEqual(zeilen([T.eintrag("a", daten: d)]).first?.mitlauf?.uebung, "Rudern")
        XCTAssertNil(zeilen([T.eintrag("a", daten: imGym)]).first?.mitlauf)
    }
}
