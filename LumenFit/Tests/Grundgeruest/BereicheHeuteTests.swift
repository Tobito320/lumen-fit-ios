import XCTest
@testable import LumenFit

/// Heute zeigt nur gewählte Bereiche: Ringe, Hinweise, Woche.
@MainActor
final class BereicheHeuteTests: XCTestCase {
    /// Einstellungen mit den genannten Bereichen aus (der Rest bleibt an).
    private func aus(_ bereiche: AppBereich...) -> Einstellungen {
        var e = Einstellungen()
        for b in bereiche { e.setze(b, an: false) }
        return e
    }

    private func umgebung(leser: any HealthLeser = FakeHealthLeser()) throws -> AppUmgebung {
        AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                    leser: leser, healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: TestUhr().uhr, passwortRunden: 1_000)
    }


    // MARK: Heute

    func testHinweiseDesAusgeschaltetenBereichsFehlen() {
        var e = TagesHinweisLogik.Eingabe(heute: "2026-09-26")   // Samstag
        e.gymZielWoche = 3
        e.gymInFolge = 4
        e.schlafMinuten = ["2026-09-26": 300, "2026-09-25": 300]
        let alle = TagesHinweisLogik.regeln(e).map(\.id)
        XCTAssertTrue(alle.contains { $0.hasPrefix("gym-folge") } && alle.contains { $0.hasPrefix("schlaf-kurz") })
        e.bereiche = aus(.gym)
        XCTAssertFalse(TagesHinweisLogik.regeln(e).contains { $0.id.hasPrefix("gym-") })
        e.bereiche = aus(.schlaf)
        XCTAssertFalse(TagesHinweisLogik.regeln(e).contains { $0.id.hasPrefix("schlaf-") })
    }

    func testWochenrueckblickNenntKeinGymOhneGym() {
        var e = TagesHinweisLogik.Eingabe(heute: "2026-09-27")   // Sonntag
        XCTAssertTrue(TagesHinweisLogik.rueckblickKarten(e).first?.text.contains("Gym") == true)
        e.bereiche = aus(.gym)
        XCTAssertFalse(TagesHinweisLogik.rueckblickKarten(e).first?.text.contains("Gym") ?? true)
    }

    func testEinsichtenHabenIhrenBereich() {
        func h(_ art: HeuteHinweis.Art, _ id: String) -> HeuteHinweis { HeuteHinweis(id: id, art: art, titel: "", zahl: "", text: "", tipp: "", basis: "", fortschritt: nil) }
        XCTAssertEqual(h(.stillstand, "stillstand.x").bereich, .gym)
        XCTAssertEqual(h(.wasser, "wasser").bereich, .gym)
        XCTAssertEqual(h(.schlaf, "schlaf").bereich, .schlaf)
        XCTAssertEqual(h(.gesperrt, "gesperrt.schlaf").bereich, .schlaf)
        XCTAssertEqual(h(.gesperrt, "gesperrt.stimmung").bereich, .schlaf)
    }

    func testWochenTagBeschreibungNenntNurGewaehlteBereiche() {
        let t = HeuteWochenTag(tag: "2026-09-21", kuerzel: "Mo", istHeute: false, zukunft: false, schritte: 0.8, gym: 1, schlaf: 0.95)
        XCTAssertEqual(WochenStreifenLogik.beschreibung(t, bereiche: aus(.gym)), "Montag, 21. September: Schritte 80 %, Schlaf 95 %")
        XCTAssertEqual(WochenStreifenLogik.beschreibung(t, bereiche: aus(.schlaf)), "Montag, 21. September: Schritte 80 %, Gym ja")
    }

    func testRingeZeichnenNurAktivesUndEinstellungenWirkenSofort() throws {
        let u = try umgebung()
        try u.profil.anlegen(name: "Test", passwort: "abcd")
        let m = HeuteModell(umgebung: u)
        m.berechne()
        XCTAssertEqual(m.stand?.boegen.map(\.id), [.bewegen, .trainieren, .erholen])
        u.daten?.einstellungen.aendere { $0.setze(.schlaf, an: false) }
        m.berechne()
        XCTAssertEqual(m.stand?.boegen.map(\.id), [.bewegen, .trainieren])
        XCTAssertFalse(m.stand?.boegenSatz.contains("Schlaf") ?? true)
        u.daten?.einstellungen.aendere { $0.setze(.gym, an: false) }
        m.berechne()
        XCTAssertEqual(m.stand?.boegen.map(\.id), [.bewegen])
        XCTAssertFalse(m.stand?.habits.contains { $0.habit.id == Habit.gym.id } ?? true, "die Gym-Gewohnheit fehlt mit dem Gym")
    }
}
