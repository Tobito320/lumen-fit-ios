import XCTest
@testable import LumenFit

/// Der Regelcoach (Idee 62) gegen `CoachKontext`: er antwortet ohne Modell, hält die Tonregeln ein, fragt bei fehlenden Daten nach.
final class RegelCoachMotorTests: XCTestCase {
    private let heute = "2026-10-08"
    private let normal = CoachTestBau.kontext()
    private let leer = CoachTestBau.kontext(bereitschaft: nil, schlafMinuten: nil, schritte: nil, letztesTraining: nil)
    private let schwer = CoachTestBau.kontext(bereitschaft: 30, schlafMinuten: 300, stimmung: .muede)

    private let fragen = [
        "Wie fühle ich mich?", "Was soll ich heute essen?", "Was esse ich noch?", "Wie läuft mein Training?", "Tagesbericht",
        "Mach meinen Wochenrückblick", "Was habe ich heute noch nicht eingetragen?", "Wie habe ich geschlafen?",
        "Wie viele Schritte bin ich gelaufen?", "Wie ist mein Gewicht?", "Hallo", "Danke", "Mein Knie tut weh", "Blablabla",
    ]

    /// Ein volles Bild mit erfundenen Zahlen.
    private func reich(kcalHeute: Double = 1200) -> CoachEingabe {
        var e = CoachEingabe(heute: heute)
        e.zieleEingerichtet = true
        e.proteinZiel = 140
        e.schrittZiel = 10_000
        e.essenKcal[heute] = kcalHeute
        e.essenProtein[heute] = 60
        for zurueck in 1...12 {
            e.essenKcal[Datum.addTage(heute, -zurueck)] = 2200
            e.essenProtein[Datum.addTage(heute, -zurueck)] = 120
        }
        for zurueck in 1...5 { e.schritte[Datum.addTage(heute, -zurueck)] = 7000 }
        for zurueck in 0...6 { e.gewicht[Datum.addTage(heute, -zurueck)] = 780 }
        e.gruppen = [CoachGruppe(name: "Brust", saetze: 2, ziel: 12, faellig: true)]
        e.uebungen = [CoachUebung(name: "Rudern", vorschlag: CoachSteigerung(kg: 40, wdh: 9, mehrGewicht: false))]
        return e
    }

    private func antwort(_ frage: String, _ kontext: CoachKontext, _ eingabe: CoachEingabe? = nil) async throws -> CoachAntwort {
        let motor = RegelCoachMotor(eingabe: { eingabe })
        return try await motor.antworte(CoachTestBau.anfrage(frage, kontext: kontext))
    }

    // MARK: - Verfügbarkeit

    func testDerRegelMotorIstImmerVerfuegbar() async {
        let verfuegbar = await RegelCoachMotor().verfuegbar()
        XCTAssertTrue(verfuegbar)
        XCTAssertEqual(RegelCoachMotor().name, "Regeln")
    }

    // MARK: - Ton: jede Antwort besteht die Prüfung

    func testJedeAntwortHaeltDiePersonaRegelnEin() async throws {
        let eingaben: [CoachEingabe?] = [nil, reich(), CoachEingabe(heute: heute)]
        for frage in fragen {
            for kontext in [normal, leer, schwer] {
                for eingabe in eingaben {
                    let a = try await antwort(frage, kontext, eingabe)
                    XCTAssertEqual(CoachAntwortPruefung.pruefe(a.text, frage: frage, kontext: kontext), [], "\(frage) -> \(a.text)")
                    XCTAssertLessThanOrEqual(a.chips.count, 2, "\(frage): höchstens zwei Chips")
                    XCTAssertFalse(a.text.contains("[["), "kein Marker im Text")
                }
            }
        }
    }

    // MARK: - Echte Zahlen

    func testAntwortenNennenDieEchtenZahlen() async throws {
        let schlaf = try await antwort("Wie habe ich geschlafen?", normal)
        XCTAssertTrue(schlaf.text.contains("7 h 30 min"), schlaf.text)
        let schritte = try await antwort("Wie viele Schritte bin ich gelaufen?", normal)
        XCTAssertTrue(schritte.text.contains("6.200"), schritte.text)
        XCTAssertTrue(schritte.text.contains("10.000"), schritte.text)
        let training = try await antwort("Wie läuft mein Training?", normal)
        XCTAssertTrue(training.text.contains("Push, gestern, 52 Minuten, 14 Sätze"), training.text)
        let gefuehl = try await antwort("Wie fühle ich mich?", normal)
        XCTAssertTrue(gefuehl.text.contains("72 von 100"), gefuehl.text)
    }

    func testEssenMitEingabeNenntLogUndRest() async throws {
        let essen = try await antwort("Was soll ich heute essen?", normal, reich())
        XCTAssertTrue(essen.text.contains("2.400 kcal"), essen.text)
        XCTAssertTrue(essen.text.contains("1.200 kcal"), essen.text)
        let rest = try await antwort("Was esse ich noch?", normal, reich())
        XCTAssertTrue(rest.text.contains("1.200 von 2.400"), rest.text)
        XCTAssertTrue(rest.text.contains("Protein"), rest.text)
    }

    func testTrainingMitEingabeNenntDenVorschlagFuersNaechsteMal() async throws {
        let a = try await antwort("Wie läuft mein Training?", normal, reich())
        XCTAssertTrue(a.text.contains("Rudern"), a.text)
        XCTAssertTrue(a.text.contains("40 kg × 9"), a.text)
    }

    // MARK: - Ehrlich, was er nicht weiß

    func testFehlendeDatenFuehrenZuEinerRueckfrage() async throws {
        for frage in ["Wie habe ich geschlafen?", "Wie viele Schritte bin ich gelaufen?", "Wie läuft mein Training?", "Wie fühle ich mich?"] {
            let a = try await antwort(frage, leer)
            XCTAssertEqual(CoachAntwortPruefung.fragen(a.text).count, 1, "\(frage) -> \(a.text)")
            XCTAssertFalse(a.text.contains("0 min"), "keine erfundene Zahl: \(a.text)")
        }
    }

    func testGewichtOhneWerteFragtNach() async throws {
        let a = try await antwort("Wie ist mein Gewicht?", normal)
        XCTAssertEqual(CoachAntwortPruefung.fragen(a.text).count, 1, a.text)
        XCTAssertEqual(a.chips.first?.aktion, .oeffne(.gewichtEintragen))
    }

    func testUnbekanntesSagtEhrlichDassErEsNichtWeiss() async throws {
        let a = try await antwort("Blablabla", normal)
        XCTAssertTrue(a.text.contains("keine sicheren Zahlen"), a.text)
    }

    // MARK: - Beschwerden und Diagnosen

    func testBeschwerdeNenntArztOhneDiagnose() async throws {
        let a = try await antwort("Mein Knie tut weh", normal)
        XCTAssertTrue(a.text.contains("Ärztin oder deinem Arzt"), a.text)
        XCTAssertTrue(a.chips.isEmpty)
        let klein = a.text.lowercased()
        for wort in CoachPersona.diagnosen { XCTAssertFalse(klein.contains(wort), wort) }
    }

    // MARK: - Schwere Tage

    func testSchwererTagIstVerstaendnisvollOhneDruck() async throws {
        for frage in ["Wie habe ich geschlafen?", "Wie läuft mein Training?", "Tagesbericht", "Wie fühle ich mich?", "Wie viele Schritte bin ich gelaufen?"] {
            let a = try await antwort(frage, schwer)
            let klein = a.text.lowercased()
            XCTAssertTrue(["langsam", "schwerer tag", "ruhig"].contains { klein.contains($0) }, "\(frage) -> \(a.text)")
            XCTAssertTrue(a.chips.contains { $0.aktion == .planMorgenLeicht }, "\(frage): leichter Plan wird angeboten")
            for wort in CoachPersona.druck + CoachPersona.belehrend { XCTAssertFalse(klein.contains(wort), wort) }
        }
    }

    func testGuterTagBietetKeinenLeichtenPlanAn() async throws {
        let a = try await antwort("Wie läuft mein Training?", normal)
        XCTAssertFalse(a.chips.contains { $0.aktion == .planMorgenLeicht })
        XCTAssertTrue(a.chips.contains { $0.aktion == .oeffne(.gym(.training)) })
    }

    // MARK: - Anrede

    func testDuAnredeUndKeinSie() async throws {
        for frage in fragen {
            let a = try await antwort(frage, normal, reich())
            XCTAssertFalse(CoachAntwortPruefung.hatSieAnrede(a.text), a.text)
        }
        let schlaf = try await antwort("Wie habe ich geschlafen?", normal)
        let klein = schlaf.text.lowercased()
        XCTAssertTrue(CoachPersona.duWoerter.contains { klein.contains($0 + " ") }, schlaf.text)
    }

    // MARK: - Chips mit Handlung

    func testNiedrigeSchrittePlanenEineGewohnheit() async throws {
        let wenig = CoachTestBau.kontext(schritte: 3000)
        let a = try await antwort("Wie viele Schritte bin ich gelaufen?", wenig)
        XCTAssertTrue(a.chips.contains { if case .gewohnheitAnlegen = $0.aktion { true } else { false } }, "Mach ich")
    }

    func testChipIdsSindStabilUndEindeutigJeAntwort() async throws {
        for frage in fragen {
            let a = try await antwort(frage, normal, reich())
            XCTAssertEqual(Set(a.chips.map(\.id)).count, a.chips.count, frage)
            for chip in a.chips { XCTAssertFalse(chip.text.isEmpty); XCTAssertFalse(chip.id.isEmpty) }
        }
    }

    // MARK: - Sicherheit beim Essen

    func testSehrWenigImLogNenntArztUndKeinDefizit() async throws {
        var e = reich()
        e.essenKcal = [:]
        for zurueck in 1...12 { e.essenKcal[Datum.addTage(heute, -zurueck)] = 900 }
        let a = try await antwort("Was soll ich heute essen?", normal, e)
        XCTAssertTrue(a.text.contains("Vielleicht fehlt nur Essen im Log"), a.text)
        XCTAssertTrue(a.text.contains("Ärztin oder deinem Arzt"), a.text)
        XCTAssertEqual(CoachAntwortPruefung.pruefe(a.text, frage: "Was soll ich heute essen?", kontext: normal), [])
        for wort in ["abnehmen", "defizit", "weniger essen"] { XCTAssertFalse(a.text.lowercased().contains(wort)) }
    }

    // MARK: - Absicht

    func testAbsichtWirdAusSchluesselwoernernErkannt() {
        XCTAssertEqual(CoachAbsicht.erkenne("Mein Knie tut weh"), .beschwerde)
        XCTAssertEqual(CoachAbsicht.erkenne("Mach meinen Wochenrückblick"), .wochenrueckblick)
        XCTAssertEqual(CoachAbsicht.erkenne("Was habe ich heute noch nicht eingetragen?"), .luecken)
        XCTAssertEqual(CoachAbsicht.erkenne("Was esse ich noch?"), .nochEssen)
        XCTAssertEqual(CoachAbsicht.erkenne("Wie fühle ich mich?"), .gefuehl)
        XCTAssertEqual(CoachAbsicht.erkenne("Was soll ich heute essen?"), .essen)
        XCTAssertEqual(CoachAbsicht.erkenne("Wie läuft mein Training?"), .training)
        XCTAssertEqual(CoachAbsicht.erkenne("Tagesbericht"), .tagesbericht)
        XCTAssertEqual(CoachAbsicht.erkenne("Wie habe ich geschlafen?"), .schlaf)
        XCTAssertEqual(CoachAbsicht.erkenne("Wie viele Schritte?"), .schritte)
        XCTAssertEqual(CoachAbsicht.erkenne("Hallo"), .gruss)
        XCTAssertEqual(CoachAbsicht.erkenne("Guten Morgen"), .gruss)
        XCTAssertEqual(CoachAbsicht.erkenne("Danke dir"), .danke)
        XCTAssertEqual(CoachAbsicht.erkenne("Erzähl mir etwas über Dinosaurier"), .unbekannt)
    }
}
