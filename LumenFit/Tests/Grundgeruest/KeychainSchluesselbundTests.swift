import Security
import Synchronization
import XCTest
@testable import LumenFit

/// Der echte Schlüsselbund ist im unsignierten Test-Host unbrauchbar (`-34018`); diese Tests prüfen Reihenfolge und Fehlerweg am Fake der vier `SecItem`-Aufrufe.
final class KeychainSchluesselbundTests: XCTestCase {
    func testEinBestehenderEintragWirdNurAktualisiertNieGeloescht() throws {
        let fake = FakeSecItem(eintrag: Data("alt".utf8))
        try KeychainSchluesselbund(zugriff: fake).schreibe(Data("neu".utf8), fuer: "k")
        XCTAssertEqual(fake.aufrufe, ["aktualisiere"], "kein Löschen, kein Anlegen: ein Abbruch kostet den alten Wert nie")
        XCTAssertEqual(fake.eintrag, Data("neu".utf8))
    }

    func testEinFehlenderEintragWirdNachDemAktualisierenAngelegtZuerstSynchronisierbar() throws {
        let fake = FakeSecItem()
        try KeychainSchluesselbund(zugriff: fake).schreibe(Data("neu".utf8), fuer: "k")
        XCTAssertEqual(fake.aufrufe, ["aktualisiere", "hinzufuegen"])
        XCTAssertEqual(fake.synchronisierbarBeimAnlegen, [true])
        XCTAssertEqual(fake.eintrag, Data("neu".utf8))
    }

    func testSchlaegtDasSynchronisierbareAnlegenFehlWirdLokalAngelegt() throws {
        let fake = FakeSecItem(anlegenStatus: [errSecNotAvailable])
        try KeychainSchluesselbund(zugriff: fake).schreibe(Data("neu".utf8), fuer: "k")
        XCTAssertEqual(fake.aufrufe, ["aktualisiere", "hinzufuegen", "hinzufuegen"])
        XCTAssertEqual(fake.synchronisierbarBeimAnlegen, [true, false])
        XCTAssertEqual(fake.eintrag, Data("neu".utf8))
    }

    func testEinFehlerBeimAktualisierenGehtNachObenOhneLoeschenOderAnlegen() {
        let fake = FakeSecItem(eintrag: Data("alt".utf8), aktualisierenFehler: errSecInteractionNotAllowed)
        XCTAssertThrowsError(try KeychainSchluesselbund(zugriff: fake).schreibe(Data("neu".utf8), fuer: "k")) {
            XCTAssertEqual($0 as? KeychainFehler, .status(errSecInteractionNotAllowed))
        }
        XCTAssertEqual(fake.aufrufe, ["aktualisiere"])
        XCTAssertEqual(fake.eintrag, Data("alt".utf8), "der alte Wert bleibt")
    }

    func testScheitertAuchDasLokaleAnlegenGehtDerFehlerNachOben() {
        let fake = FakeSecItem(anlegenStatus: [errSecNotAvailable, errSecMissingEntitlement])
        XCTAssertThrowsError(try KeychainSchluesselbund(zugriff: fake).schreibe(Data("neu".utf8), fuer: "k")) {
            XCTAssertEqual($0 as? KeychainFehler, .status(errSecMissingEntitlement))
        }
        XCTAssertNil(fake.eintrag)
    }

    func testLesenUnterscheidetNichtGefundenVonEinemFehler() throws {
        XCTAssertNil(try KeychainSchluesselbund(zugriff: FakeSecItem()).lese("k"), "nichts da ist kein Fehler")
        XCTAssertEqual(try KeychainSchluesselbund(zugriff: FakeSecItem(eintrag: Data("x".utf8))).lese("k"), Data("x".utf8))
        let gesperrt = FakeSecItem(lesenFehler: errSecInteractionNotAllowed)
        XCTAssertThrowsError(try KeychainSchluesselbund(zugriff: gesperrt).lese("k")) {
            XCTAssertEqual($0 as? KeychainFehler, .status(errSecInteractionNotAllowed))
        }
    }
}

final class RueckfallSchluesselbundTests: XCTestCase {
    private let daten = Data("x".utf8)

    func testAufDemGeraetLandetEinSchreibfehlerNieStillImSpeicher() {
        let ersatz = SpeicherSchluesselbund()
        let bund = RueckfallSchluesselbund(echt: FehlerBund(schreibfehler: .status(-25308)), ersatz: ersatz, darfAusweichen: { _ in false })
        XCTAssertThrowsError(try bund.schreibe(daten, fuer: "k")) { XCTAssertEqual($0 as? KeychainFehler, .status(-25308)) }
        XCTAssertNil(ersatz.lese("k"), "nichts im Speicher: sonst meldet die App Erfolg, und beim nächsten Start ist das Profil weg")
        XCTAssertNil(try bund.lese("k"))
    }

    func testImSimulatorWeichtEsAusUndLiestDenErsatzWieder() throws {
        let ersatz = SpeicherSchluesselbund()
        let bund = RueckfallSchluesselbund(echt: FehlerBund(schreibfehler: .status(-34018)), ersatz: ersatz, darfAusweichen: { _ in true })
        try bund.schreibe(daten, fuer: "k")
        XCTAssertEqual(ersatz.lese("k"), daten)
        XCTAssertEqual(try bund.lese("k"), daten)
    }

    func testEinLesefehlerGehtAufDemGeraetNachObenUndImSimulatorInDenErsatz() throws {
        let streng = RueckfallSchluesselbund(echt: FehlerBund(lesefehler: .status(-25308)), ersatz: SpeicherSchluesselbund(), darfAusweichen: { _ in false })
        XCTAssertThrowsError(try streng.lese("k")) { XCTAssertEqual($0 as? KeychainFehler, .status(-25308)) }

        let ersatz = SpeicherSchluesselbund()
        try ersatz.schreibe(daten, fuer: "k")
        let locker = RueckfallSchluesselbund(echt: FehlerBund(lesefehler: .status(-34018)), ersatz: ersatz, darfAusweichen: { _ in true })
        XCTAssertEqual(try locker.lese("k"), daten)
    }

    func testEinErfolgImEchtenSchluesselbundRaeumtDenErsatzAuf() throws {
        let ersatz = SpeicherSchluesselbund()
        try ersatz.schreibe(Data("alt".utf8), fuer: "k")
        let bund = RueckfallSchluesselbund(echt: FehlerBund(), ersatz: ersatz, darfAusweichen: { _ in false })
        try bund.schreibe(daten, fuer: "k")
        XCTAssertNil(ersatz.lese("k"))
    }

    func testDieStandardRichtlinieWeichtNurImSimulatorAus() {
        let weicht = RueckfallSchluesselbund.nurImSimulator(KeychainFehler.status(-34018))
        #if targetEnvironment(simulator)
        XCTAssertTrue(weicht)
        #else
        XCTAssertFalse(weicht, "auf dem Gerät nie still in den Speicher")
        #endif
    }
}

private struct FehlerBund: Schluesselbund {
    var lesefehler: KeychainFehler?
    var schreibfehler: KeychainFehler?

    func lese(_ schluessel: String) throws -> Data? {
        if let lesefehler { throw lesefehler }
        return nil
    }

    func schreibe(_ daten: Data, fuer schluessel: String) throws {
        if let schreibfehler { throw schreibfehler }
    }

    func entferne(_ schluessel: String) {}
}

private struct SecZustand: Sendable {
    var aufrufe: [String] = []
    var eintrag: Data?
    var lesenFehler: OSStatus?
    var aktualisierenFehler: OSStatus?
    var anlegenStatus: [OSStatus] = []
    var synchronisierbarBeimAnlegen: [Bool] = []

    mutating func kopiere() -> (status: OSStatus, daten: Data?) {
        aufrufe.append("kopiere")
        if let lesenFehler { return (lesenFehler, nil) }
        guard let eintrag else { return (errSecItemNotFound, nil) }
        return (errSecSuccess, eintrag)
    }

    mutating func aktualisiere(_ neu: [String: Any]) -> OSStatus {
        aufrufe.append("aktualisiere")
        if let aktualisierenFehler { return aktualisierenFehler }
        guard eintrag != nil else { return errSecItemNotFound }
        eintrag = neu[kSecValueData as String] as? Data
        return errSecSuccess
    }

    mutating func fuegeHinzu(_ anfrage: [String: Any]) -> OSStatus {
        aufrufe.append("hinzufuegen")
        synchronisierbarBeimAnlegen.append(anfrage[kSecAttrSynchronizable as String] as? Bool ?? false)
        let status = anlegenStatus.isEmpty ? errSecSuccess : anlegenStatus.removeFirst()
        if status == errSecSuccess { eintrag = anfrage[kSecValueData as String] as? Data }
        return status
    }
}

/// Die vier `SecItem`-Aufrufe im Speicher; merkt sich die Reihenfolge der Aufrufe.
private final class FakeSecItem: SecItemZugriff {
    private let zustand: Mutex<SecZustand>

    init(eintrag: Data? = nil, lesenFehler: OSStatus? = nil, aktualisierenFehler: OSStatus? = nil, anlegenStatus: [OSStatus] = []) {
        zustand = Mutex(SecZustand(eintrag: eintrag, lesenFehler: lesenFehler, aktualisierenFehler: aktualisierenFehler, anlegenStatus: anlegenStatus))
    }

    var aufrufe: [String] { zustand.withLock { $0.aufrufe } }
    var eintrag: Data? { zustand.withLock { $0.eintrag } }
    var synchronisierbarBeimAnlegen: [Bool] { zustand.withLock { $0.synchronisierbarBeimAnlegen } }

    func kopiere(_ anfrage: [String: Any]) -> (status: OSStatus, daten: Data?) { zustand.withLock { $0.kopiere() } }
    func aktualisiere(_ anfrage: [String: Any], mit neu: [String: Any]) -> OSStatus { zustand.withLock { $0.aktualisiere(neu) } }
    func fuegeHinzu(_ anfrage: [String: Any]) -> OSStatus { zustand.withLock { $0.fuegeHinzu(anfrage) } }
    func loesche(_ anfrage: [String: Any]) -> OSStatus { zustand.withLock { $0.aufrufe.append("loesche"); return errSecSuccess } }
}
