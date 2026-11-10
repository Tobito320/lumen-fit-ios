import XCTest
@testable import LumenFit

/// Kalender im Training: Raster Mo bis So, trainierte Tage rückwärts, geplante Tage nur nach vorn, Partner-Marken.
/// 2026-11-09 ist ein Montag, der 1. November ein Sonntag.
final class KalenderLogikTests: XCTestCase {
    private let heute = "2026-11-09"
    private let monat = "2026-11"

    private var plan: TrainingsPlan {
        let uebung = PlanUebung(id: "p0", uebung: "Bank", name: nil, saetze: [], minuten: nil)
        return TrainingsPlan(tage: [TrainingsTag(id: "Push", name: "Push", wochentage: [1, 4], uebungen: [uebung])])
    }

    private func einheit(_ id: String, _ tag: String) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        return GymSession(id: id, tag: "Push", start: start, ende: start.addingTimeInterval(3600), laeufe: [])
    }

    private var partnerPlan: PartnerPlan {
        PartnerPlan(name: nil, tage: [PartnerPlanTag(name: "Beine", wochentage: [2], uebungen: [])], ruhetage: nil)
    }

    private func tage(partner: Bool = false) -> [KalenderTag] {
        KalenderLogik.tage(monat: monat, sessions: [einheit("a", "2026-11-02"), einheit("b", "2026-11-09")], plan: plan,
                           partnerTage: partner ? ["2026-11-03", "2026-11-09"] : [], partnerPlan: partner ? partnerPlan : nil, heute: heute)
    }

    private func tag(_ datum: String, partner: Bool = false) throws -> KalenderTag {
        try XCTUnwrap(tage(partner: partner).first { $0.datum == datum })
    }

    func testVergangeneTageZeigenTrainiertNieGeplant() throws {
        let gemacht = try tag("2026-11-02")
        XCTAssertTrue(gemacht.trainiert)
        XCTAssertNil(gemacht.geplant)
        let verpasst = try tag("2026-11-05")
        XCTAssertFalse(verpasst.trainiert)
        XCTAssertNil(verpasst.geplant, "Donnerstag ist Plantag, liegt aber vor heute")
    }

    func testKommendeTageZeigenDenPlantagNachWochentag() throws {
        XCTAssertEqual(try tag("2026-11-12").geplant, "Push")
        XCTAssertEqual(try tag("2026-11-16").geplant, "Push")
        XCTAssertNil(try tag("2026-11-10").geplant, "Dienstag ist frei")
        XCTAssertFalse(try tag("2026-11-12").trainiert)
    }

    func testHeuteKannTrainiertUndGeplantSein() throws {
        let t = try tag("2026-11-09")
        XCTAssertTrue(t.heute)
        XCTAssertTrue(t.trainiert)
        XCTAssertEqual(t.geplant, "Push")
        XCTAssertEqual(tage().filter(\.heute).count, 1)
    }

    func testPartnerTageUndPartnerPlanWerdenMarkiert() throws {
        XCTAssertTrue(try tag("2026-11-03", partner: true).partnerTrainiert)
        XCTAssertFalse(try tag("2026-11-03", partner: true).partnerGeplant, "Dienstag vor heute: nie geplant")
        XCTAssertTrue(try tag("2026-11-10", partner: true).partnerGeplant)
        XCTAssertFalse(try tag("2026-11-10", partner: true).partnerTrainiert)
        XCTAssertTrue(try tag("2026-11-09", partner: true).partnerTrainiert)
        XCTAssertFalse(try tag("2026-11-11", partner: true).partnerGeplant, "Mittwoch ist kein Partner-Plantag")
    }

    func testRasterBeginntMontagUndEndetSonntagMitFremdtagen() throws {
        let alle = tage()
        XCTAssertEqual(alle.first?.datum, "2026-10-26")
        XCTAssertEqual(alle.last?.datum, "2026-12-06")
        XCTAssertEqual(alle.count, 42)
        XCTAssertEqual(alle.filter(\.imMonat).count, 30)
        XCTAssertFalse(try tag("2026-10-31").imMonat)
        XCTAssertTrue(try tag("2026-11-01").imMonat)
        XCTAssertTrue(try tag("2026-11-30").imMonat)
        XCTAssertFalse(try tag("2026-12-01").imMonat)
    }

    func testOhnePartnerKeineMarken() {
        XCTAssertTrue(tage().allSatisfy { !$0.partnerTrainiert && !$0.partnerGeplant })
    }

    func testMonatTextUndNaechsterUeberDieJahresgrenze() {
        XCTAssertEqual(KalenderLogik.monatText("2026-11"), "November 2026")
        XCTAssertEqual(KalenderLogik.naechster("2026-12", schritt: 1), "2027-01")
        XCTAssertEqual(KalenderLogik.naechster("2027-01", schritt: -1), "2026-12")
        XCTAssertEqual(KalenderLogik.naechster("2026-11", schritt: 0), "2026-11")
    }

    func testSprechtextNenntTagUndMarken() throws {
        XCTAssertEqual(KalenderLogik.sprechtext(try tag("2026-11-09", partner: true)), "9. November, heute, trainiert, geplant: Push, Partner trainiert")
        XCTAssertEqual(KalenderLogik.sprechtext(try tag("2026-11-10", partner: true)), "10. November, kein Training, Partner geplant")
        XCTAssertEqual(KalenderLogik.sprechtext(try tag("2026-11-12")), "12. November, geplant: Push")
    }

    // MARK: Raster in Sonderfällen

    private func raster(_ monat: String) -> [String] {
        KalenderLogik.tage(monat: monat, sessions: [], plan: plan, partnerTage: [], partnerPlan: nil, heute: "2026-11-09").map(\.datum)
    }

    /// Ganze Wochen von Montag bis Sonntag, Tag für Tag um genau einen Kalendertag weiter, kein Tag doppelt, alle Tage des Monats drin.
    private func pruefeRaster(_ monat: String, tageImMonat: Int, erster: String, letzter: String, file: StaticString = #filePath, line: UInt = #line) {
        let alle = raster(monat)
        XCTAssertEqual(alle.count % 7, 0, "\(monat): ganze Wochen", file: file, line: line)
        XCTAssertEqual(alle.first, erster, monat, file: file, line: line)
        XCTAssertEqual(alle.last, letzter, monat, file: file, line: line)
        XCTAssertEqual(Datum.wochentag(alle.first ?? ""), 1, "\(monat): beginnt am Montag", file: file, line: line)
        XCTAssertEqual(Datum.wochentag(alle.last ?? ""), 7, "\(monat): endet am Sonntag", file: file, line: line)
        XCTAssertEqual(Set(alle).count, alle.count, "\(monat): kein Tag doppelt", file: file, line: line)
        for (a, b) in zip(alle, alle.dropFirst()) {
            XCTAssertEqual(Datum.addTage(a, 1), b, "\(monat): Lücke nach \(a)", file: file, line: line)
        }
        XCTAssertEqual(alle.filter { $0.hasPrefix(monat) }.count, tageImMonat, monat, file: file, line: line)
    }

    func testRasterOktober2026MitZeitumstellung() {
        // Die Uhr wird am 25.10. zurückgestellt (Tag mit 25 Stunden): das Raster darf keinen Tag verdoppeln oder auslassen.
        pruefeRaster("2026-10", tageImMonat: 31, erster: "2026-09-28", letzter: "2026-11-01")
        XCTAssertEqual(raster("2026-10").filter { $0 == "2026-10-25" }.count, 1)
    }

    func testRasterMonatMitMontagAlsErstemUndSonntagAlsLetztem() {
        pruefeRaster("2026-06", tageImMonat: 30, erster: "2026-06-01", letzter: "2026-07-05")   // der 1. Juni ist ein Montag
        pruefeRaster("2026-05", tageImMonat: 31, erster: "2026-04-27", letzter: "2026-05-31")   // der 31. Mai ist ein Sonntag
    }

    func testRasterFebruar2028Schaltjahr() {
        pruefeRaster("2028-02", tageImMonat: 29, erster: "2028-01-31", letzter: "2028-03-05")
        pruefeRaster("2026-03", tageImMonat: 31, erster: "2026-02-23", letzter: "2026-04-05")   // Zeitumstellung am 29.03.
    }
}
