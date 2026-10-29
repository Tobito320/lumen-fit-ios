import Foundation

/// Die drei Makros im Donut. Essen ist monochrom: Grauton, Muster und Beschriftung unterscheiden die Segmente, nie eine Farbe.
enum MakroArt: String, CaseIterable, Identifiable, Sendable {
    case protein, kohlenhydrate, fett

    var id: String { rawValue }

    var name: String {
        switch self {
        case .protein: "Protein"
        case .kohlenhydrate: "Kohlenhydrate"
        case .fett: "Fett"
        }
    }

    /// kcal je Gramm (Atwater).
    var kcalProGramm: Double { self == .fett ? 9 : 4 }

    var muster: MakroMuster {
        switch self {
        case .protein: .streifen
        case .kohlenhydrate: .punkte
        case .fett: .flaeche
        }
    }

    /// Helligkeit des Grautons (0 schwarz, 1 weiß), im Hellen wie im Dunklen gut auseinanderzuhalten.
    var grau: Double {
        switch self {
        case .protein: 0.25
        case .kohlenhydrate: 0.55
        case .fett: 0.80
        }
    }
}

enum MakroMuster: String, Sendable {
    case streifen, punkte, flaeche

    var name: String {
        switch self {
        case .streifen: "Streifen"
        case .punkte: "Punkte"
        case .flaeche: "Fläche"
        }
    }
}

struct MakroSegment: Identifiable, Equatable, Sendable {
    let art: MakroArt
    let gramm: Double
    /// Energie dieses Makros in kcal.
    let kcal: Double
    /// Ganze Prozent der Energie aus Makros; die drei ergeben immer 100.
    let prozent: Int
    var id: String { art.id }

    var grammText: String { "\(Int(gramm.rounded())) g" }
    var beschriftung: String { "\(art.name): \(grammText), \(prozent) % der Energie" }
}

/// Alles, was der Donut anzeigt, ohne Oberfläche (damit testbar): Anteile an der Energie aus Protein, Kohlenhydraten und Fett.
struct MakroDonutDaten: Equatable, Sendable {
    let segmente: [MakroSegment]

    var istLeer: Bool { segmente.allSatisfy { $0.gramm <= 0 } }

    static func aus(_ n: Naehrwerte) -> MakroDonutDaten {
        let gramm: [MakroArt: Double] = [.protein: max(0, n.protein), .kohlenhydrate: max(0, n.kohlenhydrate), .fett: max(0, n.fett)]
        let kcal = MakroArt.allCases.map { (gramm[$0] ?? 0) * $0.kcalProGramm }
        let summe = kcal.reduce(0, +)
        let prozent = verteile(kcal, summe: summe)
        let segmente = MakroArt.allCases.enumerated().map { i, art in
            MakroSegment(art: art, gramm: gramm[art] ?? 0, kcal: kcal[i], prozent: prozent[i])
        }
        return MakroDonutDaten(segmente: segmente)
    }

    /// Größter-Rest-Verfahren: ganze Prozent, Summe genau 100 (bei Summe 0 alles 0).
    static func verteile(_ werte: [Double], summe: Double) -> [Int] {
        guard summe > 0 else { return werte.map { _ in 0 } }
        let roh = werte.map { $0 / summe * 100 }
        var ganz = roh.map { Int($0.rounded(.down)) }
        let rest = 100 - ganz.reduce(0, +)
        let reihenfolge = roh.indices.sorted { roh[$0] - Double(ganz[$0]) > roh[$1] - Double(ganz[$1]) }
        for i in reihenfolge.prefix(max(0, rest)) { ganz[i] += 1 }
        return ganz
    }

    /// Ein Satz für VoiceOver und die Kernzeile.
    var beschreibung: String {
        if istLeer { return "Noch nichts gegessen" }
        return segmente.map(\.beschriftung).joined(separator: "; ")
    }
}
