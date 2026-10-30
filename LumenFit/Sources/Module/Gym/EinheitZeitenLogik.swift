// Quelle: Lovea Health/GymSession.swift (ZeitenBlatt, StartzeitBlatt, NachtragenBlatt; hier nur die Regeln)
import Foundation

/// Regeln rund um Zeiten einer Einheit: Prüfung vor dem Sichern, Vorschlag für "Endzeit eintragen", Texte der Verlaufszeile.
/// Rein, ohne Zustand; die Blätter und der Verlauf lesen nur.
enum EinheitZeitenLogik {
    enum Pruefung: Equatable, Sendable {
        case ok
        /// Länger als `TrainingLogik.langNach`: die Person bestätigt ("Warst du wirklich so lange im Gym?").
        case zuLang(stunden: Double)
        /// Ende liegt vor dem Start oder in der Zukunft: so nicht sichern.
        case ungueltig
    }

    /// Ein Ende vor dem Start oder nach `jetzt` ist ungültig; über `langNach` fragt die Ansicht nach.
    static func pruefe(start: Date, ende: Date, jetzt: Date) -> Pruefung {
        if ende < start || ende > jetzt.addingTimeInterval(60) { return .ungueltig }
        if TrainingLogik.zuLang(start: start, ende: ende) { return .zuLang(stunden: ende.timeIntervalSince(start) / 3600) }
        return .ok
    }

    /// "Warst du wirklich so lange im Gym?" mit der Dauer im Text.
    static func langeFrage(stunden: Double) -> String {
        let zahl = stunden.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_DE")))
        return "Das sind \(zahl) Stunden. Warst du wirklich so lange im Gym?"
    }

    /// Vorschlag für "Endzeit eintragen" bei vergessenem Auschecken: anderthalb Stunden nach dem Start, nie nach `jetzt`.
    static func endeVorschlag(start: Date, jetzt: Date) -> Date {
        min(start.addingTimeInterval(TrainingLogik.langNach / 2), jetzt)
    }

    /// Frühester Start einer laufenden Einheit, die man zurückstellen darf (höchstens `langNach` zurück), und der späteste (jetzt).
    static func startBereich(aktuell: Date, jetzt: Date) -> ClosedRange<Date> {
        let frueh = min(aktuell, TrainingLogik.fruehesterStart(jetzt: jetzt))
        return frueh...max(frueh, jetzt)
    }

    /// "18:30–19:45 · 1:15 h", ohne Ende "ab 18:30, nicht ausgecheckt".
    static func zeitText(_ s: GymSession) -> String {
        guard let ende = s.ende else { return "ab \(Datum.uhrzeit(s.start)), nicht ausgecheckt" }
        return "\(Datum.uhrzeit(s.start))–\(Datum.uhrzeit(ende)) · \(TrainingLogik.dauerText(ende.timeIntervalSince(s.start)))"
    }

    /// Kopfzeile im Nachlesen: "Montag, 12. Oktober, 18:30–19:45".
    static func kopfZeit(_ s: GymSession) -> String {
        let tag = Datum.anzeige(Datum.text(s.start))
        guard let ende = s.ende else { return "\(tag), seit \(Datum.uhrzeit(s.start))" }
        return "\(tag), \(Datum.uhrzeit(s.start))–\(Datum.uhrzeit(ende))"
    }

    /// "Push · 4 von 5 Übungen" für die Verlaufszeile; ohne Plantag nur "Freies Training".
    static func untertitel(_ s: GymSession, tag: TrainingsTag?) -> String {
        guard let tag else { return "Freies Training" }
        let fertig = tag.uebungen.filter { s.erledigt($0.id) }.count
        let name = tag.name.isEmpty ? "Training" : tag.name
        return "\(name) · \(fertig) von \(tag.uebungen.count) Übungen"
    }

    /// Titel des Monats über dem Raster: "September 2026" (aus `HealthLogik.monatsGitter`).
    static func monatTitel(_ gitter: [String?]) -> String {
        guard let erster = gitter.compactMap({ $0 }).first else { return "" }
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        return Datum.datum(erster).formatted(stil.month(.wide).year())
    }

    /// Wie viele Monate der Wisch-Pager zeigt: vom Monat der ältesten Einheit bis heute, mindestens drei, höchstens 60.
    static func monateAnzahl(aeltesterTag: String?, heute: String) -> Int {
        guard let tag = aeltesterTag, tag.count >= 7,
              let j0 = Int(tag.prefix(4)), let m0 = Int(tag.dropFirst(5).prefix(2)),
              let j1 = Int(heute.prefix(4)), let m1 = Int(heute.dropFirst(5).prefix(2)) else { return 3 }
        return min(60, max(3, (j1 - j0) * 12 + (m1 - m0) + 1))
    }

    /// Das Monatsgitter immer mit sechs Zeilen (42 Zellen), damit alle Seiten des Pagers gleich hoch sind.
    static func gitter42(heute: String, monateZurueck: Int) -> [String?] {
        var zellen = HealthLogik.monatsGitter(heute: heute, monateZurueck: monateZurueck)
        while zellen.count < 42 { zellen.append(nil) }
        return zellen
    }

    /// VoiceOver-Text eines Tages im Monatsraster.
    static func tagSprechtext(_ tag: String, training: Bool, nurHaken: Bool) -> String {
        let datum = Datum.anzeige(tag)
        if training { return "\(datum), Training" }
        return nurHaken ? "\(datum), Gym abgehakt, keine Einheit gespeichert" : datum
    }
}
