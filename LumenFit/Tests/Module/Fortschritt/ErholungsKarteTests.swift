// Quelle: Lovea Tests/ErholungsKarteTests.swift (Logik; die Prüfungen der Karte laufen gegen die selbst gezeichnete Silhouette, die PNG-Tafeln entfallen)
import XCTest
@testable import LumenFit


/// Beispiele für die Muskelkarte: ein kleiner Katalog und Einheiten, alle relativ zu `jetzt`.
/// Dienstag, 13.10.2026, 18:00. Nicht actor-isoliert, damit `Karte.lies` als `katalog:` taugt.
private enum Karte {
    static func u(_ name: String, _ muskel: String, _ neben: [String] = []) -> Uebung {
        Uebung(id: name, name: name, en: name, muskel: muskel, koerper: "Rücken", geraet: "", neben: neben)
    }

    private static let alle: [Uebung] = [
        u("Bankdrücken Langhantel", "Brust", ["Trizeps", "Schultern"]),
        u("Schrägbankdrücken", "Brust", ["Trizeps"]),
        u("Seitheben Kurzhantel", "Schultern"),
        u("Face Pull", "Schultern"),
        u("Latzug eng", "Latissimus"),
        u("Rudern am Kabel", "Trapez", ["Bizeps"]),
        u("Rudern vorgebeugt", "oberer Rücken"),
        u("Schulterheben", "Trapez"),
        u("Kreuzheben", "Rückenstrecker", ["Po", "Beinbeuger"]),
        u("Bizeps-Curls Kurzhantel", "Bizeps"),
        u("Preacher Curls", "Bizeps"),
        u("Trizepsdrücken Kabel", "Trizeps"),
        u("Trizepsdrücken über Kopf", "Trizeps"),
        u("Kniebeuge", "Quadrizeps", ["Po", "Beinbeuger"]),
        u("Beinbeuger liegend", "Beinbeuger"),
        u("Hip Thrust", "Po"),
        u("Adduktoren Maschine", "Adduktoren"),
        u("Wadenheben stehend", "Waden"),
        u("Crunch", "Bauch"),
        u("Seitliches Beugen", "seitlicher Bauch"),
        u("Handgelenkbeugen", "Handgelenkbeuger"),
        u("Handgelenkstrecken", "Unterarme"),
        u("Hammer Curls", "Unterarme"),
    ]

    static let katalog: [String: Uebung] = Dictionary(uniqueKeysWithValues: alle.map { ($0.id, $0) })

    static func lies(_ id: String) -> Uebung? { katalog[id] }

    static let jetzt = Datum.datum("2026-10-13").addingTimeInterval(18 * 3600)

    static func saetze(_ n: Int) -> [PlanSatz] {
        (0..<n).map { _ in PlanSatz(wdh: 10, kg: 40, failure: false) }
    }

    /// Eine fertige Einheit, die `stundenVorher` Stunden vor `jetzt` zu Ende ging (Dauer eine Stunde).
    static func einheit(_ id: String, stundenVorher: Double, _ laeufe: [(String, Int)]) -> GymSession {
        let ende = jetzt.addingTimeInterval(-stundenVorher * 3600)
        let runden = laeufe.map {
            UebungsLauf(plan: $0.0, uebung: $0.0, start: nil, ende: ende, fertig: true, saetze: saetze($0.1))
        }
        return GymSession(id: id, tag: nil, start: ende.addingTimeInterval(-3600), ende: ende, laeufe: runden)
    }

    /// Fast alles vor einer Woche trainiert (nur Nacken nie): alles erholt, der Nacken bleibt grau.
    static let ganzkoerper = einheit("g1", stundenVorher: 168, [
        ("Bankdrücken Langhantel", 3), ("Schrägbankdrücken", 3), ("Seitheben Kurzhantel", 3), ("Face Pull", 3),
        ("Latzug eng", 3), ("Rudern am Kabel", 3), ("Rudern vorgebeugt", 3), ("Schulterheben", 3), ("Kreuzheben", 3),
        ("Bizeps-Curls Kurzhantel", 3), ("Preacher Curls", 3), ("Trizepsdrücken Kabel", 3), ("Trizepsdrücken über Kopf", 3),
        ("Kniebeuge", 3), ("Beinbeuger liegend", 3), ("Hip Thrust", 3), ("Adduktoren Maschine", 3), ("Wadenheben stehend", 3),
        ("Crunch", 3), ("Seitliches Beugen", 3), ("Handgelenkbeugen", 3), ("Handgelenkstrecken", 3), ("Hammer Curls", 3),
    ])

    /// Rücken-Training heute, vor drei Stunden.
    static let ruecken = einheit("r1", stundenVorher: 3, [("Latzug eng", 4), ("Rudern am Kabel", 3), ("Kreuzheben", 3)])

    /// Beine, vor 36 Stunden: Quadrizeps und Beinbeuger halb erholt, Waden schon erholt.
    static let beine = einheit("b1", stundenVorher: 36, [("Kniebeuge", 4), ("Beinbeuger liegend", 3), ("Wadenheben stehend", 4)])
}

/// Prüfungen der Körperkarte (W-008): Erholung je Teil und Gruppe, Legende, letztes Training, Tipp-Treffer, Silhouette.
final class ErholungsKarteTests: XCTestCase {
    private func daten(_ sessions: [GymSession]) -> KoerperDaten {
        KoerperDaten.bauen(sessions: sessions, plan: .leer, wert: { _ in nil }, jetzt: Karte.jetzt, katalog: Karte.lies)
    }

    // MARK: Silhouette (ersetzt die Flächen-Tabelle aus muskelkarte.json)

    /// Alle Teile einer Fläche liegen in einer Gruppe, Kopf, Hände und Füße haben keine Fläche.
    func testAlleTeileEinerFlaecheLiegenInEinerGruppe() {
        for f in SilhouetteBild.alle {
            XCTAssertFalse(f.teile.isEmpty, f.id)
            XCTAssertTrue(f.teile.allSatisfy { $0.gruppe == f.gruppe }, f.id)
            XCTAssertFalse(f.formen.isEmpty, f.id)
        }
    }

    /// Jeder Teil liegt auf mindestens einer Fläche: keine Erholung bleibt unsichtbar.
    func testJederTeilLiegtAufEinerFlaeche() {
        let gezeigt = Set(SilhouetteBild.alle.flatMap(\.teile))
        XCTAssertEqual(gezeigt, Set(MuskelTeil.allCases))
        XCTAssertEqual(Set(SilhouetteBild.alle.map(\.gruppe)), Set(MuskelGruppe.allCases))
    }

    func testFlaechenKennenIhreSeite() {
        XCTAssertTrue(SilhouetteBild.vorne.allSatisfy { $0.seite == .vorne })
        XCTAssertTrue(SilhouetteBild.hinten.allSatisfy { $0.seite == .hinten })
        XCTAssertEqual(Set(SilhouetteBild.alle.map(\.id)).count, SilhouetteBild.alle.count, "Kennungen eindeutig")
    }

    // MARK: Erholung je Fläche, Rücken-Training

    func testGrenzteilIstDerSchlechtesteMitTraining() {
        XCTAssertNil(KoerperLogik.grenzteil([:], [.rLat, .rOben]))
        XCTAssertEqual(KoerperLogik.grenzteil([.rLat: 40, .rOben: 70], [.rOben, .rLat]), .rLat)
        XCTAssertEqual(KoerperLogik.grenzteil([.rOben: 70], [.rOben, .rLat]), .rOben, "ohne Training zählt ein Teil nicht")
        XCTAssertEqual(KoerperLogik.grenzteil([.rLat: 40, .rOben: 40], [.rOben, .rLat]), .rOben, "bei Gleichstand der erste")
    }

    /// Abnahme W-008: nach einem Rücken-Training ist der Rücken nicht "erholt", in Feld, Karte, Legende und Blatt.
    func testNachRueckenTrainingIstDerRueckenNichtErholt() {
        let d = daten([Karte.ruecken])
        XCTAssertNotEqual(d.stufe(.ruecken), .erholt)
        XCTAssertEqual(d.stufe(.ruecken), .muede)
        XCTAssertTrue(d.wort(.ruecken).hasSuffix(" %"), d.wort(.ruecken))
        XCTAssertEqual(d.wort(.nacken), "kein Training", "wie die graue Karte, nicht erholt")

        // Karte: jede hintere Fläche, die der Latissimus färbt, ist müde, ebenso der untere Rücken (Kreuzheben);
        // der Nacken ohne Training bleibt leer, nicht erholt.
        let oben = SilhouetteBild.hinten.filter { $0.teile.contains(.rLat) }
        XCTAssertFalse(oben.isEmpty)
        for f in oben { XCTAssertEqual(d.stufe(teile: f.teile), .muede) }
        XCTAssertEqual(d.stufe(teile: [.rUnten]), .muede)
        XCTAssertNil(d.stufe(teile: [.nVorne, .nHinten]))

        // Legende: der Rücken steht ganz oben unter "noch nicht erholt", mit dem müdesten Teil.
        let l = KoerperLogik.legende(d.erholung, reihenfolge: d.ziele.reihenfolge)
        XCTAssertEqual(l.offen.first?.gruppe, .ruecken)
        XCTAssertEqual(l.offen.first?.teil, .rLat)
        XCTAssertFalse(l.erholt.contains(.ruecken))
        XCTAssertTrue(l.leer.contains(.nacken))

        // Blatt: Prozent und letztes Training (Tag, Übung).
        let stand = d.stand(.ruecken, teil: nil)
        XCTAssertEqual(stand?.teil, .rLat)
        XCTAssertEqual(stand?.prozent, d.erholung[.rLat])
        XCTAssertEqual(stand?.stufe, .muede)
        XCTAssertEqual(stand?.letztes?.tag, "2026-10-13")
        XCTAssertEqual(stand?.letztes?.uebungen, ["Latzug eng"])
        XCTAssertEqual(stand?.letztes?.text, "Di 13.10. · Latzug eng")
    }

    /// Der Mittelwert der Teile hätte den Rücken 40 Stunden nach dem Latzug "erholt" genannt (93), der
    /// Latissimus ist erst bei 66 %. Die Gruppe ist so erholt wie ihr schlechtester Teil.
    func testRueckenIstNachVierzigStundenNochNichtErholt() {
        let d = daten([Karte.einheit("r", stundenVorher: 40, [("Latzug eng", 3)])])
        XCTAssertEqual(d.erholung[.rLat], 66)
        XCTAssertEqual(d.prozent(.ruecken), 66)
        XCTAssertEqual(d.stufe(.ruecken), .fast)
        XCTAssertEqual(d.wort(.ruecken), "66 %")
        XCTAssertEqual(daten([Karte.einheit("r", stundenVorher: 70, [("Latzug eng", 3)])]).stufe(.ruecken), .erholt)
    }

    /// Die Beispieldaten zeigen alle vier Zustände: müde, fast erholt, erholt, kein Training.
    func testBeispieldatenZeigenAlleVierStufen() {
        let d = daten([Karte.ruecken, Karte.beine, Karte.ganzkoerper])
        let stufen = Set(SilhouetteBild.alle.map { d.stufe(teile: $0.teile) })
        let erwartet: Set<ErholungsStufe?> = [.muede, .fast, .erholt, nil]
        XCTAssertEqual(stufen, erwartet)
        XCTAssertEqual(d.stufe(teile: [.beQuads]), .fast)
        XCTAssertEqual(d.stufe(teile: [.beWaden]), .erholt)
    }

    // MARK: Legende

    func testLegendeTrenntOffenErholtUndLeer() {
        let l = KoerperLogik.legende([.sSeitlich: 40, .beQuads: 75, .bUnten: 100],
                                     reihenfolge: [.schulter, .brust, .beine, .nacken])
        XCTAssertEqual(l.offen.map(\.gruppe), [.schulter, .beine])
        XCTAssertEqual(l.offen.map(\.prozent), [40, 75])
        XCTAssertEqual(l.offen.map(\.name), ["Schulter seitlich", "Quadrizeps"])
        XCTAssertEqual(l.offen.map(\.stufe), [.muede, .fast])
        XCTAssertEqual(l.erholt, [.brust])
        XCTAssertEqual(l.leer, [.nacken])
        XCTAssertFalse(l.keinTraining)
        XCTAssertEqual(l.sprechtext, "Schulter seitlich 40 Prozent, müde. Quadrizeps 75 Prozent, fast erholt. Erholt: Brust. Kein Training erfasst: Nacken")
    }

    func testLegendeOrdnetNachMuedigkeitUndBeiGleichstandNachGruppe() {
        let l = KoerperLogik.legende([.sSeitlich: 40, .bUnten: 40, .beQuads: 10], reihenfolge: [.brust, .schulter, .beine])
        XCTAssertEqual(l.offen.map(\.gruppe), [.beine, .brust, .schulter])
    }

    /// Jeder Teil unter 90 % steht einzeln in der Liste, nicht nur der schlechteste je Gruppe: der Quadrizeps bei
    /// 55 % neben dem Po bei 5 %. Die Waden bei 100 % stehen nicht dabei, die Gruppe gilt nicht als erholt.
    func testLegendeNenntJedenTeilUnterNeunzigProzent() {
        let l = KoerperLogik.legende([.bePo: 5, .beQuads: 55, .beWaden: 100], reihenfolge: [.beine])
        XCTAssertEqual(l.offen.map(\.teil), [.bePo, .beQuads])
        XCTAssertEqual(l.offen.map(\.gruppe), [.beine, .beine])
        XCTAssertTrue(l.erholt.isEmpty)
        XCTAssertTrue(l.leer.isEmpty)
        XCTAssertEqual(l.sprechtext, "Po 5 Prozent, müde. Quadrizeps 55 Prozent, fast erholt")
    }

    /// Vier Namen beginnen groß und sagen ohne ihre Gruppe nichts ("Mitte und unten", "Beuger"): die Liste und der
    /// Sprechtext stellen sie voran. Eigenständige Namen stehen allein, kleine bekommen die Gruppe wie bisher.
    func testTeilNameNenntDieGruppeWoDerNameSieNichtTraegt() {
        XCTAssertEqual(KoerperLogik.teilName(.bUnten), "Brust Mitte und unten")
        XCTAssertEqual(KoerperLogik.teilName(.uBeuger), "Unterarme Beuger")
        XCTAssertEqual(KoerperLogik.teilName(.uStrecker), "Unterarme Strecker")
        XCTAssertEqual(KoerperLogik.teilName(.uSpeiche), "Unterarme Oberseite")
        XCTAssertEqual(KoerperLogik.teilName(.bOben), "Brust oben")
        XCTAssertEqual(KoerperLogik.teilName(.sSeitlich), "Schulter seitlich")
        XCTAssertEqual(KoerperLogik.teilName(.rLat), "Latissimus")
        XCTAssertEqual(KoerperLogik.teilName(.rTrapezUnten), "Trapez Mitte und unten")
        XCTAssertEqual(KoerperLogik.teilName(.beQuads), "Quadrizeps")
    }

    func testLegendeOhneTrainingLaedtZumTrainingEin() {
        let l = KoerperLogik.legende([:], reihenfolge: MuskelGruppe.allCases)
        XCTAssertTrue(l.keinTraining)
        XCTAssertEqual(l.leer, MuskelGruppe.allCases)
        XCTAssertEqual(l.sprechtext, "Noch kein Training erfasst.")
    }

    // MARK: Letztes Training

    /// Die Mitarbeit zählt wie in der Erholung: der Trizeps beim Bankdrücken (Hilfsmuskel) gibt das letzte Training
    /// und treibt die Prozent, auch wenn eine ältere Einheit ihn direkt trainiert hat. Reihenfolge der Einheiten egal.
    func testLetztesTrainingFolgtDerEinheitDieDieErholungTreibt() {
        let alt = Karte.einheit("a", stundenVorher: 50, [("Trizepsdrücken Kabel", 3)])
        let neu = Karte.einheit("n", stundenVorher: 10, [("Bankdrücken Langhantel", 4)])
        for sessions in [[alt, neu], [neu, alt]] {
            let d = daten(sessions)
            let letztes = d.letzte[.triSeitlich]
            XCTAssertEqual(letztes?.uebungen, ["Bankdrücken Langhantel"])
            XCTAssertEqual(letztes?.zeit, neu.ende)
            XCTAssertEqual(letztes?.tag, Datum.text(neu.start))
            let nurNeu = MuskelLogik.erholung([neu], jetzt: Karte.jetzt, katalog: Karte.lies)
            XCTAssertEqual(d.erholung[.triSeitlich], nurNeu[.triSeitlich])
        }
    }

    /// Dieselbe Regel wie `MuskelLogik.erholung`: nur fertige Läufe mit gezählten Sätzen.
    func testLetztesTrainingZaehltNurFertigeLaeufeMitSaetzen() {
        var offen = Karte.einheit("o", stundenVorher: 1, [("Latzug eng", 3), ("Kniebeuge", 3), ("Crunch", 3)])
        offen.laeufe[0].fertig = false
        offen.laeufe[1].saetze = []
        offen.laeufe[2].saetze = nil
        XCTAssertTrue(KoerperLogik.letzte([offen], katalog: Karte.lies).isEmpty)
        XCTAssertTrue(MuskelLogik.erholung([offen], jetzt: Karte.jetzt, katalog: Karte.lies).isEmpty)
    }

    func testLetztesTrainingNenntJedeUebungEinmalUndOhneEinheitNichts() {
        let doppelt = Karte.einheit("d", stundenVorher: 2, [("Latzug eng", 3), ("Latzug eng", 2)])
        XCTAssertEqual(KoerperLogik.letzte([doppelt], katalog: Karte.lies)[.rLat]?.uebungen, ["Latzug eng"])
        XCTAssertTrue(KoerperLogik.letzte([], katalog: Karte.lies).isEmpty)
    }

    func testLetztesText() {
        let viele = KoerperLetztes(zeit: Karte.jetzt, tag: "2026-10-13", uebungen: ["A", "B", "C", "D", "E"])
        XCTAssertEqual(viele.text, "Di 13.10. · A, B, C und 2 weitere")
        XCTAssertEqual(KoerperLetztes(zeit: Karte.jetzt, tag: "2026-10-13", uebungen: ["A"]).text, "Di 13.10. · A")
    }

    /// Der Tipp auf eine Fläche meldet dem Blatt den schlechtesten Teil mit Training. Ohne Training in der Fläche
    /// ihren ersten Teil, wenn die Gruppe sonst Training hat (das Blatt sagt "Kein Training erfasst" statt den Stand
    /// eines anderen Teils zu zeigen). Ist die ganze Gruppe grau, nichts: das Blatt zeigt nur die Gruppe.
    func testTippMeldetDemBlattDenTeilDerFlaeche() {
        let e: [MuskelTeil: Int] = [.rLat: 40, .rUnten: 70]
        XCTAssertEqual(KoerperLogik.tippTeil(e, gruppe: .ruecken, flaeche: [.rOben, .rLat]), .rLat)
        XCTAssertEqual(KoerperLogik.tippTeil(e, gruppe: .ruecken, flaeche: [.rTrapezOben, .rTrapezUnten]), .rTrapezOben)
        XCTAssertNil(KoerperLogik.tippTeil(e, gruppe: .brust, flaeche: [.bOben, .bUnten]))

        // Mit dem Blatt: nach dem Rücken-Training ist der Po trainiert, der Quadrizeps grau.
        let d = daten([Karte.ruecken])
        let grau = KoerperLogik.tippTeil(d.erholung, gruppe: .beine, flaeche: [.beQuads])
        XCTAssertEqual(grau, .beQuads)
        XCTAssertNil(d.stand(.beine, teil: grau), "der Quadrizeps ist nicht trainiert, kein Stand eines anderen Teils")
        let po = KoerperLogik.tippTeil(d.erholung, gruppe: .beine, flaeche: [.bePo])
        XCTAssertEqual(d.stand(.beine, teil: po)?.teil, .bePo)
    }

    func testBlattOhneTrainingHatKeinenStand() {
        let d = daten([Karte.ruecken])
        XCTAssertNil(d.stand(.nacken, teil: nil))
        XCTAssertNil(d.stand(.ruecken, teil: .rOben), "der angetippte Teil ist nicht trainiert")
        XCTAssertEqual(d.stand(.ruecken, teil: .rTrapezUnten)?.letztes?.uebungen, ["Rudern am Kabel"])
    }

    // MARK: Farben und Muster

    private func leuchtdichte(_ hex: UInt32) -> Double {
        func k(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
        return 0.2126 * k(r) + 0.7152 * k(g) + 0.0722 * k(b)
    }

    private func mischung(_ vorne: UInt32, _ hinten: UInt32, deckkraft: Double) -> UInt32 {
        func kanal(_ s: UInt32) -> Double { Double(s) }
        let r = kanal((vorne >> 16) & 0xFF) * deckkraft + kanal((hinten >> 16) & 0xFF) * (1 - deckkraft)
        let g = kanal((vorne >> 8) & 0xFF) * deckkraft + kanal((hinten >> 8) & 0xFF) * (1 - deckkraft)
        let b = kanal(vorne & 0xFF) * deckkraft + kanal(hinten & 0xFF) * (1 - deckkraft)
        return (UInt32(r.rounded()) << 16) | (UInt32(g.rounded()) << 8) | UInt32(b.rounded())
    }

    private func kontrast(_ a: UInt32, _ b: UInt32) -> Double {
        let x = leuchtdichte(a), y = leuchtdichte(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// Die müde Fläche (Schrift-Farbe mit 80 % Deckkraft) hebt sich in jedem Theme, hell und dunkel, mindestens 3:1 von der Karte ab (WCAG 1.4.11).
    func testMuedeFlaecheHebtSichVonDerKarteAb() {
        for thema in ThemaID.allCases {
            for dunkel in [false, true] {
                let t = LumenFarben.tokens(thema: thema, dunkel: dunkel)
                let flaeche = mischung(t.text, t.flaeche, deckkraft: SilhouetteStufe.muede.deckkraft)
                XCTAssertGreaterThanOrEqual(kontrast(flaeche, t.flaeche), 3, "\(thema) dunkel \(dunkel)")
            }
        }
    }

    /// Jede Stufe hat ein eigenes Muster und eine eigene Deckkraft, die Farbe trägt nie allein.
    func testStufenUnterscheidenSichInMusterUndDeckkraft() {
        let paare = SilhouetteStufe.allCases.map { "\($0.muster)-\($0.deckkraft)" }
        XCTAssertEqual(Set(paare).count, 4)
        XCTAssertEqual(Set(SilhouetteStufe.allCases.map(\.muster)).count, 4)
        XCTAssertEqual(Set(SilhouetteStufe.allCases.map(\.wort)).count, 4)
        XCTAssertEqual(SilhouetteStufe(nil), .leer)
        XCTAssertEqual(SilhouetteStufe(.muede), .muede)
    }
}
