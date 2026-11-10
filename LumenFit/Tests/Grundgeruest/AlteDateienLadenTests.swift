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

    func testAlterKontoStandMitUndOhneCoachSichtbarBleibtLesbar() throws {
        let alt = try JSONDecoder().decode(KontoStand.self, from: Data(#"{"config":{"profilAnlegenErlaubt":true,"nameAendernTage":3,"coachSichtbar":true},"loveaErlaubt":true}"#.utf8))
        XCTAssertTrue(alt.config.profilAnlegenErlaubt)
        XCTAssertTrue(alt.loveaErlaubt)
        XCTAssertFalse(alt.config.schlafSichtbar, "kein Schlaf, bis der Server ihn erlaubt (auch wenn der alte Stand den Coach kannte)")
        XCTAssertFalse(alt.config.schlafBeleg, "Schlaf-Beleg ist ohne Antwort des Servers aus")
    }

    /// Crew-Dateien (`crew-server.json`, `crew-ausstehend.json`), der Konto-Stand und ein Plan mit den Feldern, deren Editoren entfernt sind:
    /// ohne neuere Felder, mit unbekannten Feldern und mit `null` bleibt alles lesbar, nichts geht verloren.
    func testAlteCrewDateienUndPlanFelderBleibenLesbar() throws {
        // Crew-Cache: nur die Pflichtfelder, dazu Unbekanntes; ein Eintrag mit unbekannter Art fällt einzeln weg.
        let umgebung = AppUmgebung.vorschau(fixtures: FixtureOrt.ordner)
        try FileManager.default.createDirectory(at: umgebung.konto.ordner, withIntermediateDirectories: true)
        let id = String(repeating: "a", count: 32)
        let cache = """
        {"herausforderungen":[
          {"id":"\(id)","art":"saetze","modus":"gegen","start":"2026-11-02T00:00:00Z","ende":"2026-11-09T00:00:00Z",
           "teilnehmer":[{"id":"t1","ich":true,"name":"Du","zukunft":{"x":1}},{"id":"t2","name":"Freund","status":"dabei","wert":3}],"neuesFeld":[1,2]},
          {"id":"\(id)","art":"mass-von-morgen","modus":"gegen","start":"2026-11-02T00:00:00Z","ende":"2026-11-09T00:00:00Z"}],
         "reaktionen":[{"id":"r1","von":"v1","art":"respekt","zeit":"2026-11-08T10:00:00Z","zukunft":true},
                       {"id":"r2","von":"v1","art":"zeichen-von-morgen","zeit":"2026-11-08T10:00:00Z"}],
         "gesendet":[{"an":"v1","art":"respekt","ziel":"einheit:2026-11-08"}],"unbekannt":{"a":1}}
        """
        try Data(cache.utf8).write(to: umgebung.konto.ordner.appendingPathComponent(CrewDienst.dateiName))
        let warte = #"[{"pfad":"/freunde/reaktionen","methode":"POST","koerper":null},{"pfad":"/freunde/reaktionen","methode":"DELETE","koerper":"e30=","zukunft":1},{"pfad":"/x","methode":"POST"}]"#
        try Data(warte.utf8).write(to: umgebung.konto.ordner.appendingPathComponent(CrewDienst.ausstehendName))
        let dienst = CrewDienst(umgebung: umgebung)
        let h = try XCTUnwrap(dienst.antwort?.herausforderungen.first)
        XCTAssertEqual(dienst.antwort?.herausforderungen.count, 1)
        XCTAssertEqual(h.status, "laeuft", "ohne Status gilt: läuft")
        XCTAssertEqual(h.ich, "", "ohne eigenen Stand")
        XCTAssertFalse(h.ersteller)
        XCTAssertEqual(h.teilnehmer.map(\.wert), [0, 3])
        XCTAssertTrue(h.teilnehmer[0].ich)
        XCTAssertEqual(dienst.antwort?.reaktionen.map(\.id), ["r1"])
        XCTAssertEqual(dienst.antwort?.gesendet.count, 1)
        XCTAssertEqual(dienst.ausstehend.count, 3)
        XCTAssertNil(dienst.ausstehend[0].koerper, "null ist kein Körper")
        XCTAssertEqual(dienst.ausstehend[1].koerper, Data("{}".utf8))
        XCTAssertNil(dienst.ausstehend[2].koerper, "ohne Feld")

        // Konto-Stand: ohne die neueren Felder, mit Unbekanntem und mit einem falschen Typ im neuen Feld.
        let alt = try JSONDecoder().decode(KontoStand.self, from: Data(#"{"config":{},"loveaErlaubt":true,"loveaImportErledigt":true,"zukunft":[1]}"#.utf8))
        XCTAssertTrue(alt.loveaErlaubt)
        XCTAssertFalse(alt.essenExportAn)
        XCTAssertEqual(alt.essenExportAnzahl, 0)
        XCTAssertNil(alt.essenExportZiele)
        XCTAssertNil(alt.kontoProfil, "alte Stände kennen das Profil des Kontos nicht")
        let schief = try JSONDecoder().decode(KontoStand.self, from: Data(#"{"loveaErlaubt":true,"essenExportAnzahl":4,"kontoProfil":5}"#.utf8))
        XCTAssertNil(schief.kontoProfil)
        XCTAssertEqual(schief.essenExportAnzahl, 4, "ein Typfehler kostet nur sein Feld")
        var neu = KontoStand()
        neu.kontoProfil = "p1"
        XCTAssertEqual(try JSONDecoder().decode(KontoStand.self, from: JSONEncoder().encode(neu)).kontoProfil, "p1")

        // Plan: Notiz, Pausenzeit und Supersatz haben keine Oberfläche mehr, die Felder bleiben an der Übung, auch durch Verschieben, Ändern und Speichern.
        let json = """
        {"tage":[{"id":"t1","name":"Push","wochentage":[1],"uebungen":[
          {"id":"u1","uebung":"bank","name":null,"saetze":[{"wdh":8,"kg":60,"failure":false}],"notiz":"Sitz auf Stufe 4","pause":90,"supersatz":true},
          {"id":"u2","uebung":"lat","saetze":[{"wdh":10,"failure":false}]},
          {"id":"u3","uebung":"eigen","name":"Dips","saetze":[],"zukunft":1}]}]}
        """
        let plan = try JSONDecoder().decode(TrainingsPlan.self, from: Data(json.utf8))
        func ersteUebung(_ p: TrainingsPlan) -> PlanUebung? { p.tage.first?.uebungen.first { $0.id == "u1" } }
        func pruefe(_ p: TrainingsPlan, _ was: String, file: StaticString = #filePath, line: UInt = #line) {
            let u = ersteUebung(p)
            XCTAssertEqual(u?.notiz, "Sitz auf Stufe 4", was, file: file, line: line)
            XCTAssertEqual(u?.pause, 90, was, file: file, line: line)
            XCTAssertEqual(u?.supersatz, true, was, file: file, line: line)
        }
        pruefe(plan, "gelesen")

        var tag = try XCTUnwrap(plan.tage.first)
        tag = PlanEditor.verschieben(tag, von: 2, nach: 0)
        XCTAssertEqual(tag.uebungen.map(\.id), ["u3", "u1", "u2"])
        let verschoben = TrainingLogik.tagSetzen(plan, tag)
        pruefe(verschoben, "verschoben")
        pruefe(TrainingLogik.uebernehmen(verschoben, planUebung: "u1", saetze: [PlanSatz(wdh: 6, kg: 65, failure: false)]), "Sätze übernommen")
        XCTAssertEqual(ersteUebung(TrainingLogik.uebernehmen(verschoben, planUebung: "u1", saetze: [PlanSatz(wdh: 6, kg: 65, failure: false)]))?.saetze.first?.wdh, 6)
        pruefe(TrainingLogik.aendern(verschoben, planUebung: "u2") { $0.notiz = "andere Übung" }, "andere Übung geändert")
        pruefe(PlanEditor.tagWeg(verschoben, id: "gibt-es-nicht"), "unbekannter Tag")

        let ordner = try tempOrdner()
        let vorher = DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: TestUhr().uhr)
        vorher.training.planSichern(verschoben)
        pruefe(vorher.training.plan, "gespeichert")
        pruefe(DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: TestUhr().uhr).training.plan, "nach dem Neustart")
    }

    /// W-003: alte Datei ohne `schlichtGesetzt`. Monochrom (der alte Standard) wird einmal Schlicht, ein selbst gewähltes Theme bleibt,
    /// und wer danach wieder Monochrom wählt, behält es beim nächsten Start.
    func testAltesMonochromWirdEinmalSchlichtEigeneWahlBleibt() throws {
        let ordner = try tempOrdner()
        let datei = ordner.appendingPathComponent("einstellungen.json")
        try Data(#"{"thema":"monochrom","erscheinung":"dunkel"}"#.utf8).write(to: datei)
        let store = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(store.werte.thema, .schlicht)
        XCTAssertEqual(store.werte.erscheinung, .dunkel, "der Rest bleibt")
        XCTAssertTrue(try JSONDecoder().decode(Einstellungen.self, from: Data(contentsOf: datei)).schlichtGesetzt, "der Merker steht in der Datei")
        store.aendere { $0.thema = .monochrom }
        XCTAssertEqual(EinstellungenStore(ordner: ordner).werte.thema, .monochrom, "nur einmal: die neue Wahl bleibt")

        let andere = try tempOrdner()
        try Data(#"{"thema":"wald"}"#.utf8).write(to: andere.appendingPathComponent("einstellungen.json"))
        XCTAssertEqual(EinstellungenStore(ordner: andere).werte.thema, .wald, "eigene Wahl bleibt")
    }

    /// Ein Theme (Auftrag 09.11.): alte Farbwelten laden weiter, wirken aber alle als Schlicht; die übrigen Einstellungen bleiben.
    func testAlteFarbweltLaedtMitEinemTheme() throws {
        let ordner = try tempOrdner()
        try Data(#"{"thema":"wald","erscheinung":"dunkel"}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let store = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(store.werte.thema, .wald, "gespeichert wird nichts umgeschrieben")
        XCTAssertEqual(ProfilThemaWahl.wirksam(store.werte.thema, loveaErlaubt: true), .schlicht)
        XCTAssertEqual(ProfilThemaWahl.wirksam(.lovea, loveaErlaubt: true), .schlicht)
        XCTAssertEqual(store.werte.erscheinung, .dunkel, "Erscheinung bleibt")
    }

    func testEinUnbekanntesThemeErgibtDenStandardUndBehaeltDenRest() throws {
        let ordner = try tempOrdner()
        try Data(#"{"thema":"neonpink","haptik":false,"gewichtsEinheit":"stone"}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let store = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(store.werte.thema, .schlicht)
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
