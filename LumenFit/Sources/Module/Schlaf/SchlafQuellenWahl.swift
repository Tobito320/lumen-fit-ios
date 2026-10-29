import Foundation

/// Woher eine Nacht kommt. Health vermischt Uhr und Handy schon (je Minute gewinnt die genauere Phase, `SchlafNachtLogik`) und nennt keine
/// Quelle; hier gilt: Phasen sind "Uhr", nur Dauer ist "Handy", Nächte aus den Ops `fit.band.schlaf` sind "Band".
enum SchlafQuelle: String, Codable, CaseIterable, Sendable {
    case uhr, handy, band

    var name: String {
        switch self {
        case .uhr: "Uhr"
        case .handy: "Handy"
        case .band: "Band"
        }
    }

    var symbolName: String {
        switch self {
        case .uhr: "applewatch"
        case .handy: "iphone"
        case .band: "dot.radiowaves.left.and.right"
        }
    }

    /// Bei gleicher Genauigkeit gilt das Band vor der Uhr (Lovea: Armband vor Watch), die Uhr vor dem Handy.
    fileprivate var rang: Int {
        switch self {
        case .band: 3
        case .uhr: 2
        case .handy: 1
        }
    }
}

/// Eine Nacht, die nach der Zusammenführung gilt, mit der gewählten Quelle und den Quellen, die dieselbe Nacht auch gemeldet haben.
struct SchlafGewaehlteNacht: Equatable, Sendable {
    let nacht: SchlafNacht
    let quelle: SchlafQuelle
    let weitere: [SchlafQuelle]

    var hatPhasen: Bool { SchlafQuellenWahl.hatPhasen(nacht) }

    /// Ein Satz fürs Detail: welche Quelle gilt und warum.
    var erklaerung: String {
        guard !weitere.isEmpty else { return "Quelle: \(quelle.name)." }
        let namen = weitere.map(\.name).joined(separator: " und ")
        let grund = hatPhasen ? "diese Quelle die Schlafphasen kennt" : "diese Quelle genauer misst"
        return "Quelle: \(quelle.name). Auch gemeldet von: \(namen). Es zählt \(quelle.name), weil \(grund)."
    }
}

/// Idee 60, beste Schlafquelle: doppelte Nächte erscheinen einmal, die genaueste Quelle gewinnt.
/// Genauer ist, was Phasen kennt; bei Gleichstand Band vor Uhr vor Handy.
enum SchlafQuellenWahl {
    /// Mindestens so viel vom Schlaf hat eine Phase der Uhr (gleiche Schwelle wie `SchlafNachtLogik`).
    static func hatPhasen(_ nacht: SchlafNacht) -> Bool {
        let schlaf = nacht.abschnitte.filter { $0.phase.schlaeft }.reduce(0.0) { $0 + $1.bis.timeIntervalSince($1.von) }
        let gestuft = nacht.abschnitte.filter { $0.phase.gestuft }.reduce(0.0) { $0 + $1.bis.timeIntervalSince($1.von) }
        return schlaf > 0 && gestuft / schlaf >= SchlafNachtLogik.mindestAnteilMitPhase
    }

    /// Quelle einer Health-Nacht: mit Phasen die Uhr, sonst das Handy.
    static func quelle(health nacht: SchlafNacht) -> SchlafQuelle { hatPhasen(nacht) ? .uhr : .handy }

    /// Die Band-Op als Nacht. Ohne Phasen ein Abschnitt "Schlaf"; die Dauer ist die Summe der Schlaf-Abschnitte (aus Date-Unterschieden,
    /// nie aus Uhrzeiten, damit die Zeitumstellung stimmt). `nil` bei kaputtem Tag, Ende vor Beginn oder ohne Schlaf.
    static func nacht(band op: BandSchlafOp) -> SchlafNacht? {
        guard op.ende > op.start, SchlafNachtLogik.gueltigerTag(op.tag) else { return nil }
        let phasen = op.phasen.filter { $0.bis > $0.von }.sorted { $0.von < $1.von }
        let abschnitte = phasen.isEmpty ? [SchlafAbschnitt(phase: .unbestimmt, von: op.start, bis: op.ende)] : phasen
        let sekunden = abschnitte.filter { $0.phase.schlaeft }.reduce(0.0) { $0 + $1.bis.timeIntervalSince($1.von) }
        let minuten = Int((sekunden / 60).rounded())
        guard minuten > 0 else { return nil }
        return SchlafNacht(tag: op.tag, von: op.start, bis: op.ende, abschnitte: abschnitte, schlafMinuten: minuten)
    }

    /// Dieselbe Nacht: gleicher Aufwachtag oder sich überlappende Zeiten.
    static func gleicheNacht(_ a: SchlafNacht, _ b: SchlafNacht) -> Bool {
        a.tag == b.tag || (a.von < b.bis && b.von < a.bis)
    }

    private struct Kandidat {
        let nacht: SchlafNacht
        let quelle: SchlafQuelle

        /// Phasen zählen mehr als jeder Rang.
        var gewicht: Int { (SchlafQuellenWahl.hatPhasen(nacht) ? 10 : 0) + quelle.rang }
    }

    /// Alle Nächte, aufsteigend nach Aufwachtag. `band` in der Reihenfolge des Eingangs: je Tag gewinnt die zuletzt eingetroffene Op.
    static func waehle(health: [String: SchlafNacht], band: [BandSchlafOp]) -> [SchlafGewaehlteNacht] {
        var bandJeTag: [String: SchlafNacht] = [:]
        for op in band { if let n = nacht(band: op) { bandJeTag[op.tag] = n } }
        // Zwei einfache Zeilen statt einer Summe aus zwei Closures: der Typprüfer braucht dann keine Ratearbeit.
        var kandidaten: [Kandidat] = health.values.map { Kandidat(nacht: $0, quelle: quelle(health: $0)) }
        kandidaten += bandJeTag.values.map { Kandidat(nacht: $0, quelle: .band) }
        kandidaten.sort { ($0.nacht.von, $0.quelle.rang) < ($1.nacht.von, $1.quelle.rang) }
        var gruppen: [[Kandidat]] = []
        for k in kandidaten {
            if let i = gruppen.lastIndex(where: { g in g.contains { gleicheNacht($0.nacht, k.nacht) } }) {
                gruppen[i].append(k)
            } else {
                gruppen.append([k])
            }
        }
        let gewaehlt: [SchlafGewaehlteNacht] = gruppen.compactMap { gruppe in
            guard let sieger = gruppe.max(by: { $0.gewicht < $1.gewicht }) else { return nil }
            let weitere = Set(gruppe.map(\.quelle)).subtracting([sieger.quelle]).sorted { $0.rang > $1.rang }
            return SchlafGewaehlteNacht(nacht: sieger.nacht, quelle: sieger.quelle, weitere: weitere)
        }
        return gewaehlt.sorted { $0.nacht.tag < $1.nacht.tag }
    }
}
