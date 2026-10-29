import Foundation
import Security

enum KeychainFehler: Error, Equatable, Sendable { case status(Int32) }

/// Echter Schlüsselbund über `SecItem`. Schreiben zuerst synchronisierbar (iCloud-Schlüsselbund, wenn der Nutzer ihn an hat),
/// bei Fehler lokal. Lesen und Löschen immer mit `kSecAttrSynchronizableAny`, sonst findet die Abfrage synchronisierbare Einträge nicht.
/// Zugriff `AfterFirstUnlock`, kein eigenes Entitlement.
struct KeychainSchluesselbund: Schluesselbund {
    nonisolated static let standardDienst = "com.onlyus.lumen-fit.konto"
    let dienst: String

    init(dienst: String = KeychainSchluesselbund.standardDienst) { self.dienst = dienst }

    private func abfrage(_ schluessel: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: schluessel,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
    }

    func lese(_ schluessel: String) -> Data? {
        var anfrage = abfrage(schluessel)
        anfrage[kSecReturnData as String] = true
        anfrage[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: CFTypeRef?
        guard SecItemCopyMatching(anfrage as CFDictionary, &ergebnis) == errSecSuccess else { return nil }
        return ergebnis as? Data
    }

    func schreibe(_ daten: Data, fuer schluessel: String) throws {
        SecItemDelete(abfrage(schluessel) as CFDictionary)
        var neu = abfrage(schluessel)
        neu[kSecValueData as String] = daten
        neu[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        neu[kSecAttrSynchronizable as String] = true
        var status = SecItemAdd(neu as CFDictionary, nil)
        if status != errSecSuccess {
            neu[kSecAttrSynchronizable as String] = false
            status = SecItemAdd(neu as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainFehler.status(status) }
    }

    func entferne(_ schluessel: String) {
        SecItemDelete(abfrage(schluessel) as CFDictionary)
    }
}

/// Der echte Schlüsselbund mit Rückfall in den Speicher, wenn Security nicht greift (unsignierter Simulator, `-34018`):
/// die App startet dann, das Profil gilt bis zum Beenden. In signierten Builds trifft der Rückfall nie.
struct RueckfallSchluesselbund: Schluesselbund {
    let echt: any Schluesselbund
    let ersatz: any Schluesselbund

    init(echt: any Schluesselbund = KeychainSchluesselbund(), ersatz: any Schluesselbund = SpeicherSchluesselbund()) {
        self.echt = echt
        self.ersatz = ersatz
    }

    func lese(_ schluessel: String) -> Data? { echt.lese(schluessel) ?? ersatz.lese(schluessel) }

    func schreibe(_ daten: Data, fuer schluessel: String) throws {
        do {
            try echt.schreibe(daten, fuer: schluessel)
            ersatz.entferne(schluessel)
        } catch {
            try ersatz.schreibe(daten, fuer: schluessel)
        }
    }

    func entferne(_ schluessel: String) {
        echt.entferne(schluessel)
        ersatz.entferne(schluessel)
    }
}
