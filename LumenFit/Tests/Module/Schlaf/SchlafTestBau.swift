import Foundation
@testable import LumenFit

/// Bausteine für die Schlaf-Tests: erfundene Nächte und Zeiten nach Berliner Uhr.
enum SchlafTestBau {
    /// `stunde:minute` am Tag `tag` (Berliner Zeit).
    static func zeit(_ tag: String, _ stunde: Int, _ minute: Int = 0) -> Date {
        Datum.kalender.date(bySettingHour: stunde, minute: minute, second: 0, of: Datum.datum(tag))!
    }

    /// Eine Nacht mit Aufwachtag `tag`, aufgewacht um `auf`, `minuten` lang. Mit `phasen` Kern, Tief, REM (Uhr), sonst ein Abschnitt "Schlaf" (Handy).
    static func nacht(_ tag: String, minuten: Int, auf: (Int, Int) = (7, 0), phasen: Bool = false) -> SchlafNacht {
        let bis = zeit(tag, auf.0, auf.1)
        let von = bis.addingTimeInterval(-Double(minuten) * 60)
        return nacht(tag: tag, von: von, bis: bis, phasen: phasen)
    }

    /// Eine Nacht mit Einschlafzeit `bett` (ab 12 Uhr am Vortag, davor wie 00:30 am Aufwachtag) und Aufwachzeit `auf`.
    static func nacht(_ tag: String, bett: (Int, Int), auf: (Int, Int) = (7, 0), phasen: Bool = false) -> SchlafNacht {
        let bettTag = bett.0 >= 12 ? Datum.addTage(tag, -1) : tag
        return nacht(tag: tag, von: zeit(bettTag, bett.0, bett.1), bis: zeit(tag, auf.0, auf.1), phasen: phasen)
    }

    private static func nacht(tag: String, von: Date, bis: Date, phasen: Bool) -> SchlafNacht {
        let sekunden = bis.timeIntervalSince(von)
        let minuten = Int((sekunden / 60).rounded())
        guard phasen else {
            return SchlafNacht(tag: tag, von: von, bis: bis, abschnitte: [SchlafAbschnitt(phase: .unbestimmt, von: von, bis: bis)], schlafMinuten: minuten)
        }
        let a = von.addingTimeInterval(sekunden * 0.5)
        let b = von.addingTimeInterval(sekunden * 0.7)
        let abschnitte = [SchlafAbschnitt(phase: .kern, von: von, bis: a), SchlafAbschnitt(phase: .tief, von: a, bis: b),
                          SchlafAbschnitt(phase: .rem, von: b, bis: bis)]
        return SchlafNacht(tag: tag, von: von, bis: bis, abschnitte: abschnitte, schlafMinuten: minuten)
    }

    /// `anzahl` Tage ab `von`, als Text je Tag.
    static func tage(ab von: String, _ anzahl: Int) -> [String] { (0..<anzahl).map { Datum.addTage(von, $0) } }

    /// Eine Reihe von Vitalwerten je Tag ab `von`.
    static func vitale(_ art: VitalArt, ab von: String, _ werte: [Double]) -> [VitalMesswert] {
        werte.enumerated().map { VitalMesswert(art: art, tag: Datum.addTage(von, $0.offset), wert: $0.element) }
    }
}
