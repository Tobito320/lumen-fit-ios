// Quelle: Lovea Health/LoveaWidgets/GymHeuteIntent.swift
import AppIntents
import Foundation
import WidgetKit

/// Hakt Gym für heute ab oder wieder weg, ohne die App zu öffnen (Gym-Woche, Gym-Duell, Kurzbefehle). Keine Parameter: er wirkt auf das Profil und den Tag des Snapshots
/// und schreibt wie der Gewohnheiten-Haken nur eine Zeile in die Gruppe (`WidgetHabitAktion`); die App übernimmt sie beim nächsten Öffnen oder sofort.
/// Ohne Snapshot (App nie gestartet) oder ohne Profilkennung tut er nichts. Hat eine Einheit den Tag schon gefüllt, nimmt der Haken weg nur den Haken, nicht die Einheit.
struct GymHeuteIntent: AppIntent {
    static var title: LocalizedStringResource { "Gym heute abhaken" }
    static var description: IntentDescription { IntentDescription("Hakt das Gym von heute ab oder nimmt den Haken wieder weg.") }

    init() {}

    func perform() async throws -> some IntentResult {
        let ordner = AppGruppe.ordner()
        let jetzt = Date()
        guard let snapshot = WidgetSnapshotDatei.lade(ordner: ordner), let profil = snapshot.profilKennung, !profil.isEmpty else { return .result() }
        let neu = !WidgetAnzeige.gymHeuteErledigt(snapshot, jetzt: jetzt)
        WidgetHabitAktion.abhaken(habit: "gym", wert: neu ? 1 : 0, tag: Datum.text(jetzt), profil: profil, ordner: ordner, jetzt: jetzt)
        WidgetAnstoss.sende()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
