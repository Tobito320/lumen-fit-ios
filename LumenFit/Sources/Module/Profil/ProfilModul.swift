import Foundation

/// Modul profil: Onboarding, Profil-Blatt, Aussehen, Ziele, Datensicherung, Quellen, Datenschutz, Export (Ideen 71 bis 80).
enum ProfilModul {
    @MainActor private static var gestartet: Set<ObjectIdentifier> = []

    /// Nach einer Neuinstallation (Profil im Schlüsselbund, Daten fehlen) öffnet die App von selbst die Datensicherung mit der Willkommen-zurück-Karte.
    /// Das Blatt öffnet gleich und höchstens noch einmal beim ersten Vordergrund-Ereignis (falls das erste Mal zu früh war), dann nie wieder von selbst
    /// (keine Erinnerung). Solange die Karte nicht beantwortet ist, steht sie in der Datensicherung. Idempotent.
    @MainActor static func start(_ umgebung: AppUmgebung) {
        // Erst die Bedingung, dann merken: nur eine wirklich gestartete Umgebung wird vermerkt (sie lebt durch die Task weiter, ihre Adresse bleibt belegt).
        guard umgebung.neuinstallationErkannt, gestartet.insert(ObjectIdentifier(umgebung)).inserted else { return }
        oeffneWillkommenZurueck(umgebung)
        let strom = umgebung.ereignisse.strom()
        Task { @MainActor in
            for await ereignis in strom {
                guard umgebung.neuinstallationErkannt else { return }
                if case .vordergrund = ereignis {
                    oeffneWillkommenZurueck(umgebung)
                    return
                }
            }
        }
    }

    @MainActor static func oeffneWillkommenZurueck(_ umgebung: AppUmgebung) {
        guard umgebung.neuinstallationErkannt, umgebung.profil.hatProfil, umgebung.router.blatt == nil else { return }
        umgebung.router.oeffne(.profil(.datensicherung))
    }

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte): Körperdaten, Ziele daraus und eine Sicherung vor 12 Tagen.
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {
        guard let daten = umgebung.daten else { return }
        let jetzt = umgebung.uhr()
        let jahr = ProfilZielSpeicher.jahr(jetzt)
        let koerper = Koerperdaten(groesseCm: 178, geburtsjahr: 1998, geschlecht: nil)
        let ziele = ProfilZielVorschlag.vorschlag(koerper: koerper, art: .halten, gymTage: 3, kg: 78.4, jahr: jahr)
        ProfilZielSpeicher.sichere(ziele: ziele, koerper: koerper, in: daten, jahr: jahr)
        ProfilSicherungStand.merke(daten.ordner, jetzt: jetzt.addingTimeInterval(-12 * 86_400))
    }
}

/// Profil löschen (Idee 79): Passwort prüfen, Eintrag im Schlüsselbund löschen, danach den Profilordner. In dieser Reihenfolge, damit der alte
/// `DatenSatz` den Ordner nicht neu anlegt, bevor das Profil weg ist.
@MainActor
enum ProfilLoeschen {
    static func liste(_ daten: DatenSatz) -> [ProfilTexte.Loeschzeile] {
        ProfilTexte.loeschliste(einheiten: daten.training.sessions.count, essenstage: daten.essen.tage.count,
                                meilensteine: daten.meilensteine.erreicht.count, coachNachrichten: daten.coach.verlauf.count)
    }

    /// true, wenn das aktive Profil samt Daten gelöscht ist. Daten in Health bleiben unberührt.
    @discardableResult
    static func fuehreAus(_ umgebung: AppUmgebung, passwort: String) -> Bool {
        guard let aktiv = umgebung.profil.aktiv, umgebung.profil.pruefe(passwort: passwort, fuer: aktiv.id) else { return false }
        let ordner = umgebung.profilOrdner(aktiv.id)
        guard umgebung.profil.loesche(aktiv.id, passwort: passwort) else { return false }
        try? FileManager.default.removeItem(at: ordner)
        return true
    }
}
