@testable import LumenFit

/// Beispiel-Eingaben für die Tests und die Tafeln der Tagesform (W-028).
enum TagesformBeispiele {
    /// 28 Tage im Wechsel 54 und 62: Schnitt 58, Streuung 4.
    static var hrvBasis: [Double?] {
        (0..<28).map { i -> Double? in i % 2 == 0 ? 54.0 : 62.0 }
    }

    static var pulsBasis: [Double?] {
        [Double?](repeating: 56, count: 28)
    }

    /// Index 0 = heute, dahinter die Basis.
    static func reihe(_ heute: Double?, _ basis: [Double?]) -> [Double?] {
        var liste: [Double?] = [heute]
        liste.append(contentsOf: basis)
        return liste
    }

    /// 14 Nächte; vorne die genannten, der Rest `rest` Minuten.
    static func schlafReihe(_ kopf: [Int?], rest: Int = 450) -> [Int?] {
        var liste = kopf
        while liste.count < 14 { liste.append(rest) }
        return liste
    }

    /// Index 0 = der Tag selbst, dann 3 Tage `drei`, dann 25 Tage `sonst`.
    static func saetze(_ drei: Int, sonst: Int) -> [Int] {
        [0] + [Int](repeating: drei, count: 3) + [Int](repeating: sonst, count: 25)
    }

    /// Ein guter Tag mit allen Quellen: Zahl 90 (roh 90,16).
    static func voll() -> TagesformEingabe {
        var e = TagesformEingabe()
        e.schlaf = schlafReihe([470, 450, 460])
        e.bett = [Int?](repeating: 600, count: 7)
        e.hrv = reihe(58, hrvBasis)
        e.ruhepuls = reihe(56, pulsBasis)
        e.saetze = saetze(10, sonst: 10)
        e.kalorien = TagesformMass(ist: 2500, ziel: 2600, bezug: .vortag)
        e.eiweiss = TagesformMass(ist: 150, ziel: 160, bezug: .vortag)
        e.schritte = TagesformMass(ist: 9000, ziel: 10_000, bezug: .vortag)
        e.wasser = TagesformMass(ist: 7, ziel: 8, bezug: .vortag)
        return e
    }
}
