// Quelle: Lovea Health/LoveaWidgets/Shared/EssenAktivitaet.swift
import ActivityKit
import Foundation

/// Attribute der Essen-Live-Activity (Sperrbildschirm und Dynamic Island). Die App startet, aktualisiert und beendet sie (`EssenLiveDienst`),
/// das Widget-Ziel zeichnet sie (`EssenLiveWidget`). Aktualisiert wird nur bei Ereignissen (Mahlzeit gespeichert, App im Vordergrund), nie nach Zeit.
struct EssenLiveAktivitaet: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stand: EssenLiveStand
    }
}

/// Der Essensstand eines Tages, so wie ihn die Live Activity zeigt. Neue Felder nur optional (die System-Kopie einer laufenden Activity bleibt lesbar).
struct EssenLiveStand: Codable, Hashable, Sendable {
    /// Tag im Tagebuch, "yyyy-MM-dd": erkennt den Tageswechsel.
    var tag: String
    var kcal: Int
    var kcalZiel: Int
    var proteinG: Int
    var proteinZiel: Int
    var kohlenhydrateG: Int
    var kohlenhydrateZiel: Int
    var fettG: Int
    var fettZiel: Int
    /// kcal je Mahlzeit in der Reihenfolge von `Mahlzeit.allCases` (Frühstück, Mittag, Abend, Snacks). Immer genau vier Werte.
    var mahlzeitenKcal: [Int]
    /// `Mahlzeit.rawValue` der nächsten noch leeren Mahlzeit, nil wenn für den Rest des Tages keine offen ist.
    var naechste: String?
}
