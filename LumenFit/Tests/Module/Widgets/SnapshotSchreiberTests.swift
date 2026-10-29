import XCTest
@testable import LumenFit

/// Der Bauer macht aus den Werten des Profils den Snapshot (rein); der Schreiber legt ihn in den Gruppenordner (hier ein Temp-Ordner) und lädt die Widgets nur bei Änderung neu.
@MainActor
final class SnapshotSchreiberTests: XCTestCase {
    private let uhr = TestUhr()   // Mittwoch 23.09.2026, 12:00 Berlin
    private var heute: String { Datum.text(uhr.lesen) }

    private func session(_ id: String, tag: String, stunde: Double = 10) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(stunde * 3600)
        return GymSession(id: id, tag: nil, start: start, ende: start.addingTimeInterval(3600), laeufe: [])
    }

    private func plan() -> TrainingsPlan {
        TrainingsPlan(tage: [TrainingsTag(id: "push", name: "Push", wochentage: [1, 3, 5], uebungen: []),
                             TrainingsTag(id: "pull", name: "Pull", wochentage: [2, 6], uebungen: [])])
    }

    private func eingabe(sessions: [GymSession] = [], habits: [WidgetHabitEingabe] = []) -> WidgetEingabe {
        WidgetEingabe(jetzt: uhr.lesen, profilName: "Beispiel", profilKennung: "p1", thema: .stahl, erscheinung: .system, ziele: Ziele(), schritte: 8_412,
                      schlafMinuten: 432, hrv: 68, sessions: sessions, plan: plan(), kcal: 1_560, kcalZiel: 2_400, protein: 98, proteinZiel: 140,
                      habits: habits, lumi: .stolz, lumiStufe: 3)
    }

    // MARK: - Bauer (rein)

    func testBauerFuelltBoegenEssenUndKopf() {
        let s = WidgetSnapshotBauer.baue(eingabe())
        XCTAssertEqual(s.tag, "2026-09-23")
        XCTAssertEqual(s.thema, .stahl)
        XCTAssertEqual(s.lumi, .stolz)
        XCTAssertEqual(s.profilKennung, "p1")
        XCTAssertEqual(s.boegen?.schritte, 8_412)
        XCTAssertEqual(s.boegen?.schritteZiel, Ziele().schritte)
        XCTAssertEqual(s.boegen?.schlafMinuten, 432)
        XCTAssertEqual(s.boegen?.hrv, 68)
        XCTAssertEqual(s.essen, WidgetEssenStand(kcal: 1_560, kcalZiel: 2_400, protein: 98, proteinZiel: 140))
    }

    func testTrainingTageZaehlenVerschiedeneTageDerWoche() {
        let liste = [session("a", tag: "2026-09-21"), session("b", tag: "2026-09-21", stunde: 18), session("c", tag: "2026-09-23"),
                     session("d", tag: "2026-09-16")]   // letzte Woche
        XCTAssertEqual(WidgetSnapshotBauer.trainingTage(liste, heute: heute), 2)
        XCTAssertEqual(WidgetSnapshotBauer.baue(eingabe(sessions: liste)).boegen?.trainingTage, 2)
    }

    func testSerieZaehltWochenInFolge() {
        let liste = [session("a", tag: "2026-09-22"), session("b", tag: "2026-09-15"), session("c", tag: "2026-09-08")]
        XCTAssertEqual(WidgetSnapshotBauer.baue(eingabe(sessions: liste)).serieWochen, 3)
        XCTAssertEqual(WidgetSnapshotBauer.baue(eingabe()).serieWochen, 0)
    }

    func testNaechsterTagIstHeuteOderNachTrainingMorgenOderSpaeter() {
        // Mittwoch (3) ist Push-Tag.
        XCTAssertEqual(WidgetSnapshotBauer.naechsterTag(plan: plan(), sessions: [], heute: heute), WidgetPlanTag(name: "Push", tag: "2026-09-23"))
        // War heute schon Training, kommt der nächste Plantag: Donnerstag ist frei, Freitag (5) ist Push.
        let nach = WidgetSnapshotBauer.naechsterTag(plan: plan(), sessions: [session("a", tag: "2026-09-23")], heute: heute)
        XCTAssertEqual(nach, WidgetPlanTag(name: "Push", tag: "2026-09-25"))
    }

    func testNaechsterTagOhnePlanIstNil() {
        XCTAssertNil(WidgetSnapshotBauer.naechsterTag(plan: TrainingsPlan(tage: []), sessions: [], heute: heute))
    }

    func testKachelZaehltZielUndWertHeute() {
        let wasser = WidgetSnapshotBauer.kachel(WidgetHabitEingabe(habit: .wasser, werte: [heute: 5, "2026-09-22": 8, "2026-09-21": 8], ziel: 8), heute: heute)
        XCTAssertEqual(wasser.ziel, 8)
        XCTAssertEqual(wasser.heute, 5)
        XCTAssertTrue(wasser.zaehlen)
        XCTAssertEqual(wasser.serie, 2, "gestern und vorgestern erfüllt, heute noch offen bricht die Serie nicht")
        let gym = WidgetSnapshotBauer.kachel(WidgetHabitEingabe(habit: .gym, werte: [:], ziel: 3), heute: heute)
        XCTAssertEqual(gym.ziel, 1, "nicht zählende Gewohnheiten haben das Ziel 1")
        XCTAssertEqual(gym.heute, 0)
    }

    func testHoechstensSechsGewohnheiten() {
        let acht = (1...8).map { i in
            WidgetHabitEingabe(habit: Habit(id: "h\(i)", name: "Habit \(i)", symbol: "star.fill", farbe: HabitFarbe.mint.rawValue, zaehlen: false, tagesziel: nil,
                                            haeufigkeit: .taeglich, fuer: "ich"), werte: [:], ziel: nil)
        }
        XCTAssertEqual(WidgetSnapshotBauer.baue(eingabe(habits: acht)).habits?.count, WidgetSnapshotBauer.hoechstensHabits)
    }

    // MARK: - Schreiber

    func testSchreibtDenSnapshotDesAktivenProfilsUndLaedtNurBeiAenderungNeu() throws {
        let ordner = try tempOrdner()
        let u = try WidgetsTestUmgebung.neu(ordner: ordner, uhr: uhr)
        let daten = try XCTUnwrap(u.daten)
        let zaehler = WidgetsTestZaehler()
        let schreiber = WidgetSnapshotSchreiber(umgebung: u, neuladen: { zaehler.erhoehe() })

        XCTAssertTrue(schreiber.schreibeJetzt())
        let erster = try XCTUnwrap(WidgetSnapshotDatei.lade(ordner: ordner))
        XCTAssertEqual(erster.profilName, "Beispiel")
        XCTAssertEqual(erster.profilKennung, daten.profil.rawValue)
        XCTAssertEqual(erster.tag, heute)
        XCTAssertEqual(erster.lumi, .bereit)
        XCTAssertEqual(erster.habits?.map(\.id), ["gym", "wasser"])
        XCTAssertEqual(zaehler.wert, 1)

        XCTAssertFalse(schreiber.schreibeJetzt(), "unveränderter Inhalt: nichts schreiben, nichts neu laden")
        XCTAssertEqual(zaehler.wert, 1)

        daten.habits.setze("wasser", datum: heute, wert: 3)
        XCTAssertTrue(schreiber.schreibeJetzt())
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.habits?.first { $0.id == "wasser" }?.heute, 3)
        XCTAssertEqual(zaehler.wert, 2)
    }

    func testLumiStimmungKommtAusDerHeutigenOp() throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner(), uhr: uhr)
        let daten = try XCTUnwrap(u.daten)
        daten.raum.senden("fit.lumi.stimmung", StimmungsEintrag(tag: "2026-09-22", wert: 1, stimmung: .muede))
        XCTAssertEqual(WidgetSnapshotSchreiber.snapshot(u).lumi, .bereit, "eine Stimmung von gestern zählt nicht")
        daten.raum.senden("fit.lumi.stimmung", StimmungsEintrag(tag: heute, wert: 5, stimmung: .stolz))
        XCTAssertEqual(WidgetSnapshotSchreiber.snapshot(u).lumi, .stolz)
    }

    func testEssenUndTrainingFliessenEin() throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner(), uhr: uhr)
        let daten = try XCTUnwrap(u.daten)
        for op in TestDaten.essenOps(von: daten.profil, datum: heute, zeit: uhr.lesen) { daten.raum.einreihen(op) }
        for op in TestDaten.gymOps(von: daten.profil, start: uhr.lesen.addingTimeInterval(-7200)) { daten.raum.einreihen(op) }
        let s = WidgetSnapshotSchreiber.snapshot(u)
        XCTAssertEqual(s.essen?.kcal, 222, "60 g Haferflocken mit 370 kcal je 100 g")
        XCTAssertEqual(s.boegen?.trainingTage, 1)
        XCTAssertEqual(s.serieWochen, 1)
    }

    func testOhneProfilGibtEsEinenLeerenSnapshot() throws {
        let ordner = try tempOrdner()
        let u = try WidgetsTestUmgebung.neu(ordner: ordner, uhr: uhr, profil: false)
        let schreiber = WidgetSnapshotSchreiber(umgebung: u, neuladen: {})
        XCTAssertTrue(schreiber.schreibeJetzt())
        let s = try XCTUnwrap(WidgetSnapshotDatei.lade(ordner: ordner))
        XCTAssertNil(s.profilName)
        XCTAssertNil(s.boegen)
        XCTAssertNil(s.habits)
    }

    func testEinNichtBestaetigterVorabHakenWirdUeberschrieben() throws {
        let ordner = try tempOrdner()
        let u = try WidgetsTestUmgebung.neu(ordner: ordner, uhr: uhr)
        let schreiber = WidgetSnapshotSchreiber(umgebung: u, neuladen: {})
        schreiber.schreibeJetzt()
        let kennung = try XCTUnwrap(u.profil.aktiv?.id.rawValue)
        WidgetHabitAktion.abhaken(habit: "gym", wert: 1, tag: heute, profil: kennung, ordner: ordner)
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.habits?.first { $0.id == "gym" }?.heute, 1)
        // Die App hat die Op nicht übernommen: der nächste Lauf zeigt wieder den Stand der Daten.
        XCTAssertTrue(schreiber.schreibeJetzt())
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.habits?.first { $0.id == "gym" }?.heute, 0)
    }

    func testDemoSaatSchreibtBeispielwerteImThemaDesProfils() throws {
        let ordner = try tempOrdner()
        let u = try WidgetsTestUmgebung.neu(ordner: ordner, uhr: uhr)
        u.daten?.einstellungen.aendere { $0.thema = .glut }
        WidgetsModul.demoSaat(u)
        let s = try XCTUnwrap(WidgetSnapshotDatei.lade(ordner: ordner))
        XCTAssertEqual(s.thema, .glut)
        XCTAssertEqual(s.boegen?.schritte, 8_412)
        XCTAssertEqual(s.profilKennung, u.profil.aktiv?.id.rawValue)
    }

    // MARK: - Drossel

    @MainActor private struct Aufbau {
        let uhr: TestUhr
        let laeufe: WidgetsTestZaehler
        let verzoegerung: WidgetsTestVerzoegerung
        let drossel: WidgetsDrossel

        init() {
            let uhr = TestUhr(), laeufe = WidgetsTestZaehler(), verzoegerung = WidgetsTestVerzoegerung()
            self.uhr = uhr
            self.laeufe = laeufe
            self.verzoegerung = verzoegerung
            self.drossel = WidgetsDrossel(uhr: uhr.uhr, aktion: { laeufe.erhoehe() }, verzoegere: { verzoegerung.merke($0, $1) })
        }
    }

    func testVieleAnforderungenErgebenHoechstensEinenLaufJe30SekundenUndEinNachholen() {
        let a = Aufbau()
        for _ in 0..<20 {
            a.drossel.anfordern()
            a.uhr.vor(sekunden: 1)
        }
        XCTAssertEqual(a.laeufe.wert, 1)
        XCTAssertEqual(a.verzoegerung.wartezeiten.count, 1, "genau ein Nachholen ist geplant")
    }

    func testDieLetzteAenderungGehtNichtVerloren() throws {
        let a = Aufbau()
        a.drossel.anfordern()
        a.uhr.vor(sekunden: 5)
        a.drossel.anfordern()
        let wartezeit = try XCTUnwrap(a.verzoegerung.wartezeiten.first)
        XCTAssertEqual(wartezeit, 25, accuracy: 0.5)
        a.uhr.vor(sekunden: wartezeit)
        a.verzoegerung.fuehreAlleAus()
        XCTAssertEqual(a.laeufe.wert, 2)
        a.verzoegerung.fuehreAlleAus()
        XCTAssertEqual(a.laeufe.wert, 2, "nicht doppelt")
    }

    func testNachDemAbstandLaeuftDieNaechsteAnforderungSofort() {
        let a = Aufbau()
        a.drossel.anfordern()
        a.uhr.vor(sekunden: 31)
        a.drossel.anfordern()
        XCTAssertEqual(a.laeufe.wert, 2)
        XCTAssertTrue(a.verzoegerung.wartezeiten.isEmpty)
    }

    func testSofortUmgehtDenAbstandUndEineUeberholteAufgabeTutNichts() {
        let a = Aufbau()
        a.drossel.anfordern()
        a.uhr.vor(sekunden: 5)
        a.drossel.anfordern()                 // geplant für +25 s
        a.uhr.vor(sekunden: 5)
        a.drossel.anfordern(sofort: true)     // läuft sofort, erledigt das Geplante
        XCTAssertEqual(a.laeufe.wert, 2)
        a.uhr.vor(sekunden: 15)
        a.drossel.anfordern()                 // neu geplant, nur 20 s nach dem sofortigen Lauf
        a.verzoegerung.fuehreAus(0)           // die alte Aufgabe wäre jetzt fällig
        XCTAssertEqual(a.laeufe.wert, 2, "die überholte Aufgabe läuft nicht")
        a.uhr.vor(sekunden: 20)
        a.verzoegerung.fuehreAus(1)
        XCTAssertEqual(a.laeufe.wert, 3)
    }

    // MARK: - Portiert: WidgetThrottle (Lovea, WidgetStandTests)

    func testWartezeitDirektNachSchreibenIstVolleFrist() {
        let jetzt = Date()
        XCTAssertEqual(WidgetsDrossel.wartezeit(zuletzt: jetzt, jetzt: jetzt, minAbstand: 15), 15)
    }

    func testWartezeitNachAblaufDerFristIstNull() {
        let zuletzt = Date()
        XCTAssertEqual(WidgetsDrossel.wartezeit(zuletzt: zuletzt, jetzt: zuletzt.addingTimeInterval(20), minAbstand: 15), 0)
    }

    func testWartezeitInDerMitteDerFrist() {
        let zuletzt = Date()
        XCTAssertEqual(WidgetsDrossel.wartezeit(zuletzt: zuletzt, jetzt: zuletzt.addingTimeInterval(5), minAbstand: 15), 10, accuracy: 0.001)
    }
}
