import Foundation
import Observation

enum ProfilFehler: Error, Equatable, Sendable {
    case nameLeer
    case passwortZuKurz
    case speichernFehlgeschlagen
    /// Der Eintrag im Schlüsselbund ließ sich nicht lesen oder deuten: nichts wird überschrieben, bis die Person es ansieht (`ProfilLadeProblem`).
    case profileNichtLesbar
}

/// Warum die Profile beim Start nicht geladen wurden. `lesefehler`: Security meldete einen Fehler (gesperrt, Entitlement), der Eintrag ist ungewiss,
/// nur "Erneut versuchen" hilft. `kaputt`: der Eintrag ist da, aber kein Profil darin ist lesbar; die Person kann ihn verwerfen (eine Kopie bleibt).
enum ProfilLadeProblem: Equatable, Sendable { case lesefehler, kaputt }

/// Die Profile dieses Geräts und das aktive. Ablage im Schlüsselbund (`konto.profile` als JSON, `konto.aktiv` als UUID-Text),
/// nie das Passwort, nur seine Spur. Es gibt keinen Anmeldebildschirm: ist ein Profil aktiv, startet die App direkt.
/// Schutz vor Verlust (SPEC 5.4): Lesefehler sind von "nichts da" unterschieden; ein nicht lesbarer Eintrag wird nie überschrieben; jedes Profil wird
/// einzeln gelesen (ein defekter Eintrag nimmt die anderen nicht mit); vor jedem Schreiben bleibt der letzte vollständig lesbare Stand als
/// `konto.profile.alt` liegen. Reihenfolge beim Schreiben: erst die Profile, dann das aktive (ein Abbruch dazwischen kostet nie ein Profil).
@MainActor @Observable
final class ProfilStore {
    nonisolated static let profileSchluessel = "konto.profile"
    nonisolated static let aktivSchluessel = "konto.aktiv"
    nonisolated static let kopieSchluessel = "konto.profile.alt"

    private(set) var profile: [Profil] = []
    private(set) var aktiv: Profil?
    /// nil, solange das Laden geklappt hat. Sonst zeigt die App statt des Onboardings eine Fehlerseite und legt nichts an.
    private(set) var ladeProblem: ProfilLadeProblem?
    var hatProfil: Bool { aktiv != nil }

    @ObservationIgnored private let schluesselbund: any Schluesselbund
    @ObservationIgnored private let ereignisse: EreignisKanal
    @ObservationIgnored private let runden: Int
    @ObservationIgnored private let uhr: Uhr
    /// Roh gelesener, nicht deutbarer Eintrag (für die Kopie beim Verwerfen).
    @ObservationIgnored private var rohKaputt: Data?
    /// Beim Laden wurden einzelne Einträge übersprungen: die Kopie hält den vollen Rohstand und wird nicht überschrieben.
    @ObservationIgnored private var kopieGesperrt = false

    /// `runden` ist nur für Tests kleiner als der Standard (600.000 brauchen je Aufruf spürbar Zeit).
    init(schluesselbund: any Schluesselbund, ereignisse: EreignisKanal, runden: Int = Passwort.standardRunden, uhr: @escaping Uhr = { Date() }) {
        self.schluesselbund = schluesselbund
        self.ereignisse = ereignisse
        self.runden = runden
        self.uhr = uhr
        ladeNeu()
    }

    /// Liest die Profile aus dem Schlüsselbund (beim Start und bei "Erneut versuchen"). Setzt `ladeProblem`, statt eine leere Liste zu erfinden.
    func ladeNeu() {
        let stand = Self.lade(schluesselbund)
        profile = stand.profile
        ladeProblem = stand.problem
        rohKaputt = stand.problem == .kaputt ? stand.roh : nil
        if stand.uebersprungen > 0, let roh = stand.roh {
            try? schluesselbund.schreibe(roh, fuer: Self.kopieSchluessel)
            kopieGesperrt = true
        }
        let aktivID = (try? schluesselbund.lese(Self.aktivSchluessel)).flatMap { String(data: $0, encoding: .utf8) }
        aktiv = profile.first { $0.id.rawValue == aktivID } ?? profile.first
    }

    /// Verwirft einen nicht deutbaren Eintrag, damit ein neues Profil angelegt werden kann. Der Rohstand bleibt als `konto.profile.alt` liegen.
    /// Nur bei `.kaputt`; bei einem Lesefehler ist der Eintrag ungewiss und bleibt unberührt.
    @discardableResult
    func verwerfeKaputtes() -> Bool {
        guard ladeProblem == .kaputt else { return false }
        if let roh = rohKaputt {
            guard (try? schluesselbund.schreibe(roh, fuer: Self.kopieSchluessel)) != nil else { return false }
        }
        schluesselbund.entferne(Self.profileSchluessel)
        schluesselbund.entferne(Self.aktivSchluessel)
        rohKaputt = nil
        ladeProblem = nil
        profile = []
        aktiv = nil
        return true
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
        _ = try? speichere(neu, aktiv: aktuell.id)
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
        return entferne(id)
    }

    /// "Passwort vergessen": löscht ein Profil ohne Passwort. Die Bestätigung (Liste, doppelte Frage) verlangt die Oberfläche (`ProfilLoeschen`).
    @discardableResult
    func setzeZurueck(_ id: ProfilID) -> Bool { entferne(id) }

    private func entferne(_ id: ProfilID) -> Bool {
        guard profile.contains(where: { $0.id == id }) else { return false }
        let rest = profile.filter { $0.id != id }
        let vorher = aktiv?.id
        let neuerAktiv = vorher == id ? rest.first?.id : vorher
        guard let daten = try? speichere(rest, aktiv: neuerAktiv) else { return false }
        // Die Kopie hält sonst Name und Passwort-Spur des gelöschten Profils weiter vor.
        if !kopieGesperrt {
            if rest.isEmpty { schluesselbund.entferne(Self.kopieSchluessel) } else { try? schluesselbund.schreibe(daten, fuer: Self.kopieSchluessel) }
        }
        if rest.isEmpty { ereignisse.senden(.profilGeloescht) }
        else if let neuerAktiv, neuerAktiv != vorher { ereignisse.senden(.profilGewechselt(neuerAktiv)) }
        return true
    }

    // MARK: - Intern

    /// Schreibt die Liste und das aktive Profil. Gibt die geschriebene Liste (JSON) zurück.
    @discardableResult
    private func speichere(_ liste: [Profil], aktiv aktivID: ProfilID?) throws -> Data {
        guard ladeProblem == nil else { throw ProfilFehler.profileNichtLesbar }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let daten = try? encoder.encode(liste) else { throw ProfilFehler.speichernFehlgeschlagen }
        sichereKopie()
        do {
            try schluesselbund.schreibe(daten, fuer: Self.profileSchluessel)
            if let aktivID { try schluesselbund.schreibe(Data(aktivID.rawValue.utf8), fuer: Self.aktivSchluessel) }
            else { schluesselbund.entferne(Self.aktivSchluessel) }
        } catch { throw ProfilFehler.speichernFehlgeschlagen }
        profile = liste
        aktiv = liste.first { $0.id == aktivID }
        return daten
    }

    /// Vor dem Überschreiben: der bisherige Eintrag nach `konto.profile.alt`, aber nur ein vollständig lesbarer Stand ersetzt die Kopie
    /// (ein halb lesbarer oder kaputter Stand würde sonst die gute Kopie zerstören).
    private func sichereKopie() {
        guard !kopieGesperrt, let roh = try? schluesselbund.lese(Self.profileSchluessel), let stand = Self.dekodiere(roh), stand.uebersprungen == 0 else { return }
        try? schluesselbund.schreibe(roh, fuer: Self.kopieSchluessel)
    }

    /// Jedes Profil einzeln: ein Eintrag, der sich nicht lesen lässt, kostet nur sich selbst.
    private struct Versuch<Inhalt: Decodable>: Decodable {
        let wert: Inhalt?
        init(from decoder: Decoder) throws { wert = try? Inhalt(from: decoder) }
    }

    private static func dekodiere(_ roh: Data) -> (profile: [Profil], uebersprungen: Int)? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let versuche = try? decoder.decode([Versuch<Profil>].self, from: roh) else { return nil }
        let profile = versuche.compactMap(\.wert)
        return (profile, versuche.count - profile.count)
    }

    private struct Stand {
        var profile: [Profil] = []
        var problem: ProfilLadeProblem?
        var uebersprungen = 0
        var roh: Data?
    }

    private static func lade(_ schluesselbund: any Schluesselbund) -> Stand {
        let gelesen: Data?
        do { gelesen = try schluesselbund.lese(profileSchluessel) } catch { return Stand(problem: .lesefehler) }
        guard let roh = gelesen else { return Stand() }
        guard let ergebnis = dekodiere(roh) else { return Stand(problem: .kaputt, roh: roh) }
        // Es gab Einträge, aber keiner war lesbar: auch das ist kaputt, nicht "leer".
        let nichtsLesbar = ergebnis.profile.isEmpty && ergebnis.uebersprungen > 0
        return Stand(profile: ergebnis.profile, problem: nichtsLesbar ? .kaputt : nil, uebersprungen: ergebnis.uebersprungen, roh: roh)
    }
}
