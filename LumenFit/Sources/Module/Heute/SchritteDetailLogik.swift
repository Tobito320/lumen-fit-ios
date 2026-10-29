import Foundation

/// Alles, was das Schritte-Detail (Idee 18) für einen Zeitraum zeigt. Reine Logik auf `SchritteLogik`; die Tageswerte kommen aus `GesundheitsStand.tage`
/// (je Tag das Maximum aus Health und Band, nie die Summe).
struct SchritteDetailStand: Equatable, Sendable {
    var zeitraum: SchritteZeitraum
    var titel: String
    /// Summe der Tage bis heute; nil ohne einen Wert.
    var summe: Int?
    /// Mittel über die Tage bis heute mit Schritten; nil ohne Wert.
    var schnitt: Int?
    var distanzKm: Double
    var etagen: Int
    /// Tage bis heute mit mindestens dem Ziel, und Tage bis heute mit Schritten.
    var zielTage: Int
    var tageMitDaten: Int
    /// Die drei besten Tage, höchster zuerst.
    var beste: [SchrittPunkt]
    var punkte: [SchrittPunkt]
    var ziel: Int
    /// Für das Diagramm: wo die Zielmarke liegt (Tag: das Ziel selbst; Woche und Monat: das Tagesziel als Linie).
    var hoechster: Int
}

enum SchritteDetailLogik {
    static func stand(zeitraum: SchritteZeitraum, anker: String, heute: String, tage: [String: TagesWerte], ziel: Int) -> SchritteDetailStand {
        let tageListe = SchritteLogik.tage(zeitraum, anker: anker).filter { $0 <= heute }
        let schritte: [String: Int] = tage.compactMapValues { $0.schritte > 0 ? $0.schritte : nil }
        let mitDaten = tageListe.filter { schritte[$0] != nil }
        let summe = SchritteLogik.summe(schritte, tage: tageListe, heute: heute)
        let schnitt: Int? = mitDaten.isEmpty ? nil : (summe ?? 0) / mitDaten.count
        let meter = tageListe.reduce(0.0) { $0 + (tage[$1]?.distanzMeter ?? 0) }
        let etagen = tageListe.reduce(0) { $0 + (tage[$1]?.etagen ?? 0) }
        let beste = mitDaten.map { SchrittPunkt(tag: $0, schritte: schritte[$0] ?? 0) }.sorted { ($0.schritte, $1.tag) > ($1.schritte, $0.tag) }.prefix(3)
        let fenster = zeitraum == .tag ? SchritteLogik.fensterTage(anker: anker, heute: heute) : SchritteLogik.tage(zeitraum, anker: anker)
        let punkte = SchritteLogik.linienPunkte(tage: fenster, werte: schritte, heute: heute)
        return SchritteDetailStand(zeitraum: zeitraum, titel: titel(zeitraum, anker), summe: summe, schnitt: schnitt, distanzKm: meter / 1000, etagen: etagen,
                                   zielTage: mitDaten.filter { (schritte[$0] ?? 0) >= ziel }.count, tageMitDaten: mitDaten.count,
                                   beste: Array(beste), punkte: punkte, ziel: ziel, hoechster: max(ziel, punkte.map(\.schritte).max() ?? 0))
    }

    static func titel(_ zeitraum: SchritteZeitraum, _ anker: String) -> String {
        switch zeitraum {
        case .tag:
            return Datum.anzeige(anker)
        case .woche:
            let tage = SchritteLogik.tage(.woche, anker: anker)
            return "\(kurz(tage.first ?? anker)) bis \(kurz(tage.last ?? anker))"
        case .monat:
            let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
            return Datum.datum(anker).formatted(stil.month(.wide).year())
        }
    }

    /// "23.09."
    static func kurz(_ tag: String) -> String {
        let teile = tag.split(separator: "-")
        return teile.count == 3 ? "\(teile[2]).\(teile[1])." : tag
    }
}
