import Foundation

/// Woher ein Lebensmittel stammt, für die Zeile "Quelle: …" in der Detailansicht (Namensnennung: BLS CC BY 4.0, Open Food Facts ODbL).
enum EssenQuelle {
    static func name(_ l: Lebensmittel) -> String {
        if l.quelle == "bls" || l.id.hasPrefix("bls-") { return "BLS" }
        if l.quelle == "off" || l.id.hasPrefix("off-") { return "Open Food Facts" }
        if l.istRezept { return "dein Rezept" }
        return "von dir eingetragen"
    }

    static func zeile(_ l: Lebensmittel) -> String { "Quelle: \(name(l))" }
}
