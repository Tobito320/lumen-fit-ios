// Quelle: Lovea Health/Heute/Tagesform/TagesformQuellen.swift
import Foundation

/// Der Schlaf einer Nacht für die Rechnungen des Heute-Tabs: Health (mit der Quelle Watch oder iPhone) oder, wenn Health nichts hat, das Band.
struct HeuteNacht: Equatable, Sendable {
    var tag: String
    var minuten: Int
    var einschlafen: Date?
    var quelle: TagesformSchlafQuelle
}

/// Sammelt die Rohwerte eines Tages aus dem Datensatz des Profils und dem Gesundheitsstand (`TagesformEingabe`). Liest nur und rechnet nichts:
/// die Regeln stehen in `TagesformRechnung` und `TagesformQuellenLogik`. Für `tag` zählt, was an diesem Tag schon bekannt war: Einheiten und
/// Essen nach dem Tag fließen nicht ein, ein Tag in der Zukunft hat keine Werte.
@MainActor
enum TagesformQuellen {
    /// Nächte für den Schlaf-Schnitt, Nächte für die Bettzeit, Tage für Vitalwerte und Training (der Tag selbst und 28 davor).
    static let schlafNaechte = 14
    static let bettNaechte = 7
    static let vergleichsTage = 29

    static func eingabe(daten: DatenSatz, gesundheit: GesundheitsStand, tag: String, jetzt: Date) -> TagesformEingabe {
        var e = TagesformEingabe()
        guard tag <= Datum.text(jetzt) else { return e }
        e.stunde = TagesformRechnung.stunde(tag: tag, jetzt: jetzt)
        schlaf(&e, daten, gesundheit, tag)
        vital(&e, gesundheit, tag)
        training(&e, daten, tag, jetzt)
        essen(&e, daten, tag)
        bewegung(&e, daten, gesundheit, tag)
        return e
    }

    /// Eine Nacht je Aufwachtag: Health zuerst, sonst das Band (Op `fit.band.schlaf`). nil ohne Schlaf.
    static func nacht(_ tag: String, daten: DatenSatz, gesundheit: GesundheitsStand) -> HeuteNacht? {
        if let n = gesundheit.naechte[tag], n.schlafMinuten > 0 {
            let quelle: TagesformSchlafQuelle = n.phasen.contains(where: { $0.gestuft }) ? .appleWatch : .iPhone
            return HeuteNacht(tag: tag, minuten: n.schlafMinuten, einschlafen: n.von, quelle: quelle)
        }
        var band: BandSchlafOp?
        for op in daten.raum.ops(arten: ["fit.band.schlaf"]) {
            if let b = op.daten(BandSchlafOp.self), b.tag == tag { band = b }
        }
        guard let b = band else { return nil }
        let phasen = b.phasen.filter { $0.phase.schlaeft }.reduce(0.0) { $0 + $1.bis.timeIntervalSince($1.von) }
        let sekunden: TimeInterval = phasen > 0 ? phasen : b.ende.timeIntervalSince(b.start)
        let minuten = Int(sekunden / 60)
        guard minuten > 0 else { return nil }
        return HeuteNacht(tag: tag, minuten: minuten, einschlafen: b.start, quelle: .armband)
    }

    private static func schlaf(_ e: inout TagesformEingabe, _ daten: DatenSatz, _ gesundheit: GesundheitsStand, _ tag: String) {
        let naechte: [String] = TagesformQuellenLogik.tage(ab: tag, anzahl: schlafNaechte)
        let alle: [HeuteNacht?] = naechte.map { nacht($0, daten: daten, gesundheit: gesundheit) }
        e.schlafZiel = daten.ziele.ziele.schlafMinuten
        e.schlaf = alle.map { $0?.minuten }
        e.bett = alle.prefix(bettNaechte).map { (n: HeuteNacht?) -> Int? in n?.einschlafen.map { TagesformRechnung.bettMinuten($0) } }
        let quelle: String? = alle.first.flatMap { $0 }?.quelle.rawValue
        e.schlafSicherheit = TagesformRechnung.schlafSicherheit(quelle: quelle, abweichung: nil)
        e.schlafHinweis = TagesformRechnung.schlafHinweis(quelle: quelle, abweichung: nil)
    }

    private static func vital(_ e: inout TagesformEingabe, _ gesundheit: GesundheitsStand, _ tag: String) {
        let tage: [String] = TagesformQuellenLogik.tage(ab: tag, anzahl: vergleichsTage)
        func je(_ art: VitalArt) -> [String: Double] {
            var dict: [String: Double] = [:]
            for m in gesundheit.vitale[art] ?? [] { dict[m.tag] = m.wert }
            return dict
        }
        e.ruhepuls = TagesformQuellenLogik.reihe(je(.ruhepuls), tage: tage)
        e.hrv = TagesformQuellenLogik.reihe(je(.hrv), tage: tage)
    }

    private static func training(_ e: inout TagesformEingabe, _ daten: DatenSatz, _ tag: String, _ jetzt: Date) {
        let t = TagesformQuellenLogik.training(daten.training.sessions, tag: tag, jetzt: jetzt, anzahl: vergleichsTage)
        e.muskeln = t.muskeln
        e.saetze = t.saetze
    }

    private static func essen(_ e: inout TagesformEingabe, _ daten: DatenSatz, _ tag: String) {
        let vortag = Datum.addTage(tag, -1)
        func summe(_ t: String) -> Naehrwerte? { daten.essen.eintraege(t).isEmpty ? nil : daten.essen.summe(t) }
        let m = TagesformQuellenLogik.essen(tag: summe(tag), zielTag: daten.essen.ernaehrungsZiele(tag: tag), vortag: summe(vortag),
                                            zielVortag: daten.essen.ernaehrungsZiele(tag: vortag), stunde: e.stunde)
        e.kalorien = m.kalorien
        e.eiweiss = m.eiweiss
    }

    private static func bewegung(_ e: inout TagesformEingabe, _ daten: DatenSatz, _ gesundheit: GesundheitsStand, _ tag: String) {
        let vortag = Datum.addTage(tag, -1)
        let tage = gesundheit.tage
        func schritte(_ t: String) -> Int? { tage[t].flatMap { $0.schritte > 0 ? $0.schritte : nil } }
        e.schritte = TagesformQuellenLogik.schritte(heute: schritte(tag), vortag: schritte(vortag), ziel: daten.ziele.ziele.schritte, stunde: e.stunde)
        let letzte: [String] = TagesformQuellenLogik.tage(ab: tag, anzahl: TagesformQuellenLogik.wasserTage)
        let genutzt: [Int] = letzte.map { daten.habits.wert(Habit.wasser.id, $0) }
        e.wasser = TagesformQuellenLogik.wasser(heute: daten.habits.wert(Habit.wasser.id, tag), vortag: daten.habits.wert(Habit.wasser.id, vortag),
                                                letzteTage: genutzt, ziel: daten.habits.habitZiel(Habit.wasser.id) ?? 8, stunde: e.stunde)
    }
}
