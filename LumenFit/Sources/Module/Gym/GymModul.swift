import Foundation

/// Das Modul gym: setzt den Port `trainingSteuerung` (`GymSitzung`), damit Live Activity, Band und Kurzbefehle ein Training ohne
/// Oberfläche steuern können. `start` läuft synchron in `ModulStart.starteAlle` und ist idempotent.
enum GymModul {
    @MainActor static func start(_ umgebung: AppUmgebung) {
        if umgebung.trainingSteuerung is GymSitzung { return }
        let sitzung = GymSitzung(umgebung: umgebung, puls: GymPulsMessung())
        umgebung.trainingSteuerung = sitzung
        sitzung.ladeWennNoetig()
        GymTipps.konfiguriere()   // TipKit einmal, im Test-Host und bei -lumenFitDemo nicht
        _ = sitzung.eigene   // eigene Übungen (Op fit.gym.uebung) schon beim Start falten
        PlanBilder.beobachte(umgebung)   // Bilder der Plan-Übungen vorab holen (Idee 26)
        // Zurück in der App: ein Training, das im Hintergrund per Intent oder Band begann, übernimmt die Sitzung.
        Task { @MainActor in
            for await ereignis in umgebung.ereignisse.strom() {
                if case .vordergrund = ereignis { sitzung.ladeWennNoetig() }
            }
        }
    }

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte): ein Split mit 3 Tagen und die letzten 8 Wochen Training
    /// mit steigenden Gewichten. Heute bleibt frei, damit die Startseite "Starten" zeigt.
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {
        guard let training = umgebung.daten?.training, let split = SplitLogik.fuer(nil, tage: 3).first else { return }
        let plan = SplitLogik.alsPlan(split)
        training.planSichern(plan)
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let montag = Datum.montagDerWoche(heute)
        for woche in 0..<8 {
            for tag in plan.tage {
                for wochentag in tag.wochentage {
                    let datum = Datum.addTage(montag, -7 * woche + wochentag - 1)
                    guard datum < heute else { continue }
                    let start = Datum.datum(datum).addingTimeInterval(18 * 3600)
                    training.nachtragen(tag: tag.id, start: start, ende: start.addingTimeInterval(55 * 60))
                    guard let session = training.sessions.first(where: { $0.start == start }) else { continue }
                    for (k, u) in tag.uebungen.enumerated() where !u.istCardio {
                        let kg = Double(20 + 10 * k) + 2.5 * Double(7 - woche)
                        let saetze = u.saetze.map { PlanSatz(wdh: $0.wdh, kg: kg, failure: false, ok: true) }
                        training.saetzeSenden(session.id, u, saetze)
                    }
                }
            }
        }
    }
}
