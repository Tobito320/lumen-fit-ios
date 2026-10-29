import Foundation

/// Wochen- oder Monatsrückblick (Idee 39): die Zahlen eines Zeitraums und der beste Moment.
struct RueckblickDaten: Equatable, Sendable {
    enum Zeitraum: String, CaseIterable, Identifiable, Sendable {
        case woche, monat
        var id: String { rawValue }
        var name: String { self == .woche ? "Woche" : "Monat" }
    }

    let zeitraum: Zeitraum
    /// Erster und letzter Tag (`yyyy-MM-dd`), beide inklusive.
    let von: String
    let bis: String
    /// Trainingstage: Einheiten und Gym-Häkchen, jeder Tag einmal.
    let gymTage: Int
    let einheiten: Int
    let saetze: Int
    let volumenKg: Double
    /// Schnitt der Nächte im Zeitraum in Minuten; nil ohne Nacht.
    let schlafSchnitt: Int?
    let schlafNaechte: Int
    /// Ein Satz: der Rekord, der schwerste Satz oder ein Wartesatz, wenn es nichts gab.
    let besterMoment: String

    /// Die Aussage als Titel: "Deine Woche: 3 Gym-Tage" oder "Noch kein Training in dieser Woche".
    var titel: String {
        guard gymTage > 0 else { return "Noch kein Training in \(zeitraum == .woche ? "dieser Woche" : "diesem Monat")" }
        return "Dein\(zeitraum == .woche ? "e Woche" : " Monat"): \(gymTage) \(gymTage == 1 ? "Gym-Tag" : "Gym-Tage")"
    }

    /// Lumi freut sich mit, wenn etwas gelaufen ist.
    var stimmung: LumiStimmung { gymTage > 0 ? .stolz : .bereit }

    /// "Volumen 12.400 kg · 42 Sätze" und der Schlaf.
    var zeile: String {
        var teile = ["Volumen \(Rueckblick.zahl(volumenKg)) kg", "\(saetze) Sätze"]
        if let s = schlafSchnitt { teile.append("Schlaf im Schnitt \(Rueckblick.dauer(s))") }
        return teile.joined(separator: " · ")
    }

    /// Für VoiceOver und das geteilte Bild: alles in einem Satz.
    var sprechtext: String {
        guard gymTage > 0 else { return "\(titel). \(besterMoment)" }
        return "\(titel). \(zeile). \(besterMoment)"
    }
}

enum Rueckblick {
    /// Der Rückblick für die Woche oder den Monat, in dem `bezug` liegt. Eine Woche geht von Montag bis Sonntag, ein Monat vom 1. bis zum letzten Tag.
    static func bauen(_ zeitraum: RueckblickDaten.Zeitraum, bezug: String, sessions: [GymSession], gym: [String: Int], schlafMinuten: [String: Int],
                      katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> RueckblickDaten {
        let (von, bis) = grenzen(zeitraum, bezug: bezug)
        let imZeitraum = { (tag: String) in tag >= von && tag <= bis }
        let eigene = sessions.filter { imZeitraum(Datum.text($0.start)) }
        var tage = Set(eigene.map { Datum.text($0.start) })
        tage.formUnion(gym.filter { $0.value > 0 && imZeitraum($0.key) }.keys)
        let laeufe = eigene.flatMap(\.laeufe)
        let saetze = laeufe.reduce(0) { $0 + KonstanzRaster.gezaehlteSaetze($1) }
        let volumen = laeufe.flatMap { KraftKurve.arbeitssaetze($0) }.reduce(0.0) { $0 + ($1.kg ?? 0) * Double($1.wdh) }
        let naechte = schlafMinuten.filter { imZeitraum($0.key) && $0.value > 0 }.map(\.value)
        let schnitt = naechte.isEmpty ? nil : naechte.reduce(0, +) / naechte.count
        return RueckblickDaten(zeitraum: zeitraum, von: von, bis: bis, gymTage: tage.count, einheiten: eigene.count, saetze: saetze, volumenKg: volumen,
                               schlafSchnitt: schnitt, schlafNaechte: naechte.count,
                               besterMoment: besterMoment(sessions: sessions, von: von, bis: bis, schlafMinuten: schlafMinuten, katalog: katalog))
    }

    static func grenzen(_ zeitraum: RueckblickDaten.Zeitraum, bezug: String) -> (von: String, bis: String) {
        switch zeitraum {
        case .woche:
            let montag = Datum.montagDerWoche(bezug)
            return (montag, Datum.addTage(montag, 6))
        case .monat:
            let erster = String(bezug.prefix(7)) + "-01"
            let naechster = Datum.kalender.date(byAdding: .month, value: 1, to: Datum.datum(erster)).map { Datum.text($0) } ?? erster
            return (erster, Datum.addTage(naechster, -1))
        }
    }

    /// Der Rekord mit dem größten Sprung (geschätztes 1RM gegen alles davor), sonst der schwerste Satz, sonst die beste Nacht, sonst ein Wartesatz.
    static func besterMoment(sessions: [GymSession], von: String, bis: String, schlafMinuten: [String: Int],
                             katalog: (String) -> Uebung?) -> String {
        var davor: [String: Double] = [:]
        var inZeitraum: [String: (e1rm: Double, satz: PlanSatz)] = [:]
        for s in sessions {
            let tag = Datum.text(s.start)
            guard tag <= bis else { continue }
            for lauf in s.laeufe {
                for satz in KraftKurve.arbeitssaetze(lauf) {
                    guard let e = VerlaufLogik.e1rm(satz) else { continue }
                    if tag < von {
                        davor[lauf.uebung] = max(davor[lauf.uebung] ?? 0, e)
                    } else if e > (inZeitraum[lauf.uebung]?.e1rm ?? 0) {
                        inZeitraum[lauf.uebung] = (e, satz)
                    }
                }
            }
        }
        let rekorde = inZeitraum.compactMap { uebung, bestes -> (name: String, satz: PlanSatz, sprung: Double)? in
            guard let alt = davor[uebung], bestes.e1rm > alt, let u = katalog(uebung) else { return nil }
            return (u.name, bestes.satz, bestes.e1rm / alt)
        }.max { $0.sprung != $1.sprung ? $0.sprung < $1.sprung : $0.name > $1.name }
        if let r = rekorde { return "Rekord: \(r.name), \(satzText(r.satz))" }

        let schwerster = inZeitraum.compactMap { uebung, bestes -> (name: String, satz: PlanSatz)? in
            katalog(uebung).map { ($0.name, bestes.satz) }
        }.max { ($0.satz.kg ?? 0) != ($1.satz.kg ?? 0) ? ($0.satz.kg ?? 0) < ($1.satz.kg ?? 0) : $0.name > $1.name }
        if let s = schwerster { return "Schwerster Satz: \(s.name), \(satzText(s.satz))" }

        if let beste = schlafMinuten.filter({ $0.key >= von && $0.key <= bis }).max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }), beste.value > 0 {
            return "Beste Nacht: \(dauer(beste.value)) am \(Datum.anzeige(beste.key))"
        }
        return "Dein bester Moment kommt noch. Lumi wartet."
    }

    /// "70 kg × 8", ohne Gewicht "12 Wdh".
    static func satzText(_ s: PlanSatz) -> String {
        s.kg.map { "\(TrainingLogik.kgText($0)) kg × \(s.wdh)" } ?? "\(s.wdh) Wdh"
    }

    /// 450 -> "7 h 30 min".
    static func dauer(_ minuten: Int) -> String { "\(minuten / 60) h \(String(format: "%02d", minuten % 60)) min" }

    /// 12400 -> "12.400".
    static func zahl(_ wert: Double) -> String {
        wert.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))
    }
}
