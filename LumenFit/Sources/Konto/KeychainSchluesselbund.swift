import Foundation
import Security

enum KeychainFehler: Error, Equatable, Sendable { case status(Int32) }

/// Die vier `SecItem`-Aufrufe hinter einem Port. Der echte Schlüsselbund ist im unsignierten Test-Host unbrauchbar (`-34018`);
/// ein Fake prüft so die Reihenfolge (zuerst aktualisieren, nur bei "nicht gefunden" anlegen).
protocol SecItemZugriff: Sendable {
    func kopiere(_ anfrage: [String: Any]) -> (status: OSStatus, daten: Data?)
    func aktualisiere(_ anfrage: [String: Any], mit neu: [String: Any]) -> OSStatus
    func fuegeHinzu(_ anfrage: [String: Any]) -> OSStatus
    func loesche(_ anfrage: [String: Any]) -> OSStatus
}

struct SystemSecItem: SecItemZugriff {
    func kopiere(_ anfrage: [String: Any]) -> (status: OSStatus, daten: Data?) {
        var ergebnis: CFTypeRef?
        let status = SecItemCopyMatching(anfrage as CFDictionary, &ergebnis)
        return (status, ergebnis as? Data)
    }

    func aktualisiere(_ anfrage: [String: Any], mit neu: [String: Any]) -> OSStatus { SecItemUpdate(anfrage as CFDictionary, neu as CFDictionary) }
    func fuegeHinzu(_ anfrage: [String: Any]) -> OSStatus { SecItemAdd(anfrage as CFDictionary, nil) }
    func loesche(_ anfrage: [String: Any]) -> OSStatus { SecItemDelete(anfrage as CFDictionary) }
}

/// Echter Schlüsselbund über `SecItem`. Schreiben: erst `SecItemUpdate` (der alte Eintrag bleibt, bis der neue Wert drin ist), nur bei
/// "nicht gefunden" `SecItemAdd`, zuerst synchronisierbar (iCloud-Schlüsselbund, wenn der Nutzer ihn an hat), bei Fehler lokal.
/// Fehler gehen nach oben: nie erst löschen, dann anlegen (ein Abbruch dazwischen kostete das Profil).
/// Lesen, Aktualisieren und Löschen immer mit `kSecAttrSynchronizableAny`, sonst findet die Abfrage synchronisierbare Einträge nicht.
/// Zugriff `AfterFirstUnlock`, kein eigenes Entitlement.
struct KeychainSchluesselbund: Schluesselbund {
    nonisolated static let standardDienst = "com.onlyus.lumen-fit.konto"
    let dienst: String
    let zugriff: any SecItemZugriff

    init(dienst: String = KeychainSchluesselbund.standardDienst, zugriff: any SecItemZugriff = SystemSecItem()) {
        self.dienst = dienst
        self.zugriff = zugriff
    }

    private func abfrage(_ schluessel: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: schluessel,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
    }

    func lese(_ schluessel: String) throws -> Data? {
        var anfrage = abfrage(schluessel)
        anfrage[kSecReturnData as String] = true
        anfrage[kSecMatchLimit as String] = kSecMatchLimitOne
        let antwort = zugriff.kopiere(anfrage)
        if antwort.status == errSecItemNotFound { return nil }
        guard antwort.status == errSecSuccess else { throw KeychainFehler.status(antwort.status) }
        return antwort.daten
    }

    func schreibe(_ daten: Data, fuer schluessel: String) throws {
        var status = zugriff.aktualisiere(abfrage(schluessel), mit: [kSecValueData as String: daten])
        if status == errSecItemNotFound {
            var neu = abfrage(schluessel)
            neu[kSecValueData as String] = daten
            neu[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            neu[kSecAttrSynchronizable as String] = true
            status = zugriff.fuegeHinzu(neu)
            if status != errSecSuccess {
                neu[kSecAttrSynchronizable as String] = false
                status = zugriff.fuegeHinzu(neu)
            }
        }
        guard status == errSecSuccess else { throw KeychainFehler.status(status) }
    }

    func entferne(_ schluessel: String) {
        _ = zugriff.loesche(abfrage(schluessel))
    }
}

/// Der echte Schlüsselbund mit Rückfall in den Speicher, aber nur dort, wo `darfAusweichen` es erlaubt. Im Standard ist das nur der Simulator
/// (unsignierter Build, `-34018`): die App startet dann, das Profil gilt bis zum Beenden. Auf dem Gerät geht der Fehler nach oben
/// (`ProfilFehler.speichernFehlgeschlagen`), damit die App nie Erfolg meldet und das Profil nur im Arbeitsspeicher liegt.
struct RueckfallSchluesselbund: Schluesselbund {
    let echt: any Schluesselbund
    let ersatz: any Schluesselbund
    let darfAusweichen: @Sendable (any Error) -> Bool

    init(echt: any Schluesselbund = KeychainSchluesselbund(), ersatz: any Schluesselbund = SpeicherSchluesselbund(),
         darfAusweichen: @escaping @Sendable (any Error) -> Bool = RueckfallSchluesselbund.nurImSimulator) {
        self.echt = echt
        self.ersatz = ersatz
        self.darfAusweichen = darfAusweichen
    }

    /// Die Richtlinie der echten App: ausweichen nur in einem Simulator-Build.
    nonisolated static func nurImSimulator(_ fehler: any Error) -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func lese(_ schluessel: String) throws -> Data? {
        do {
            if let daten = try echt.lese(schluessel) { return daten }
        } catch {
            guard darfAusweichen(error) else { throw error }
        }
        return try ersatz.lese(schluessel)
    }

    func schreibe(_ daten: Data, fuer schluessel: String) throws {
        do {
            try echt.schreibe(daten, fuer: schluessel)
            ersatz.entferne(schluessel)
        } catch {
            guard darfAusweichen(error) else { throw error }
            try ersatz.schreibe(daten, fuer: schluessel)
        }
    }

    func entferne(_ schluessel: String) {
        echt.entferne(schluessel)
        ersatz.entferne(schluessel)
    }
}
