import Foundation
import Observation

/// Der Ablauf des Onboardings in sechs Karten (Idee 71): Willkommen, Name (ohne Passwort), Bereiche, ein Ziel (Gym-Tage nur mit Gym), die Frage nach der Nutzungsmeldung, Health (nur gewählte Typen).
/// Alles Eingegebene bleibt hier im Speicher.
/// Das Profil entsteht erst auf der letzten Karte: `AppRootView` wechselt sofort zu den Tabs, sobald es ein aktives Profil gibt,
/// und würde die Karten 3 und 4 sonst mitten im Ausfüllen wegnehmen.
@MainActor @Observable
final class ProfilOnboardingFluss {
    enum Karte: Int, CaseIterable, Sendable {
        case willkommen, profil, bereiche, ziel, nutzung, health
    }

    private(set) var karte: Karte = .willkommen
    var name = ""
    var art: Zielart = .halten
    var gymTage = 3
    /// Die gewählten Bereiche (Standard alle drei); `setzeBereich` lässt den letzten nie ausschalten.
    private(set) var bereiche = Einstellungen()
    private(set) var healthAngefragt = false
    /// Die Antwort auf die Frage nach der Nutzungsmeldung; ohne Antwort geht es auf dieser Karte nicht weiter, vorgewählt ist nichts. Health hängt nie daran.
    private(set) var nutzung: NutzungAntwort = .offen
    private(set) var fehler: String?

    var anzahl: Int { Karte.allCases.count }
    /// "Schritt 2 von 5" für VoiceOver und die Anzeige.
    var stand: String { "Schritt \(karte.rawValue + 1) von \(anzahl)" }
    var istLetzte: Bool { karte == .health }

    var nameGueltig: Bool { if case .success = NamenRegel.pruefe(name) { true } else { false } }

    var kannWeiter: Bool {
        switch karte {
        case .willkommen, .bereiche, .ziel, .health: true
        case .profil: nameGueltig
        case .nutzung: nutzung != .offen
        }
    }

    /// Hält die Antwort fest und geht zur nächsten Karte.
    func antworteNutzung(_ antwort: NutzungAntwort) {
        nutzung = antwort
        weiter()
    }

    /// Schaltet einen Bereich der Auswahl; false, wenn es der letzte eingeschaltete wäre.
    @discardableResult
    func setzeBereich(_ bereich: AppBereich, an: Bool) -> Bool { bereiche.setze(bereich, an: an) }

    /// Wohin die App nach dem Einrichten geht: mit Gym zu den Plänen (dort "Geführt erstellen" oder ein fertiger Split), sonst bleibt es bei Heute.
    var startRoute: Route? { bereiche.gymAn ? .gym(.plaene) : nil }

    func weiter() {
        guard kannWeiter, let naechste = Karte(rawValue: karte.rawValue + 1) else { return }
        fehler = nil
        karte = naechste
    }

    func zurueck() {
        guard let vorige = Karte(rawValue: karte.rawValue - 1) else { return }
        fehler = nil
        karte = vorige
    }

    /// Fragt Health nur für die gewählten Bereiche (das System zeigt sein Blatt nur beim ersten Mal). Ohne Zwang: "Später" legt das Profil ohne diese Frage an.
    func healthFragen(leser: any HealthLeser) async {
        _ = await leser.zugriff(fuer: bereiche.healthTypen)
        healthAngefragt = true
    }

    /// Hinweis zum Namensfeld (nil, solange nichts getippt ist oder alles passt); gleiche Regel wie beim Ändern.
    var nameHinweis: String? { Self.nameHinweis(name) }

    static func nameHinweis(_ name: String) -> String? {
        guard !name.isEmpty, case .failure(let f) = NamenRegel.pruefe(name) else { return nil }
        return NamenRegel.text(f)
    }

    /// Legt das Profil an und schreibt Ziele und Einstellungen in einem Schritt. false mit `fehler`, wenn es nicht ging.
    @discardableResult
    func abschliessen(in umgebung: AppUmgebung) -> Bool {
        beende(Result { try umgebung.profil.anlegen(name: name, passwort: "") }, in: umgebung)
    }

    /// Wie `abschliessen`, aber abseits des Hauptthreads (die Oberfläche hängt nicht). Die Oberfläche nutzt diese.
    @discardableResult
    func abschliessenImHintergrund(in umgebung: AppUmgebung) async -> Bool {
        let ergebnis: Result<Profil, Error>
        do { ergebnis = .success(try await umgebung.profil.anlegenImHintergrund(name: name, passwort: "")) } catch { ergebnis = .failure(error) }
        return beende(ergebnis, in: umgebung)
    }

    private func beende(_ ergebnis: Result<Profil, Error>, in umgebung: AppUmgebung) -> Bool {
        if case .failure(let grund) = ergebnis {
            switch grund as? ProfilFehler {
            case .nameLeer:
                fehler = "Wie soll Lumi dich nennen?"
                karte = .profil
            case .nameUngueltig(let f):
                fehler = NamenRegel.text(f)
                karte = .profil
            case .nichtErlaubt:
                fehler = "Weitere Profile sind auf diesem iPhone nicht möglich."
            default:
                fehler = "Das Profil konnte nicht gespeichert werden. Versuch es nochmal."
            }
            return false
        }
        guard let daten = umgebung.daten else { return false }
        let jetzt = umgebung.uhr()
        let ziele = ProfilZielVorschlag.vorschlag(koerper: Koerperdaten(), art: art, gymTage: gymTage, kg: nil, jahr: ProfilZielSpeicher.jahr(jetzt))
        ProfilZielSpeicher.sichere(ziele: ziele, koerper: Koerperdaten(), in: daten, jahr: ProfilZielSpeicher.jahr(jetzt))
        let angefragt = healthAngefragt
        let gewaehlt = bereiche
        let antwort = nutzung
        let tag = Datum.text(jetzt)
        daten.einstellungen.aendere {
            $0.antworteNutzung(antwort, tag: tag)
            $0.healthGefragt = angefragt
            $0.gymAn = gewaehlt.gymAn
            $0.essenAn = gewaehlt.essenAn
            $0.schlafAn = gewaehlt.schlafAn
        }
        return true
    }
}
