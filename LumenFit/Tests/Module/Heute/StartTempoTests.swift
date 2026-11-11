import XCTest
@testable import LumenFit

/// Misst den Start mit einem Datenstand wie nach dem Lovea-Import (rund 7500 Ops: Schritte, Gewohnheiten, Gym, Essen).
/// Die Zeiten stehen im Log (`START-TEMPO`); geprüft wird nur eine grobe Obergrenze, damit ein Rückschritt auffällt.
@MainActor
final class StartTempoTests: XCTestCase {
    private struct SchritteD: Encodable { let datum: String; let anzahl: Int }

    func testStartMitVielenOps() throws {
        let ordner = try tempOrdner()
        let uhr = TestUhr()
        let schluessel = SpeicherSchluesselbund()
        func umgebung() -> AppUmgebung {
            AppUmgebung(ordner: ordner, schluesselbund: schluessel, http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                        leser: FakeHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
        }

        // Saat (nicht gemessen)
        let saat = umgebung()
        try saat.profil.anlegen(name: "Test", passwort: "abcd")
        let ich = try XCTUnwrap(saat.profil.aktiv?.id)
        let raum = try XCTUnwrap(saat.daten?.raum)
        let jetzt = uhr.uhr()
        let heute = Datum.text(jetzt)
        for i in 0..<400 {
            let tag = Datum.addTage(heute, -i), zeit = Datum.datum(tag).addingTimeInterval(20 * 3600)
            for k in 0..<10 { raum.einreihen(TestDaten.op("schritte.setzen", SchritteD(datum: tag, anzahl: 800 * (k + 1)), von: ich, zeit: zeit + Double(k))) }
            guard i < 365 else { continue }
            for op in TestDaten.habitOps(von: ich, datum: tag, zeit: zeit) { raum.einreihen(op) }
            for art in ["kreatin", "lesen", "dehnen"] {
                raum.einreihen(TestDaten.op("habit.setzen", HabitSetzenD(art: art, datum: tag, wert: 1), von: ich, zeit: zeit))
            }
            if i < 300 { for op in TestDaten.essenOps(von: ich, datum: tag, zeit: zeit) { raum.einreihen(op) } }
            if i % 3 == 0 && i < 360 {
                let s = "s\(i)", start = Datum.datum(tag).addingTimeInterval(17 * 3600)
                raum.einreihen(TestDaten.op("gym.checkin", GymD(session: s, tag: "push", start: start), von: ich, zeit: start))
                for u in 0..<5 {
                    let saetze = (0..<3).map { _ in PlanSatz(wdh: 8, kg: 40 + Double(u * 5 + i % 7), failure: false, ok: true) }
                    raum.einreihen(TestDaten.op("gym.uebung", GymD(session: s, plan: "p1", uebung: "u\(u)", status: "satz", saetze: saetze), von: ich, zeit: start + Double(u * 600)))
                    raum.einreihen(TestDaten.op("gym.uebung", GymD(session: s, plan: "p1", uebung: "u\(u)", status: "fertig", saetze: saetze), von: ich, zeit: start + Double(u * 600 + 500)))
                }
                raum.einreihen(TestDaten.op("gym.checkout", GymD(session: s, ende: start + 3600, status: "ende"), von: ich, zeit: start + 3600))
            }
        }
        let anzahl = raum.anzahl
        let logDatei = try XCTUnwrap(saat.daten?.ordner).appendingPathComponent("ops.jsonl")

        // Start wie in der App, Schritt für Schritt
        let uhrStart = ContinuousClock.now
        var marken: [(String, Duration)] = []
        var letzte = uhrStart
        func marke(_ name: String) { let n = ContinuousClock.now; marken.append((name, n - letzte)); letzte = n }

        var log = LokalerOpLog(datei: logDatei)
        XCTAssertEqual(log.lade().count, anzahl); marke("log")
        let u = umgebung(); marke("umgebung")
        let daten = try XCTUnwrap(u.daten); marke("datensatz")
        _ = daten.training.sessions; marke("sessions")
        u.beobachteHealth(); marke("health")
        let sitzung = GymSitzung.von(u); sitzung.ladeWennNoetig(); _ = sitzung.eigene; marke("gym")
        FortschrittModul.start(u); marke("fortschritt")
        EssenModul.start(u); marke("essen")
        WidgetsModul.start(u, senke: WidgetsTestSenke(), fabrik: WidgetsTestFabrik(), neuladen: {}); marke("widgets")
        let modell = HeuteModell(umgebung: u)
        modell.berechne(); marke("heute1")
        modell.berechne(); marke("heute2")
        let gesamt = ContinuousClock.now - uhrStart

        let text = marken.map { "\($0.0)=\(Int(NutzungMass.sekunden($0.1) * 1000))ms" }.joined(separator: " ")
        print("START-TEMPO ops=\(anzahl) \(text) gesamt=\(Int(NutzungMass.sekunden(gesamt) * 1000))ms")
        XCTAssertNotNil(modell.stand)
        XCTAssertLessThan(NutzungMass.sekunden(gesamt), 10)
    }
}
