// Quelle: Lovea Health/UebungRekorde.swift (RekordLogik, RekordArt, UebungTag; die Ansicht `UebungDetail` ist neu: UebungDetailView)
import Foundation

/// Eine Einheit, in der die Übung gemacht wurde, mit ihren gezählten Sätzen.
struct UebungTag: Identifiable, Equatable, Sendable {
    var id: String
    var datum: Date
    var saetze: [PlanSatz]
}

enum RekordArt: String, CaseIterable, Identifiable, Sendable {
    case gewicht, e1rm, satzVolumen, sitzungsVolumen, wiederholungen

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .gewicht: "Schwerstes Gewicht"
        case .e1rm: "One-Rep-Max"
        case .satzVolumen: "Bestes Satzvolumen"
        case .sitzungsVolumen: "Bestes Sitzungsvolumen"
        case .wiederholungen: "Meiste Wiederholungen"
        }
    }

    /// Kurzwort für den Toast ("Neuer Rekord: Gewicht").
    var kurz: String {
        switch self {
        case .gewicht: "Gewicht"
        case .e1rm: "1RM"
        case .satzVolumen: "Satzvolumen"
        case .sitzungsVolumen: "Volumen"
        case .wiederholungen: "Wiederholungen"
        }
    }
}

enum RekordLogik {
    /// Was direkt nach einem Satz geprüft wird. Das Sitzungsvolumen gibt es erst am Ende.
    static let liveArten: [RekordArt] = [.gewicht, .wiederholungen, .e1rm, .satzVolumen]

    /// Alle Einheiten mit gezählten Sätzen dieser Übung, älteste zuerst. Katalog-Übungen über die
    /// Katalog-id (egal an welchem Tag), eigene über ihren Plan-Eintrag. Aufwärmsätze zählen nicht (`PlanSatz.zaehlt`).
    static func tage(katalogId: String, planId: String? = nil, in sessions: [GymSession]) -> [UebungTag] {
        sessions.sorted { $0.start < $1.start }.compactMap { s in
            let passend = s.laeufe.filter { katalogId == PlanUebung.eigen ? $0.plan == planId : $0.uebung == katalogId }
            let saetze = passend.flatMap { $0.fertig ? $0.saetze ?? [] : [] }
            return saetze.isEmpty ? nil : UebungTag(id: s.id, datum: s.start, saetze: saetze)
        }
    }

    /// kg × Wdh; ohne Gewicht nil.
    static func volumen(_ s: PlanSatz) -> Double? {
        guard let kg = s.kg, kg > 0, s.wdh > 0 else { return nil }
        return kg * Double(s.wdh)
    }

    /// Epley: kg × (1 + Wdh / 30), eine Wiederholung ist das Gewicht selbst. Sätze ohne Gewicht geben nil.
    /// Gleiche Formel wie die Kraftkurve im Modul fortschritt.
    static func e1rm(_ s: PlanSatz) -> Double? {
        guard let kg = s.kg, kg > 0, s.wdh > 0 else { return nil }
        return s.wdh == 1 ? kg : kg * (1 + Double(s.wdh) / 30)
    }

    /// Der Wert einer Einheit für eine Rekordart; nil, wenn kein Satz ein Gewicht hat (Wiederholungen brauchen keins).
    static func wert(_ saetze: [PlanSatz], _ art: RekordArt) -> Double? {
        switch art {
        case .gewicht: return saetze.compactMap(\.kg).filter { $0 > 0 }.max()
        case .e1rm: return saetze.compactMap(e1rm).max()
        case .satzVolumen: return saetze.compactMap(volumen).max()
        case .sitzungsVolumen:
            let summe = saetze.compactMap(volumen).reduce(0, +)
            return summe > 0 ? summe : nil
        case .wiederholungen: return saetze.map(\.wdh).filter { $0 > 0 }.max().map(Double.init)
        }
    }

    static func rekord(_ tage: [UebungTag], _ art: RekordArt) -> Double? {
        tage.compactMap { wert($0.saetze, art) }.max()
    }

    /// Welche Rekorde `saetze` gegenüber allem davor brechen. Das erste Mal ist kein Rekord.
    static func neue(_ saetze: [PlanSatz], gegen frueher: [UebungTag], arten: [RekordArt] = RekordArt.allCases) -> [RekordArt] {
        arten.filter { art in
            guard let neu = wert(saetze, art), let alt = rekord(frueher, art) else { return false }
            return neu > alt
        }
    }

    /// Live nach dem Haken: bricht dieser eine Satz einen Rekord gegen die Historie und gegen die früheren Sätze der Übung in
    /// diesem Training? Ein Aufwärmsatz nie. `davor`: die schon gezählten Sätze dieser Übung heute, ohne diesen.
    static func beimSatz(_ satz: PlanSatz, davor: [PlanSatz], gegen frueher: [UebungTag]) -> [RekordArt] {
        guard satz.typ != "w", !frueher.isEmpty else { return [] } // das erste Mal ist kein Rekord
        let bisher = frueher + (davor.isEmpty ? [] : [UebungTag(id: "heute", datum: .distantFuture, saetze: davor)])
        return neue([satz], gegen: bisher, arten: liveArten)
    }

    /// In wie vielen Übungen dieses Training einen Rekord gebrochen hat (für `auschecken(rekorde:)`).
    static func anzahl(_ liste: [WorkoutUebung], frueher: [GymSession]) -> Int {
        liste.filter { u in
            let saetze = u.saetze.filter(\.zaehlt)
            guard !saetze.isEmpty else { return false }
            return !neue(saetze, gegen: tage(katalogId: u.planUebung.uebung, planId: u.id, in: frueher)).isEmpty
        }.count
    }

    /// Der Wert einer Rekordart als Text: "80 kg", "12 Wdh", ohne Wert "–".
    static func text(_ wert: Double?, art: RekordArt = .gewicht) -> String {
        guard let wert else { return "–" }
        return art == .wiederholungen ? "\(Int(wert)) Wdh" : "\(TrainingLogik.kgText(wert)) kg"
    }

    /// Toast-Inhalt für einen oder mehrere Rekorde eines Satzes; nil ohne Rekord. Lumi ist stolz (Idee 24).
    static func toast(uebung: String, arten: [RekordArt], satz: PlanSatz) -> ToastInhalt? {
        guard !arten.isEmpty else { return nil }
        let titel = arten.count == 1 ? "Neuer Rekord: \(arten[0].kurz)" : "Neue Rekorde: \(arten.map(\.kurz).joined(separator: ", "))"
        return ToastInhalt(titel: titel, zeile: "\(uebung), \(WorkoutLogik.satzText(satz))", stimmung: .stolz)
    }
}
