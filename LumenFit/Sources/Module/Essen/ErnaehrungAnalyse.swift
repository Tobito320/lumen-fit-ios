// Quelle: Lovea Health/Ernaehrung/ErnaehrungAnalyse.swift (Logik; die Ansicht ist neu: WochenanalyseView)
import Foundation

// Zeiträume von einer Woche bis zu 2 Jahren: bei langen Zeiträumen Werte je Woche bzw. Monat gemittelt statt Tag für Tag.

enum AnalyseGruppierung: Sendable { case tag, woche, monat }

/// Ein Abschnitt im Diagramm (ein Tag, eine Woche oder ein Monat) mit den Tagen, die hineinfallen.
/// `start` ist der Schlüssel: der Tag selbst, der Montag der Woche oder "yyyy-MM".
struct AnalyseBucket: Identifiable, Sendable, Equatable {
    var start: String
    var tage: [String]
    var id: String { start }
}

// MARK: - Reine Logik

/// Bucket-Bildung, Schnitt nur über Tage mit Einträgen, Serie, Prozent der EU-Referenz. Ohne Modell,
/// ohne Singletons, komplett testbar.
enum AnalyseLogik {
    /// `anzahl` Tage bis einschließlich `bis`, älteste zuerst.
    static func tage(bis: String, anzahl: Int) -> [String] {
        Array((0..<anzahl).map { Datum.addTage(bis, -$0) }.reversed())
    }

    /// Fasst `tage` zu Buckets zusammen: 1:1 pro Tag, ab Montag der Woche oder ab dem 1. des Monats.
    static func buckets(_ tage: [String], gruppierung: AnalyseGruppierung) -> [AnalyseBucket] {
        switch gruppierung {
        case .tag:
            return tage.map { AnalyseBucket(start: $0, tage: [$0]) }
        case .woche:
            return gruppiert(tage) { Datum.montagDerWoche($0) }
        case .monat:
            return gruppiert(tage) { String($0.prefix(7)) }
        }
    }

    private static func gruppiert(_ tage: [String], schluessel: (String) -> String) -> [AnalyseBucket] {
        var reihenfolge: [String] = []
        var gruppen: [String: [String]] = [:]
        for tag in tage {
            let s = schluessel(tag)
            if gruppen[s] == nil { reihenfolge.append(s) }
            gruppen[s, default: []].append(tag)
        }
        return reihenfolge.map { AnalyseBucket(start: $0, tage: gruppen[$0] ?? []) }
    }

    /// Schnitt eines Buckets, nur über die Tage darin, für die `werte` einen Wert hat. nil ohne Werte.
    static func bucketSchnitt(_ bucket: AnalyseBucket, _ werte: [String: Double]) -> Double? {
        let vorhanden = bucket.tage.compactMap { werte[$0] }
        guard !vorhanden.isEmpty else { return nil }
        return vorhanden.reduce(0, +) / Double(vorhanden.count)
    }

    /// Schnitt über alle Tage mit Werten (nicht über Buckets, sonst verzerren lange Lücken).
    static func schnitt(_ werte: [String: Double]) -> Double {
        guard !werte.isEmpty else { return 0 }
        return werte.values.reduce(0, +) / Double(werte.count)
    }

    /// Wie viele der Werte höchstens `toleranz` (Anteil) neben `ziel` liegen.
    static func tageImZiel(_ werte: [Double], ziel: Double, toleranz: Double = 0.1) -> Int {
        guard ziel > 0 else { return 0 }
        return werte.filter { abs($0 - ziel) <= ziel * toleranz }.count
    }

    /// `wert` als Prozent der EU-Tagesreferenz. nil ohne Referenz für diesen Mikronährstoff.
    static func prozentReferenz(_ wert: Double, _ m: Mikro) -> Double? {
        guard let referenz = m.referenz, referenz > 0 else { return nil }
        return wert / referenz * 100
    }

    /// Tage in Folge mit mindestens einem Eintrag, endend bei `heute` (oder gestern, falls heute
    /// noch nichts eingetragen ist – die Serie reißt erst, wenn ein Tag wirklich leer bleibt).
    static func serie(_ tageMitEintraegen: Set<String>, heute: String) -> Int {
        var tag = tageMitEintraegen.contains(heute) ? heute : Datum.addTage(heute, -1)
        var anzahl = 0
        while tageMitEintraegen.contains(tag) {
            anzahl += 1
            tag = Datum.addTage(tag, -1)
        }
        return anzahl
    }

    /// Beschriftung im Diagramm je Gruppierung: "23" (Tag), "23.09." (Wochenstart), "Sep. 26" (Monat).
    static func label(_ bucket: AnalyseBucket, _ gruppierung: AnalyseGruppierung) -> String {
        switch gruppierung {
        case .tag:
            return String(Int(bucket.start.suffix(2)) ?? 0)
        case .woche:
            let teile = bucket.start.split(separator: "-")
            return teile.count == 3 ? "\(teile[2]).\(teile[1])." : bucket.start
        case .monat:
            let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
            return Datum.datum(bucket.start + "-01").formatted(stil.month(.abbreviated).year(.twoDigits))
        }
    }
}

/// Eine Zeile "Name, Menge, % der EU-Referenz" für Nährstoff-Listen (Analyse und Tagesblatt).
struct NaehrstoffZeile: Identifiable {
    var id: String
    var name: String
    var menge: String
    var prozent: Double?
}
