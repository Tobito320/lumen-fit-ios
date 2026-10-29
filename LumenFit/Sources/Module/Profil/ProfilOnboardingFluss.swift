import Foundation
import Observation

/// Der Ablauf des Onboardings in vier Karten (Idee 71): Willkommen, Name und Passwort, ein Ziel, Health. Alles Eingegebene bleibt hier im Speicher.
/// Das Profil entsteht erst auf der letzten Karte: `AppRootView` wechselt sofort zu den Tabs, sobald es ein aktives Profil gibt,
/// und würde die Karten 3 und 4 sonst mitten im Ausfüllen wegnehmen.
@MainActor @Observable
final class ProfilOnboardingFluss {
    enum Karte: Int, CaseIterable, Sendable {
        case willkommen, profil, ziel, health
    }

    private(set) var karte: Karte = .willkommen
    var name = ""
    var passwort = ""
    var art: Zielart = .halten
    var gymTage = 3
    private(set) var healthAngefragt = false
    private(set) var fehler: String?

    var anzahl: Int { Karte.allCases.count }
    /// "Schritt 2 von 4" für VoiceOver und die Anzeige.
    var stand: String { "Schritt \(karte.rawValue + 1) von \(anzahl)" }
    var istLetzte: Bool { karte == .health }

    var nameGueltig: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var passwortGueltig: Bool { passwort.count >= Passwort.mindestLaenge }

    var kannWeiter: Bool {
        switch karte {
        case .willkommen, .ziel, .health: true
        case .profil: nameGueltig && passwortGueltig
        }
    }

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

    /// Fragt Health (das System zeigt sein Blatt nur beim ersten Mal). Ohne Zwang: "Später" legt das Profil ohne diese Frage an.
    func healthFragen(leser: any HealthLeser) async {
        _ = await leser.zugriff(fuer: Set(HealthTyp.allCases))
        healthAngefragt = true
    }

    /// Hinweis zum Passwortfeld (leer, solange alles passt).
    var passwortHinweis: String? {
        guard !passwort.isEmpty, !passwortGueltig else { return nil }
        return "Mindestens \(Passwort.mindestLaenge) Zeichen."
    }

    /// Legt das Profil an und schreibt Ziele und Einstellungen in einem Schritt. false mit `fehler`, wenn es nicht ging.
    @discardableResult
    func abschliessen(in umgebung: AppUmgebung) -> Bool {
        beende(Result { try umgebung.profil.anlegen(name: name, passwort: passwort) }, in: umgebung)
    }

    /// Wie `abschliessen`, aber das Passwort wird abseits des Hauptthreads verarbeitet (die Oberfläche hängt nicht). Die Oberfläche nutzt diese.
    @discardableResult
    func abschliessenImHintergrund(in umgebung: AppUmgebung) async -> Bool {
        let ergebnis: Result<Profil, Error>
        do { ergebnis = .success(try await umgebung.profil.anlegenImHintergrund(name: name, passwort: passwort)) } catch { ergebnis = .failure(error) }
        return beende(ergebnis, in: umgebung)
    }

    private func beende(_ ergebnis: Result<Profil, Error>, in umgebung: AppUmgebung) -> Bool {
        if case .failure(let grund) = ergebnis {
            switch grund as? ProfilFehler {
            case .nameLeer:
                fehler = "Wie soll Lumi dich nennen?"
                karte = .profil
            case .passwortZuKurz:
                fehler = "Das Passwort braucht mindestens \(Passwort.mindestLaenge) Zeichen."
                karte = .profil
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
        daten.einstellungen.aendere { $0.healthGefragt = angefragt }
        passwort = ""
        return true
    }
}
