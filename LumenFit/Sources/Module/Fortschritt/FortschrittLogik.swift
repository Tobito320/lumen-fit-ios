import Foundation

/// Diese Woche (Mo bis heute) gegen den Schnitt der vier Wochen davor.
struct TrainingsWochenVergleich: Equatable, Sendable {
    var einheiten: Int
    var einheitenSchnitt: Double
    /// Summe kg mal Wiederholungen der Arbeitssätze in kg.
    var volumen: Double
    var volumenSchnitt: Double
    var saetze: Int
    var saetzeSchnitt: Double
    /// Hauptübungen, deren schwerster Satz der letzten 4 Wochen über dem der 4 Wochen davor liegt.
    var gestiegen: Int
    /// Übungen im Plan mit Gewicht in den letzten 8 Wochen.
    var hauptuebungen: Int
}

/// Eine Plan-Übung mit ihrem schwersten Satz je Woche.
struct GewichtZeile: Equatable, Identifiable, Sendable {
    var uebungId: String
    var name: String
    var muskel: String
    /// Acht Werte, älteste Woche zuerst; nil = in der Woche nicht gemacht.
    var wochen: [Double?]
    /// Schwerster Satz der letzten 4 Wochen (gab es keinen, der letzte bekannte).
    var aktuell: Double
    /// Schwerster Satz der letzten 4 Wochen minus der der 4 Wochen davor; 0, wenn eine der beiden Hälften leer ist.
    var aenderung4Wochen: Double
    var id: String { uebungId }
}

enum StatistikArt: CaseIterable, Sendable {
    case dauer, volumen, wiederholungen

    var titel: String {
        switch self {
        case .dauer: "Dauer"
        case .volumen: "Volumen"
        case .wiederholungen: "Wiederholungen"
        }
    }
}

/// Der Wert einer Woche (`montag` als `yyyy-MM-dd`); Dauer in Minuten, Volumen in kg.
struct WochenWert: Equatable, Sendable {
    var montag: String
    var wert: Double
}

/// Eine Übung in der Karte einer Einheit: Zahl der Arbeitssätze und der schwerste.
struct EinheitUebungZeile: Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var saetze: Int
    var bester: PlanSatz?
    var rekord: Bool
}

/// Alles, was die Karte einer Einheit im Verlauf zeigt.
struct EinheitDaten: Equatable, Identifiable, Sendable {
    var id: String
    var titel: String
    var start: Date
    var dauer: TimeInterval?
    var volumen: Double
    var saetze: Int
    var rekorde: Int
    var zeilen: [EinheitUebungZeile]
}

/// Rechnen für die Seite Fortschritt. Rein, ohne Zustand. Gezählt wird, was abgehakt ist (Stand der Satzzeilen, bei alten Einheiten die Sätze des fertigen Laufs);
/// Aufwärmsätze zählen weder fürs Volumen noch für die Sätze (wie "Sätze je Muskel"). Cardio hat keine Sätze und gibt nichts.
enum FortschrittLogik {
    static let wochenAnzahl = 8

    // MARK: Zählregeln

    /// Beendet, oder ohne Ende von einem früheren Tag (Auschecken vergessen): eine Einheit von heute ohne Ende läuft noch und zählt nicht.
    /// Mit `jetzt` gilt auch eine Einheit von gestern als laufend, solange sie jünger als `TrainingLogik.langNach` ist (Start 23:40, jetzt 00:30).
    static func beendet(_ s: GymSession, heute: String, jetzt: Date? = nil) -> Bool {
        if s.ende != nil { return true }
        if let jetzt, TrainingLogik.laufend(s, jetzt: jetzt) { return false }
        return Datum.text(s.start) < heute
    }

    /// Die Arbeitssätze eines Laufs: abgehakt, ohne Aufwärmen.
    static func arbeitssaetze(_ lauf: UebungsLauf) -> [PlanSatz] {
        let abgehakt = lauf.stand.map { stand in stand.filter { $0.ok == true } } ?? (lauf.fertig ? lauf.saetze ?? [] : [])
        return abgehakt.filter { $0.typ != "w" }
    }

    private struct Summe {
        var minuten = 0.0, volumen = 0.0, saetze = 0, wdh = 0
        mutating func add(_ s: GymSession) {
            if let ende = s.ende { minuten += max(0, ende.timeIntervalSince(s.start)) / 60 }
            for satz in s.laeufe.flatMap(FortschrittLogik.arbeitssaetze) {
                volumen += (satz.kg ?? 0) * Double(satz.wdh)
                saetze += 1
                wdh += satz.wdh
            }
        }
    }

    // MARK: Woche gegen Schnitt

    static func vergleich(_ sessions: [GymSession], plan: TrainingsPlan, heute: String, jetzt: Date? = nil,
                          katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> TrainingsWochenVergleich {
        let montag = Datum.montagDerWoche(heute)
        let davor = Datum.addTage(montag, -28)
        var woche = Summe(), schnitt = Summe(), einheiten = 0, einheitenDavor = 0
        for s in sessions where beendet(s, heute: heute, jetzt: jetzt) {
            let tag = Datum.text(s.start)
            if tag >= montag, tag <= heute {
                woche.add(s)
                einheiten += 1
            } else if tag >= davor, tag < montag {
                schnitt.add(s)
                einheitenDavor += 1
            }
        }
        let zeilen = gewichte(sessions, plan: plan, heute: heute, katalog: katalog)
        return TrainingsWochenVergleich(
            einheiten: einheiten, einheitenSchnitt: Double(einheitenDavor) / 4,
            volumen: woche.volumen, volumenSchnitt: schnitt.volumen / 4,
            saetze: woche.saetze, saetzeSchnitt: Double(schnitt.saetze) / 4,
            gestiegen: zeilen.filter { $0.aenderung4Wochen > 0 }.count, hauptuebungen: zeilen.count)
    }

    /// Wie viele Trainings der Plan für den Rest der Woche noch vorsieht: spätere Tage, und heute, solange heute nicht trainiert wurde.
    static func geplantRest(_ plan: TrainingsPlan, sessions: [GymSession], heute: String) -> Int {
        let effektiv = WochenLogik.effektiverPlan(plan, woche: Datum.montagDerWoche(heute))
        let wochentag = Datum.wochentag(heute)
        let heuteGemacht = sessions.contains { Datum.text($0.start) == heute }
        return effektiv.tage.flatMap(\.wochentage).filter { $0 > wochentag || ($0 == wochentag && !heuteGemacht) }.count
    }

    /// Der Satz unter "Wie geht's dir"; nil ohne Hauptübungen.
    static func satz(_ v: TrainingsWochenVergleich, geplantRest: Int) -> String? {
        guard v.hauptuebungen > 0 else { return nil }
        let eine = v.hauptuebungen == 1
        var text = "\(v.gestiegen) von \(v.hauptuebungen) \(eine ? "Hauptübung ist" : "Hauptübungen sind") gestiegen."
        if geplantRest > 0 {
            text += " Die Woche läuft noch, \(geplantRest) \(geplantRest == 1 ? "Training ist" : "Trainings sind") geplant."
        }
        return text
    }

    // MARK: Gewichte

    /// Die Plan-Übungen mit Gewicht in den letzten 8 Wochen, in der Reihenfolge des Plans. Eine Übung, die an mehreren Tagen steht, kommt einmal;
    /// Cardio und eigene Übungen ohne Katalog-Id fehlen. shortcut: Sätze ohne Gewicht (Klimmzüge ohne Zusatz) geben keinen Wert, bei Bedarf Wiederholungen zeigen.
    static func gewichte(_ sessions: [GymSession], plan: TrainingsPlan, heute: String,
                         katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [GewichtZeile] {
        let montag = Datum.montagDerWoche(heute)
        let montage = (0..<wochenAnzahl).map { Datum.addTage(montag, -7 * (wochenAnzahl - 1 - $0)) }
        var gesehen = Set<String>()
        var zeilen: [GewichtZeile] = []
        for u in plan.tage.flatMap(\.uebungen) {
            guard !u.istCardio, u.uebung != PlanUebung.eigen, gesehen.insert(u.uebung).inserted else { continue }
            let k = katalog(u.uebung)
            guard let name = u.name ?? k?.name else { continue }
            let punkte = Dictionary(KraftKurve.punkte(sessions, uebung: u.uebung, heute: heute, wochen: wochenAnzahl).map { ($0.woche, $0.gewicht) },
                                    uniquingKeysWith: max)
            let wochen = montage.map { punkte[$0] }
            let alle = wochen.compactMap { $0 }
            guard let letzter = alle.last else { continue }
            let neu = wochen[(wochenAnzahl / 2)...].compactMap { $0 }.max()
            let alt = wochen[..<(wochenAnzahl / 2)].compactMap { $0 }.max()
            zeilen.append(GewichtZeile(uebungId: u.uebung, name: name, muskel: k?.muskel ?? "", wochen: wochen,
                                       aktuell: neu ?? letzter, aenderung4Wochen: neu.flatMap { n in alt.map { n - $0 } } ?? 0))
        }
        return zeilen
    }

    // MARK: Wochen fürs Diagramm

    /// Die letzten `anzahl` Wochen bis zur Woche von `heute`, älteste zuerst; Wochen ohne Training mit 0.
    static func wochen(_ sessions: [GymSession], heute: String, jetzt: Date? = nil, art: StatistikArt, anzahl: Int = FortschrittLogik.wochenAnzahl) -> [WochenWert] {
        let montag = Datum.montagDerWoche(heute)
        let n = max(anzahl, 1)
        var summen: [String: Summe] = [:]
        for s in sessions where beendet(s, heute: heute, jetzt: jetzt) { summen[Datum.montagDerWoche(Datum.text(s.start)), default: Summe()].add(s) }
        return (0..<n).map { i in
            let m = Datum.addTage(montag, -7 * (n - 1 - i))
            let s = summen[m] ?? Summe()
            return WochenWert(montag: m, wert: art == .dauer ? s.minuten : art == .volumen ? s.volumen : Double(s.wdh))
        }
    }

    // MARK: Einheiten nach Wochen

    /// Beendete Einheiten je Woche, neueste Woche zuerst, in der Woche neueste zuerst. Titel: "Diese Woche", "Letzte Woche", sonst "KW 44".
    /// shortcut: ohne Jahr im Titel, bei mehr als einem Jahr Verlauf kann "KW 44" zweimal vorkommen; dann Jahr ergänzen.
    static func nachWochen(_ sessions: [GymSession], heute: String, jetzt: Date? = nil) -> [(titel: String, sessions: [GymSession])] {
        let montag = Datum.montagDerWoche(heute)
        let letzte = Datum.addTage(montag, -7)
        let gruppen = Dictionary(grouping: sessions.filter { beendet($0, heute: heute, jetzt: jetzt) }.sorted { $0.start > $1.start }) {
            Datum.montagDerWoche(Datum.text($0.start))
        }
        return gruppen.keys.sorted(by: >).map { m in
            (titel: m == montag ? "Diese Woche" : m == letzte ? "Letzte Woche" : "KW \(kalenderwoche(m))", sessions: gruppen[m] ?? [])
        }
    }

    nonisolated private static let iso: Calendar = {
        var kalender = Calendar(identifier: .iso8601)
        kalender.timeZone = Datum.zone
        return kalender
    }()

    /// ISO-Kalenderwoche (Woche 1 hat den ersten Donnerstag des Jahres) des Tages `tag`.
    static func kalenderwoche(_ tag: String) -> Int {
        iso.component(.weekOfYear, from: Datum.datum(tag))
    }

    // MARK: Karte einer Einheit

    /// Die Zahlen und Zeilen der Karte. Rekord: ein Arbeitssatz der Übung bricht einen früheren Rekord (`RekordLogik`); das erste Mal ist keiner.
    static func einheit(_ s: GymSession, titel: String?, frueher: [GymSession],
                        katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> EinheitDaten {
        let davor = frueher.filter { $0.start < s.start }
        var summe = Summe()
        summe.add(s)
        var zeilen: [EinheitUebungZeile] = []
        for (i, lauf) in s.laeufe.enumerated() {
            let arbeit = arbeitssaetze(lauf)
            guard !arbeit.isEmpty else { continue }
            let rekord = !RekordLogik.neue(arbeit, gegen: RekordLogik.tage(katalogId: lauf.uebung, planId: lauf.plan, in: davor)).isEmpty
            let bester = arbeit.max { ($0.kg ?? 0, $0.wdh) < ($1.kg ?? 0, $1.wdh) }
            zeilen.append(EinheitUebungZeile(id: "\(lauf.plan)-\(i)", name: lauf.name ?? katalog(lauf.uebung)?.name ?? "Übung",
                                             saetze: arbeit.count, bester: bester, rekord: rekord))
        }
        return EinheitDaten(id: s.id, titel: titel ?? "Training", start: s.start, dauer: s.ende.map { max(0, $0.timeIntervalSince(s.start)) },
                            volumen: summe.volumen, saetze: summe.saetze, rekorde: zeilen.filter(\.rekord).count, zeilen: zeilen)
    }

    // MARK: Text

    private static let deutsch = Locale(identifier: "de_DE")

    /// "Mi., 11. Nov." für die Karte einer Einheit (FormatStyle, kein DateFormatter).
    static func kurzDatum(_ datum: Date) -> String {
        datum.formatted(Date.FormatStyle(locale: deutsch, calendar: Datum.kalender, timeZone: Datum.zone).weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "5. Okt. – 11. Okt." für die Woche mit dem Montag `montag`.
    static func wochenSpanne(_ montag: String) -> String {
        let stil = Date.FormatStyle(locale: deutsch, calendar: Datum.kalender, timeZone: Datum.zone).day().month(.abbreviated)
        return "\(Datum.datum(montag).formatted(stil)) – \(Datum.datum(Datum.addTage(montag, 6)).formatted(stil))"
    }

    /// Zahl mit höchstens einer Nachkommastelle, deutsch: "3,8", "46".
    static func zahl(_ wert: Double) -> String { TrainingLogik.kgText(wert) }

    /// "+5 kg", "−2,5 kg", "±0 kg" (Änderung seit 4 Wochen).
    static func aenderungText(_ kg: Double) -> String {
        if kg > 0 { return "+\(zahl(kg)) kg" }
        if kg < 0 { return "−\(zahl(-kg)) kg" }
        return "±0 kg"
    }

    /// "12,9 t" ab 10 000 kg, sonst "9.690 kg". Die Grenze gilt nach dem Runden (9999,6 kg wird "10,0 t", nicht "10.000 kg").
    static func volumenText(_ kg: Double) -> String {
        if kg.rounded() >= 10_000 { return "\((kg / 1000).formatted(.number.precision(.fractionLength(1)).locale(deutsch))) t" }
        return "\(kg.formatted(.number.precision(.fractionLength(0)).locale(deutsch))) kg"
    }
}

extension GewichtZeile {
    /// Für VoiceOver: "Brustpresse, 32,5 Kilo, plus 5 seit 4 Wochen".
    var sprechtext: String {
        let aenderung = aenderung4Wochen > 0 ? "plus \(FortschrittLogik.zahl(aenderung4Wochen)) seit 4 Wochen"
            : aenderung4Wochen < 0 ? "minus \(FortschrittLogik.zahl(-aenderung4Wochen)) seit 4 Wochen" : "unverändert seit 4 Wochen"
        return "\(name), \(FortschrittLogik.zahl(aktuell)) Kilo, \(aenderung)"
    }
}
