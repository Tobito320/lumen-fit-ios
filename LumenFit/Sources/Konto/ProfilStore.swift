import Foundation
import Observation

enum ProfilFehler: Error, Equatable, Sendable {
    case nameLeer
    case passwortZuKurz
    case speichernFehlgeschlagen
}

/// Die Profile dieses Geräts und das aktive. Ablage im Schlüsselbund (`konto.profile` als JSON, `konto.aktiv` als UUID-Text),
/// nie das Passwort, nur seine Spur. Es gibt keinen Anmeldebildschirm: ist ein Profil aktiv, startet die App direkt.
@MainActor @Observable
final class ProfilStore {
    nonisolated static let profileSchluessel = "konto.profile"
    nonisolated static let aktivSchluessel = "konto.aktiv"

    private(set) var profile: [Profil] = []
    private(set) var aktiv: Profil?
    var hatProfil: Bool { aktiv != nil }

    @ObservationIgnored private let schluesselbund: any Schluesselbund
    @ObservationIgnored private let ereignisse: EreignisKanal
    @ObservationIgnored private let runden: Int
    @ObservationIgnored private let uhr: Uhr

    /// `runden` ist nur für Tests kleiner als der Standard (600.000 brauchen je Aufruf spürbar Zeit).
    init(schluesselbund: any Schluesselbund, ereignisse: EreignisKanal, runden: Int = Passwort.standardRunden, uhr: @escaping Uhr = { Date() }) {
        self.schluesselbund = schluesselbund
        self.ereignisse = ereignisse
        self.runden = runden
        self.uhr = uhr
        profile = Self.lade(schluesselbund)
        let aktivID = schluesselbund.lese(Self.aktivSchluessel).flatMap { String(data: $0, encoding: .utf8) }
        aktiv = profile.first { $0.id.rawValue == aktivID } ?? profile.first
    }

    // MARK: - Schreiben

    /// Legt ein Profil an und macht es aktiv. Name nicht leer, Passwort mindestens 4 Zeichen (es schützt nur lokale Handlungen).
    @discardableResult
    func anlegen(name: String, passwort: String) throws -> Profil {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else { throw ProfilFehler.nameLeer }
        guard passwort.count >= Passwort.mindestLaenge else { throw ProfilFehler.passwortZuKurz }
        let profil = Profil(id: .neu(), name: sauber, erstellt: uhr(), passwort: Passwort.spur(fuer: passwort, runden: runden))
        var neu = profile
        neu.append(profil)
        try speichere(neu, aktiv: profil.id)
        ereignisse.senden(.profilGewechselt(profil.id))
        return profil
    }

    /// Wechselt das aktive Profil; nur mit richtigem Passwort des Ziels.
    @discardableResult
    func wechsle(zu id: ProfilID, passwort: String) -> Bool {
        guard let ziel = profile.first(where: { $0.id == id }), Passwort.stimmt(passwort, mit: ziel.passwort) else { return false }
        guard (try? speichere(profile, aktiv: id)) != nil else { return false }
        ereignisse.senden(.profilGewechselt(id))
        return true
    }

    func pruefe(passwort: String, fuer id: ProfilID) -> Bool {
        profile.first { $0.id == id }.map { Passwort.stimmt(passwort, mit: $0.passwort) } ?? false
    }

    /// Benennt das aktive Profil um (leerer Name ändert nichts).
    func benenne(um name: String) {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty, let aktuell = aktiv, let i = profile.firstIndex(where: { $0.id == aktuell.id }) else { return }
        var neu = profile
        neu[i].name = sauber
        try? speichere(neu, aktiv: aktuell.id)
    }

    /// Ändert das Passwort des aktiven Profils; nur mit richtigem alten Passwort und neuem von mindestens 4 Zeichen.
    @discardableResult
    func aenderePasswort(alt: String, neu: String) -> Bool {
        guard let aktuell = aktiv, Passwort.stimmt(alt, mit: aktuell.passwort), neu.count >= Passwort.mindestLaenge,
              let i = profile.firstIndex(where: { $0.id == aktuell.id }) else { return false }
        var liste = profile
        liste[i].passwort = Passwort.spur(fuer: neu, runden: runden)
        return (try? speichere(liste, aktiv: aktuell.id)) != nil
    }

    /// Löscht ein Profil aus dem Schlüsselbund (nur mit seinem Passwort). Die Daten im Profilordner räumt das Profil-Modul weg.
    /// War es aktiv, wird das erste übrige aktiv, sonst gibt es kein aktives Profil und das Onboarding erscheint wieder.
    @discardableResult
    func loesche(_ id: ProfilID, passwort: String) -> Bool {
        guard let ziel = profile.first(where: { $0.id == id }), Passwort.stimmt(passwort, mit: ziel.passwort) else { return false }
        let rest = profile.filter { $0.id != id }
        let vorher = aktiv?.id
        let neuerAktiv = vorher == id ? rest.first?.id : vorher
        guard (try? speichere(rest, aktiv: neuerAktiv)) != nil else { return false }
        if let neuerAktiv, neuerAktiv != vorher { ereignisse.senden(.profilGewechselt(neuerAktiv)) }
        return true
    }

    // MARK: - Intern

    private func speichere(_ liste: [Profil], aktiv aktivID: ProfilID?) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let daten = try? encoder.encode(liste) else { throw ProfilFehler.speichernFehlgeschlagen }
        do {
            try schluesselbund.schreibe(daten, fuer: Self.profileSchluessel)
            if let aktivID { try schluesselbund.schreibe(Data(aktivID.rawValue.utf8), fuer: Self.aktivSchluessel) }
            else { schluesselbund.entferne(Self.aktivSchluessel) }
        } catch { throw ProfilFehler.speichernFehlgeschlagen }
        profile = liste
        aktiv = liste.first { $0.id == aktivID }
    }

    private static func lade(_ schluesselbund: any Schluesselbund) -> [Profil] {
        guard let daten = schluesselbund.lese(profileSchluessel) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode([Profil].self, from: daten)) ?? []
    }
}
