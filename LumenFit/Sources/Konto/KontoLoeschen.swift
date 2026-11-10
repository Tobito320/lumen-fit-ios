import Foundation

/// Antwort des Servers auf `DELETE /konto`, aus Sicht der App.
enum KontoLoeschErgebnis: Equatable, Sendable {
    /// Auf dem Server weg (oder dort schon unbekannt); die Kennung auf dem Gerät ist vergessen.
    case geloescht
    /// Kein Netz: nichts gelöscht, weder dort noch hier.
    case keinNetz
    /// Der Server hat abgelehnt (gesperrt, Fehler) oder der Schlüsselbund war nicht lesbar: nichts gelöscht.
    case abgelehnt
}

/// "Konto löschen" (Profil > Konto): erst das Passwort, dann der Server, erst danach das Gerät (wie "Alles löschen"). In dieser Reihenfolge,
/// damit ohne Netz nichts lokal verschwindet und ein falsches Passwort nie den Server erreicht.
@MainActor
enum KontoLoeschen {
    enum Ergebnis: Equatable, Sendable {
        case geloescht, falschesPasswort, keinNetz, abgelehnt
        /// Server ist weg, das Gerät konnte die Profile nicht löschen (Schlüsselbund schreibt nicht): "Alles löschen" nochmal versuchen.
        case lokalFehlgeschlagen
    }

    static func fuehreAus(passwortStimmt: @MainActor () async -> Bool, server: @MainActor () async -> KontoLoeschErgebnis,
                          lokal: @MainActor () async -> Bool) async -> Ergebnis {
        guard await passwortStimmt() else { return .falschesPasswort }
        switch await server() {
        case .keinNetz: return .keinNetz
        case .abgelehnt: return .abgelehnt
        case .geloescht: return await lokal() ? .geloescht : .lokalFehlgeschlagen
        }
    }

    /// Was die Oberfläche danach zeigt; nil heißt: nichts zeigen (gelöscht, das Onboarding erscheint, oder das Passwort-Blatt meldet selbst).
    static func meldung(_ e: Ergebnis) -> String? {
        switch e {
        case .geloescht, .falschesPasswort: nil
        case .keinNetz: String(localized: "Keine Verbindung zum Server. Es wurde nichts gelöscht, weder dort noch auf diesem iPhone. Versuch es mit Netz nochmal.")
        case .abgelehnt: String(localized: "Der Server hat das Löschen gerade abgelehnt. Es wurde nichts gelöscht. Versuch es später nochmal oder schreib uns über das Kontaktformular.")
        case .lokalFehlgeschlagen: String(localized: "Dein Konto auf dem Server ist gelöscht. Auf diesem iPhone konnte nicht alles gelöscht werden. Lösch es bitte unter Deine Daten mit „Alles löschen“.")
        }
    }
}
