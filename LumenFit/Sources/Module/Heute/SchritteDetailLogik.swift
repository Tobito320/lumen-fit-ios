import Foundation

/// Alles, was das Schritte-Detail (Idee 18) für einen Zeitraum zeigt. Reine Logik auf `SchritteLogik`; die Tageswerte kommen aus `GesundheitsStand.tage`
/// (aus Apple Health, von Hand nur an Tagen ohne Health-Schritte).
struct SchritteDetailStand: Equatable, Sendable {
    var zeitraum: SchritteZeitraum
    var titel: String
    /// Summe der Tage bis heute; nil ohne einen Wert.
    var summe: Int?
    /// Mittel über die Tage bis heute mit Schritten; nil ohne Wert.
    var schnitt: Int?
    var distanzKm: Double
    var etagen: Int
    /// Aktive Energie und Trainingsminuten der Tage bis heute (0 = keine Daten).
    var kcal = 0
    var aktivMinuten = 0
    /// Tagesziel mal alle Tage des Zeitraums (auch die noch kommenden): Nenner des großen Bogens.
    var periodenZiel = 0
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
        let kcal = Int(tageListe.reduce(0.0) { $0 + (tage[$1]?.aktiveKcal ?? 0) }.rounded())
        let aktiv = tageListe.reduce(0) { $0 + (tage[$1]?.trainingMinuten ?? 0) }
        let beste = mitDaten.map { SchrittPunkt(tag: $0, schritte: schritte[$0] ?? 0) }.sorted { ($0.schritte, $1.tag) > ($1.schritte, $0.tag) }.prefix(3)
        let fenster = zeitraum == .tag ? SchritteLogik.fensterTage(anker: anker, heute: heute) : SchritteLogik.tage(zeitraum, anker: anker)
        let punkte = SchritteLogik.linienPunkte(tage: fenster, werte: schritte, heute: heute)
        return SchritteDetailStand(zeitraum: zeitraum, titel: titel(zeitraum, anker), summe: summe, schnitt: schnitt, distanzKm: meter / 1000, etagen: etagen,
                                   kcal: kcal, aktivMinuten: aktiv, periodenZiel: ziel * SchritteLogik.tage(zeitraum, anker: anker).count,
                                   zielTage: mitDaten.filter { (schritte[$0] ?? 0) >= ziel }.count, tageMitDaten: mitDaten.count,
                                   beste: Array(beste), punkte: punkte, ziel: ziel, hoechster: max(ziel, punkte.map(\.schritte).max() ?? 0))
    }

    static func titel(_ zeitraum: SchritteZeitraum, _ anker: String) -> String {
        switch zeitraum {
        case .tag:
            return Datum.anzeige(anker)
        case .woche:
            let tage = SchritteLogik.tage(.woche, anker: anker)
            return String(localized: "\(kurz(tage.first ?? anker)) bis \(kurz(tage.last ?? anker))")
        case .monat:
            let stil = Date.FormatStyle(locale: Datum.anzeigeLocale, calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
            return Datum.datum(anker).formatted(stil.month(.wide).year())
        }
    }

    /// "23.09."
    static func kurz(_ tag: String) -> String {
        let teile = tag.split(separator: "-")
        return teile.count == 3 ? "\(teile[2]).\(teile[1])." : tag
    }
}

/// Der große Bogen: erste Runde bis 100 Prozent, zweite Runde darüber (bis 200 Prozent, danach bleibt er voll).
enum SchritteBogenLogik {
    struct Laeufe: Equatable, Sendable {
        var erste: Double
        var zweite: Double
        var prozent: Int
        var erreicht: Bool { prozent >= 100 }
    }

    static func laeufe(anzahl: Int?, ziel: Int) -> Laeufe {
        let anteil = max(0, Double(anzahl ?? 0)) / Double(max(1, ziel))
        return Laeufe(erste: min(anteil, 1), zweite: min(max(anteil - 1, 0), 1), prozent: Int((anteil * 100).rounded(.down)))
    }

    /// "2:05" aus 125 Minuten.
    static func stundenText(_ minuten: Int) -> String { "\(minuten / 60):" + String(format: "%02d", minuten % 60) }
}
