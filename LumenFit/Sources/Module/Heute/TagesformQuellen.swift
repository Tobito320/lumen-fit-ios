// Quelle: Lovea Health/Heute/Tagesform/TagesformQuellen.swift
import Foundation

/// Der Schlaf einer Nacht für die Rechnungen des Heute-Tabs: das Band, wenn es die Nacht kennt, sonst Health (mit der Quelle Watch oder iPhone).
struct HeuteNacht: Equatable, Sendable {
    var tag: String
    var minuten: Int
    var einschlafen: Date?
    var quelle: TagesformSchlafQuelle
}

extension SchlafQuelle {
    /// Die Quelle, wie Heute sie nennt (Hinweis "Quelle: ..." und Sicherheit der Schlafzahl).
    var heuteQuelle: TagesformSchlafQuelle {
        switch self {
        case .eingetragen: .eingetragen
        case .band: .armband
        case .uhr: .appleWatch
        case .handy: .iPhone
        }
    }
}

/// Sammelt die Rohwerte eines Tages aus dem Datensatz des Profils und dem Gesundheitsstand (`TagesformEingabe`). Liest nur und rechnet nichts:
/// die Regeln stehen in `TagesformRechnung` und `TagesformQuellenLogik`. Für `tag` zählt, was an diesem Tag schon bekannt war: Einheiten und
/// Essen nach dem Tag fließen nicht ein, ein Tag in der Zukunft hat keine Werte.
@MainActor
enum TagesformQuellen {
    /// Nächte für den Schlaf-Schnitt, Nächte für die Bettzeit, Tage für Vitalwerte und Training (der Tag selbst und 28 davor).
    nonisolated static let schlafNaechte = 14
    nonisolated static let bettNaechte = 7
    nonisolated static let vergleichsTage = 29

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

    /// Eine Nacht je Aufwachtag aus der einen Wahl `GesundheitsStand.gewaehlteNaechte`: von Hand (Op `fit.schlaf.hand`), sonst das Band (Op `fit.band.schlaf`,
    /// es misst selbst: Lovea `automatikVorrang`), sonst Health. Hand und Band liest sie aus dem Raum von `daten`. Kein Eintrag ohne Schlaf.
    static func naechte(daten: DatenSatz, gesundheit: GesundheitsStand) -> [String: HeuteNacht] {
        var ergebnis: [String: HeuteNacht] = [:]
        for gewaehlt in gesundheit.gewaehlteNaechte(eigene: SchlafEigeneQuellen.lesen(daten.raum)) where gewaehlt.nacht.schlafMinuten > 0 {
            let n = gewaehlt.nacht
            ergebnis[n.tag] = HeuteNacht(tag: n.tag, minuten: n.schlafMinuten, einschlafen: n.von, quelle: gewaehlt.quelle.heuteQuelle)
        }
        return ergebnis
    }

    /// Eine einzelne Nacht; wer mehrere braucht, ruft `naechte` einmal (jeder Aufruf liest den Raum neu).
    static func nacht(_ tag: String, daten: DatenSatz, gesundheit: GesundheitsStand) -> HeuteNacht? {
        naechte(daten: daten, gesundheit: gesundheit)[tag]
    }

    private static func schlaf(_ e: inout TagesformEingabe, _ daten: DatenSatz, _ gesundheit: GesundheitsStand, _ tag: String) {
        let naechte: [String] = TagesformQuellenLogik.tage(ab: tag, anzahl: schlafNaechte)
        let gewaehlt: [String: HeuteNacht] = Self.naechte(daten: daten, gesundheit: gesundheit)
        let alle: [HeuteNacht?] = naechte.map { gewaehlt[$0] }
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
