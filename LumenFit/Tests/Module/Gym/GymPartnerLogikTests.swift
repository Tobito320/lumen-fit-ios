import XCTest
@testable import LumenFit

/// Die Partner-Zeile auf der Gym-Startseite und die Einheiten im Verlauf: Lovea-Worte, Freigaben, Plan nach Wochentag.
@MainActor
final class GymPartnerLogikTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_761_897_600) // 2025-10-31 08:00 UTC
    private var heute: String { Datum.text(jetzt) }

    private func datei(freigaben: [FreigabeArt] = [.plan, .verlauf], verlauf: PartnerVerlauf? = nil, plan: PartnerPlan? = nil) -> ZusammenfassungDatei {
        var tag = TagesZusammenfassung(tag: heute)
        tag.verlauf = verlauf
        tag.plan = plan
        return ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: jetzt, profilName: "Mia", freigaben: freigaben, heute: tag, ereignisse: [])
    }

    private func plan() -> PartnerPlan {
        let alle = Array(1...7)
        return PartnerPlan(name: nil, tage: [PartnerPlanTag(name: "Push", wochentage: alle.filter { $0 != 7 }, uebungen: [])], ruhetage: [7])
    }

    func testOhneFreigabeSteht_nichtFreigegeben() {
        XCTAssertEqual(GymPartnerLogik.status(datei(freigaben: []), datum: heute, heute: heute, jetzt: jetzt), "nicht freigegeben")
    }

    func testGeradeImGym() {
        let v = PartnerVerlauf(imGym: true, imGymSeit: jetzt.addingTimeInterval(-1200), imGymName: nil, trainings: [])
        XCTAssertEqual(GymPartnerLogik.status(datei(verlauf: v), datum: heute, heute: heute, jetzt: jetzt), "gerade im Gym")
    }

    func testVergessenesLaufendesTrainingZaehltNichtMehr() {
        let v = PartnerVerlauf(imGym: true, imGymSeit: jetzt.addingTimeInterval(-4 * 3600), imGymName: nil, trainings: [])
        XCTAssertEqual(GymPartnerLogik.status(datei(verlauf: v), datum: heute, heute: heute, jetzt: jetzt), "noch nicht")
    }

    func testDauerUndSaetze() {
        let v = PartnerVerlauf(trainings: [PartnerTrainingKurz(tag: heute, name: "Push", minuten: 54, saetze: 27, uebungen: 6, kcal: nil)])
        XCTAssertEqual(GymPartnerLogik.status(datei(verlauf: v), datum: heute, heute: heute, jetzt: jetzt), "54 min · 27 Sätze")
        let ein = PartnerVerlauf(trainings: [PartnerTrainingKurz(tag: heute, name: nil, minuten: 54, saetze: 1, uebungen: 1, kcal: nil)])
        XCTAssertEqual(GymPartnerLogik.status(datei(verlauf: ein), datum: heute, heute: heute, jetzt: jetzt), "54 min · 1 Satz")
        let ohne = PartnerVerlauf(trainings: [PartnerTrainingKurz(tag: heute, name: nil, minuten: nil, saetze: 0, uebungen: 0, kcal: nil)])
        XCTAssertEqual(GymPartnerLogik.status(datei(verlauf: ohne), datum: heute, heute: heute, jetzt: jetzt), "war im Gym")
    }

    func testVergangenheitUndHeuteOhneEinheit() {
        let gestern = Datum.addTage(heute, -1)
        XCTAssertEqual(GymPartnerLogik.status(datei(verlauf: PartnerVerlauf(trainings: [])), datum: gestern, heute: heute, jetzt: jetzt), "nicht im Gym")
        XCTAssertEqual(GymPartnerLogik.status(datei(verlauf: PartnerVerlauf(trainings: [])), datum: heute, heute: heute, jetzt: jetzt), "noch nicht")
    }

    func testZukunftFolgtDemPlanNachWochentag() {
        let morgen = Datum.addTage(heute, 1)
        let d = datei(plan: plan())
        let tag = Datum.wochentag(morgen) == 7 ? "Ruhetag" : "geplant: Push"
        XCTAssertEqual(GymPartnerLogik.status(d, datum: morgen, heute: heute, jetzt: jetzt), tag)
        XCTAssertEqual(GymPartnerLogik.status(datei(), datum: morgen, heute: heute, jetzt: jetzt), "noch nicht", "ohne Plan weiß man nichts")
    }

    func testNurVerbundenMitNamenGibtEinenPartner() {
        XCTAssertNil(GymPartnerLogik.partner(.nichtVerbunden))
        XCTAssertNil(GymPartnerLogik.partner(.unbekannteVersion))
        XCTAssertEqual(GymPartnerLogik.partner(.verbunden(datei()))?.profilName, "Mia")
        XCTAssertEqual(GymPartnerLogik.partner(.veraltet(datei()))?.profilName, "Mia")
    }

    func testEinheitenNeuesteZuerstUndNurMitFreigabe() {
        let a = PartnerTrainingKurz(tag: "2025-10-20", name: nil, minuten: 40, saetze: 10, uebungen: 3, kcal: nil)
        let b = PartnerTrainingKurz(tag: "2025-10-28", name: nil, minuten: 50, saetze: 12, uebungen: 4, kcal: nil)
        let v = PartnerVerlauf(trainings: [a, b])
        XCTAssertEqual(GymPartnerLogik.einheiten(datei(verlauf: v)).map(\.tag), ["2025-10-28", "2025-10-20"])
        XCTAssertEqual(GymPartnerLogik.trainingstage(datei(verlauf: v)), ["2025-10-20", "2025-10-28"])
        XCTAssertTrue(GymPartnerLogik.einheiten(datei(freigaben: [.plan], verlauf: v)).isEmpty)
    }
}
