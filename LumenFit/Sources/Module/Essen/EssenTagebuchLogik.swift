// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (TagebuchAnsicht: Titel, Wasserzähler, Mahlzeit-Zeile, Körperwerte)
import Foundation

/// Reine Regeln des Essen-Tabs, getestet ohne Oberfläche.
enum EssenTagebuchLogik {
    /// Ein Glas im Wasserzähler, wie beim Wasser-Habit (Gläser je Tag).
    nonisolated static let glasMl = 250

    /// "Heute", "Gestern", "Morgen" oder der Tag ausgeschrieben (eine Regel für Tab und Mahlzeiten-Seiten).
    nonisolated static func titel(tag: String, heute: String) -> String { EssenMahlzeitenLogik.tagTitel(tag, heute: heute) }

    nonisolated static func woche(tag: String) -> Int { Datum.kalender.component(.weekOfYear, from: Datum.datum(tag)) }

    /// Milliliter als Liter mit Komma ohne überflüssige Nullen: 1750 -> "1,75 l", 2000 -> "2 l".
    nonisolated static func liter(_ ml: Int) -> String {
        var text = String(format: "%.2f", Double(ml) / 1000)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",") + " l"
    }

    /// Wie viele Gläser das Raster zeigt: das Ziel, und ein leeres zum Weiterzählen, wenn man darüber liegt.
    nonisolated static func glasAnzahl(ziel: Int, voll: Int, bearbeitbar: Bool = true) -> Int {
        max(ziel, voll + (bearbeitbar ? 1 : 0))
    }

    /// Tipp auf ein volles Glas: bis dahin zurück. Tipp auf das nächste leere: eins mehr.
    nonisolated static func glaeserNachTipp(index: Int, voll: Int) -> Int { index < voll ? index : index + 1 }

    /// Richtwert einer Mahlzeit in kcal aus dem Tagesziel.
    nonisolated static func richtwert(_ m: Mahlzeit, zielKcal: Int) -> Int { Int((m.anteil * Double(zielKcal)).rounded()) }

    /// Anteil 0 bis 1, darüber wird gekappt.
    nonisolated static func anteil(ist: Double, soll: Double) -> Double { soll > 0 ? min(1, max(0, ist / soll)) : 0 }

    nonisolated static func gewichtText(zehntel: Int?) -> String {
        guard let zehntel else { return "–" }
        return "\(ErnaehrungLogik.zahl(Double(zehntel) / 10)) kg"
    }

    /// Unter dem Gewicht: für diesen Tag eingetragen, zuletzt früher ("Zuletzt am 03.10.") oder noch nie.
    nonisolated static func gewichtUnterzeile(datum: String?, tag: String) -> String {
        guard let datum else { return "Noch nicht eingetragen" }
        if datum == tag { return "An diesem Tag eingetragen" }
        let teile = datum.split(separator: "-")
        return teile.count == 3 ? "Zuletzt am \(teile[2]).\(teile[1])." : "Zuletzt am \(datum)"
    }

    /// Neues Gewicht in Zehntel-kg nach einem Schritt (±1), begrenzt auf 30,0 bis 249,9 kg (`Koerpermasse`).
    nonisolated static func gewichtNach(zehntel: Int, schritt: Int) -> Int {
        min(Koerpermasse.gewichtZehntel.upperBound, max(Koerpermasse.gewichtZehntel.lowerBound, zehntel + schritt))
    }
}
