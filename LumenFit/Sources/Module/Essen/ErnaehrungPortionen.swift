// Quelle: Lovea Health/Ernaehrung/ErnaehrungPortionen.swift (MengenOption, MengenRad; HaushaltsMasse liegt im Grundgerüst)
import Foundation

/// Eine wählbare Menge: eine bestimmte Portion, oder Gramm/Milliliter direkt.
enum MengenOption: Hashable {
    case portion(LebensmittelPortion)
    case gramm
    case milliliter

    var einheit: Einheit {
        switch self {
        case .portion: .portion
        case .gramm: .g
        case .milliliter: .ml
        }
    }

    /// Portionen zuerst, danach Gramm/Milliliter, die Basis-Einheit des Lebensmittels vor der anderen.
    static func optionen(_ l: Lebensmittel) -> [MengenOption] {
        var liste: [MengenOption] = ErnaehrungLogik.portionsAuswahl(l).map { .portion($0) }
        liste += l.fluessig ? [.milliliter, .gramm] : [.gramm, .milliliter]
        return liste
    }

    /// Passende Option zu einer gespeicherten Menge (Eintrag oder "letzte Menge"). `.packung` läuft
    /// über die gleichnamige Portion aus `portionsAuswahl`.
    static func auswahl(einheit: Einheit, portionName: String?, l: Lebensmittel) -> MengenOption {
        switch einheit {
        case .g: return .gramm
        case .ml: return .milliliter
        case .portion:
            if let name = portionName, let p = ErnaehrungLogik.portionsAuswahl(l).first(where: { $0.name == name }) {
                return .portion(p)
            }
            return .portion(LebensmittelPortion(name: portionName ?? "Portion", gramm: l.portionMenge ?? 100))
        case .packung:
            if let p = ErnaehrungLogik.portionsAuswahl(l).first(where: { $0.name == "Packung" }) { return .portion(p) }
            return .gramm
        }
    }

    /// "ganze, mittelgroß (120 g)", "Gramm", "Milliliter".
    func anzeige(_ l: Lebensmittel) -> String {
        switch self {
        case .portion(let p): "\(p.name) (\(ErnaehrungLogik.zahl(p.gramm)) \(l.basisEinheit.rawValue))"
        case .gramm: "Gramm"
        case .milliliter: "Milliliter"
        }
    }
}

/// Drei Spalten: Ganzzahl, Bruch, Einheit. Das Feld darüber nimmt jede Zahl, das Rad klemmt am Rand.
enum MengenRad {
    static let maxGanz = 2000
    static let brueche: [(text: String, wert: Double)] = [
        ("–", 0), ("⅛", 0.125), ("¼", 0.25), ("⅓", 1.0 / 3), ("½", 0.5), ("⅔", 2.0 / 3), ("¾", 0.75), ("⅞", 0.875),
    ]

    static func zahl(ganz: Int, bruch: Int) -> Double { Double(ganz) + brueche[min(max(bruch, 0), brueche.count - 1)].wert }

    static func zerlegen(_ zahl: Double) -> (ganz: Int, bruch: Int) {
        let z = max(0, zahl)
        let ganz = min(Int(z.rounded(.down)), maxGanz)
        let rest = ganz == maxGanz ? 0 : z - Double(ganz)
        let bruch = brueche.indices.min { abs(brueche[$0].wert - rest) < abs(brueche[$1].wert - rest) } ?? 0
        return (ganz, bruch)
    }

    /// Bis 3 Nachkommastellen, deutsches Komma, ohne Nullen am Ende: 721,875 / 500 / 0,5.
    static func feldText(_ zahl: Double) -> String {
        var t = String(format: "%.3f", zahl)
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t.replacingOccurrences(of: ".", with: ",")
    }
}
