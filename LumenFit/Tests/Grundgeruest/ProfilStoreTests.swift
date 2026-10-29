import Synchronization
import XCTest
@testable import LumenFit

@MainActor
final class ProfilStoreTests: XCTestCase {
    private func neuerStore(_ bund: SpeicherSchluesselbund = SpeicherSchluesselbund(), uhr: TestUhr = TestUhr()) -> (store: ProfilStore, kanal: EreignisKanal, bund: SpeicherSchluesselbund) {
        let kanal = EreignisKanal()
        return (ProfilStore(schluesselbund: bund, ereignisse: kanal, runden: 1_000, uhr: uhr.uhr), kanal, bund)
    }

    func testOhneProfilStartetDasOnboarding() {
        let (store, _, _) = neuerStore()
        XCTAssertFalse(store.hatProfil)
        XCTAssertNil(store.aktiv)
        XCTAssertTrue(store.profile.isEmpty)
    }

    func testAnlegenMachtDasProfilAktivUndSpeichertNurDieSpur() throws {
        let uhr = TestUhr()
        let (store, _, bund) = neuerStore(uhr: uhr)
        let profil = try store.anlegen(name: "  Beispiel  ", passwort: "geheim-1234")
        XCTAssertEqual(profil.name, "Beispiel")
        XCTAssertEqual(profil.erstellt, uhr.lesen)
        XCTAssertEqual(store.aktiv?.id, profil.id)
        XCTAssertTrue(store.pruefe(passwort: "geheim-1234", fuer: profil.id))
        XCTAssertFalse(store.pruefe(passwort: "falsch", fuer: profil.id))

        let gespeichert = try XCTUnwrap(bund.lese(ProfilStore.profileSchluessel))
        XCTAssertFalse(String(decoding: gespeichert, as: UTF8.self).contains("geheim-1234"), "das Passwort selbst wird nie gespeichert")
        XCTAssertEqual(bund.lese(ProfilStore.aktivSchluessel).map { String(decoding: $0, as: UTF8.self) }, profil.id.rawValue)
    }

    func testEingabenWerdenGeprueft() {
        let (store, _, _) = neuerStore()
        XCTAssertThrowsError(try store.anlegen(name: "   ", passwort: "abcd")) { XCTAssertEqual($0 as? ProfilFehler, .nameLeer) }
        XCTAssertThrowsError(try store.anlegen(name: "Beispiel", passwort: "abc")) { XCTAssertEqual($0 as? ProfilFehler, .passwortZuKurz) }
        XCTAssertFalse(store.hatProfil)
    }

    func testNeuerStoreMitDemselbenSchluesselbundFindetDasProfilWieder() throws {
        let (erster, _, bund) = neuerStore()
        let a = try erster.anlegen(name: "Eins", passwort: "abcd")
        let b = try erster.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertEqual(erster.aktiv?.id, b.id, "das zuletzt angelegte ist aktiv")

        let zweiter = neuerStore(bund).store
        XCTAssertEqual(zweiter.profile.map(\.name), ["Eins", "Zwei"])
        XCTAssertEqual(zweiter.aktiv?.id, b.id)
        XCTAssertTrue(zweiter.pruefe(passwort: "abcd", fuer: a.id))
    }

    func testWechselnBrauchtDasPasswortDesZielsUndMeldetEinEreignis() async throws {
        let (store, kanal, _) = neuerStore()
        let a = try store.anlegen(name: "Eins", passwort: "abcd")
        let b = try store.anlegen(name: "Zwei", passwort: "efgh")
        let strom = kanal.strom()

        XCTAssertFalse(store.wechsle(zu: a.id, passwort: "efgh"), "Passwort des anderen Profils zählt nicht")
        XCTAssertEqual(store.aktiv?.id, b.id)
        XCTAssertTrue(store.wechsle(zu: a.id, passwort: "abcd"))
        XCTAssertEqual(store.aktiv?.id, a.id)

        var gemeldet: ProfilID?
        for await ereignis in strom {
            if case .profilGewechselt(let id) = ereignis { gemeldet = id; break }
        }
        XCTAssertEqual(gemeldet, a.id)
    }

    func testUmbenennenUndPasswortAendern() throws {
        let (store, _, bund) = neuerStore()
        let profil = try store.anlegen(name: "Alt", passwort: "abcd")
        store.benenne(um: "  Neu ")
        XCTAssertEqual(store.aktiv?.name, "Neu")
        store.benenne(um: "   ")
        XCTAssertEqual(store.aktiv?.name, "Neu", "leerer Name ändert nichts")

        XCTAssertFalse(store.aenderePasswort(alt: "falsch", neu: "wxyz"))
        XCTAssertFalse(store.aenderePasswort(alt: "abcd", neu: "abc"), "neues Passwort zu kurz")
        XCTAssertTrue(store.aenderePasswort(alt: "abcd", neu: "wxyz"))
        XCTAssertFalse(store.pruefe(passwort: "abcd", fuer: profil.id))
        XCTAssertTrue(store.pruefe(passwort: "wxyz", fuer: profil.id))
        XCTAssertTrue(neuerStore(bund).store.pruefe(passwort: "wxyz", fuer: profil.id), "gespeichert")
    }

    func testLoeschenNurMitPasswortUndDasNaechsteProfilWirdAktiv() throws {
        let (store, _, bund) = neuerStore()
        let a = try store.anlegen(name: "Eins", passwort: "abcd")
        let b = try store.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertFalse(store.loesche(b.id, passwort: "abcd"))
        XCTAssertEqual(store.profile.count, 2)

        XCTAssertTrue(store.loesche(b.id, passwort: "efgh"))
        XCTAssertEqual(store.profile.map(\.id), [a.id])
        XCTAssertEqual(store.aktiv?.id, a.id, "war das aktive weg, wird das erste übrige aktiv")

        XCTAssertTrue(store.loesche(a.id, passwort: "abcd"))
        XCTAssertFalse(store.hatProfil)
        XCTAssertNil(bund.lese(ProfilStore.aktivSchluessel), "ohne aktives Profil kein Eintrag")
        XCTAssertTrue(neuerStore(bund).store.profile.isEmpty)
    }

    // Geändert gegenüber dem ersten Stand ("kaputter Eintrag ergibt einen leeren Store"): ein nicht lesbarer Eintrag ist nicht leer. Der Store zeigt
    // den Fehler und überschreibt nichts, sonst gingen alle Profile samt Passwort-Spur verloren (SPEC 5.4, Auftrag: "einmal Profil erstellt dann bleibt es").
    func testKaputterSchluesselbundEintragIstEinFehlerUndWirdNieUeberschrieben() throws {
        let bund = SpeicherSchluesselbund()
        let kaputt = Data("kein json".utf8)
        try bund.schreibe(kaputt, fuer: ProfilStore.profileSchluessel)
        let (store, _, _) = neuerStore(bund)
        XCTAssertFalse(store.hatProfil)
        XCTAssertEqual(store.ladeProblem, .kaputt)
        XCTAssertThrowsError(try store.anlegen(name: "Neu", passwort: "abcd")) { XCTAssertEqual($0 as? ProfilFehler, .profileNichtLesbar) }
        XCTAssertEqual(bund.lese(ProfilStore.profileSchluessel), kaputt, "der Eintrag bleibt unberührt")
        XCTAssertNil(bund.lese(ProfilStore.aktivSchluessel))
    }

    func testKaputtesVerwerfenSichertDenRohstandUndGibtDenWegFrei() throws {
        let bund = SpeicherSchluesselbund()
        let kaputt = Data("kein json".utf8)
        try bund.schreibe(kaputt, fuer: ProfilStore.profileSchluessel)
        let (store, _, _) = neuerStore(bund)
        XCTAssertTrue(store.verwerfeKaputtes())
        XCTAssertNil(store.ladeProblem)
        XCTAssertEqual(bund.lese(ProfilStore.kopieSchluessel), kaputt, "der Rohstand bleibt als Kopie")
        XCTAssertNil(bund.lese(ProfilStore.profileSchluessel))
        XCTAssertNoThrow(try store.anlegen(name: "Neu", passwort: "abcd"))
        XCTAssertEqual(bund.lese(ProfilStore.kopieSchluessel), kaputt, "die Kopie des kaputten Stands wird vom ersten Schreiben nicht zerstört")
    }

    func testEinLesefehlerIstKeinLeererSchluesselbundUndSchreibtNichts() throws {
        let bund = LesefehlerBund()
        let (store, _, _) = neuerStore2(bund)
        XCTAssertEqual(store.ladeProblem, .lesefehler)
        XCTAssertThrowsError(try store.anlegen(name: "Neu", passwort: "abcd")) { XCTAssertEqual($0 as? ProfilFehler, .profileNichtLesbar) }
        XCTAssertFalse(store.verwerfeKaputtes(), "bei einem Lesefehler ist der Eintrag ungewiss und wird nicht verworfen")
        XCTAssertEqual(bund.schreibzugriffe, 0, "es wurde nichts geschrieben")
        bund.liefert = .success(nil)
        store.ladeNeu()
        XCTAssertNil(store.ladeProblem, "Erneut versuchen liest noch einmal")
        XCTAssertNoThrow(try store.anlegen(name: "Neu", passwort: "abcd"))
    }

    func testEinDefekterEintragNimmtDieAnderenProfileNichtMit() throws {
        let (erster, _, bund) = neuerStore()
        let gut = try erster.anlegen(name: "Gut", passwort: "abcd")
        var roh = try XCTUnwrap(bund.lese(ProfilStore.profileSchluessel))
        // ein zweiter Eintrag ohne Kennung ist nicht lesbar
        let text = String(decoding: roh, as: UTF8.self)
        roh = Data((String(text.dropLast()) + #",{"name":"ohne id"}]"#).utf8)
        try bund.schreibe(roh, fuer: ProfilStore.profileSchluessel)

        let (zweiter, _, _) = neuerStore(bund)
        XCTAssertNil(zweiter.ladeProblem, "ein lesbares Profil genügt")
        XCTAssertEqual(zweiter.profile.map(\.id), [gut.id])
        XCTAssertEqual(bund.lese(ProfilStore.kopieSchluessel), roh, "der volle Rohstand liegt als Kopie")
        _ = try zweiter.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertEqual(bund.lese(ProfilStore.kopieSchluessel), roh, "die Kopie des Rohstands bleibt")
    }

    func testVorDemUeberschreibenBleibtDerLetzteVollstaendigeStandAlsKopie() throws {
        let (store, _, bund) = neuerStore()
        _ = try store.anlegen(name: "Eins", passwort: "abcd")
        let nachEins = try XCTUnwrap(bund.lese(ProfilStore.profileSchluessel))
        XCTAssertNil(bund.lese(ProfilStore.kopieSchluessel), "vor dem ersten Schreiben gab es nichts zu sichern")
        _ = try store.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertEqual(bund.lese(ProfilStore.kopieSchluessel), nachEins)
    }

    func testEinSchreibfehlerLaesstDenAltenStandStehen() throws {
        let bund = SchreibfehlerBund()
        let (store, _, _) = neuerStore2(bund)
        let eins = try store.anlegen(name: "Eins", passwort: "abcd")
        bund.schreibenGeht = false
        XCTAssertThrowsError(try store.anlegen(name: "Zwei", passwort: "efgh")) { XCTAssertEqual($0 as? ProfilFehler, .speichernFehlgeschlagen) }
        XCTAssertEqual(store.profile.map(\.id), [eins.id], "im Speicher kein Profil, das nicht gespeichert ist")
        XCTAssertEqual(neuerStore2(bund).store.profile.map(\.id), [eins.id], "im Schlüsselbund bleibt das alte Profil")
    }

    func testDasLoeschenDesLetztenProfilsMeldetEinEreignisUndEntferntDieKopie() async throws {
        let (store, kanal, bund) = neuerStore()
        let a = try store.anlegen(name: "Eins", passwort: "abcd")
        let strom = kanal.strom()
        XCTAssertTrue(store.loesche(a.id, passwort: "abcd"))
        kanal.senden(.vordergrund)
        var geloescht = false
        for await ereignis in strom {
            if case .profilGeloescht = ereignis { geloescht = true }
            if case .vordergrund = ereignis { break }
        }
        XCTAssertTrue(geloescht)
        XCTAssertNil(bund.lese(ProfilStore.kopieSchluessel), "die Kopie hält Name und Spur des gelöschten Profils nicht weiter vor")
    }

    func testZuruecksetzenLoeschtOhnePasswort() throws {
        let (store, _, _) = neuerStore()
        let a = try store.anlegen(name: "Eins", passwort: "abcd")
        let b = try store.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertTrue(store.setzeZurueck(a.id))
        XCTAssertEqual(store.profile.map(\.id), [b.id])
        XCTAssertEqual(store.aktiv?.id, b.id)
        XCTAssertFalse(store.setzeZurueck(a.id), "ein unbekanntes Profil gibt es nicht")
    }

    // MARK: - Helfer

    private func neuerStore2(_ bund: any Schluesselbund) -> (store: ProfilStore, kanal: EreignisKanal, bund: any Schluesselbund) {
        let kanal = EreignisKanal()
        return (ProfilStore(schluesselbund: bund, ereignisse: kanal, runden: 1_000, uhr: TestUhr().uhr), kanal, bund)
    }
}

/// Ein Schlüsselbund, dessen Lesen scheitert (zum Beispiel gesperrt) und der Schreibzugriffe zählt.
private final class LesefehlerBund: Schluesselbund {
    private let zustand = Mutex<(ergebnis: Result<Data?, KeychainFehler>, schreibzugriffe: Int)>((.failure(.status(-25308)), 0))
    var liefert: Result<Data?, KeychainFehler> {
        get { zustand.withLock { $0.ergebnis } }
        set { zustand.withLock { $0.ergebnis = newValue } }
    }
    var schreibzugriffe: Int { zustand.withLock { $0.schreibzugriffe } }

    func lese(_ schluessel: String) throws -> Data? { try zustand.withLock { $0.ergebnis }.get() }
    func schreibe(_ daten: Data, fuer schluessel: String) throws { zustand.withLock { $0.schreibzugriffe += 1 } }
    func entferne(_ schluessel: String) { zustand.withLock { $0.schreibzugriffe += 1 } }
}

/// Speicher, der nach `schreibenGeht = false` jedes Schreiben ablehnt.
private final class SchreibfehlerBund: Schluesselbund {
    private let eintraege = Mutex<[String: Data]>([:])
    private let geht = Mutex(true)
    var schreibenGeht: Bool {
        get { geht.withLock { $0 } }
        set { geht.withLock { $0 = newValue } }
    }

    func lese(_ schluessel: String) -> Data? { eintraege.withLock { $0[schluessel] } }
    func schreibe(_ daten: Data, fuer schluessel: String) throws {
        guard schreibenGeht else { throw KeychainFehler.status(-25308) }
        eintraege.withLock { $0[schluessel] = daten }
    }
    func entferne(_ schluessel: String) { _ = eintraege.withLock { $0.removeValue(forKey: schluessel) } }
}
