import Foundation

/// Modul coach: setzt den Motor-Port der Umgebung (`CoachWahlMotor`: Apple Intelligence auf dem Gerät, sonst der Regelcoach) und bringt für
/// `-lumenFitDemo` einen kurzen Verlauf mit.
enum CoachModul {
    /// Idempotent: setzt nur den Port. Nichts läuft im Hintergrund, nichts wird gesendet; der Coach arbeitet erst, wenn jemand fragt.
    @MainActor static func start(_ umgebung: AppUmgebung) {
        let eingabe: @Sendable @MainActor () -> CoachEingabe? = { [weak umgebung] in
            guard let umgebung, let daten = umgebung.daten else { return nil }
            return CoachDaten.eingabe(umgebung, daten)
        }
        umgebung.coachMotor = CoachWahlMotor(modell: ModellCoachMotor(nachladen: .live(umgebung)), regeln: RegelCoachMotor(eingabe: eingabe))
    }

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte): ein Gespräch von gestern und eins von heute. Nur in einem leeren Verlauf.
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {
        guard let daten = umgebung.daten, daten.coach.verlauf.isEmpty else { return }
        let jetzt = umgebung.uhr()
        func nachricht(_ id: String, _ rolle: CoachRolle, _ text: String, vor minuten: Double, chips: [CoachChip] = [], daumen: Bool? = nil) -> CoachNachricht {
            CoachNachricht(id: "demo-coach-\(id)", rolle: rolle, text: text, zeit: jetzt.addingTimeInterval(-minuten * 60), chips: chips, daumen: daumen)
        }
        let nachrichten = [
            nachricht("1", .nutzer, "Wie habe ich geschlafen?", vor: 26 * 60),
            nachricht("2", .coach, "Du hast 7 h 10 min geschlafen, dein Ziel sind 8 h. Dir fehlen 50 min. Heute etwas früher ins Bett würde helfen.",
                      vor: 26 * 60 - 1, chips: [CoachChip(id: "gewohnheit-demo", text: "Mach ich", aktion: .gewohnheitAnlegen(name: "Früher ins Bett"))], daumen: true),
            nachricht("3", .nutzer, "Wie läuft mein Training?", vor: 12),
            nachricht("4", .coach, "Dein letztes Training: Push, gestern, 52 Minuten, 14 Sätze. Nächstes Mal bei Rudern: 40 kg × 9. Magst du morgen locker anfangen?",
                      vor: 11, chips: [CoachChip(id: "plan-morgen-leicht", text: "Morgen leicht", aktion: .planMorgenLeicht),
                                       CoachChip(id: "zeig-training", text: "Zeig mir", aktion: .oeffne(.gym(.training)))]),
        ]
        for n in nachrichten { daten.coach.haenge(n) }
        daten.coach.merke("Linkes Knie vorsichtig belasten")
    }
}
