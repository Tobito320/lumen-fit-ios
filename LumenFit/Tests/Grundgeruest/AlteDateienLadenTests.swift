import XCTest
@testable import LumenFit

/// Dateien aus älteren oder neueren Ständen dürfen nie dazu führen, dass der Store leer startet oder Daten verliert.
@MainActor
final class AlteDateienLadenTests: XCTestCase {
    func testAlteZyklusFelderStoerenNichtObwohlLumenFitDenZyklusNichtMehrHat() throws {
        // Der Zyklus ist aus Lumen Fit entfernt. Alte Dateien, Ops und Server-Antworten mit Zyklus-Feldern müssen weiter laden, der Rest bleibt.
        let ordner = try tempOrdner()
        try Data(#"{"aktiv":true,"sperre":false,"partnerZeigen":true}"#.utf8).write(to: ordner.appendingPathComponent("zyklus-lokal.json"))
        try Data(#"{"thema":"wald","haptik":false,"zyklus":{"aktiv":true}}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let raum = LokalerRaum(ordner: ordner, profil: .testA)
        raum.senden("zyklus.tag", ["id": "2026-10-29"])
        let satz = DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: { Date() })
        XCTAssertEqual(satz.einstellungen.werte.thema, .wald, "andere Daten bleiben erhalten")
        XCTAssertFalse(satz.einstellungen.werte.haptik)
        XCTAssertEqual(satz.raum.ops(arten: ["zyklus.tag"]).count, 1, "die Op bleibt im Log, wird nur nicht mehr gelesen")

        let einstellung = try LoveaVertrag.decoder().decode(VerbindungEinstellung.self, from: Data(#"{"zeigt":["schritte","zyklus"],"ausblenden":["zyklus"]}"#.utf8))
        XCTAssertEqual(einstellung.zeigt, ["schritte", "zyklus"], "der Text bleibt, nur der Bereich ist unbekannt")
        XCTAssertEqual(einstellung.zeigtBereiche, [.schritte])
        XCTAssertTrue(einstellung.ausgeblendet.isEmpty)

        let heute = try LoveaVertrag.decoder().decode(
            TagesZusammenfassung.self,
            from: Data(#"{"tag":"2026-10-29","schritte":12,"zyklus":{"phase":"follikel","tag":3,"wunsch":"a","satz":"b","tipps":[]}}"#.utf8))
        XCTAssertEqual(heute.schritte, 12, "eine alte Partner-Datei mit Zyklus-Feld lädt, das Feld wird ignoriert")
    }

    func testEinAltesNutzungZaehlenTrueIstKeineEinwilligung() throws {
        for alt in [#"{"thema":"wald","nutzungZaehlen":true}"#, #"{"nutzungZaehlen":false}"#, #"{"nutzungAntwort":"vielleicht"}"#, #"{"nutzungAntwort":3}"#] {
            let ordner = try tempOrdner()
            try Data(alt.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
            let werte = EinstellungenStore(ordner: ordner).werte
            XCTAssertEqual(werte.nutzungAntwort, .offen, alt)
            XCTAssertFalse(werte.nutzungErlaubt, alt)
        }
        let ordner = try tempOrdner()
        try Data(#"{"nutzungAntwort":"ja","nutzungJaSeit":"2026-11-02"}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let werte = EinstellungenStore(ordner: ordner).werte
        XCTAssertTrue(werte.nutzungErlaubt)
        XCTAssertEqual(werte.nutzungJaSeit, "2026-11-02")
    }

    func testNutzungAntwortHaeltDenTagDesJaNurBeimJa() {
        var e = Einstellungen()
        e.antworteNutzung(.ja, tag: "2026-11-02")
        XCTAssertEqual(e.nutzungJaSeit, "2026-11-02")
        e.antworteNutzung(.ja, tag: "2026-11-05")
        XCTAssertEqual(e.nutzungJaSeit, "2026-11-02", "ein zweites Ja ändert den Tag nicht")
        e.antworteNutzung(.nein, tag: "2026-11-06")
        XCTAssertNil(e.nutzungJaSeit)
        XCTAssertFalse(e.nutzungErlaubt)
    }

    func testEinstellungenMitNurEinemFeldUndFremdenFeldernSindLesbar() throws {
        let ordner = try tempOrdner()
        try Data(#"{"thema":"wald","gibtEsNochNicht":{"a":1}}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let store = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(store.werte.thema, .wald)
        XCTAssertEqual(store.werte.erscheinung, .system)
        XCTAssertTrue(store.werte.haptik)
        XCTAssertFalse(store.werte.healthSchreiben)
        XCTAssertTrue(store.werte.alarmWeckt, "neues Feld fehlt in der alten Datei: Standard an")
        XCTAssertEqual(store.werte.nutzungAntwort, .offen, "neues Feld fehlt in der alten Datei: noch nicht gefragt")
        XCTAssertFalse(store.werte.nutzungErlaubt)
        XCTAssertNil(store.werte.nutzungJaSeit)
        XCTAssertFalse(store.werte.fastenAn, "neues Feld fehlt in der alten Datei: Fasten aus")
        XCTAssertFalse(store.werte.bandEingerichtet, "Band nie angefasst: nur die Zeile Band einrichten")
        var band = store.werte
        band.bandBewusstAus = true
        XCTAssertTrue(band.bandEingerichtet, "einmal bewusst ausgeschaltet heißt eingerichtet")
        band.bandBewusstAus = false; band.bandAktiv = true
        XCTAssertTrue(band.bandEingerichtet)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("einstellungen.json.defekt").path))
    }

    func testEinstellungenOhneBereicheZeigenAllesUndBehaltenGewaehlteBereiche() throws {
        let ordner = try tempOrdner()
        try Data(#"{"thema":"wald"}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let alt = EinstellungenStore(ordner: ordner)
        XCTAssertTrue(alt.werte.gymAn && alt.werte.essenAn && alt.werte.schlafAn, "Bestandsprofil: alle Bereiche an")
        alt.aendere { $0.setze(.schlaf, an: false) }
        let neu = EinstellungenStore(ordner: ordner)
        XCTAssertFalse(neu.werte.schlafAn, "die Wahl übersteht den Neustart")
        XCTAssertEqual(neu.werte.thema, .wald)
    }

    func testAlterKontoStandOhneCoachSichtbarBleibtLesbarUndZeigtKeinenCoach() throws {
        let alt = try JSONDecoder().decode(KontoStand.self, from: Data(#"{"config":{"profilAnlegenErlaubt":true,"nameAendernTage":3},"loveaErlaubt":true}"#.utf8))
        XCTAssertTrue(alt.config.profilAnlegenErlaubt)
        XCTAssertTrue(alt.loveaErlaubt)
        XCTAssertFalse(alt.config.coachSichtbar)
    }

    func testEinUnbekanntesThemeErgibtDenStandardUndBehaeltDenRest() throws {
        let ordner = try tempOrdner()
        try Data(#"{"thema":"neonpink","haptik":false,"gewichtsEinheit":"stone"}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let store = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(store.werte.thema, .monochrom)
        XCTAssertFalse(store.werte.haptik, "der gültige Rest bleibt")
        XCTAssertEqual(store.werte.gewichtsEinheit, .kg)
    }

    func testEinstellungenUeberlebenNeustartUndMeldenAenderungen() async throws {
        let ordner = try tempOrdner()
        let kanal = EreignisKanal()
        let strom = kanal.strom()
        let store = EinstellungenStore(ordner: ordner, ereignisse: kanal)
        store.aendere { $0.thema = .glut; $0.mitteilungen["partner"] = true }
        store.aendere { $0.thema = .glut }   // keine Änderung, kein Ereignis, keine Schreibarbeit
        let neu = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(neu.werte.thema, .glut)
        XCTAssertEqual(neu.werte.mitteilungen, ["partner": true])

        kanal.senden(.vordergrund)
        var anzahl = 0
        for await e in strom {
            if case .einstellungenGeaendert = e { anzahl += 1 }
            if case .vordergrund = e { break }
        }
        XCTAssertEqual(anzahl, 1)
    }

    func testZieleMitFehlendenUndFalschenFeldern() throws {
        let ordner = try tempOrdner()
        try Data(#"{"schritte":12000,"art":"turbo","kalorien":"viel"}"#.utf8).write(to: ordner.appendingPathComponent("ziele.json"))
        let store = ZieleStore(ordner: ordner)
        XCTAssertEqual(store.ziele.schritte, 12_000)
        XCTAssertEqual(store.ziele.art, .halten)
        XCTAssertEqual(store.ziele.kalorien, 2_400)
        XCTAssertEqual(store.ziele.schlafMinuten, 480)
    }

    func testKaputteDateiStartetLeerUndWirdGesichert() throws {
        let ordner = try tempOrdner()
        try Data("{kaputt".utf8).write(to: ordner.appendingPathComponent("ziele.json"))
        let store = ZieleStore(ordner: ordner)
        XCTAssertEqual(store.ziele, Ziele())
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("ziele.json.defekt").path))
    }

    func testOpsAusLoveaSicherungenMitSeqUndOhneBruchteileSindLesbar() throws {
        let ordner = try tempOrdner()
        let zeilen = [
            #"{"id":"a","seq":12,"art":"habit.setzen","von":"test-a","zeit":"2026-09-23T10:00:00.000Z","d":{"art":"wasser","datum":"2026-09-23","wert":5},"unbekannt":1}"#,
            #"{"id":"b","art":"habit.setzen","von":"test-a","zeit":"2026-09-23T10:05:00Z","d":{"art":"wasser","datum":"2026-09-23","wert":6}}"#,
        ]
        try (zeilen.joined(separator: "\n") + "\n").write(to: ordner.appendingPathComponent("ops.jsonl"), atomically: true, encoding: .utf8)
        var log = LokalerOpLog(datei: ordner.appendingPathComponent("ops.jsonl"))
        let ops = log.lade()
        XCTAssertEqual(ops.map(\.id), ["a", "b"])
        XCTAssertEqual(ops[1].zeit.timeIntervalSince1970, 1_790_157_900, accuracy: 0.001, "2026-09-23T10:05:00Z ohne Sekundenbruchteile")
        XCTAssertEqual(ops[0].daten(HabitSetzenD.self)?.wert, 5)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("ops.jsonl.defekt").path))
    }

    // MARK: - Profil im Schlüsselbund (SPEC 5.3: jede Änderung an einem gespeicherten Typ bekommt hier einen Fall)

    /// Der eingefrorene Eintrag `konto.profile` des ersten Stands: `erstellt` als Sekunden seit 1970, Salz und Hash als Base64, Passwort "abcd", 1.000 Runden.
    private static let ersterStand = #"[{"id":"11111111-2222-3333-4444-555555555555","name":"Eins","erstellt":1790000000,"passwort":{"salz":"AQIDBAUGBwgJCgsMDQ4PEA==","hash":"3n0ScAtNMoU/rPrXCLQlLu3qN/Ybs35X6LSHpuiSiAI=","runden":1000}}]"#

    private func storeMit(json: String) throws -> (store: ProfilStore, bund: SpeicherSchluesselbund) {
        let bund = SpeicherSchluesselbund()
        try bund.schreibe(Data(json.utf8), fuer: ProfilStore.profileSchluessel)
        return (ProfilStore(schluesselbund: bund, ereignisse: EreignisKanal(), runden: 1_000), bund)
    }

    func testProfilDesErstenStandsBleibtLesbarUndDasPasswortStimmt() throws {
        let (store, bund) = try storeMit(json: Self.ersterStand)
        XCTAssertNil(store.ladeProblem)
        let profil = try XCTUnwrap(store.profile.first)
        XCTAssertEqual(profil.name, "Eins")
        XCTAssertEqual(profil.erstellt.timeIntervalSince1970, 1_790_000_000)
        XCTAssertEqual(store.aktiv?.id, profil.id, "ohne konto.aktiv gilt das erste Profil")
        XCTAssertTrue(store.pruefe(passwort: "abcd", fuer: profil.id))
        XCTAssertFalse(store.pruefe(passwort: "abce", fuer: profil.id))
        XCTAssertFalse(profil.ohnePasswort, "ein altes Profil behält sein Passwort (das Feld fehlt dort)")
        XCTAssertEqual(bund.lese(ProfilStore.profileSchluessel), Data(Self.ersterStand.utf8), "Lesen schreibt nichts")
    }

    func testProfilOhnePasswortLaedtNeuUndAltBleibtMitPasswort() throws {
        let neu = Self.ersterStand.replacingOccurrences(of: #""name":"Eins""#, with: #""name":"Eins","ohnePasswort":true"#)
        let (store, _) = try storeMit(json: neu)
        let profil = try XCTUnwrap(store.profile.first)
        XCTAssertTrue(profil.ohnePasswort)
        XCTAssertTrue(store.wechsle(zu: profil.id, passwort: ""), "ohne Passwort genügt die Bestätigung")

        let ohneFeld = Self.ersterStand.replacingOccurrences(of: #""name":"Eins""#, with: #""name":"Eins","ohnePasswort":"kaputt""#)
        let (alt, _) = try storeMit(json: ohneFeld)
        XCTAssertEqual(alt.profile.count, 1, "ein falscher Typ im Feld kostet das Profil nicht")
        XCTAssertFalse(try XCTUnwrap(alt.profile.first).ohnePasswort, "und lässt das Passwort bestehen")
        XCTAssertFalse(alt.wechsle(zu: try XCTUnwrap(alt.profile.first).id, passwort: "falsch"))
    }

    func testProfilMitUnbekanntemZusatzfeldBleibtLesbar() throws {
        let json = Self.ersterStand
            .replacingOccurrences(of: #""name":"Eins""#, with: #""name":"Eins","farbe":"blau","neu":{"a":[1,2]}"#)
            .replacingOccurrences(of: #""runden":1000"#, with: #""runden":1000,"verfahren":"pbkdf2""#)
        let (store, _) = try storeMit(json: json)
        XCTAssertNil(store.ladeProblem)
        let profil = try XCTUnwrap(store.profile.first)
        XCTAssertTrue(store.pruefe(passwort: "abcd", fuer: profil.id))
    }

    func testProfilOhneNameGeaendertDarfSofortUmbenanntWerden() throws {
        let (store, bund) = try storeMit(json: Self.ersterStand)
        XCTAssertNil(try XCTUnwrap(store.profile.first).nameGeaendert, "der erste Stand kennt das Feld nicht")
        XCTAssertEqual(store.aendereName("Zwei", sperreTage: 7), .geaendert)
        let neu = ProfilStore(schluesselbund: bund, ereignisse: EreignisKanal(), runden: 1_000)
        XCTAssertNotNil(neu.aktiv?.nameGeaendert, "das Datum übersteht den Neustart")
        XCTAssertEqual(neu.aendereName("Drei", sperreTage: 7).isGesperrt, true, "und die Sperre auch")
    }

    func testProfilMitFehlendenFeldernBleibtLesbarUndStimmtNie() throws {
        let ohneNameUndDatum = #"[{"id":"11111111-2222-3333-4444-555555555555","passwort":{"salz":"AQIDBAUGBwgJCgsMDQ4PEA==","hash":"3n0ScAtNMoU/rPrXCLQlLu3qN/Ybs35X6LSHpuiSiAI=","runden":1000}}]"#
        var (store, _) = try storeMit(json: ohneNameUndDatum)
        var profil = try XCTUnwrap(store.profile.first)
        XCTAssertEqual(profil.name, "Profil", "fehlender Name: Standard")
        XCTAssertTrue(store.pruefe(passwort: "abcd", fuer: profil.id), "das Passwort ist unversehrt")

        let ohnePasswort = #"[{"id":"11111111-2222-3333-4444-555555555555","name":"Eins","erstellt":1790000000}]"#
        (store, _) = try storeMit(json: ohnePasswort)
        profil = try XCTUnwrap(store.profile.first)
        XCTAssertEqual(profil.name, "Eins")
        XCTAssertFalse(store.pruefe(passwort: "abcd", fuer: profil.id), "ohne Spur stimmt kein Passwort, das Profil bleibt aber da und lässt sich zurücksetzen")
        XCTAssertTrue(store.setzeZurueck(profil.id))

        let ohneRunden = #"[{"id":"11111111-2222-3333-4444-555555555555","name":"Eins","erstellt":1790000000,"passwort":{"salz":"AQIDBAUGBwgJCgsMDQ4PEA==","hash":"3n0ScAtNMoU/rPrXCLQlLu3qN/Ybs35X6LSHpuiSiAI="}}]"#
        (store, _) = try storeMit(json: ohneRunden)
        XCTAssertEqual(store.profile.count, 1, "fehlende Rundenzahl macht den Eintrag nicht unlesbar")
    }

    func testEinTypfehlerInEinemFeldKostetNurDiesesFeld() throws {
        let json = Self.ersterStand.replacingOccurrences(of: #""erstellt":1790000000"#, with: #""erstellt":"gestern""#)
        let (store, _) = try storeMit(json: json)
        XCTAssertNil(store.ladeProblem)
        XCTAssertEqual(store.profile.first?.name, "Eins")
    }

    /// `GymD.notiz` ist neu (Notiz je Training): ältere Ops haben das Feld nicht, neuere Builds dürfen weitere haben.
    func testGymBodyOhneNotizMitNotizUndMitFremdemFeldIstLesbar() {
        func op(_ json: String) -> Op { Op(id: "x", art: "gym.checkout", von: .testA, zeit: Date(timeIntervalSince1970: 1_790_000_000), d: Data(json.utf8)) }
        let alt = op(#"{"session":"s1","status":"ende","minuten":60}"#).daten(GymD.self)
        XCTAssertEqual(alt?.session, "s1")
        XCTAssertEqual(alt?.minuten, 60)
        XCTAssertNil(alt?.notiz)
        let neu = op(#"{"session":"s1","notiz":"Schulter zwickt","zukunft":{"a":[1,2]}}"#).daten(GymD.self)
        XCTAssertEqual(neu?.notiz, "Schulter zwickt")
    }

    func testKonsistenzDateiOhneZuordnungUndGeraeteDateiOhneFelderSindLesbar() throws {
        let ordner = try tempOrdner()
        try Data(#"{"kategorien":[{"id":"a","name":"Beine","farbe":"34C3A0"}],"fremd":1}"#.utf8).write(to: ordner.appendingPathComponent("konsistenz.json"))
        XCTAssertEqual(KonsistenzKategorienDatei.lesen(ordner).kategorien.map(\.name), ["Beine"])
        try Data(#"{"eintraege":{"bank":{"stufe":"4"}}}"#.utf8).write(to: ordner.appendingPathComponent("geraete.json"))
        XCTAssertEqual(GeraeteEinstellungDatei.lesen(ordner).eintraege["bank"]?.stufe, "4")
        XCTAssertNil(GeraeteEinstellungDatei.lesen(ordner).eintraege["bank"]?.notiz)
    }

    /// Acht Ziel-Medaillen sind neu im Katalog: bereits erreichte bleiben nach dem Update, und Lumis Stufe ändert sich weder durch sie noch durch den Neustart.
    func testErreichteMedaillenBleibenUndLumisStufeBleibtMitZielMedaillen() throws {
        let ordner = try tempOrdner()
        let alte = MeilensteinKatalog.alle.map(\.id).filter { !MeilensteinKatalog.neueIds.contains($0) }
        let vorher = DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: TestUhr().uhr)
        for id in alte.prefix(11) { vorher.meilensteine.markiere(id) }
        XCTAssertEqual(vorher.meilensteine.stufe, 6)
        let nachher = DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: TestUhr().uhr)
        XCTAssertEqual(nachher.meilensteine.erreicht.count, 11)
        XCTAssertEqual(nachher.meilensteine.stufe, 6)
        for id in MeilensteinKatalog.neueIds { nachher.meilensteine.markiere(id) }
        XCTAssertEqual(nachher.meilensteine.erreicht.count, 19)
        XCTAssertEqual(nachher.meilensteine.stufe, 6, "Ziel-Medaillen heben die Stufe nicht")
    }

    /// `KoerperArt.schulter` ist neu: alte Körperwerte (Oberarm, Taille) bleiben lesbar, der Oberarm liegt weiter unter `MessArt.bizeps`.
    func testKoerperwerteMitAlterUndNeuerArtSindLesbar() {
        func op(_ json: String) -> Op { Op(id: "x", art: "koerper.setzen", von: .testA, zeit: Date(timeIntervalSince1970: 1_790_000_000), d: Data(json.utf8)) }
        let alt = op(#"{"datum":"2026-10-01","art":"oberarm","wert":36.5}"#).daten(KoerperwertD.self)
        XCTAssertEqual(alt?.art, .oberarm)
        XCTAssertEqual(alt?.art.messArt.habitId, "mass.bizeps")
        XCTAssertEqual(op(#"{"datum":"2026-10-01","art":"schulter","wert":110,"zukunft":1}"#).daten(KoerperwertD.self)?.art, .schulter)
    }
}

private extension NamenAenderung {
    var isGesperrt: Bool { if case .gesperrt = self { true } else { false } }
}
