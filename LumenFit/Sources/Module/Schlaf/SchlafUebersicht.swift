import Foundation

/// Übliche Bett- und Aufstehzeit (Minuten ab Mitternacht) für den Verlauf.
struct SchlafZeiten: Equatable, Sendable {
    let bett: Int
    let auf: Int

    /// "23:00 bis 07:00".
    var text: String { "\(Datum.uhrzeit(minuten: bett)) bis \(Datum.uhrzeit(minuten: auf))" }
}

/// Lumi schläft nachts (22 bis 5 Uhr) und im Schlaf-Tab, ist müde nach einer kurzen Nacht oder wenn die Erholung "schonen" sagt, sonst bereit.
/// Reine Funktion, keine Animation (Reduce Motion: `LumiView` ist ohnehin statisch).
enum SchlafLumi {
    static func stimmung(jetzt: Date, letzteNachtMinuten: Int?, erholung: ErholungsKlartext.Stufe?) -> LumiStimmung {
        let stunde = SchlafFormat.minuteDesTages(jetzt) / 60
        if stunde >= 22 || stunde < 5 { return .schlaeft }
        if let minuten = letzteNachtMinuten, minuten < ErholungsKlartext.kurzeNacht { return .muede }
        if erholung == .schonen { return .muede }
        return .bereit
    }
}

/// Alles, was der Schlaf-Tab zeigt, aus Health, den Band-Ops, den Zielen und dem Tag gerechnet (rein, ohne Oberfläche).
struct SchlafUebersicht: Sendable {
    let heute: String
    let zielMinuten: Int
    /// Alle Nächte bis heute, aufsteigend, doppelte zusammengeführt.
    let naechte: [SchlafGewaehlteNacht]
    let schuld: SchlafSchuld.Ergebnis?
    let regelmaessigkeit: Regelmaessigkeit.Ergebnis?
    let woche: WochenVergleich
    let hrv: SchlafVitalStand
    let chips: [SchlafVitalStand]
    let erholung: ErholungsKlartext.Ergebnis
    let vergleich: [SchlafVergleichNacht]
    let werktag: SchlafZeiten?
    let wochenende: SchlafZeiten?
    /// Extra-Tage mit anderem Schlafziel (Op `fit.schlaf.ziel`); ohne Eintrag gilt `zielMinuten` an jedem Tag.
    var zielExtra = SchlafZielExtra()

    /// Die neueste Nacht bis heute.
    var letzte: SchlafGewaehlteNacht? { naechte.last }

    var hatDaten: Bool { !naechte.isEmpty }

    /// Das Schlafziel für die Nacht, die an `tag` endet (an Extra-Tagen mehr oder weniger).
    func ziel(fuer tag: String) -> Int { SchlafZielLogik.ziel(basis: zielMinuten, extra: zielExtra, tag: tag) }

    /// "Letzte Nacht" oder bei älteren Nächten "Nacht auf Mittwoch, 23. September".
    var titelLetzte: String {
        guard let letzte else { return "Letzte Nacht" }
        return letzte.nacht.tag >= heute ? "Letzte Nacht" : "Nacht auf \(Datum.anzeige(letzte.nacht.tag))"
    }

    /// Nur mit iPhone: die neueste Nacht kennt keine Phasen.
    var ohnePhasen: Bool { letzte.map { !$0.hatPhasen } ?? false }

    /// Die Vergleichsnacht der gezeigten Nacht, wenn Band und Health sie beide kennen.
    var vergleichLetzte: SchlafVergleichNacht? { letzte.flatMap { vergleichsnacht(fuer: $0.nacht.tag) } }

    /// Die Vergleichsnacht des Aufwachtags, wenn Band und Health sie beide kennen.
    func vergleichsnacht(fuer tag: String) -> SchlafVergleichNacht? {
        vergleich.first { $0.tag == tag && $0.band != nil && $0.health != nil }
    }

    /// Die letzten Tage bis heute (so viele wie `anzahl`), älteste zuerst; ohne Nacht ist `minuten` leer.
    func tage(_ anzahl: Int) -> [WochenVergleich.Tag] {
        var jeTag: [String: Int] = [:]
        for n in naechte { jeTag[n.nacht.tag] = n.nacht.schlafMinuten }
        return (0..<max(anzahl, 0)).map { i in
            let tag = Datum.addTage(heute, -(anzahl - 1 - i))
            return WochenVergleich.Tag(tag: tag, minuten: jeTag[tag])
        }
    }

    func lumi(jetzt: Date) -> LumiStimmung {
        SchlafLumi.stimmung(jetzt: jetzt, letzteNachtMinuten: letzte?.nacht.schlafMinuten, erholung: erholung.stufe)
    }

    private static func zeiten(_ naechte: [SchlafNacht], wochenende: Bool) -> SchlafZeiten? {
        let bekannt = naechte.map { SchlafLogik.BekannteNacht(tag: $0.tag, von: $0.von, bis: $0.bis) }
        return SchlafLogik.gewohnheit(bekannt, wochenende: wochenende).map { SchlafZeiten(bett: $0.bett, auf: $0.auf) }
    }

    static func bauen(health: [String: SchlafNacht], band: [BandSchlafOp], vitale: [VitalArt: [VitalMesswert]], zielMinuten: Int, heute: String,
                       eingetragen: [String: SchlafNacht] = [:], zielExtra: SchlafZielExtra = SchlafZielExtra()) -> SchlafUebersicht {
        let gewaehlt = SchlafQuellenWahl.waehle(health: health, band: band, eingetragen: eingetragen).filter { $0.nacht.tag <= heute }
        let reine = gewaehlt.map(\.nacht)
        let hrv = SchlafVitalStand.bauen(art: .hrv, werte: vitale[.hrv] ?? [], heute: heute)
        let chips = SchlafVitalStand.chipArten.map { SchlafVitalStand.bauen(art: $0, werte: vitale[$0] ?? [], heute: heute) }
        let ruhepuls = chips.first { $0.art == .ruhepuls }?.frischerBereich
        // Eine Nacht von vor drei Tagen sagt nichts über die Erholung heute.
        let frisch = reine.last.flatMap { $0.tag >= Datum.addTage(heute, -1) ? $0.schlafMinuten : nil }
        return SchlafUebersicht(
            heute: heute, zielMinuten: zielMinuten, naechte: gewaehlt,
            schuld: SchlafSchuld.berechne(naechte: reine, heute: heute, ziel: zielMinuten),
            regelmaessigkeit: Regelmaessigkeit.berechne(naechte: reine, heute: heute),
            woche: WochenVergleich.berechne(naechte: reine, heute: heute),
            hrv: hrv, chips: chips,
            erholung: ErholungsKlartext.bewerte(hrv: hrv.frischerBereich, ruhepuls: ruhepuls, letzteNachtMinuten: frisch, ziel: zielMinuten),
            vergleich: SchlafVergleich.verlauf(health: health, band: band, heute: heute),
            werktag: zeiten(reine, wochenende: false), wochenende: zeiten(reine, wochenende: true), zielExtra: zielExtra)
    }
}
