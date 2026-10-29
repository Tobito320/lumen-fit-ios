import XCTest
@testable import LumenFit

/// W-028: die Regeln der Quellen (`TagesformQuellenLogik`): welche Tage zählen, welcher Stand eines Tages, wann etwas fehlt.
/// Reine Logik mit übergebenen Werten, ohne Modelle. Die Rechnung selbst prüft `TagesformRechnungTests`.
final class TagesformQuellenTests: XCTestCase {
    // MARK: Hilfen

    private func satz() -> PlanSatz { PlanSatz(wdh: 10, kg: nil, failure: false) }

    private func uebung(_ name: String, _ muskel: String) -> Uebung {
        Uebung(id: name, name: name, en: name, muskel: muskel, koerper: "", geraet: "", neben: [])
    }

    private func katalog(_ liste: Uebung...) -> (String) -> Uebung? {
        let nachId = Dictionary(uniqueKeysWithValues: liste.map { ($0.id, $0) })
        return { nachId[$0] }
    }

    /// Eine Einheit mit einer Übung und `n` gezählten Sätzen, die um `start` beginnt.
    private func session(_ id: String, start: Date, uebung: String, saetze n: Int, fertig: Bool = true) -> GymSession {
        let lauf = UebungsLauf(plan: "p", uebung: uebung, start: nil, ende: start, fertig: fertig,
                               saetze: [PlanSatz](repeating: satz(), count: n))
        return GymSession(id: id, tag: nil, start: start, ende: nil, laeufe: [lauf])
    }

    private func essen(_ kcal: Double, _ protein: Double) -> Naehrwerte { Naehrwerte(kcal: kcal, protein: protein) }

    private let ziele = ErnaehrungsZiele(kcal: 2600, protein: 160)

    // MARK: Tage und Reihen

    func testTageZaehlenVomTagRueckwaerts() {
        XCTAssertEqual(TagesformQuellenLogik.tage(ab: "2026-10-12", anzahl: 4), ["2026-10-12", "2026-10-11", "2026-10-10", "2026-10-09"])
        XCTAssertEqual(TagesformQuellenLogik.tage(ab: "2026-03-01", anzahl: 2), ["2026-03-01", "2026-02-28"], "über die Monatsgrenze")
        XCTAssertTrue(TagesformQuellenLogik.tage(ab: "2026-10-12", anzahl: 0).isEmpty)
    }

    func testReiheFolgtDenTagenUndLaesstLueckenLeer() {
        let tage = TagesformQuellenLogik.tage(ab: "2026-10-12", anzahl: 4)
        let reihe = TagesformQuellenLogik.reihe(["2026-10-12": 55, "2026-10-10": 57, "2026-01-01": 99], tage: tage)
        XCTAssertEqual(reihe, [55, nil, 57, nil], "Index 0 ist der Tag selbst, fremde Tage fallen weg")
    }

    // MARK: Training

    func testTrainingZaehltNurBisZumEndeDesTagesUndSaetzeJeTag() {
        let bank = uebung("Bankdrücken", "Brust")
        let gestern = Datum.datum("2026-10-09").addingTimeInterval(18 * 3600)
        let abends = Datum.datum("2026-10-10").addingTimeInterval(19 * 3600)
        let naechsterTag = Datum.datum("2026-10-11").addingTimeInterval(10 * 3600)
        let sessions = [
            session("a", start: gestern, uebung: bank.id, saetze: 4),
            session("b", start: abends, uebung: bank.id, saetze: 3),
            session("c", start: naechsterTag, uebung: bank.id, saetze: 9),
        ]
        // Der 10. liegt in der Vergangenheit: die Einheit vom 11. gehört nicht dazu, Index 0 ist der Tag selbst.
        let t = TagesformQuellenLogik.training(sessions, tag: "2026-10-10", jetzt: Datum.datum("2026-10-20"), anzahl: 4, katalog: katalog(bank))
        XCTAssertEqual(t.saetze, [3, 4, 0, 0])
        // Brust ist ein großer Teil (60 h); um Mitternacht, fünf Stunden nach der letzten Einheit, sind es 5 von 60 Stunden.
        XCTAssertEqual(t.muskeln, [TagesformMuskel(gruppe: "Brust", prozent: 8)])
    }

    func testTrainingNachJetztZaehltNieSonstFaelltDieErholungAufNull() {
        let bank = uebung("Bankdrücken", "Brust")
        let abends = Datum.datum("2026-10-10").addingTimeInterval(19 * 3600)
        let spaeter = Datum.datum("2026-10-10").addingTimeInterval(21 * 3600)
        let sessions = [
            session("a", start: abends, uebung: bank.id, saetze: 3),
            session("b", start: spaeter, uebung: bank.id, saetze: 6),
        ]
        // Es ist 20 Uhr: die Einheit um 21 Uhr gälte sonst als "gerade eben" (0 Prozent) und brächte 6 Sätze mit.
        let t = TagesformQuellenLogik.training(sessions, tag: "2026-10-10", jetzt: abends.addingTimeInterval(3600), anzahl: 2, katalog: katalog(bank))
        XCTAssertEqual(t.saetze, [3, 0])
        XCTAssertEqual(t.muskeln, [TagesformMuskel(gruppe: "Brust", prozent: 1)], "eine Stunde von 60")
    }

    func testTrainingZaehltNurFertigeLaeufe() {
        let bank = uebung("Bankdrücken", "Brust")
        let abends = Datum.datum("2026-10-10").addingTimeInterval(19 * 3600)
        let offen = session("o", start: abends, uebung: bank.id, saetze: 5, fertig: false)
        let t = TagesformQuellenLogik.training([offen], tag: "2026-10-10", jetzt: abends.addingTimeInterval(3600), anzahl: 1, katalog: katalog(bank))
        XCTAssertEqual(t.saetze, [0])
        XCTAssertTrue(t.muskeln.isEmpty)
        let leer = TagesformQuellenLogik.training([], tag: "2026-10-10", jetzt: abends, anzahl: 3, katalog: katalog(bank))
        XCTAssertEqual(leer.saetze, [0, 0, 0])
        XCTAssertTrue(leer.muskeln.isEmpty)
    }

    func testTrainingSortiertDieMuedestenZuerstUndNenntDieGruppe() {
        let bank = uebung("Bankdrücken", "Brust")
        let curl = uebung("Curl", "Bizeps")
        let tag = Datum.datum("2026-10-10")
        let sessions = [
            session("a", start: tag.addingTimeInterval(10 * 3600), uebung: curl.id, saetze: 3),
            session("b", start: tag.addingTimeInterval(19 * 3600), uebung: bank.id, saetze: 3),
        ]
        let t = TagesformQuellenLogik.training(sessions, tag: "2026-10-10", jetzt: tag.addingTimeInterval(20 * 3600), anzahl: 1, katalog: katalog(bank, curl))
        XCTAssertEqual(t.muskeln.map { $0.gruppe }, ["Brust", "Bizeps"], "1 von 60 Stunden gegen 10 von 30: Brust ist müder")
        XCTAssertEqual(t.muskeln.map { $0.prozent }, [1, 33])
    }

    // MARK: Essen

    func testHeuteZaehltEssenNieNurDerVortag() {
        let m = TagesformQuellenLogik.essen(tag: essen(1500, 90), zielTag: ziele, vortag: essen(2400, 150), zielVortag: ziele, stunde: 20)
        XCTAssertEqual(m.kalorien, TagesformMass(ist: 2400, ziel: 2600, bezug: .vortag))
        XCTAssertEqual(m.eiweiss, TagesformMass(ist: 150, ziel: 160, bezug: .vortag))
        // Ohne Vortag gibt es nichts, auch wenn heute schon viel eingetragen ist: ein halber Tag wäre ein falsches Minus.
        let leer = TagesformQuellenLogik.essen(tag: essen(2600, 160), zielTag: ziele, vortag: nil, zielVortag: ziele, stunde: 20)
        XCTAssertNil(leer.kalorien)
        XCTAssertNil(leer.eiweiss)
    }

    func testEinVergangenerTagZaehltSelbstUndFaelltAufDenTagDavorZurueck() {
        let selbst = TagesformQuellenLogik.essen(tag: essen(2000, 120), zielTag: ziele, vortag: essen(2400, 150), zielVortag: ziele, stunde: 24)
        XCTAssertEqual(selbst.kalorien, TagesformMass(ist: 2000, ziel: 2600, bezug: .tag))
        XCTAssertEqual(selbst.eiweiss, TagesformMass(ist: 120, ziel: 160, bezug: .tag))
        let fehlt = TagesformQuellenLogik.essen(tag: nil, zielTag: ziele, vortag: essen(2400, 150), zielVortag: ziele, stunde: 24)
        XCTAssertEqual(fehlt.kalorien, TagesformMass(ist: 2400, ziel: 2600, bezug: .vortag))
    }

    func testEinSnackIstKeinVollerTag() {
        // 800 von 2.600 kcal (31 Prozent) und 40 g Eiweiß: nur ein Snack eingetragen. Der Tag fehlt, statt ein falsches Minus zu geben.
        let snack = TagesformQuellenLogik.essen(tag: nil, zielTag: ziele, vortag: essen(800, 40), zielVortag: ziele, stunde: 10)
        XCTAssertNil(snack.kalorien)
        XCTAssertNil(snack.eiweiss)
        // Ab 40 Prozent des Kalorienziels zählt der Tag, auch wenn er wenig ist.
        let knapp = TagesformQuellenLogik.essen(tag: nil, zielTag: ziele, vortag: essen(1000, 60), zielVortag: ziele, stunde: 10)
        XCTAssertNil(knapp.kalorien, "38 Prozent")
        let genug = TagesformQuellenLogik.essen(tag: nil, zielTag: ziele, vortag: essen(1100, 60), zielVortag: ziele, stunde: 10)
        XCTAssertEqual(genug.kalorien, TagesformMass(ist: 1100, ziel: 2600, bezug: .vortag), "42 Prozent")
        XCTAssertEqual(genug.eiweiss, TagesformMass(ist: 60, ziel: 160, bezug: .vortag))
        // Ein vergangener Tag nur mit Snack fällt auf den Tag davor.
        let davor = TagesformQuellenLogik.essen(tag: essen(500, 20), zielTag: ziele, vortag: essen(2400, 150), zielVortag: ziele, stunde: 24)
        XCTAssertEqual(davor.kalorien, TagesformMass(ist: 2400, ziel: 2600, bezug: .vortag))
        XCTAssertEqual(TagesformQuellenLogik.mindestEssen, 0.4)
    }

    func testJederTagZaehltGegenSeinEigenesZiel() {
        // Flexible Tage haben mehr Kalorien: der Vortag mit 3.000 zählt gegen 3.000, nicht gegen das Ziel von heute.
        let wochenende = ErnaehrungsZiele(kcal: 3000, protein: 180)
        let m = TagesformQuellenLogik.essen(tag: nil, zielTag: ziele, vortag: essen(2900, 170), zielVortag: wochenende, stunde: 10)
        XCTAssertEqual(m.kalorien, TagesformMass(ist: 2900, ziel: 3000, bezug: .vortag))
        XCTAssertEqual(m.eiweiss, TagesformMass(ist: 170, ziel: 180, bezug: .vortag))
        let selbst = TagesformQuellenLogik.essen(tag: essen(2900, 170), zielTag: wochenende, vortag: essen(2400, 150), zielVortag: ziele, stunde: 24)
        XCTAssertEqual(selbst.kalorien?.ziel, 3000)
    }

    func testEinZielOhneWertGibtKeinenMesswert() {
        let ohneEiweiss = ErnaehrungsZiele(kcal: 2600, protein: 0)
        let a = TagesformQuellenLogik.essen(tag: nil, zielTag: ziele, vortag: essen(2400, 150), zielVortag: ohneEiweiss, stunde: 10)
        XCTAssertNotNil(a.kalorien)
        XCTAssertNil(a.eiweiss)
        let ohneKcal = ErnaehrungsZiele(kcal: 0, protein: 160)
        let b = TagesformQuellenLogik.essen(tag: nil, zielTag: ziele, vortag: essen(2400, 150), zielVortag: ohneKcal, stunde: 10)
        XCTAssertNil(b.kalorien)
        XCTAssertNil(b.eiweiss, "ohne Kalorienziel lässt sich nicht sagen, ob der Tag vollständig war")
    }

    // MARK: Schritte und Wasser

    func testSchritteGehenAmVormittagVomVortagInHeuteUeber() {
        // Vor 8 Uhr nur der Vortag, 11 Uhr je zur Hälfte, ab 14 Uhr nur heute, der vergangene Tag ganz.
        let frueh = TagesformQuellenLogik.schritte(heute: 500, vortag: 9000, ziel: 10_000, stunde: 7)
        XCTAssertEqual(frueh, TagesformMass(ist: 9000, ziel: 10_000, bezug: .vortag))
        let mitte = TagesformQuellenLogik.schritte(heute: 500, vortag: 9000, ziel: 10_000, stunde: 11)
        XCTAssertEqual(mitte?.bezug, .bisJetzt)
        XCTAssertEqual(mitte?.davor?.anteil ?? 0, 0.5, accuracy: 1e-9)
        let abends = TagesformQuellenLogik.schritte(heute: 500, vortag: 9000, ziel: 10_000, stunde: 20)
        XCTAssertEqual(abends?.bezug, .bisJetzt)
        XCTAssertNil(abends?.davor)
        let vorbei = TagesformQuellenLogik.schritte(heute: 8000, vortag: 9000, ziel: 10_000, stunde: 24)
        XCTAssertEqual(vorbei, TagesformMass(ist: 8000, ziel: 10_000, bezug: .tag))
        // Keine Schritte von heute: der Vortag. Gar keine: nichts.
        XCTAssertEqual(TagesformQuellenLogik.schritte(heute: nil, vortag: 9000, ziel: 10_000, stunde: 20)?.bezug, .vortag)
        XCTAssertNil(TagesformQuellenLogik.schritte(heute: nil, vortag: nil, ziel: 10_000, stunde: 20))
    }

    func testWasserNurWennInDenLetztenAchtTagenEingetragen() {
        func wasser(_ tage: [Int]) -> TagesformMass? {
            TagesformQuellenLogik.wasser(heute: 0, vortag: 5, letzteTage: tage, ziel: 8, stunde: 10)
        }
        // Index 0 ist der Tag selbst: ein Eintrag am achten Tag (Index 7) zählt, am neunten (Index 8) nicht mehr.
        XCTAssertNotNil(wasser([0, 0, 0, 0, 0, 0, 0, 2]))
        XCTAssertNotNil(wasser([3]))
        XCTAssertNil(wasser([0, 0, 0, 0, 0, 0, 0, 0, 5]), "kein Eintrag heißt hier nicht, dass nichts getrunken wurde")
        XCTAssertNil(wasser([0, 0, 0, 0, 0, 0, 0, 0]))
        XCTAssertNil(wasser([]))
        XCTAssertEqual(TagesformQuellenLogik.wasserTage, 8)
    }
}

/// Der Adapter auf `DatenSatz` und `GesundheitsStand`.
@MainActor
final class TagesformQuellenAdapterTests: XCTestCase {
    private let jetzt = Datum.datum("2026-10-12").addingTimeInterval(12 * 3600)

    private func satz(_ ordner: URL) -> DatenSatz {
        DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: { Date(timeIntervalSince1970: 1_790_000_000) })
    }

    private func nacht(_ tag: String, minuten: Int, mitPhasen: Bool) -> SchlafNacht {
        let ende = Datum.datum(tag).addingTimeInterval(7 * 3600)
        let start = ende.addingTimeInterval(-Double(minuten) * 60)
        let phase: SchlafPhase = mitPhasen ? .kern : .unbestimmt
        return SchlafNacht(tag: tag, von: start, bis: ende, abschnitte: [SchlafAbschnitt(phase: phase, von: start, bis: ende)], schlafMinuten: minuten)
    }

    func testEinTagInDerZukunftHatKeineWerte() throws {
        let daten = satz(try tempOrdner())
        let stand = GesundheitsStand(leser: FakeHealthLeser(), uhr: { self.jetzt })
        XCTAssertEqual(TagesformQuellen.eingabe(daten: daten, gesundheit: stand, tag: "2026-10-13", jetzt: jetzt), TagesformEingabe())
        XCTAssertEqual(TagesformQuellen.eingabe(daten: daten, gesundheit: stand, tag: "2099-01-01", jetzt: jetzt), TagesformEingabe())
    }

    func testSchlafAusHealthMitQuelleUndZiel() async throws {
        let daten = satz(try tempOrdner())
        let leser = FakeHealthLeser(naechte: [nacht("2026-10-12", minuten: 400, mitPhasen: true), nacht("2026-10-11", minuten: 430, mitPhasen: false)])
        let stand = GesundheitsStand(leser: leser, uhr: { self.jetzt })
        await stand.aktualisiere()
        let e = TagesformQuellen.eingabe(daten: daten, gesundheit: stand, tag: "2026-10-12", jetzt: jetzt)
        XCTAssertEqual(e.schlaf.prefix(3).map { $0 }, [400, 430, nil])
        XCTAssertEqual(e.schlafZiel, 480)
        XCTAssertEqual(e.schlafSicherheit, 1, "Watch-Phasen zählen voll")
        XCTAssertEqual(e.schlafHinweis, "Quelle: Apple Watch")
        XCTAssertEqual(TagesformQuellen.nacht("2026-10-11", daten: daten, gesundheit: stand)?.quelle, .iPhone)
        XCTAssertEqual(e.bett.count, 7)
        XCTAssertNotNil(e.bett[0])
        XCTAssertNil(e.bett[2])
    }

    func testBandSchlafSpringtEinWennHealthNichtsHat() throws {
        let daten = satz(try tempOrdner())
        let ende = Datum.datum("2026-10-12").addingTimeInterval(7 * 3600)
        let start = ende.addingTimeInterval(-6 * 3600)
        daten.raum.senden("fit.band.schlaf", BandSchlafOp(tag: "2026-10-12", start: start, ende: ende, phasen: []))
        let stand = GesundheitsStand(leser: FakeHealthLeser(), uhr: { self.jetzt })
        let n = TagesformQuellen.nacht("2026-10-12", daten: daten, gesundheit: stand)
        XCTAssertEqual(n?.minuten, 360)
        XCTAssertEqual(n?.quelle, .armband)
        XCTAssertNil(TagesformQuellen.nacht("2026-10-11", daten: daten, gesundheit: stand))
    }

    func testWasserUndSchritteAusDemDatensatz() async throws {
        let daten = satz(try tempOrdner())
        daten.habits.setze(Habit.wasser.id, datum: "2026-10-11", wert: 6)
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: "2026-10-11", schritte: 9000)])
        let stand = GesundheitsStand(leser: leser, uhr: { self.jetzt })
        await stand.aktualisiere()
        let e = TagesformQuellen.eingabe(daten: daten, gesundheit: stand, tag: "2026-10-12", jetzt: jetzt)
        XCTAssertEqual(e.stunde, 12)
        XCTAssertEqual(e.schritte?.bezug, .vortag, "heute noch keine Schritte: der Vortag zählt")
        XCTAssertEqual(e.schritte?.ist, 9000)
        XCTAssertEqual(e.wasser?.bezug, .bisJetzt)
        XCTAssertEqual(e.wasser?.davor?.ist, 6, "am Vormittag zählt der Vortag noch mit")
    }
}
