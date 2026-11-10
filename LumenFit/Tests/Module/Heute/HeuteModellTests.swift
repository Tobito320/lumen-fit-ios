import XCTest
@testable import LumenFit

@MainActor
final class HeuteModellTests: XCTestCase {
    /// Mittwoch, 23.09.2026, 12:00 Berlin.
    private let uhr = TestUhr()
    private let heute = "2026-09-23"

    // @unchecked Sendable: veränderlicher Zustand liegt hinter einem NSLock (wie FakeHealthLeser).
    private final class HeuteSpurSchreiber: HealthSchreiber, @unchecked Sendable {
        private let schloss = NSLock()
        private var _gewichte: [Double] = []
        var gewichte: [Double] { schloss.withLock { _gewichte } }
        func speichere(training: GymSession) async -> Bool { false }
        func speichere(gewichtKg: Double, am datum: Date) async -> Bool {
            schloss.withLock { _gewichte.append(gewichtKg) }
            return true
        }
    }

    private func umgebung(leser: FakeHealthLeser = FakeHealthLeser(), schreiber: any HealthSchreiber = KeinHealthSchreiber(), profil: Bool = true) throws -> AppUmgebung {
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                            leser: leser, healthSchreiber: schreiber, bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
        if profil { try u.profil.anlegen(name: "Test", passwort: "abcd") }
        var config = ServerConfig.standard
        config.schlafSichtbar = true   // Schlaf gehört nur Konten mit Erlaubnis; diese Tests prüfen ihn
        u.konto.uebernimm(config)
        return u
    }

    private func nacht(_ tag: String, minuten: Int, watch: Bool = true) -> SchlafNacht {
        let ende = Datum.datum(tag).addingTimeInterval(7 * 3600)
        let start = ende.addingTimeInterval(-Double(minuten) * 60)
        return SchlafNacht(tag: tag, von: start, bis: ende, abschnitte: [SchlafAbschnitt(phase: watch ? .kern : .unbestimmt, von: start, bis: ende)], schlafMinuten: minuten)
    }

    private func plan(_ daten: DatenSatz, name: String = "Beine", wochentag: Int = 3) {
        let u = PlanUebung(id: "u1", uebung: PlanUebung.eigen, name: "Kniebeuge", saetze: [PlanSatz(wdh: 8, kg: 60, failure: false)], minuten: nil)
        daten.training.planSichern(TrainingsPlan(tage: [TrainingsTag(id: "t1", name: name, wochentage: [wochentag], uebungen: [u])], ruhetage: []))
    }

    // MARK: Ohne Daten

    func testOhneProfilGibtEsKeinenStand() throws {
        let m = HeuteModell(umgebung: try umgebung(profil: false))
        m.berechne()
        XCTAssertNil(m.stand)
    }

    func testOhneHealthIstEsEinLeerzustandMitFehlendemScore() throws {
        let m = HeuteModell(umgebung: try umgebung())
        m.berechne()
        let s = try XCTUnwrap(m.stand)
        XCTAssertFalse(s.hatGesundheit)
        XCTAssertFalse(s.healthGeprueft, "vor dem ersten Lesen kein Leerzustand: sonst blitzt beim Start \"Health erlauben\" auf")
        XCTAssertNil(s.score.punkte)
        XCTAssertEqual(s.boegen.map(\.anteil), [0, 0, 0])
        XCTAssertTrue(s.morgensatz.contains("Mir fehlen noch Daten"))
        XCTAssertEqual(s.stimmung, .denkt)
        XCTAssertTrue(s.hinweise.isEmpty)
        XCTAssertEqual(s.woche.count, 7)
    }

    func testNachDemLesenOhneDatenIstDerLeerzustandDa() async throws {
        let m = HeuteModell(umgebung: try umgebung())
        await m.lade()
        XCTAssertEqual(m.stand?.hatGesundheit, false)
        XCTAssertEqual(m.stand?.healthGeprueft, true)
    }

    // MARK: Mit Health

    func testBoegenZahlenUndSatzFuerVoiceOver() async throws {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 8_412, distanzMeter: 6_300, etagen: 7)], naechte: [nacht(heute, minuten: 400)])
        let u = try umgebung(leser: leser)
        let m = HeuteModell(umgebung: u)
        await m.lade()
        let s = try XCTUnwrap(m.stand)
        XCTAssertTrue(s.hatGesundheit)
        XCTAssertEqual(s.boegen.map(\.id), [.bewegen, .trainieren, .erholen])
        XCTAssertEqual(s.boegen[0].anteil, 0.8412, accuracy: 0.0001)
        XCTAssertEqual(s.boegen[0].zahl, "8.412")
        XCTAssertEqual(s.boegen[0].beschriftung, "Schritte von 10.000")
        XCTAssertEqual(s.boegen[1].zahl, "0 von 3")
        XCTAssertEqual(s.boegen[2].zahl, "6:40 h")
        XCTAssertEqual(s.boegenSatz, "Schritte: 8.412 von 10.000. Gym: 0 von 3 Tagen. Schlaf: 6:40 h von 8:00 h.")
        XCTAssertEqual(s.schritte.schritte, 8_412)
        XCTAssertEqual(s.schritte.etagen, 7)
        XCTAssertEqual(s.schritte.distanzKm, 6.3, accuracy: 0.0001)
        XCTAssertEqual(leser.tagesAbfragen.count, 1, "Health wird beim Laden einmal gelesen")
    }

    func testHealthMeldungRechnetNeuOhneHealthNochmalZuLesen() async throws {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 4_000)])
        let m = HeuteModell(umgebung: try umgebung(leser: leser))
        await m.lade()
        XCTAssertEqual(leser.tagesAbfragen.count, 1)
        await m.verarbeite(.healthAktualisiert)
        XCTAssertEqual(leser.tagesAbfragen.count, 1, "die Meldung kommt erst nach dem Abruf (oder nach einem Eintrag von Hand): kein zweites Lesen")
        XCTAssertEqual(m.stand?.schritte.schritte, 4_000)
        await m.verarbeite(.vordergrund)
        XCTAssertEqual(leser.tagesAbfragen.count, 2, "im Vordergrund liest Heute Health neu")
    }

    func testSchritteKommenNurAusHealthNichtVomBand() async throws {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 6_000, distanzMeter: 4_000)])
        let u = try umgebung(leser: leser)
        u.daten?.raum.senden("fit.band.tag", BandTagOp(tag: heute, schritte: 7_500, meter: 5_000))
        let m = HeuteModell(umgebung: u)
        await m.lade()
        XCTAssertEqual(m.stand?.schritte.schritte, 6_000, "Besitzer 10.11.2026: nur Apple Health zählt (vorher das Maximum mit dem Band, 7500)")
        XCTAssertEqual(m.stand?.schritte.distanzKm ?? 0, 4.0, accuracy: 0.0001)
    }

    func testNurMitIPhoneRechnetDerScoreMitSchlafUndSagtWasFehlt() async throws {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 3_000)], naechte: [nacht(heute, minuten: 420, watch: false)])
        let m = HeuteModell(umgebung: try umgebung(leser: leser))
        await m.lade()
        let s = try XCTUnwrap(m.stand)
        XCTAssertNotNil(s.score.punkte)
        XCTAssertEqual(s.score.teile.map(\.art), [.schlaf])
        XCTAssertTrue(s.score.fehlend.contains(.erholung))
        XCTAssertTrue(s.score.satz.contains("Ohne"))
    }

    func testVitalwerteUndLastSpeisenErholungUndBelastung() async throws {
        let vitale: [VitalArt: [VitalMesswert]] = [
            .hrv: (0..<20).map { VitalMesswert(art: .hrv, tag: Datum.addTage(heute, -$0), wert: $0 % 2 == 0 ? 48 : 52) },
            .ruhepuls: (0..<20).map { VitalMesswert(art: .ruhepuls, tag: Datum.addTage(heute, -$0), wert: 55) },
        ]
        let tage = (0...31).map { TagesWerte(tag: Datum.addTage(heute, -$0), schritte: 5_000, aktiveKcal: 300) }
        let leser = FakeHealthLeser(tage: tage, naechte: [nacht(heute, minuten: 480)], vitale: vitale)
        let m = HeuteModell(umgebung: try umgebung(leser: leser))
        await m.lade()
        let score = try XCTUnwrap(m.stand?.score)
        XCTAssertEqual(score.teile.map(\.art), [.schlaf, .erholung, .belastung])
        XCTAssertTrue(score.fehlend.isEmpty)
        XCTAssertEqual(score.teil(.belastung)?.wert ?? 0, 100, accuracy: 0.001, "300 kcal an jedem Tag: das Gleiche wie sonst")
        XCTAssertNotNil(score.punkte)
    }

    func testBandSchlafGiltWennHealthKeinenHat() async throws {
        let u = try umgebung(leser: FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 1_000)]))
        let ende = Datum.datum(heute).addingTimeInterval(7 * 3600)
        u.daten?.raum.senden("fit.band.schlaf", BandSchlafOp(tag: heute, start: ende.addingTimeInterval(-7 * 3600), ende: ende, phasen: []))
        let m = HeuteModell(umgebung: u)
        await m.lade()
        XCTAssertEqual(m.stand?.boegen[2].zahl, "7:00 h")
    }

    // MARK: Morgen-Check

    private func mitSchlaf(_ minuten: Int) throws -> (AppUmgebung, HeuteModell) {
        let u = try umgebung(leser: FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 2_000)], naechte: [nacht(heute, minuten: minuten)]))
        return (u, HeuteModell(umgebung: u))
    }

    func testWertEinsOderZweiMachtLumiMuedeUndDenPlanLocker() async throws {
        for wert in [1, 2] {
            let (u, m) = try mitSchlaf(480)
            let daten = try XCTUnwrap(u.daten)
            plan(daten)
            daten.raum.senden("fit.lumi.stimmung", StimmungsEintrag(tag: heute, wert: wert, stimmung: .muede))
            await m.lade()
            let s = try XCTUnwrap(m.stand)
            XCTAssertEqual(s.stimmung, .muede, "Wert \(wert)")
            XCTAssertTrue(s.plan.locker)
            XCTAssertTrue(s.plan.tipp.hasPrefix("Heute locker"))
            XCTAssertEqual(s.stimmungsWert, wert)
        }
    }

    func testWertVierHebtDenBereitSatz() async throws {
        let (u, m) = try mitSchlaf(480)
        let daten = try XCTUnwrap(u.daten)
        plan(daten)
        await m.lade()
        XCTAssertEqual(m.stand?.morgensatz, "Gut erholt (Schlaf 8:00 h). Heute Beine?")
        daten.raum.senden("fit.lumi.stimmung", StimmungsEintrag(tag: heute, wert: 4, stimmung: .bereit))
        m.berechne()
        XCTAssertEqual(m.stand?.morgensatz, "Gut erholt (Schlaf 8:00 h), und du fühlst dich stark. Heute Beine?")
        XCTAssertEqual(m.stand?.stimmung, .bereit)
    }

    func testEinMorgenCheckVonGesternZaehltHeuteNicht() async throws {
        let (u, m) = try mitSchlaf(480)
        u.daten?.raum.senden("fit.lumi.stimmung", StimmungsEintrag(tag: "2026-09-22", wert: 1, stimmung: .muede))
        await m.lade()
        XCTAssertNil(m.stand?.stimmungsWert)
        XCTAssertEqual(m.stand?.stimmung, .bereit)
    }

    func testDerNeuesteMorgenCheckDesTagesGewinnt() async throws {
        let (u, m) = try mitSchlaf(480)
        u.daten?.raum.senden("fit.lumi.stimmung", StimmungsEintrag(tag: heute, wert: 1, stimmung: .muede))
        u.daten?.raum.senden("fit.lumi.stimmung", StimmungsEintrag(tag: heute, wert: 5, stimmung: .bereit))
        await m.lade()
        XCTAssertEqual(m.stand?.stimmungsWert, 5)
    }

    // MARK: Energie-Bank

    func testEnergieVerlaufHatEinenPunktJeDreiStundenBisJetzt() async throws {
        let (_, m) = try mitSchlaf(480)
        await m.lade()
        let e = try XCTUnwrap(m.stand?.energie)
        XCTAssertEqual(e.verlauf.map(\.stunde), [6, 9, 12])
        XCTAssertEqual(e.verlauf.last?.akku, e.ergebnis.akku, "der letzte Punkt ist die Zahl von jetzt")
    }

    func testGefuehlWirdMitDenRohwertenGespeichert() async throws {
        let (u, m) = try mitSchlaf(480)
        await m.lade()
        XCTAssertNil(m.stand?.energie.gefuehl)
        m.speichereGefuehl(4)
        XCTAssertEqual(m.stand?.energie.gefuehl, 4)
        let datei = try XCTUnwrap(u.daten).ordner.appendingPathComponent(TagesformGefuehl.dateiname)
        let gelesen = TagesformGefuehl.laden(datei)
        XCTAssertEqual(gelesen.map(\.gefuehl), [4])
        XCTAssertEqual(gelesen.first?.tag, heute)
        XCTAssertEqual(gelesen.first?.eingabe.schlaf.first, 480)
        m.speichereGefuehl(99)
        XCTAssertEqual(m.stand?.energie.gefuehl, 5, "außerhalb 1 bis 5 wird begrenzt")
    }

    // MARK: Gewohnheiten

    func testHakenUndZaehlerPerTipp() throws {
        let u = try umgebung()
        let m = HeuteModell(umgebung: u)
        m.berechne()
        func zeile(_ id: String) throws -> HeuteHabitZeile { try XCTUnwrap(m.stand?.habits.first { $0.id == id }) }
        XCTAssertEqual(try zeile("gym").erledigt, false)
        m.tippe(try zeile("gym"))
        XCTAssertEqual(try zeile("gym").erledigt, true)
        XCTAssertEqual(m.stand?.boegen[1].zahl, "1 von 3", "der Gym-Haken füllt den Gym-Bogen")
        m.tippe(try zeile("gym"))
        XCTAssertEqual(try zeile("gym").erledigt, false, "zweiter Tipp nimmt den Haken weg")

        m.tippe(try zeile("wasser"))
        m.tippe(try zeile("wasser"))
        XCTAssertEqual(try zeile("wasser").wert, 2)
        XCTAssertEqual(try zeile("wasser").zaehlerText, "2 von 8")
        m.weniger(try zeile("wasser"))
        XCTAssertEqual(try zeile("wasser").wert, 1)
        m.weniger(try zeile("wasser"))
        m.weniger(try zeile("wasser"))
        XCTAssertEqual(try zeile("wasser").wert, 0, "unter null geht es nicht")
    }

    func testSerieInTagenUndWochen() throws {
        let u = try umgebung()
        let daten = try XCTUnwrap(u.daten)
        daten.habits.anlegen(Habit(id: "dehnen", name: "Dehnen", symbol: "figure.yoga", farbe: HabitFarbe.grau.rawValue, zaehlen: false, tagesziel: nil, haeufigkeit: .taeglich, fuer: "ich"))
        for zurueck in 1...3 { daten.habits.setze("dehnen", datum: Datum.addTage(heute, -zurueck), wert: 1) }
        let m = HeuteModell(umgebung: u)
        m.berechne()
        let dehnen = try XCTUnwrap(m.stand?.habits.first { $0.id == "dehnen" })
        XCTAssertEqual(dehnen.serie, 3)
        XCTAssertEqual(dehnen.serieText, "Serie: 3 Tage")
        let gym = try XCTUnwrap(m.stand?.habits.first { $0.id == "gym" })
        XCTAssertEqual(gym.serieText, nil, "ohne Wochenziel keine Serie")
    }

    // MARK: Gewicht

    func testGewichtSpeichernSchreibtLokalUndImmerNachHealth() async throws {
        let spur = HeuteSpurSchreiber()
        let u = try umgebung(schreiber: spur)
        let m = HeuteModell(umgebung: u)
        m.berechne()
        let erstes = await m.speichereGewicht(zehntel: 784)
        XCTAssertTrue(erstes)
        XCTAssertEqual(m.stand?.gewicht.aktuellKg ?? 0, 78.4, accuracy: 0.0001)
        XCTAssertEqual(m.stand?.gewicht.heuteEingetragen, true)
        XCTAssertEqual(spur.gewichte, [78.4], "immer nach Health, ohne Schalter")

        let zweites = await m.speichereGewicht(zehntel: 781)
        XCTAssertTrue(zweites)
        XCTAssertEqual(spur.gewichte, [78.4, 78.1])
    }

    func testGewichtAusserhalbDesBereichsWirdAbgelehnt() async throws {
        let m = HeuteModell(umgebung: try umgebung())
        m.berechne()
        let zuLeicht = await m.speichereGewicht(zehntel: 299)
        let zuSchwer = await m.speichereGewicht(zehntel: 2_501)
        XCTAssertFalse(zuLeicht)
        XCTAssertFalse(zuSchwer)
        XCTAssertNil(m.stand?.gewicht.aktuellKg)
    }

    func testGewichtVerlaufMitZielUndAenderung() async throws {
        let u = try umgebung()
        let daten = try XCTUnwrap(u.daten)
        daten.ziele.setze({ var z = Ziele(); z.gewichtKg = 75; return z }())
        daten.habits.setze(Habit.gewicht.id, datum: "2026-09-10", wert: 800)
        daten.habits.setze(Habit.gewicht.id, datum: "2026-09-20", wert: 790)
        let m = HeuteModell(umgebung: u)
        m.berechne()
        let g = try XCTUnwrap(m.stand?.gewicht)
        XCTAssertEqual(g.zielKg, 75)
        XCTAssertEqual(g.punkte.map(\.tag), ["2026-09-10", "2026-09-20"])
        XCTAssertEqual(g.aenderung, "−1,0 kg zur Vorwoche")
        XCTAssertEqual(g.startZehntel, 790)
        XCTAssertFalse(g.heuteEingetragen)
        XCTAssertEqual(m.stand?.planWoche.count, 7)
        XCTAssertEqual(m.stand?.planWoche.firstIndex(where: \.istHeute), 3)
    }

    func testGewichtszielAusDemBlattWirktAufKarteUndZiele() throws {
        let u = try umgebung()
        let m = HeuteModell(umgebung: u)
        m.berechne()
        m.setzeGewichtsziel(80)
        XCTAssertEqual(m.stand?.gewicht.zielKg, 80)
        XCTAssertEqual(u.daten?.ziele.ziele.gewichtKg, 80)
        m.setzeGewichtsziel(nil)
        XCTAssertNil(m.stand?.gewicht.zielKg)
    }

    func testHealthGewichtUndHandEintragAmSelbenTagDerHandEintragGewinnt() async throws {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 1)], gewichte: [GewichtsMesswert(tag: heute, kg: 80.0)])
        let u = try umgebung(leser: leser)
        u.daten?.habits.setze(Habit.gewicht.id, datum: heute, wert: 777)
        let m = HeuteModell(umgebung: u)
        await m.lade()
        XCTAssertEqual(m.stand?.gewicht.aktuellKg ?? 0, 77.7, accuracy: 0.0001)
    }

    // MARK: Hinweise

    func testHoechstensDreiHinweiseUndWeggewischteRuecken() async throws {
        let leser = FakeHealthLeser(
            tage: (0...3).map { TagesWerte(tag: Datum.addTage(heute, -$0), schritte: 11_000) },
            naechte: [nacht(heute, minuten: 330), nacht("2026-09-22", minuten: 340)])
        let u = try umgebung(leser: leser)
        let daten = try XCTUnwrap(u.daten)
        for zurueck in 1...3 { daten.habits.setzeGym(datum: Datum.addTage(heute, -zurueck), an: true) }
        daten.habits.setze(Habit.gewicht.id, datum: "2026-09-13", wert: 800)
        let m = HeuteModell(umgebung: u)
        await m.lade()
        // Vier Anlässe (kurze Nächte, drei Gym-Tage, lange nicht gewogen, Schritt-Serie), gezeigt werden drei.
        XCTAssertEqual(m.stand?.hinweise.map(\.id), ["schlaf-kurz-2026-09-23", "gym-folge-2026-09-23", "gewicht-2026-09-23"])
        m.wischeHinweis("schlaf-kurz-2026-09-23")
        XCTAssertEqual(m.stand?.hinweise.map(\.id), ["gym-folge-2026-09-23", "gewicht-2026-09-23", "schritte-serie-2026-09-23"])
        XCTAssertLessThanOrEqual(m.stand?.hinweise.count ?? 0, TagesHinweisLogik.hoechstens)
        // Ein neues Modell (App-Neustart) liest die weggewischten aus der Datei.
        let neu = HeuteModell(umgebung: u)
        neu.berechne()
        XCTAssertEqual(neu.stand?.hinweise.first?.id, "gym-folge-2026-09-23")
    }

    // MARK: Plan

    func testPlanKarteZeigtDenHeutigenTagUndErledigtNachDemHaken() throws {
        let u = try umgebung()
        let daten = try XCTUnwrap(u.daten)
        plan(daten)
        let m = HeuteModell(umgebung: u)
        m.berechne()
        XCTAssertEqual(m.stand?.plan.art, .training)
        XCTAssertEqual(m.stand?.plan.name, "Beine")
        XCTAssertEqual(m.stand?.plan.tagID, "t1")
        daten.habits.setzeGym(datum: heute, an: true)
        m.berechne()
        XCTAssertEqual(m.stand?.plan.art, .erledigt)
        XCTAssertEqual(m.stand?.stimmung, .ziel)
    }

    // MARK: Mitternacht und Sommerzeit

    func testTagWechseltUmMitternachtUndLumiSchlaeftNachts() async throws {
        let u = try umgebung()
        u.daten?.habits.setzeWasser(datum: heute, anzahl: 5)
        let m = HeuteModell(umgebung: u)
        uhr.setze(Datum.datum(heute).addingTimeInterval(23 * 3600 + 59 * 60 + 30))
        m.berechne()
        XCTAssertEqual(m.stand?.tag, heute)
        XCTAssertEqual(m.stand?.stunde, 23)
        XCTAssertEqual(m.stand?.stimmung, .schlaeft)
        XCTAssertEqual(m.stand?.habits.first { $0.id == "wasser" }?.wert, 5)

        uhr.setze(Datum.datum("2026-09-24").addingTimeInterval(30))
        m.berechne()
        XCTAssertEqual(m.stand?.tag, "2026-09-24")
        XCTAssertEqual(m.stand?.stunde, 0)
        XCTAssertEqual(m.stand?.habits.first { $0.id == "wasser" }?.wert, 0, "der neue Tag beginnt bei null")
        XCTAssertEqual(m.stand?.woche.first { $0.istHeute }?.tag, "2026-09-24")

        uhr.setze(Datum.datum("2026-09-24").addingTimeInterval(8 * 3600))
        m.berechne()
        XCTAssertNotEqual(m.stand?.stimmung, .schlaeft)
    }

    func testWocheWechseltAmMontagNachDemSommerzeitEnde() throws {
        let m = HeuteModell(umgebung: try umgebung())
        // Sonntag, 25.10.2026, 23:30: der Tag hat 25 Stunden.
        uhr.setze(Datum.datum("2026-10-25").addingTimeInterval(24 * 3600 + 30 * 60))
        m.berechne()
        XCTAssertEqual(m.stand?.tag, "2026-10-25", "um 23:30 Winterzeit (24 Stunden nach Mitternacht) ist es noch Sonntag")
        XCTAssertEqual(m.stand?.woche.first?.tag, "2026-10-19")
        uhr.setze(Datum.datum("2026-10-26").addingTimeInterval(30 * 60))
        m.berechne()
        XCTAssertEqual(m.stand?.tag, "2026-10-26")
        XCTAssertEqual(m.stand?.woche.first?.tag, "2026-10-26")
        XCTAssertEqual(m.stand?.woche.first?.istHeute, true)
    }

    func testProfilwechselRechnetMitDemNeuenDatensatz() throws {
        let u = try umgebung()
        u.daten?.habits.setzeWasser(datum: heute, anzahl: 4)
        let m = HeuteModell(umgebung: u)
        m.berechne()
        XCTAssertEqual(m.stand?.habits.first { $0.id == "wasser" }?.wert, 4)
        try u.profil.anlegen(name: "Zwei", passwort: "efgh")
        m.berechne()
        XCTAssertEqual(m.stand?.habits.first { $0.id == "wasser" }?.wert, 0, "das zweite Profil hat eigene Daten")
    }
}

/// Eingefrorene Dateien vom letzten Stand: Neue Felder müssen alte Dateien weiter lesen (`SPEC.md` 5.3).
final class HeuteAlteDateienTests: XCTestCase {
    func testGefuehlDateiVomLetztenStandLaesstSichLesen() throws {
        let json = """
        [{"tag":"2026-09-20","gefuehl":3,"akku":61,"formel":2,"gespeichert":1790000000,\
        "eingabe":{"stunde":24,"schlafZiel":480,"schlaf":[420,450],"bett":[600],"schlafSicherheit":1,"ruhepuls":[],"hrv":[],"muskeln":[],"saetze":[]}}]
        """
        let datei = try tempOrdner().appendingPathComponent(TagesformGefuehl.dateiname)
        try Data(json.utf8).write(to: datei)
        let liste = TagesformGefuehl.laden(datei)
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?.gefuehl, 3)
        XCTAssertEqual(liste.first?.eingabe.schlaf, [420, 450])
        XCTAssertNil(liste.first?.eingabe.schritte)
    }

    @MainActor
    func testHinweiseDateiVomLetztenStandLaesstSichLesen() throws {
        let ordner = try tempOrdner()
        try Data(#"["gewicht-2026-09-01","wasser-2026-09-02"]"#.utf8).write(to: ordner.appendingPathComponent(TagesHinweisSpeicher.dateiname))
        XCTAssertEqual(TagesHinweisSpeicher(ordner: ordner).weggewischt, ["gewicht-2026-09-01", "wasser-2026-09-02"])
    }

    @MainActor
    func testKaputteHinweiseDateiStartetLeerStattMitAbsturz() throws {
        let ordner = try tempOrdner()
        try Data("kein json".utf8).write(to: ordner.appendingPathComponent(TagesHinweisSpeicher.dateiname))
        XCTAssertTrue(TagesHinweisSpeicher(ordner: ordner).weggewischt.isEmpty)
    }
}
