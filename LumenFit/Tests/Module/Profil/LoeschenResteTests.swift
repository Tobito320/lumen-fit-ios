import XCTest
@testable import LumenFit

/// "Passwort vergessen" (Profil ohne Passwort zurücksetzen) und die Reste nach "Alles löschen" (SPEC 5.4): Widgets, Lovea-Dateien, Band, Temp-Dateien.
@MainActor
final class LoeschenResteTests: XCTestCase {
    func testZuruecksetzenLoeschtProfilUndOrdnerOhnePasswort() throws {
        let (u, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        let ordner = daten.ordner
        XCTAssertTrue(ProfilLoeschen.setzeZurueck(u, profil: daten.profil))
        XCTAssertFalse(u.profil.hatProfil, "danach erscheint das Onboarding wieder")
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.path))
    }

    func testZuruecksetzenEinesAnderenProfilsLaesstDasAktiveStehen() throws {
        let (u, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner(), name: "Eins")
        let erstes = daten.profil
        try u.profil.anlegen(name: "Zwei", passwort: "efgh")
        let zweites = try XCTUnwrap(u.profil.aktiv).id
        XCTAssertTrue(ProfilLoeschen.setzeZurueck(u, profil: erstes))
        XCTAssertEqual(u.profil.aktiv?.id, zweites)
        XCTAssertFalse(FileManager.default.fileExists(atPath: u.profilOrdner(erstes).path))
        XCTAssertFalse(ProfilLoeschen.setzeZurueck(u, profil: erstes), "ein Profil, das es nicht mehr gibt, ist kein Erfolg")
    }

    func testDieTexteNennenWasVerschwindetUndDassKeinRueckwegPerMailGibt() {
        XCTAssertTrue(ProfilTexte.zuruecksetzenWarnung.contains("nicht rückgängig"))
        XCTAssertTrue(ProfilTexte.zuruecksetzenWarnung.contains("Health bleiben"))
        XCTAssertTrue(ProfilTexte.zuruecksetzenText.contains("keinen Server"))
        XCTAssertEqual(ProfilTexte.zuruecksetzenTitel(name: "Beispiel"), "Beispiel zurücksetzen?")
    }

    func testNachDemLetztenProfilSchreibenDieWidgetsDenLeerenStand() async throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner())
        WidgetsModul.start(u, senke: WidgetsTestSenke(), fabrik: WidgetsTestFabrik(), neuladen: {})
        let laufzeit = try XCTUnwrap(WidgetsModul.laufzeit(u))
        laufzeit.schreiber.schreibeJetzt()
        XCTAssertNotNil(WidgetSnapshotDatei.lade(ordner: u.ordner)?.profilKennung, "vorher steht das Profil im Stand")

        let id = try XCTUnwrap(u.profil.aktiv).id
        XCTAssertTrue(ProfilLoeschen.setzeZurueck(u, profil: id))
        await laufzeit.verarbeite(.profilGeloescht)
        let danach = try XCTUnwrap(WidgetSnapshotDatei.lade(ordner: u.ordner))
        XCTAssertNil(danach.profilKennung)
        XCTAssertNil(danach.profilName)
        XCTAssertNil(danach.boegen)
        XCTAssertNil(danach.essen)
    }

    func testDieLoveaBrueckeLoeschtNurIhrenOrdner() throws {
        let lovea = try tempOrdner()
        let bruecke = LoveaBruecke(ordner: lovea)
        bruecke.melde(erledigt: ["a"])
        let eigene = lovea.appendingPathComponent("LumenFit", isDirectory: true)
        let fremde = lovea.appendingPathComponent("widget-stand.json")
        try Data("{}".utf8).write(to: fremde)
        XCTAssertTrue(FileManager.default.fileExists(atPath: eigene.appendingPathComponent("band-erledigt.json").path))

        bruecke.loescheEigeneDateien()
        XCTAssertFalse(FileManager.default.fileExists(atPath: eigene.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fremde.path), "Loveas eigene Dateien bleiben")
        LoveaBruecke(ordner: nil).loescheEigeneDateien()   // ohne Gruppe (unsigniert) passiert nichts
    }

    func testBandResteRaeumenNurDieBandSchluesselWeg() throws {
        let suite = "lumenfit-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("kennung", forKey: "fit.band.kennung")
        defaults.set(Data([1]), forKey: BandReihen.schluessel)
        defaults.set(Data([2]), forKey: "fit.bandlabor.messungen")
        defaults.set("bleibt", forKey: "anderes")

        BandReste.loesche(defaults)
        XCTAssertNil(defaults.object(forKey: "fit.band.kennung"))
        XCTAssertNil(defaults.object(forKey: BandReihen.schluessel))
        XCTAssertNil(defaults.object(forKey: "fit.bandlabor.messungen"))
        XCTAssertEqual(defaults.string(forKey: "anderes"), "bleibt")
    }

    func testTempAufraeumenLoeschtSicherungenUndTabellenAberNichtsAnderes() throws {
        let ordner = try tempOrdner()
        for name in ["lumenfit-sicherung-2026-10-29.json", "lumenfit-training-2026-10-29.csv", "fremd.json"] {
            try Data("x".utf8).write(to: ordner.appendingPathComponent(name))
        }
        ProfilSicherungLogik.raeumeTempAuf(ordner: ordner)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: ordner.path), ["fremd.json"])
    }
}
