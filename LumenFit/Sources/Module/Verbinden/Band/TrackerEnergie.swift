// Quelle: Lovea Health/Tracker/TrackerEnergie.swift
import Foundation

/// Energiesparen der Tracker-Seite: ein Schalter, an oder aus (W-030). Das Protokoll kennt nur für den Puls einen Abstand
/// (SpO2, Stress und HRV sind nur an oder aus), darum setzt der Schalter den Abstand der Puls-Dauermessung. Aus ist der
/// Wert, den der Tracker ab Werk hat (am 08.10.2026 gelesen); der Spar-Abstand ist eine Annahme, nicht am Gerät gemessen.
/// Der Zustand liegt am Tracker und wird zurückgelesen, die App merkt sich nichts. Ein in Build 136 gewählter Abstand
/// (5, 10, 15, 30, 45 oder 60 Minuten) wird nach derselben Regel gedeutet und nicht umgeschrieben.
enum TrackerEnergie {
    /// Abstand ab Werk in Minuten.
    static let standardMinuten = 10
    /// Abstand bei Energiesparen in Minuten (früher die Stufe "Sparsam").
    static let sparMinuten = 30

    /// An, wenn der Tracker seltener misst als ab Werk. Ein früher gewählter dichterer Abstand (5 Minuten) zählt als aus.
    static func an(minuten: Int) -> Bool { minuten > standardMinuten }

    /// Der Abstand, den der Schalter an den Tracker schreibt.
    static func minuten(an: Bool) -> Int { an ? sparMinuten : standardMinuten }

    /// Der Satz unter dem Schalter. Nennt den Abstand, den der Tracker meldet, und sagt ehrlich, dass die Ersparnis offen ist.
    static func erklaerung(minuten: Int) -> String {
        if an(minuten: minuten) {
            return String(localized: "Der Puls wird alle \(minuten) Minuten gemessen statt alle \(standardMinuten). Das spart Akku, wie viel ist noch nicht gemessen.")
        }
        return String(localized: "Der Puls wird alle \(minuten) Minuten gemessen. Mit Energiesparen alle \(sparMinuten) Minuten: das spart Akku, wie viel ist noch nicht gemessen.")
    }
}
