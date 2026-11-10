import Foundation

/// Reine Rechnung der Seite "Energie und Tagesform": das Gefühl (1 = leer bis 5 = voll) je Tag der laufenden Woche, Mo bis So, und das Urteil der Woche.
/// shortcut: liest das Tagesgefühl der Energie-Bank (`TagesformGefuehl`); kommt das Gefühl nach dem Training (Seite Geschafft) dazu, hier einspeisen.
enum FortEnergie {
    /// Sieben Werte, Montag zuerst; nil = kein Eintrag. Tage nach `heute` bleiben leer.
    static func woche(_ werte: [String: Int], heute: String) -> [Int?] {
        let montag = Datum.montagDerWoche(heute)
        return (0..<7).map { i in
            let tag = Datum.addTage(montag, i)
            guard tag <= heute, let w = werte[tag] else { return nil }
            return min(5, max(1, w))
        }
    }

    /// Der gerundete Schnitt der Woche (1 bis 5); nil ohne Eintrag.
    static func urteil(_ woche: [Int?]) -> Int? {
        let da = woche.compactMap { $0 }
        guard !da.isEmpty else { return nil }
        return Int((Double(da.reduce(0, +)) / Double(da.count)).rounded())
    }

    /// Der Satz unter dem Urteil.
    static func satz(_ urteil: Int?) -> String {
        switch urteil {
        case nil: String(localized: "Noch kein Gefühl diese Woche. Tippe es in der Energie-Bank an.")
        case 4?, 5?: String(localized: "Du fühlst dich diese Woche meist gut.")
        case 3?: String(localized: "Diese Woche eher mittel. Schlaf und Pausen helfen.")
        default: String(localized: "Diese Woche eher müde. Gönn dir Erholung.")
        }
    }
}
