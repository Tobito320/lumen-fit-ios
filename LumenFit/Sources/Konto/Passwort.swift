import CommonCrypto
import Foundation

/// Passwort-Spur: PBKDF2-HMAC-SHA256 (CommonCrypto), 600.000 Runden (OWASP 2023, in der Spur gespeichert, damit sie steigen können),
/// Vergleich in konstanter Zeit. Das Passwort selbst wird nie gespeichert.
enum Passwort {
    nonisolated static let standardRunden = 600_000
    nonisolated static let mindestLaenge = 4

    static func spur(fuer passwort: String, runden: Int = standardRunden) -> PasswortSpur {
        let salz = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        return PasswortSpur(salz: salz, hash: hash(passwort, salz: salz, runden: runden), runden: runden)
    }

    static func stimmt(_ passwort: String, mit spur: PasswortSpur) -> Bool {
        gleich(hash(passwort, salz: spur.salz, runden: spur.runden), spur.hash)
    }

    /// Dieselbe Rechnung abseits des Hauptthreads: 600.000 Runden sind auf dem Gerät spürbar (Hänger beim Tippen auf "Weiter").
    static func spurImHintergrund(fuer passwort: String, runden: Int = standardRunden) async -> PasswortSpur {
        await Task.detached(priority: .userInitiated) { spur(fuer: passwort, runden: runden) }.value
    }

    static func stimmtImHintergrund(_ passwort: String, mit spur: PasswortSpur) async -> Bool {
        await Task.detached(priority: .userInitiated) { stimmt(passwort, mit: spur) }.value
    }

    /// 32 Byte; bei einem Fehler der Funktion (kommt nicht vor) ein leerer Hash, der nie stimmt.
    static func hash(_ passwort: String, salz: Data, runden: Int) -> Data {
        var ergebnis = [UInt8](repeating: 0, count: 32)
        let status = salz.withUnsafeBytes { salzPuffer in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwort, passwort.utf8.count,
                salzPuffer.bindMemory(to: UInt8.self).baseAddress, salz.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(max(1, runden)),
                &ergebnis, ergebnis.count)
        }
        return status == Int32(kCCSuccess) ? Data(ergebnis) : Data()
    }

    /// Dauer hängt nur von der Länge ab, nie davon, wo die Bytes sich unterscheiden.
    static func gleich(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count, !a.isEmpty else { return false }
        var unterschied: UInt8 = 0
        for (x, y) in zip(a, b) { unterschied |= x ^ y }
        return unterschied == 0
    }
}
