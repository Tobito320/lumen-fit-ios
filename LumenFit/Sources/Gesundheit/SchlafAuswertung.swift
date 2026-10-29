import Foundation

/// Macht aus rohen Schlaf-Abschnitten (Health) die Nächte eines Tagesbereichs. Reine Logik, getestet ohne HealthKit.
enum SchlafAuswertung {
    /// Eine Nacht je Aufwachtag mit Schlaf. Mit Phasen der Watch (`SchlafNachtLogik.nacht`), sonst nur die Dauer als ein Abschnitt "Schlaf"
    /// (iPhone allein liefert keine Phasen; die Zeit ist trotzdem echt).
    static func naechte(_ roh: [SchlafNachtLogik.Roh], von: String, bis: String) -> [SchlafNacht] {
        guard SchlafNachtLogik.gueltigerTag(von), SchlafNachtLogik.gueltigerTag(bis), von <= bis else { return [] }
        var ergebnis: [SchlafNacht] = []
        var tag = von
        while tag <= bis {
            if let nacht = SchlafNachtLogik.nacht(roh, tag: tag) ?? ohnePhasen(roh, tag: tag) { ergebnis.append(nacht) }
            tag = Datum.addTage(tag, 1)
        }
        return ergebnis
    }

    private static func ohnePhasen(_ roh: [SchlafNachtLogik.Roh], tag: String) -> SchlafNacht? {
        let schlaf = roh.filter { $0.phase.schlaeft && $0.bis > $0.von }
        guard let block = HealthLogik.schlafNacht(schlaf.map { HealthLogik.SchlafIntervall(von: $0.von, bis: $0.bis) }, tag: tag) else { return nil }
        return SchlafNacht(tag: tag, von: block.von, bis: block.bis,
                           abschnitte: [SchlafAbschnitt(phase: .unbestimmt, von: block.von, bis: block.bis)], schlafMinuten: block.minuten)
    }
}
