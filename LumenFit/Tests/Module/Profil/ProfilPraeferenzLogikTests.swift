import XCTest
@testable import LumenFit

final class ProfilPraeferenzLogikTests: XCTestCase {
    private func vorlage(_ id: String, geraet: String = "studio", ziel: String = "muskeln", tage: Int = 3) -> SplitVorlage {
        SplitVorlage(id: id, name: id, gruppe: "m", level: "einsteiger", ziel: ziel, geraet: geraet, tage: tage, einheiten: [])
    }

    func testZielartAbnehmenVorAufbauenVorHalten() {
        XCTAssertEqual(ProfilPraeferenzLogik.zielart([]), .halten)
        XCTAssertEqual(ProfilPraeferenzLogik.zielart([.fitter]), .halten)
        XCTAssertEqual(ProfilPraeferenzLogik.zielart([.staerker]), .aufbauen)
        XCTAssertEqual(ProfilPraeferenzLogik.zielart([.muskeln, .abnehmen]), .abnehmen)
    }

    func testSplitZielUndGeraet() {
        XCTAssertEqual(ProfilPraeferenzLogik.splitZiel([]), "muskeln")
        XCTAssertEqual(ProfilPraeferenzLogik.splitZiel([.fitter, .staerker]), "kraft", "feste Reihenfolge, nicht die des Tippens")
        XCTAssertEqual(ProfilPraeferenzLogik.splitZiel([.abnehmen]), "definieren")
        XCTAssertEqual(ProfilPraeferenzLogik.splitGeraet([]), "studio")
        XCTAssertEqual(ProfilPraeferenzLogik.splitGeraet([.calisthenics, .studio]), "studio")
        XCTAssertEqual(ProfilPraeferenzLogik.splitGeraet([.calisthenics, .zuhause]), "kurzhantel")
        XCTAssertEqual(ProfilPraeferenzLogik.splitGeraet([.calisthenics]), "zuhause")
    }

    func testFokusHoechstensZweiDerAeltesteFaelltRaus() {
        var f = ProfilPraeferenzLogik.fokusUmschalten([], .brust)
        f = ProfilPraeferenzLogik.fokusUmschalten(f, .beine)
        XCTAssertEqual(f, ["brust", "beine"])
        f = ProfilPraeferenzLogik.fokusUmschalten(f, .bauch)
        XCTAssertEqual(f, ["beine", "bauch"])
        f = ProfilPraeferenzLogik.fokusUmschalten(f, .beine)
        XCTAssertEqual(f, ["bauch"])
        XCTAssertEqual(ProfilPraeferenzLogik.fokusText([]), "Ausgewogen")
    }

    func testMinutenGerundetUndBegrenzt() {
        XCTAssertEqual(ProfilPraeferenzLogik.minutenGerundet(52), 45)
        XCTAssertEqual(ProfilPraeferenzLogik.minutenGerundet(10), 30)
        XCTAssertEqual(ProfilPraeferenzLogik.minutenGerundet(500), 120)
    }

    func testPlanBisFuenfundvierzigMinutenZuerstKurzplanSonstNormal() {
        let liste = [vorlage("m-3-kurz45-a"), vorlage("m-3-voll"), vorlage("m-3-heim", geraet: "kurzhantel")]
        var e = Einstellungen()
        e.trainingsMinuten = 45
        XCTAssertEqual(ProfilPraeferenzLogik.plan(e, tage: 3, geschlecht: nil, in: liste)?.id, "m-3-kurz45-a")
        e.trainingsMinuten = 90
        XCTAssertEqual(ProfilPraeferenzLogik.plan(e, tage: 3, geschlecht: nil, in: liste)?.id, "m-3-voll")
        e.trainingsOrte = [.zuhause]
        e.trainingsMinuten = 30
        XCTAssertEqual(ProfilPraeferenzLogik.plan(e, tage: 3, geschlecht: nil, in: liste)?.id, "m-3-heim", "kein Kurzplan für Zuhause: dann der normale")
        e.trainingsOrte = [.calisthenics]
        XCTAssertNil(ProfilPraeferenzLogik.plan(e, tage: 3, geschlecht: nil, in: liste), "ohne passende Ausstattung kein Plan")
    }

    func testUmschaltenUndTexte() {
        XCTAssertEqual(ProfilPraeferenzLogik.umschalten([TrainingsOrt.studio], .zuhause), [.studio, .zuhause])
        XCTAssertEqual(ProfilPraeferenzLogik.umschalten([TrainingsOrt.studio, .zuhause], .studio), [.zuhause])
        XCTAssertEqual(ProfilPraeferenzLogik.zieleText([]), "Nicht gewählt")
        XCTAssertEqual(ProfilInitialen.aus("lumi fit nutzer"), "LF")
        XCTAssertEqual(ProfilInitialen.aus("  "), "?")
        XCTAssertEqual(ProfilSprache.aktiv(["de"]), "Deutsch")
        XCTAssertEqual(ProfilSprache.aktiv(["en"]), "English")
    }
}
