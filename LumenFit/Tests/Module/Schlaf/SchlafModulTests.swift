import UIKit
import XCTest
@testable import LumenFit

/// Das Modul mit echter Umgebung: Demo-Saat, Band-Ops aus dem Raum, Übersicht aus Health plus Band; dazu die Symbolnamen der Oberfläche.
@MainActor
final class SchlafModulTests: XCTestCase {
    private func umgebung(health: [SchlafNacht] = [], vitale: [VitalArt: [VitalMesswert]] = [:], uhr: TestUhr = TestUhr()) throws -> AppUmgebung {
        let leser = FakeHealthLeser(naechte: health, vitale: vitale)
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                            leser: leser, healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "abcd")
        return u
    }

    func testStartIstIdempotentUndTutNichts() throws {
        let u = try umgebung()
        SchlafModul.start(u)
        SchlafModul.start(u)
        XCTAssertEqual(SchlafDaten.bandOps(u).count, 0)
    }

    func testDemoSaatLegtSechsBandNaechteAnUndIstIdempotent() throws {
        let u = try umgebung()
        SchlafModul.demoSaat(u)
        let ops = SchlafDaten.bandOps(u)
        XCTAssertEqual(ops.count, 6)
        SchlafModul.demoSaat(u)
        XCTAssertEqual(SchlafDaten.bandOps(u).count, 6, "feste Op-Kennungen: zweimal säen ändert nichts")
        XCTAssertTrue(ops.allSatisfy { $0.ende > $0.start && !$0.phasen.isEmpty })
        XCTAssertEqual(Set(ops.map(\.tag)).count, 6)
        let heute = Datum.text(TestUhr().lesen)
        XCTAssertTrue(ops.allSatisfy { $0.tag < heute })
    }

    func testBandOpsAusDemSaatErgebenNaechteMitPhasen() throws {
        let u = try umgebung()
        SchlafModul.demoSaat(u)
        let uebersicht = SchlafDaten.uebersicht(u, band: SchlafDaten.bandOps(u))
        XCTAssertEqual(uebersicht.naechte.count, 6)
        XCTAssertTrue(uebersicht.naechte.allSatisfy { $0.quelle == .band && $0.hatPhasen })
        XCTAssertEqual(uebersicht.vergleich.filter { $0.band != nil }.count, 6)
    }

    func testUebersichtNimmtHealthZielUndBandZusammen() async throws {
        let uhr = TestUhr()
        let tag = Datum.text(uhr.lesen)
        let health = [SchlafTestBau.nacht(tag, minuten: 450, phasen: true)]
        let u = try umgebung(health: health, uhr: uhr)
        var frei = ServerConfig()
        frei.schlafSichtbar = true
        u.konto.uebernimm(frei)   // Schlaf liest Health nur mit Server-Freigabe
        await u.gesundheit.aktualisiere()
        u.daten?.ziele.setze({ var z = Ziele(); z.schlafMinuten = 420; return z }())
        let band = BandSchlafOp(tag: Datum.addTage(tag, -1), start: SchlafTestBau.zeit(Datum.addTage(tag, -2), 23), ende: SchlafTestBau.zeit(Datum.addTage(tag, -1), 7), phasen: [])
        let uebersicht = SchlafDaten.uebersicht(u, band: [band])
        XCTAssertEqual(uebersicht.zielMinuten, 420)
        XCTAssertEqual(uebersicht.naechte.map(\.quelle), [.band, .uhr])
        XCTAssertEqual(uebersicht.letzte?.nacht.schlafMinuten, 450)
    }

    func testOhneProfilGibtEsKeineBandOps() {
        let u = AppUmgebung.vorschau()
        XCTAssertTrue(SchlafDaten.bandOps(u).isEmpty)
        XCTAssertFalse(SchlafDaten.uebersicht(u, band: []).hatDaten)
        XCTAssertEqual(SchlafDaten.uebersicht(u, band: []).zielMinuten, 480)
    }

    func testAlleSymbolNamenGibtEsImSystem() {
        var namen: [String] = []
        namen += SchlafQuelle.allCases.map(\.symbolName)
        namen += VitalArt.allCases.map { SchlafVitalInfo.symbolName($0) }
        namen += [Regelmaessigkeit.Stufe.sehrGleichmaessig, .gleichmaessig, .schwankend, .wechselhaft].map(\.symbolName)
        namen += [ErholungsKlartext.Stufe.bereit, .normal, .schonen, .offen].map(\.symbolName)
        namen += [PersoenlicherBereich.Trend.hoeher, .gleich, .tiefer].map(\.symbolName)
        namen += ["checkmark", "arrow.down", "arrow.right", "arrow.up", "moon.zzz.fill", "bed.double.fill", "chart.bar.fill", "chevron.right", "calendar",
                  "dot.radiowaves.left.and.right", "applewatch"]
        for name in namen {
            XCTAssertNotNil(UIImage(systemName: name), "SF Symbol fehlt: \(name)")
        }
    }
}
