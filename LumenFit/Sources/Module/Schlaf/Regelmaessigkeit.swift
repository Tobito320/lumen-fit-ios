import Foundation

/// Idee 57, Regelmäßigkeit: wie stark die Einschlafzeit streut, als ruhiger Wert von 0 bis 100 statt als Vorwurf.
/// Die Zeit läuft auf der Skala von `SchlafFormat.bettSkala` (00:30 liegt hinter 23:00), sonst wäre 23:30 gegen 00:30 ein Sprung von 23 Stunden.
enum Regelmaessigkeit {
    static let fenster = 14
    static let mindestNaechte = 5
    /// Bei dieser Streuung (Standardabweichung in Minuten) ist der Wert 0.
    static let streuungNull = 90.0

    enum Stufe: Equatable, Sendable {
        case sehrGleichmaessig, gleichmaessig, schwankend, wechselhaft

        var name: String {
            switch self {
            case .sehrGleichmaessig: "Sehr gleichmäßig"
            case .gleichmaessig: "Ziemlich gleichmäßig"
            case .schwankend: "Mal früher, mal später"
            case .wechselhaft: "Jeden Abend anders"
            }
        }

        var symbolName: String {
            switch self {
            case .sehrGleichmaessig: "checkmark.seal.fill"
            case .gleichmaessig: "checkmark.circle.fill"
            case .schwankend: "waveform.path.ecg"
            case .wechselhaft: "chart.xyaxis.line"
            }
        }
    }

    struct Ergebnis: Equatable, Sendable {
        /// 0 bis 100, höher ist gleichmäßiger.
        let score: Int
        /// Standardabweichung der Einschlafzeit in Minuten.
        let streuungMinuten: Int
        /// Mittlere Einschlafzeit auf der Skala von `SchlafFormat.bettSkala`.
        let typischeBettzeit: Int
        let naechte: Int

        var stufe: Stufe {
            switch score {
            case 80...: .sehrGleichmaessig
            case 60..<80: .gleichmaessig
            case 40..<60: .schwankend
            default: .wechselhaft
            }
        }

        var satz: String {
            "Du schläfst meist gegen \(SchlafFormat.uhrzeit(skala: typischeBettzeit)) ein, mal etwa \(streuungMinuten) Minuten früher oder später."
        }
    }

    /// Die letzten 14 Tage bis `heute`. `nil` unter 5 Nächten ("zu wenig Daten").
    static func berechne(naechte: [SchlafNacht], heute: String) -> Ergebnis? {
        let ab = Datum.addTage(heute, -(fenster - 1))
        let werte = naechte.filter { $0.tag >= ab && $0.tag <= heute }.map { Double(SchlafFormat.bettSkala($0.von)) }
        guard werte.count >= mindestNaechte else { return nil }
        let mittel: Double = werte.reduce(0, +) / Double(werte.count)
        let quadrate: Double = werte.reduce(0) { (summe: Double, wert: Double) in summe + (wert - mittel) * (wert - mittel) }
        let varianz: Double = quadrate / Double(werte.count)
        let streuung = varianz.squareRoot()
        let score = Int((100 * max(0, 1 - streuung / streuungNull)).rounded())
        return Ergebnis(score: score, streuungMinuten: Int(streuung.rounded()), typischeBettzeit: Int(mittel.rounded()), naechte: werte.count)
    }
}
