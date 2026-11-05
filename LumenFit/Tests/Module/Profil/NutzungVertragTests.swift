import XCTest
@testable import LumenFit

/// Vertrag App <-> Server: jeder Name, den die App melden kann, steht in `server/nutzung-namen.js`. Sonst wirft der Server ihn weg und die Auswertung hat ein Loch.
final class NutzungVertragTests: XCTestCase {
    private func namen() throws -> [String: Any] {
        let pfad = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("server/nutzung-namen.js")
        let text = try String(contentsOf: pfad, encoding: .utf8)
        let von = try XCTUnwrap(text.firstIndex(of: "{")), bis = try XCTUnwrap(text.lastIndex(of: "}"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text[von...bis].utf8)) as? [String: Any])
    }

    private func liste(_ n: [String: Any], _ schluessel: String) throws -> Set<String> { Set(try XCTUnwrap(n[schluessel] as? [String])) }
    private func unter(_ n: [String: Any], _ a: String, _ b: String) throws -> Set<String> { Set(try XCTUnwrap((n[a] as? [String: Any])?[b] as? [String])) }

    private func seiten() -> [String] {
        let routen: [Route] = [.heute, .verlauf, .gewichtEintragen, .uebung(id: "x"), .freund(daten: nil)]
            + [GymBereich.training, .plaene, .fortschritt].map { Route.gym($0) }
            + [EssenBereich.heute, .scan, .favoriten].map { Route.essen($0) }
            + [SchlafBereich.letzteNacht, .verlauf, .werte].map { Route.schlaf($0) }
            + [ProfilBereich.uebersicht, .einstellungen, .aussehen, .ziele, .verbindungen, .datensicherung, .quellen, .meilensteine, .lumi].map { Route.profil($0) }
        return routen.map { NutzungName.seite($0) } + LumenFitTab.allCases.map { NutzungName.tab($0) } + [NutzungName.blatt(.profil(.uebersicht)), NutzungName.blatt(.freund(daten: nil))]
    }

    func testJederBereichUndWegDerAppStehtImServer() throws {
        let n = try namen()
        let bereiche = try liste(n, "bereiche"), von = try unter(n, "weg", "von"), nach = try unter(n, "weg", "nach"), absprung = try liste(n, "absprung")
        for s in seiten() {
            XCTAssertTrue(bereiche.contains(s), "bereiche: \(s)")
            XCTAssertTrue(von.contains(s), "weg.von: \(s)")
            XCTAssertTrue(nach.contains(s), "weg.nach: \(s)")
            XCTAssertTrue(absprung.contains(s), "absprung: \(s)")
        }
        XCTAssertTrue(von.contains("start"))
    }

    func testFunktionenErsterGriffUndZielStehenImServer() throws {
        let n = try namen()
        let fn = try liste(n, "funktionen"), erster = try liste(n, "erster")
        let ereignisse: [Ereignis] = [.trainingGestartet(session: "s"), .satzFertig(session: "s", rekord: false), .mahlzeitGespeichert(tag: "2026-09-23"), .gewichtGespeichert(tag: "2026-09-23"), .habitGeaendert(tag: "2026-09-23"), .meilensteinErreicht(id: "m")]
        for f in ereignisse.compactMap({ NutzungName.funktion($0) }) {
            XCTAssertTrue(fn.contains(f), f)
            XCTAssertTrue(erster.contains("fn.\(f)"), f)
        }
        for t in LumenFitTab.allCases { XCTAssertTrue(erster.contains("tab.\(t.rawValue)")) }
        XCTAssertTrue(NutzungName.zielFunktionen.isSubset(of: try unter(n, "ziel", "namen")))
    }

    func testFehlerAblaeufeEintraegeUndStandStehenImServer() throws {
        let n = try namen()
        let fehler = try liste(n, "fehler")
        for f in NutzungFehler.allCases { XCTAssertTrue(fehler.contains(f.rawValue), f.rawValue) }
        let ablauf = try XCTUnwrap(n["ablauf"] as? [String: [String]])
        XCTAssertEqual(Set(ablauf.keys), Set(NutzungAblauf.allCases.map(\.rawValue)))
        for a in NutzungAblauf.allCases { XCTAssertEqual(Set(ablauf[a.rawValue] ?? []), Set(a.stufen), a.rawValue) }
        let eintraege = try liste(n, "eintraege")
        for e in NutzungEintrag.allCases { XCTAssertTrue(eintraege.contains(e.rawValue), e.rawValue) }
        let stand = try liste(n, "stand")
        for t in ThemaID.allCases { XCTAssertTrue(stand.contains("theme_\(t.rawValue)")) }
        for b in AppBereich.allCases { XCTAssertTrue(stand.contains("bereich_\(b.rawValue)")) }
        XCTAssertTrue(stand.isSuperset(of: ["band_an", "band_aus", "einheit_kg", "einheit_lb", "haptik_aus"]))
    }

    func testRoutenMassUndStartStehenImServer() throws {
        let n = try namen()
        let routen = try unter(n, "route", "namen"), status = try unter(n, "route", "status"), tempoNamen = try unter(n, "tempo", "namen"), tempoBucket = try unter(n, "tempo", "bucket")
        let pfade = ["/konto", "/config", "/lovea/freigabe", "/lovea/agent/ops", "/lovea/import-erledigt", "/lovea/import-beleg", "/partner", "/ki/foto", "/verbindungen/x"]
        for p in pfade {
            for m in ["GET", "PUT"] {
                let r = try XCTUnwrap(NutzungRoute.name(methode: m, pfad: p), p)
                XCTAssertTrue(routen.contains(r), r)
                XCTAssertTrue(tempoNamen.contains(r), r)
            }
        }
        XCTAssertTrue(tempoNamen.contains("start"))
        for c in [nil, 400, 401, 403, 404, 409, 413, 418, 429, 500, 502, 503, 504] as [Int?] { XCTAssertTrue(status.contains(NutzungRoute.status(c)), "\(String(describing: c))") }
        for s in [0.1, 2, 9] as [Double] { XCTAssertTrue(tempoBucket.contains(NutzungMass.tempo(s))) }
        XCTAssertEqual(try liste(n, "dauer"), Set([10, 100, 600, 1200, 4000].map { NutzungMass.dauer($0) }))
        XCTAssertEqual(try unter(n, "ziel", "bucket"), Set([1, 20, 40, 100, 400].map { NutzungMass.ziel($0) }))
        let start = try liste(n, "start")
        XCTAssertTrue(start.contains("anzahl"))
        for z in [3, 8, 12, 16, 20].map({ Datum.datum("2026-09-23").addingTimeInterval(TimeInterval($0) * 3600) }) { XCTAssertTrue(start.contains("block_\(NutzungMass.block(z))")) }
    }
}
