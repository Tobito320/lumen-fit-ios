import Foundation

/// Texte der Verbinden-Seite, die ehrlich sagen, was heute läuft (SPEC 5.5 und 16, Annahme 33).
/// Quelle A (Lovea an Lumen Fit) läuft ab dem ersten Tag. Vertrag B (Lumen Fit an Lovea, Band-Wünsche) wartet auf eine Lovea-Runde;
/// sobald Lovea die Dateien liest und schreibt, wird `loveaTauschtDateien` wahr und die Zusätze verschwinden.
enum VerbindenTexte {
    nonisolated static let loveaTauschtDateien = false

    nonisolated static func freigabenFuss(loveaTauscht: Bool = VerbindenTexte.loveaTauschtDateien) -> String {
        let basis = "Standard: nichts. Dein Partner sieht nur, was du hier einschaltest, und immer nur eine Zusammenfassung von heute."
        return loveaTauscht ? basis : basis + " Lumen Fit legt die Datei schon ab; Lovea zeigt sie aber erst nach einem eigenen Update."
    }

    nonisolated static func vorschauFuss(loveaTauscht: Bool = VerbindenTexte.loveaTauschtDateien) -> String {
        let basis = "Genau diese Zeilen stehen in der Datei für Lovea, dazu Meldungen wie \"im Gym\", soweit die Art freigegeben ist."
        return loveaTauscht ? basis : basis + " Bis Lovea aktualisiert ist, sieht dein Partner davon noch nichts."
    }

    nonisolated static let mitteilungenFuss = "Wenn dein Partner etwas teilt, zeigt Lumen Fit eine Mitteilung, einmal je Ereignis. Sie kommt, wenn Lumen Fit läuft oder iOS es kurz weckt; sofort meldet nur Lovea selbst."

    nonisolated static func wunschFuss(loveaTauscht: Bool = VerbindenTexte.loveaTauschtDateien) -> String {
        let basis = "Wenn dein Partner in Lovea eine Vibration wünscht. Lumen Fit führt sie aus, sobald es läuft; ein Wunsch, der älter als 15 Minuten ist, verfällt."
        return loveaTauscht ? basis : basis + " Lovea schickt solche Wünsche erst nach einem eigenen Update."
    }

    nonisolated static let pauseFuss = "Wenn die Pause im offenen Training abläuft. Bei gesperrtem iPhone kann iOS die App anhalten: dann summt das Band erst, wenn sie wieder wach ist, nach mehr als 30 Sekunden gar nicht mehr. Der Zähler auf dem Sperrbildschirm läuft immer weiter."
}
