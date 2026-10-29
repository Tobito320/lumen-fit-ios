// Quelle: Lovea Health/GymLive.swift
import ActivityKit
import Foundation

/// Wann die Live Activity eine neue Anzeige braucht. Rein.
enum LiveAktivitaetLogik {
    /// Nur bei Satzwechsel (neue Übung, neuer Satz, andere Satzzahl) oder wenn sich die Pause ändert. Alles andere, etwa ein wiederholter Aufruf mit
    /// demselben Stand, kostet nur Akku und bleibt aus.
    static func brauchtUpdate(alt: TrainingLiveStand?, neu: TrainingLiveStand) -> Bool {
        guard let alt else { return true }
        return alt.uebung != neu.uebung || alt.satz != neu.satz || alt.von != neu.von || alt.pauseEnde != neu.pauseEnde
    }
}

/// Die Stelle, die ActivityKit anfasst. Im Test ein Fake. `Activity` ist nicht Sendable: die echte Fabrik hält kein Objekt, sie fragt `Activity.activities` jedes Mal neu.
protocol LiveAktivitaetFabrik: Sendable {
    /// Läuft schon eine Training-Activity (auch eine, die ein früherer App-Prozess gestartet hat)?
    func laeuft() async -> Bool
    /// Legt sie an. Geht nur im Vordergrund und mit erlaubten Live Activities; false heißt: nicht gestartet, der nächste Aufruf versucht es noch einmal.
    func starte(_ stand: TrainingLiveStand) async -> Bool
    func aktualisiere(_ stand: TrainingLiveStand) async
    func beende() async
}

/// `LiveAnzeige` des Moduls widgets: das Training (Gym) meldet `training(stand)` bei jedem Satzwechsel und `training(nil)` am Ende.
/// Gestartet wird nur mit einem Stand (also nur im Training); beendet bei `nil` und von `WidgetsModul` bei `Ereignis.trainingBeendet`.
/// Aufrufe laufen nacheinander (eine Kette), damit ein schnelles Ende nicht vor dem noch laufenden Start überholt.
actor LiveActivityDienst: LiveAnzeige {
    private let fabrik: any LiveAktivitaetFabrik
    private var gestartet = false
    private var letzter: TrainingLiveStand?
    private var kette: Task<Void, Never>?

    init(fabrik: any LiveAktivitaetFabrik) { self.fabrik = fabrik }

    func training(_ stand: TrainingLiveStand?) async {
        let vorher = kette
        let aufgabe = Task { [self] in
            await vorher?.value
            await verarbeite(stand)
        }
        kette = aufgabe
        await aufgabe.value
    }

    private func verarbeite(_ stand: TrainingLiveStand?) async {
        guard let stand else {
            if gestartet { await fabrik.beende() } else if await fabrik.laeuft() { await fabrik.beende() }
            gestartet = false
            letzter = nil
            return
        }
        if !gestartet {
            // Eine Activity eines früheren Prozesses (App im Training beendet) wird weitergeführt statt doppelt angelegt.
            if await fabrik.laeuft() {
                gestartet = true
                letzter = stand
                await fabrik.aktualisiere(stand)
            } else if await fabrik.starte(stand) {
                gestartet = true
                letzter = stand
            }
            return
        }
        guard LiveAktivitaetLogik.brauchtUpdate(alt: letzter, neu: stand) else { return }
        letzter = stand
        await fabrik.aktualisiere(stand)
    }
}

/// ActivityKit (ungeprüft ohne Gerät: Start nur im Vordergrund, Anzeige, Knopf).
struct ActivityKitFabrik: LiveAktivitaetFabrik {
    private static func lebt(_ activity: Activity<TrainingAktivitaet>) -> Bool {
        activity.activityState == .active || activity.activityState == .stale
    }

    func laeuft() async -> Bool {
        Activity<TrainingAktivitaet>.activities.contains { Self.lebt($0) }
    }

    func starte(_ stand: TrainingLiveStand) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        for alt in Activity<TrainingAktivitaet>.activities { await alt.end(nil, dismissalPolicy: .immediate) }
        let inhalt = ActivityContent(state: TrainingAktivitaet.ContentState(stand: stand), staleDate: nil)
        return (try? Activity.request(attributes: TrainingAktivitaet(planName: stand.planName), content: inhalt)) != nil
    }

    func aktualisiere(_ stand: TrainingLiveStand) async {
        let inhalt = ActivityContent(state: TrainingAktivitaet.ContentState(stand: stand), staleDate: nil)
        for activity in Activity<TrainingAktivitaet>.activities where Self.lebt(activity) { await activity.update(inhalt) }
    }

    func beende() async {
        for activity in Activity<TrainingAktivitaet>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
