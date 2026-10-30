import XCTest
@testable import LumenFit

/// Leser für importierte Lovea-Ops (`ImportVerlaufLogik`, `ImportVerlaufStore`). Fixtures: erfundene Werte im Zeilenformat von Loveas Op-Log.
@MainActor
final class ImportVerlaufLogikTests: XCTestCase {
    private let tag = "2026-09-20"

    /// Eine Op wie im Lovea-Log (`id`, `art`, `von`, `zeit` als Text, `d` als Objekt).
    private func zeile(_ id: String, _ art: String, _ zeit: String, _ d: String) throws -> Op {
        let json = #"{"id":"\#(id)","art":"\#(art)","von":"person","zeit":"\#(zeit)","d":\#(d)}"#
        return try JSONDecoder().decode(Op.self, from: Data(json.utf8))
    }

    private func falte(_ ops: [Op]) -> ImportVerlaufStand {
        var stand = ImportVerlaufStand()
        for op in ops { ImportVerlaufLogik.nimmAuf(op, in: &stand) }
        return stand
    }

    private func uhr(_ tag: String, _ stunde: Int, _ minute: Int) -> Date {
        Datum.kalender.date(bySettingHour: stunde, minute: minute, second: 0, of: Datum.datum(tag))!
    }

    // MARK: - Schritte

    func testNeuesteSchritteOpJeTagGewinntMitKmUndKcal() throws {
        let stand = falte([
            try zeile("a", "schritte.setzen", "2026-09-20T08:00:00.250Z", #"{"datum":"2026-09-20","anzahl":3000}"#),
            try zeile("b", "schritte.setzen", "2026-09-20T18:00:00Z", #"{"datum":"2026-09-20","anzahl":9100,"km":6.4,"etagen":7,"kcal":310,"aktivMinuten":42}"#),
            try zeile("c", "schritte.setzen", "2026-09-20T12:00:00Z", #"{"datum":"2026-09-20","anzahl":5000}"#),
        ])
        XCTAssertEqual(stand.schritte[tag], ImportSchritteTag(anzahl: 9100, meter: 6400, etagen: 7, kcal: 310, aktivMinuten: 42), "die spätere Zeit gewinnt, nicht die Reihenfolge im Log")
        XCTAssertEqual(stand.schritte.count, 1)
    }

    func testKaputterTagUndUnlesbareOpWerdenUebersprungen() throws {
        let stand = falte([
            try zeile("a", "schritte.setzen", "2026-09-20T08:00:00Z", #"{"datum":"2026-02-30","anzahl":10}"#),
            try zeile("b", "schritte.setzen", "2026-09-20T08:00:00Z", #"{"datum":"morgen","anzahl":10}"#),
            try zeile("c", "schritte.setzen", "2026-09-20T08:00:00Z", #"{"anzahl":10}"#),
            try zeile("d", "gym.checkin", "2026-09-20T08:00:00Z", #"{"datum":"2026-09-20"}"#),
        ])
        XCTAssertEqual(stand, ImportVerlaufStand())
    }

    func testTageNehmenDasMaximumUndFuellenLuecken() {
        var stand = ImportVerlaufStand()
        stand.schritte = [
            "2026-09-18": ImportSchritteTag(anzahl: 8000, meter: 5600, etagen: 4, kcal: 250, aktivMinuten: 30),
            "2026-09-19": ImportSchritteTag(anzahl: 4000, meter: 2000, etagen: 0, kcal: 0, aktivMinuten: 0),
            "2026-09-01": ImportSchritteTag(anzahl: 6500, meter: 4500, etagen: 2, kcal: 180, aktivMinuten: 20),
        ]
        let health: [String: TagesWerte] = [
            "2026-09-18": TagesWerte(tag: "2026-09-18", schritte: 5000, distanzMeter: 3500, etagen: 6, aktiveKcal: 100, trainingMinuten: 10),
            "2026-09-19": TagesWerte(tag: "2026-09-19", schritte: 9000, distanzMeter: 6000, etagen: 1, aktiveKcal: 400, trainingMinuten: 50),
        ]
        let ergebnis = ImportVerlaufLogik.tage(health, stand: stand)
        XCTAssertEqual(ergebnis["2026-09-18"], TagesWerte(tag: "2026-09-18", schritte: 8000, distanzMeter: 5600, etagen: 6, aktiveKcal: 250, trainingMinuten: 30), "je Feld das Maximum, nie die Summe")
        XCTAssertEqual(ergebnis["2026-09-19"]?.schritte, 9000, "Health ist größer")
        XCTAssertEqual(ergebnis["2026-09-01"]?.schritte, 6500, "ein Tag vor den 60 Tagen von Health kommt aus dem Import")
        XCTAssertEqual(ergebnis["2026-09-01"]?.distanzMeter, 4500)
        XCTAssertEqual(ImportVerlaufLogik.tage(health, stand: ImportVerlaufStand()), health, "ohne Import bleibt alles gleich")
    }

    // MARK: - Schlaf

    func testSchlafSetzenFuelltNurTageOhneHealth() throws {
        let stand = falte([
            try zeile("a", "schlaf.setzen", "2026-09-20T07:00:00Z", #"{"datum":"2026-09-20","minuten":430,"von":"2026-09-19T21:10:00.000Z","bis":"2026-09-20T05:20:00Z","quelle":"appleWatch"}"#),
            try zeile("b", "schlaf.setzen", "2026-09-21T07:00:00Z", #"{"datum":"2026-09-21","minuten":400,"von":"2026-09-20T21:30:00Z","bis":"2026-09-21T05:10:00Z"}"#),
            try zeile("c", "schlaf.setzen", "2026-09-22T07:00:00Z", #"{"datum":"2026-09-22","minuten":400,"von":"kaputt","bis":"2026-09-22T05:10:00Z"}"#),
        ])
        XCTAssertEqual(Set(stand.schlafAutomatik.keys), ["2026-09-20", "2026-09-21"], "eine Nacht ohne lesbare Zeiten fehlt")
        let vorhanden = SchlafNacht(tag: "2026-09-21", von: uhr("2026-09-20", 23, 0), bis: uhr("2026-09-21", 6, 30),
                                    abschnitte: [SchlafAbschnitt(phase: .kern, von: uhr("2026-09-20", 23, 0), bis: uhr("2026-09-21", 6, 30))], schlafMinuten: 450)
        let ergebnis = ImportVerlaufLogik.naechte(health: ["2026-09-21": vorhanden], stand: stand)
        XCTAssertEqual(ergebnis["2026-09-21"], vorhanden, "Health bleibt, wo es etwas hat")
        XCTAssertEqual(ergebnis["2026-09-20"]?.schlafMinuten, 430)
        XCTAssertEqual(ergebnis["2026-09-20"]?.abschnitte.map(\.phase), [.wach, .unbestimmt], "die Wachzeit füllt die Lücke, die Schlaf-Abschnitte ergeben genau die Minuten")
        XCTAssertEqual(ergebnis["2026-09-20"]?.minuten(.unbestimmt), 430)
        XCTAssertEqual(ergebnis["2026-09-20"]?.minuten(.wach), 60)
        XCTAssertEqual(ergebnis["2026-09-20"]?.bis.timeIntervalSince(ergebnis["2026-09-20"]?.von ?? .distantPast), 8 * 3600 + 10 * 60)
    }

    func testEigenerEintragGehtVorHealthUndNullMinutenSperrt() throws {
        let bett = uhr("2026-09-19", 23, 30), auf = uhr("2026-09-20", 7, 0)
        // Lovea schreibt Date als Zahl (Sekunden seit 2001), Lumen Fit liest es mit demselben Decoder.
        let stand = falte([
            try zeile("a", "schlaf.zeiten", "2026-09-20T08:00:00Z", #"{"datum":"2026-09-20","bett":\#(bett.timeIntervalSinceReferenceDate),"auf":\#(auf.timeIntervalSinceReferenceDate)}"#),
            try zeile("b", "schlaf.zeiten", "2026-09-21T08:00:00Z", #"{"datum":"2026-09-21","bett":\#(auf.timeIntervalSinceReferenceDate),"auf":\#(auf.timeIntervalSinceReferenceDate)}"#),
        ])
        let health: [String: SchlafNacht] = [
            "2026-09-20": SchlafNacht(tag: "2026-09-20", von: uhr("2026-09-20", 0, 0), bis: uhr("2026-09-20", 6, 0), abschnitte: [], schlafMinuten: 360),
            "2026-09-21": SchlafNacht(tag: "2026-09-21", von: uhr("2026-09-21", 0, 0), bis: uhr("2026-09-21", 6, 0), abschnitte: [], schlafMinuten: 360),
        ]
        let ergebnis = ImportVerlaufLogik.naechte(health: health, stand: stand)
        XCTAssertEqual(ergebnis["2026-09-20"]?.schlafMinuten, 450, "eigener Eintrag vor Health")
        XCTAssertEqual(ergebnis["2026-09-20"]?.bis, auf)
        XCTAssertEqual(ergebnis["2026-09-20"]?.von, bett)
        XCTAssertNil(ergebnis["2026-09-21"], "ein gelöschter Eintrag (0 Minuten) sperrt die Nacht")
        XCTAssertEqual(ImportVerlaufLogik.naechte(health: health, stand: ImportVerlaufStand()), health)
    }

    // MARK: - Stimmung

    func testTeilOpBehaeltBraucheUndSatzAberGanzeOpErsetzt() throws {
        let stand = falte([
            try zeile("a", "stimmung.setzen", "2026-09-20T08:00:00Z", #"{"datum":"2026-09-20","stimmung":"gut","brauche":"ruhe","satz":"Langer Tag"}"#),
            try zeile("b", "stimmung.setzen", "2026-09-20T09:00:00Z", #"{"datum":"2026-09-20","stimmung":"mittel","teil":true}"#),
            try zeile("c", "stimmung.setzen", "2026-09-21T09:00:00Z", #"{"datum":"2026-09-21","stimmung":"gut","brauche":"ruhe"}"#),
            try zeile("d", "stimmung.setzen", "2026-09-21T10:00:00Z", #"{"datum":"2026-09-21","stimmung":"schlecht"}"#),
        ])
        XCTAssertEqual(stand.stimmung["2026-09-20"], ImportStimmung(roh: "mittel", brauche: "ruhe", satz: "Langer Tag"))
        XCTAssertEqual(stand.stimmung["2026-09-21"], ImportStimmung(roh: "schlecht", brauche: nil, satz: nil), "ohne teil ersetzt die Op den Eintrag")
        XCTAssertEqual(stand.stimmung["2026-09-21"]?.stufe, .schlecht)
    }

    func testStimmungReiheUndAussage() throws {
        let stand = falte([
            try zeile("a", "stimmung.setzen", "2026-09-18T08:00:00Z", #"{"datum":"2026-09-18","stimmung":"gut"}"#),
            try zeile("b", "stimmung.setzen", "2026-09-19T08:00:00Z", #"{"datum":"2026-09-19","stimmung":"unbekannt"}"#),
            try zeile("c", "stimmung.setzen", "2026-09-20T08:00:00Z", #"{"datum":"2026-09-20","stimmung":"gut"}"#),
            try zeile("d", "stimmung.setzen", "2026-08-01T08:00:00Z", #"{"datum":"2026-08-01","stimmung":"schlecht"}"#),
        ])
        let reihe = ImportVerlaufLogik.stimmungReihe(stand, heute: "2026-09-20", anzahl: 14)
        XCTAssertEqual(reihe.map(\.tag), ["2026-09-18", "2026-09-20"], "ältester zuerst, unbekannter Text und alte Tage fehlen")
        XCTAssertEqual(ImportVerlaufLogik.stimmungAussage(reihe), "Letzte 2 Einträge: 2 mal richtig gut")
        XCTAssertEqual(ImportVerlaufLogik.stimmungAussage([]), "Noch keine Stimmung eingetragen")
    }

    // MARK: - Store

    func testStoreSpieltVorhandeneOpsAbUndFaltetLive() throws {
        let raum = LokalerRaum(ordner: try tempOrdner(), profil: .testA, uhr: TestUhr().uhr)
        raum.einreihen(try zeile("a", "schritte.setzen", "2026-09-20T08:00:00Z", #"{"datum":"2026-09-20","anzahl":4200,"km":3.1}"#))
        let store = ImportVerlaufStore(raum: raum)
        XCTAssertEqual(store.stand.schritte[tag]?.anzahl, 4200, "vorhandene Ops werden beim Anlegen abgespielt")
        raum.einreihen(try zeile("b", "schritte.setzen", "2026-09-20T09:00:00Z", #"{"datum":"2026-09-20","anzahl":5200}"#))
        XCTAssertEqual(store.stand.schritte[tag]?.anzahl, 5200)
        store.setzeStimmung(.gut, tag: tag)
        XCTAssertEqual(store.stimmung(tag)?.stufe, .gut)
        let op = try XCTUnwrap(raum.ops(arten: ["stimmung.setzen"]).first)
        XCTAssertEqual(op.daten(StimmungSetzenD.self), StimmungSetzenD(datum: tag, stimmung: "gut", teil: true), "dieselbe Teil-Op wie in Lovea")
    }

    // MARK: - Zusammenspiel mit dem Gesundheitsstand

    func testGesundheitsStandZeigtImportierteTageUndNaechte() throws {
        let uhr = TestUhr()
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                            leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "abcd")
        let raum = try XCTUnwrap(u.daten?.raum)
        raum.einreihen(try zeile("a", "schritte.setzen", "2026-05-02T08:00:00Z", #"{"datum":"2026-05-02","anzahl":7300,"km":5.2,"kcal":210}"#))
        raum.einreihen(try zeile("b", "schlaf.setzen", "2026-05-02T08:00:00Z", #"{"datum":"2026-05-02","minuten":410,"von":"2026-05-01T21:30:00Z","bis":"2026-05-02T05:00:00Z"}"#))
        XCTAssertEqual(u.gesundheit.tage["2026-05-02"]?.schritte, 7300)
        XCTAssertEqual(u.gesundheit.tage["2026-05-02"]?.distanzMeter, 5200)
        XCTAssertEqual(u.gesundheit.tage["2026-05-02"]?.aktiveKcal, 210)
        XCTAssertEqual(u.gesundheit.naechte["2026-05-02"]?.schlafMinuten, 410)
        let heute = Datum.text(uhr.lesen)
        u.daten?.importVerlauf.setzeStimmung(.mittel, tag: heute)
        XCTAssertEqual(u.daten?.importVerlauf.stimmung(heute)?.stufe, .mittel)
    }
}
