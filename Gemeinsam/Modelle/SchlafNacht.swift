// Quelle: Lovea Health/SchlafNacht.swift
import Foundation

// Schlafphasen einer Nacht (Apple Watch): die Zeitleiste hinter dem Nacht-Diagramm im Schlaf-Tab.
// Reine Logik ohne HealthKit-Typen; die Abfrage steht in `HealthModell.schlafPhasen`.
// Die Nacht ist genau die des Tabs (`HealthLogik.schlafNacht`: Aufwachtag, Block mit Pausen bis 3 h), nur feiner aufgelöst.

enum SchlafPhase: Int, Codable, CaseIterable, Sendable {
    /// Reihenfolge = Zeilen im Diagramm von oben nach unten, wie in Apple Health.
    case wach, rem, kern, tief
    /// Schlaf ohne Phase (iPhone, ältere Geräte): zählt als Schlaf, fällt aber in keine Zeile der Watch.
    case unbestimmt

    var name: String {
        switch self {
        case .wach: "Wach"
        case .rem: "REM"
        case .kern: "Kern"
        case .tief: "Tief"
        case .unbestimmt: "Schlaf"
        }
    }

    var schlaeft: Bool { self != .wach }

    /// Phase der Watch (Kern, Tief, REM)?
    var gestuft: Bool { self == .rem || self == .kern || self == .tief }

    /// Melden zwei Quellen dieselbe Minute, gewinnt die genauere.
    fileprivate var vorrang: Int {
        switch self {
        case .tief: 4
        case .rem: 3
        case .kern: 2
        case .unbestimmt: 1
        case .wach: 0
        }
    }
}

struct SchlafAbschnitt: Codable, Hashable, Sendable {
    let phase: SchlafPhase
    let von: Date
    let bis: Date
}

struct SchlafNacht: Codable, Equatable, Sendable {
    /// Aufwachtag (`yyyy-MM-dd`, Berliner Zeit): dem ordnet auch der Schlaf-Tab die Nacht zu.
    let tag: String
    /// Eingeschlafen.
    let von: Date
    /// Aufgewacht.
    let bis: Date
    /// Lückenlos von `von` bis `bis`, zeitlich sortiert, benachbarte Abschnitte haben verschiedene Phasen.
    let abschnitte: [SchlafAbschnitt]
    /// Schlafdauer genau wie im Schlaf-Tab (`HealthLogik.schlafNacht`): Tab und Heute nennen dieselbe Zahl.
    let schlafMinuten: Int
    /// Kurze Schläfchen am selben Aufwachtag (Blöcke ab 20 Minuten, nicht die Nacht). Optional, damit alte Dateien ladbar bleiben.
    var nickerchen: [SchlafAbschnitt]? = nil

    /// Wach in der Nacht: die Lücken zwischen den Schlaf-Abschnitten, ab 2 Minuten.
    var wachPhasen: [SchlafAbschnitt] { abschnitte.filter { $0.phase == .wach && $0.bis.timeIntervalSince($0.von) >= 120 } }

    /// Die Phasen, die in dieser Nacht vorkommen, in Zeilenreihenfolge.
    var phasen: [SchlafPhase] { SchlafPhase.allCases.filter { phase in abschnitte.contains { $0.phase == phase } } }

    private func sekunden(_ pruefung: (SchlafPhase) -> Bool) -> TimeInterval {
        abschnitte.filter { pruefung($0.phase) }.reduce(0) { $0 + $1.bis.timeIntervalSince($1.von) }
    }

    func minuten(_ phase: SchlafPhase) -> Int { Int((sekunden { $0 == phase } / 60).rounded()) }

    /// Summe der Abschnitte außer Wach, nur zur Prüfung des Phasen-Anteils (kann um eine Minute von `schlafMinuten` abweichen).
    fileprivate var abschnittsMinuten: Int { Int((sekunden { $0.schlaeft } / 60).rounded()) }

    /// "7 h 05 min".
    private static func dauerText(_ minuten: Int) -> String { "\(minuten / 60) h \(String(format: "%02d", minuten % 60)) min" }

    /// Für VoiceOver: ein Satz mit den Zeiten und den Minuten je Phase.
    var beschreibung: String {
        let teile = phasen.map { "\($0.name) \(Self.dauerText(minuten($0)))" }.joined(separator: ", ")
        return "Schlaf in der Nacht auf \(Datum.anzeige(tag)): eingeschlafen \(Datum.uhrzeit(von)), aufgewacht \(Datum.uhrzeit(bis)), "
            + "\(Self.dauerText(schlafMinuten)) geschlafen. \(teile)"
    }
}

enum SchlafNachtLogik {
    /// Ein Schlaf-Abschnitt aus Health. Wach-Werte gehören nicht hierher: Lücken zwischen den Abschnitten sind die Wachzeit.
    struct Roh: Equatable, Sendable {
        var phase: SchlafPhase
        var von: Date
        var bis: Date
    }

    /// Mindestens so viel vom Schlaf muss eine Phase der Watch haben, sonst gibt es nichts zu zeigen.
    static let mindestAnteilMitPhase = 0.5

    /// Die Nacht von `tag` als Zeitleiste. `nil` ohne Schlaf an diesem Tag oder ohne brauchbare Phasen
    /// (nur "Schlaf" ohne Phase, etwa vom iPhone allein): dann zeigt die App kein Diagramm und keinen Fehler.
    // ponytail: Schnittpunkte mal Abschnitte, quadratisch; eine Nacht hat einige hundert Abschnitte, das reicht.
    static func nacht(_ roh: [Roh], tag: String) -> SchlafNacht? {
        let schlaf = roh.filter { $0.phase.schlaeft && $0.bis > $0.von }
        guard let block = HealthLogik.schlafNacht(schlaf.map { HealthLogik.SchlafIntervall(von: $0.von, bis: $0.bis) }, tag: tag) else { return nil }
        let zugeschnitten = schlaf.compactMap { r -> Roh? in
            let von = max(r.von, block.von)
            let bis = min(r.bis, block.bis)
            return bis > von ? Roh(phase: r.phase, von: von, bis: bis) : nil
        }
        let grenzen = Set(zugeschnitten.flatMap { [$0.von, $0.bis] }).sorted()
        var abschnitte: [SchlafAbschnitt] = []
        for (a, b) in zip(grenzen, grenzen.dropFirst()) {
            let phase = zugeschnitten.filter { $0.von <= a && $0.bis >= b }.map(\.phase).max { $0.vorrang < $1.vorrang } ?? .wach
            if let letzter = abschnitte.last, letzter.phase == phase {
                abschnitte[abschnitte.count - 1] = SchlafAbschnitt(phase: phase, von: letzter.von, bis: b)
            } else {
                abschnitte.append(SchlafAbschnitt(phase: phase, von: a, bis: b))
            }
        }
        let nacht = SchlafNacht(tag: tag, von: block.von, bis: block.bis, abschnitte: abschnitte, schlafMinuten: block.minuten,
                                nickerchen: nickerchen(schlaf, tag: tag))
        let gesamt = Double(nacht.abschnittsMinuten)
        let mitPhase = Double(nacht.minuten(.rem) + nacht.minuten(.kern) + nacht.minuten(.tief))
        guard gesamt > 0, mitPhase / gesamt >= mindestAnteilMitPhase else { return nil }
        return nacht
    }

    /// Nickerchen aus den rohen Schlaf-Abschnitten als Abschnitte ohne Phase.
    static func nickerchen(_ schlaf: [Roh], tag: String) -> [SchlafAbschnitt] {
        HealthLogik.nickerchen(schlaf.map { HealthLogik.SchlafIntervall(von: $0.von, bis: $0.bis) }, tag: tag)
            .map { SchlafAbschnitt(phase: .unbestimmt, von: $0.von, bis: $0.bis) }
    }

    /// `yyyy-MM-dd` als echter Tag: "2026-02-30" und "2026-1-5" sind keiner. Schützt `Datum.datum`, das bei Unsinn abstürzt.
    static func gueltigerTag(_ text: String) -> Bool {
        let teile = text.split(separator: "-", omittingEmptySubsequences: false)
        guard teile.count == 3, teile[0].count == 4, teile[1].count == 2, teile[2].count == 2,
              text.allSatisfy({ $0 == "-" || ($0.isASCII && $0.isNumber) }),
              let jahr = Int(teile[0]), let monat = Int(teile[1]), let tag = Int(teile[2]),
              (2000...2100).contains(jahr), (1...12).contains(monat) else { return false }
        var erster = DateComponents()
        erster.year = jahr
        erster.month = monat
        erster.day = 1
        guard let datum = Datum.kalender.date(from: erster),
              let tage = Datum.kalender.range(of: .day, in: .month, for: datum) else { return false }
        return tage.contains(tag)
    }
}
