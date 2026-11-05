// Quelle: Lovea Health/EnergieKarte.swift (SchlafEintragenView), Lovea Health/Energie.swift (SchlafZeitenD)
import Foundation

/// Inhalt der Op `fit.schlaf.hand`: Bett- und Aufstehzeit einer Nacht von Hand. `tag` ist der Aufwachtag. `geloescht` nimmt den Eintrag zurück
/// (dann gilt wieder die automatische Erkennung); ältere Ops ohne das Feld sind Einträge.
struct SchlafHandD: Codable, Equatable, Sendable {
    var tag: String
    var bett: Date
    var auf: Date
    var geloescht: Bool? = nil
}

/// Nächte von Hand: eintragen, korrigieren, nachtragen, löschen. Ein Eintrag gilt vor jeder automatischen Quelle (`SchlafQuelle.eingetragen`).
enum SchlafHandLogik {
    nonisolated static let art = "fit.schlaf.hand"

    /// Die Nacht zu einem Eintrag; nil bei Löschung, kaputtem Tag oder unmöglicher Dauer (unter 1 oder über 16 Stunden).
    static func nacht(_ d: SchlafHandD) -> SchlafNacht? {
        guard d.geloescht != true, SchlafNachtLogik.gueltigerTag(d.tag), d.auf > d.bett else { return nil }
        let minuten = Int((d.auf.timeIntervalSince(d.bett) / 60).rounded())
        guard (60...(16 * 60)).contains(minuten) else { return nil }
        return SchlafNacht(tag: d.tag, von: d.bett, bis: d.auf, abschnitte: [SchlafAbschnitt(phase: .unbestimmt, von: d.bett, bis: d.auf)], schlafMinuten: minuten)
    }

    /// Je Aufwachtag die Nacht der zuletzt eingetroffenen Op (ältere zuerst im Eingang); gelöschte Tage fehlen.
    static func naechte(ops: [Op]) -> [String: SchlafNacht] {
        var ergebnis: [String: SchlafNacht] = [:]
        for op in ops {
            guard let d = op.daten(SchlafHandD.self) else { continue }
            ergebnis[d.tag] = nacht(d)
        }
        return ergebnis
    }

    /// Zeiten aus zwei Zeitwählern (nur Stunde und Minute zählen) zur Nacht des Aufwachtags `tag`; Bett nach der Aufstehzeit heißt Vorabend.
    static func eintrag(tag: String, bett: Date, auf: Date) -> SchlafHandD? {
        let k = Datum.kalender
        let b = k.dateComponents([.hour, .minute], from: bett), a = k.dateComponents([.hour, .minute], from: auf)
        guard let bh = b.hour, let bm = b.minute, let ah = a.hour, let am = a.minute,
              let (von, bis) = zeiten(bett: (bh, bm), auf: (ah, am), tag: tag) else { return nil }
        return SchlafHandD(tag: tag, bett: von, auf: bis)
    }

    /// `tag` = der Morgen des Aufwachens (wie `SchlafHandD.tag`). Bett nach der Aufstehzeit = Vorabend. nil bei unter 1 oder über 16 Stunden.
    private static func zeiten(bett: (h: Int, m: Int), auf: (h: Int, m: Int), tag: String) -> (Date, Date)? {
        let k = Datum.kalender
        let morgen = Datum.datum(tag)
        guard let aufDatum = k.date(bySettingHour: auf.h, minute: auf.m, second: 0, of: morgen),
              var bettDatum = k.date(bySettingHour: bett.h, minute: bett.m, second: 0, of: morgen) else { return nil }
        if bettDatum >= aufDatum { bettDatum = k.date(byAdding: .day, value: -1, to: bettDatum) ?? bettDatum }
        let stunden = aufDatum.timeIntervalSince(bettDatum) / 3600
        guard stunden >= 1, stunden <= 16 else { return nil }
        return (bettDatum, aufDatum)
    }

    /// Startwerte des Blatts: der Eintrag oder die erkannte Nacht, sonst 23:00 bis 07:00.
    static func start(tag: String, vorhanden: SchlafNacht?) -> (bett: Date, auf: Date) {
        if let v = vorhanden { return (v.von, v.bis) }
        let k = Datum.kalender
        let morgen = Datum.datum(tag)
        let auf = k.date(bySettingHour: 7, minute: 0, second: 0, of: morgen) ?? morgen
        let vorabend = k.date(byAdding: .day, value: -1, to: morgen) ?? morgen
        return (k.date(bySettingHour: 23, minute: 0, second: 0, of: vorabend) ?? vorabend, auf)
    }
}
