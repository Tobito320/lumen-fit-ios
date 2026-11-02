import UIKit
import XCTest
@testable import LumenFit

/// Zählt, welche Methoden die Probe aufruft (Rechte fragen darf sie nie).
// @unchecked Sendable: der Zähler hängt hinter einem NSLock, `innen` ist selbst thread-sicher.
private final class ProfilZaehlLeser: HealthLeser, @unchecked Sendable {
    private let schloss = NSLock()
    private var _zugriffe = 0
    let innen: FakeHealthLeser

    init(_ innen: FakeHealthLeser) { self.innen = innen }

    var zugriffe: Int { schloss.withLock { _zugriffe } }

    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff { schloss.withLock { _zugriffe += 1 }; return await innen.zugriff(fuer: typen) }
    func tagesWerte(von: String, bis: String) async -> [TagesWerte] { await innen.tagesWerte(von: von, bis: bis) }
    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] { await innen.schlafNaechte(von: von, bis: bis) }
    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] { await innen.vitalwerte(art, von: von, bis: bis) }
    func gewichte(von: String, bis: String) async -> [GewichtsMesswert] { await innen.gewichte(von: von, bis: bis) }
    func workouts(von: String, bis: String) async -> [HealthWorkout] { await innen.workouts(von: von, bis: bis) }
    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) { innen.beobachte(typen, bei: aenderung) }
}

final class ProfilHealthTests: XCTestCase {
    private let verboten = ["erlaubt", "abgelehnt", "verweigert"]

    func testZusammenfassungZaehltTypenMitDaten() {
        let leer = ProfilHealthProbe.Befund()
        XCTAssertEqual(ProfilHealthProbe.zusammenfassung(leer), "0 von \(HealthTyp.allCases.count) mit Daten")
        let befund = ProfilHealthProbe.Befund(tage: [TagesWerte(tag: "2026-09-23", schritte: 5_000)])
        XCTAssertEqual(ProfilHealthProbe.zusammenfassung(befund), "1 von \(HealthTyp.allCases.count) mit Daten")
    }

    private func alleTexte() -> [String] {
        var texte = [ProfilHealthProbe.wegText]
        for typ in HealthTyp.allCases { texte += [ProfilHealthProbe.name(typ), ProfilHealthProbe.grund(typ)] }
        for zeile in [ProfilHealthZeile.datenDa, .keineDaten, .nichtPruefbar] { texte.append(ProfilHealthProbe.text(zeile)) }
        return texte
    }

    func testKeinSatzBehauptetErlaubtOderAbgelehnt() {
        for text in alleTexte() + [ProfilHealthProbe.erklaerung] {
            for wort in verboten { XCTAssertFalse(text.lowercased().contains(wort), "\"\(text)\" sagt \(wort)") }
        }
    }

    func testDieZeilenSindDatenDaOderKeineDaten() {
        XCTAssertEqual(ProfilHealthProbe.text(.datenDa), "Daten da")
        XCTAssertEqual(ProfilHealthProbe.text(.keineDaten), "keine Daten in 30 Tagen")
    }

    func testJederTypHatNameGrundUndSymbol() {
        XCTAssertEqual(HealthTyp.allCases.count, 14, "Stehen wird nicht mehr gelesen")
        for typ in HealthTyp.allCases {
            XCTAssertFalse(ProfilHealthProbe.name(typ).isEmpty)
            XCTAssertFalse(ProfilHealthProbe.grund(typ).isEmpty)
            XCTAssertNotNil(UIImage(systemName: ProfilHealthProbe.symbol(typ)), "SF Symbol fehlt: \(ProfilHealthProbe.symbol(typ))")
        }
        for name in ["checkmark.circle.fill", "circle.dashed", "questionmark.circle"] { XCTAssertNotNil(UIImage(systemName: name), name) }
    }

    func testLeererBefundSagtKeineDatenOderNichtPruefbar() {
        let leer = ProfilHealthProbe.Befund()
        for typ in HealthTyp.allCases {
            let z = ProfilHealthProbe.zeile(typ, leer)
            XCTAssertEqual(z, typ == .puls ? .nichtPruefbar : .keineDaten, "\(typ)")
        }
    }

    func testVollerBefundSagtDatenDa() {
        let t = TagesWerte(tag: "2026-09-22", schritte: 8_000, distanzMeter: 5_000, etagen: 6, aktiveKcal: 400, trainingMinuten: 30, stehStunden: 9)
        var b = ProfilHealthProbe.Befund(tage: [t])
        b.naechte = [SchlafNacht(tag: "2026-09-22", von: Date(), bis: Date().addingTimeInterval(3_600), abschnitte: [], schlafMinuten: 60)]
        b.gewichte = [GewichtsMesswert(tag: "2026-09-22", kg: 78)]
        for art in VitalArt.allCases { b.vitale[art] = [VitalMesswert(art: art, tag: "2026-09-22", wert: 50)] }
        b.workouts = [HealthWorkout(id: "w", art: "Krafttraining", start: Date(), ende: Date(), kcal: 200, puls: 120)]
        for typ in HealthTyp.allCases { XCTAssertEqual(ProfilHealthProbe.zeile(typ, b), .datenDa, "\(typ)") }
    }

    func testNullwerteZaehlenAlsKeineDaten() {
        let t = TagesWerte(tag: "2026-09-22", schritte: 0, distanzMeter: 0, etagen: 0, aktiveKcal: 0, trainingMinuten: 0, stehStunden: 0)
        let b = ProfilHealthProbe.Befund(tage: [t])
        for typ in [HealthTyp.schritte, .distanz, .etagen, .aktiveEnergie, .training] {
            XCTAssertEqual(ProfilHealthProbe.zeile(typ, b), .keineDaten, "\(typ)")
        }
    }

    func testProbeLiestNurDieLetztenDreissigTageUndFragtKeineRechte() async {
        let fake = FakeHealthLeser(tage: [TagesWerte(tag: "2026-09-20", schritte: 7_000), TagesWerte(tag: "2026-07-01", etagen: 12)])
        let leser = ProfilZaehlLeser(fake)
        let befund = await ProfilHealthProbe.probe(leser: leser, heute: "2026-09-23")
        XCTAssertEqual(leser.zugriffe, 0, "die Probe fragt nie nach Rechten")
        XCTAssertEqual(ProfilHealthProbe.zeile(.schritte, befund), .datenDa)
        XCTAssertEqual(ProfilHealthProbe.zeile(.etagen, befund), .keineDaten, "der Eintrag vom Juli liegt außerhalb von 30 Tagen")
        XCTAssertEqual(fake.tagesAbfragen.first?.von, "2026-08-25")
        XCTAssertEqual(fake.tagesAbfragen.first?.bis, "2026-09-23")
    }
}
