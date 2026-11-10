import Foundation

/// Der Stand im Level (Erfolge): Holz bis Diamant aus den Punkten von `StatsPunkte.gesamt`.
struct FortLevel: Equatable, Sendable {
    /// 0 = Holz ... 5 = Diamant.
    var index: Int
    var punkte: Int
    /// Punkte, ab denen das nächste Level gilt; nil auf Diamant.
    var naechsteAb: Int?
    /// 0 bis 1 zwischen diesem und dem nächsten Level (Diamant: 1).
    var anteil: Double
    var nummer: Int { index + 1 }
    var name: String { FortErfolgeLogik.name(index) }
    var naechsterName: String? { naechsteAb == nil ? nil : FortErfolgeLogik.name(index + 1) }
    var rest: Int { max(0, (naechsteAb ?? punkte) - punkte) }
}

/// Farbe einer Medaille im Raster: Bronze, Silber, Gold, Platin.
enum FortMedaillenStufe: Sendable {
    case bronze, silber, gold, platin
}

struct FortAbzeichen: Equatable, Identifiable, Sendable {
    var meilenstein: Meilenstein
    var stufe: FortMedaillenStufe
    var id: String { meilenstein.id }
}

/// Reine Regeln der Seite Erfolge: Level-Schwellen (Besitzer 10.11.2026: Holz 0, Stein 500, Eisen 1500, Stahl 3000, Titan 6000, Diamant 12000)
/// und welche Farbe eine Medaille im Raster bekommt. Die Punkte selbst rechnet `StatsPunkte`.
enum FortErfolgeLogik {
    static let schwellen = [0, 500, 1500, 3000, 6000, 12000]

    static func name(_ index: Int) -> String {
        switch min(max(index, 0), schwellen.count - 1) {
        case 0: String(localized: "Holz")
        case 1: String(localized: "Stein")
        case 2: String(localized: "Eisen")
        case 3: String(localized: "Stahl")
        case 4: String(localized: "Titan")
        default: String(localized: "Diamant")
        }
    }

    static func level(_ punkte: Int) -> FortLevel {
        let p = max(0, punkte)
        let index = schwellen.lastIndex { p >= $0 } ?? 0
        guard index + 1 < schwellen.count else { return FortLevel(index: index, punkte: p, naechsteAb: nil, anteil: 1) }
        let von = schwellen[index], bis = schwellen[index + 1]
        return FortLevel(index: index, punkte: p, naechsteAb: bis, anteil: Double(p - von) / Double(bis - von))
    }

    /// Alle Medaillen eines Abschnitts als Abzeichen in der Reihenfolge der Seite; Reihen werden zu ihren Stufen aufgefächert.
    static func abzeichen(_ abschnitt: MedaillenAbschnitt) -> [FortAbzeichen] {
        abschnitt.eintraege.flatMap { e -> [FortAbzeichen] in
            switch e {
            case .einzel(let m): [FortAbzeichen(meilenstein: m, stufe: .bronze)]
            case .reihe(_, let ms): ms.enumerated().map { FortAbzeichen(meilenstein: $0.element, stufe: stufe(index: $0.offset, von: ms.count)) }
            }
        }
    }

    /// Stufe einer Medaille: in einer Reihe nach ihrem Platz (wie `MedaillenAnsicht.stufenName`), einzelne Medaillen sind Bronze.
    static func stufe(index: Int, von anzahl: Int) -> FortMedaillenStufe {
        switch MedaillenAnsicht.stufenName(index, von: anzahl) {
        case "Silber": .silber
        case "Gold": .gold
        case "Platin": .platin
        default: .bronze
        }
    }
}
