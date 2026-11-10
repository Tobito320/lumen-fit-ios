// Quelle: Lovea Health/Workout.swift (WorkoutUebung, WorkoutLogik, Anstrengung; WorkoutUhr und WorkoutAktion ersetzt GymSitzung)
import Foundation

/// Eine Übung im Training: aus dem Plantag, oder im Training dazugekommen (`extra`).
struct WorkoutUebung: Identifiable, Equatable, Sendable {
    var planUebung: PlanUebung
    /// Die Satzzeilen, wie sie gerade stehen; leer bei Cardio.
    var saetze: [PlanSatz]
    /// Dieselbe Übung beim letzten Mal (Spalte "Vorher").
    var vorher: [PlanSatz]
    var extra: Bool
    var cardioFertig = false
    /// Übersprungen (Gerät besetzt, keine Zeit): ein leerer Stand wurde gesendet. Zählt nicht als dran.
    var ausgelassen = false
    /// Katalog-id der Plan-Übung, wenn sie im Training getauscht wurde (`AusweichLogik`); `planUebung`
    /// ist dann die Ersatz-Übung, die Plan-Id bleibt.
    var ersatzFuer: String? = nil

    var id: String { planUebung.id }
    var gesamt: Int { planUebung.istCardio ? 1 : saetze.count }
    var fertigZahl: Int { planUebung.istCardio ? (cardioFertig ? 1 : 0) : saetze.filter { $0.ok == true }.count }
    var fertig: Bool { gesamt > 0 && fertigZahl == gesamt }
}

enum WorkoutLogik {
    static let standardPause = 120
    static let pausen = [0, 60, 90, 120, 150, 180, 240, 300]

    /// Ziehen und Ablegen im Training: die Übung `von` kommt an die Stelle `nach`; nur sie verlässt ihren Supersatz (`SupersatzLogik.verschieben`).
    static func verschieben(_ liste: [WorkoutUebung], von: Int, nach: Int) -> [WorkoutUebung] {
        guard liste.indices.contains(von), liste.indices.contains(nach), von != nach else { return liste }
        return SupersatzLogik.verschieben(liste.map(\.planUebung), von: von, nach: nach).map { s in
            var u = liste[s.index]
            u.planUebung.supersatz = s.supersatz
            return u
        }
    }

    /// Eine im Training dazugekommene Übung darf nur ohne abgehakten Satz (und ohne fertiges Cardio) wieder heraus, damit nichts Eingetragenes verloren geht.
    static func entfernbar(_ u: WorkoutUebung) -> Bool {
        u.extra && !u.cardioFertig && !u.saetze.contains { $0.ok == true }
    }

    /// Die Liste in der Reihenfolge von `ids` (Blatt "Reihenfolge ändern"): Zug für Zug über `verschieben`, damit Supersätze wie beim Ziehen bleiben.
    static func umordnen(_ liste: [WorkoutUebung], ids: [String]) -> [WorkoutUebung] {
        var l = liste
        for (ziel, id) in ids.enumerated() {
            if let von = l.firstIndex(where: { $0.id == id }), von != ziel { l = verschieben(l, von: von, nach: ziel) }
        }
        return l
    }

    /// Der Plantag in der Reihenfolge der Liste, die Kopplungen wie in der Liste; Plan-Übungen, die nicht in der Liste stehen, bleiben dahinter.
    static func tagInReihenfolge(_ tag: TrainingsTag, _ liste: [WorkoutUebung]) -> TrainingsTag {
        var t = tag
        let stelle = Dictionary(liste.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        let rang = { (u: PlanUebung) in stelle[u.id] ?? Int.max }
        t.uebungen = tag.uebungen.enumerated().sorted { (rang($0.element), $0.offset) < (rang($1.element), $1.offset) }.map(\.element)
        let kopplung = Dictionary(liste.map { ($0.id, $0.planUebung.supersatz) }, uniquingKeysWith: { a, _ in a })
        for i in t.uebungen.indices { if let k = kopplung[t.uebungen[i].id] { t.uebungen[i].supersatz = k } }
        return t
    }

    /// Plan-Übungen in Planreihenfolge, dahinter die im Training dazugekommenen. `frueher`: ältere
    /// Einheiten, neueste zuerst.
    static func uebungen(_ s: GymSession, tag: TrainingsTag?, frueher: [GymSession]) -> [WorkoutUebung] {
        var letzter: [String: UebungsLauf] = [:]
        var reihenfolge: [String] = []
        for l in s.laeufe {
            if letzter[l.plan] == nil { reihenfolge.append(l.plan) }
            letzter[l.plan] = l
        }
        let geplant = tag?.uebungen ?? []
        let planIds = Set(geplant.map(\.id))
        let extras = reihenfolge.filter { !planIds.contains($0) }.compactMap { id -> PlanUebung? in
            guard let l = letzter[id] else { return nil }
            let cardio = UebungsKatalog.nachId[l.uebung]?.istCardio == true
            return PlanUebung(id: id, uebung: l.uebung, name: l.name, saetze: [], minuten: cardio ? 20 : nil)
        }
        let alle = geplant.map { ($0, false) } + extras.map { ($0, true) }
        return alle.map { geplantU, extra in
            let lauf = letzter[geplantU.id]
            var u = geplantU
            if lauf?.ersatzFuer != nil, let neu = lauf?.uebung, !neu.isEmpty, neu != u.uebung {
                u.uebung = neu
                u.name = nil
            }
            let vorher = vorherige(u, in: frueher)
            return WorkoutUebung(planUebung: u, saetze: zeilen(u, lauf: lauf, vorher: vorher), vorher: vorher, extra: extra,
                                 cardioFertig: u.istCardio && lauf?.fertig == true, ausgelassen: lauf?.stand?.isEmpty == true,
                                 ersatzFuer: lauf?.ersatzFuer)
        }
    }

    /// Die Satzzeilen einer Übung: der gesendete Stand, sonst (alte Einheit) die abgehakten Sätze,
    /// sonst die Plan-Sätze mit den Werten vom letzten Mal.
    static func zeilen(_ u: PlanUebung, lauf: UebungsLauf?, vorher: [PlanSatz]) -> [PlanSatz] {
        if u.istCardio { return [] }
        if let stand = lauf?.stand { return stand }
        if let lauf, lauf.fertig {
            return (lauf.saetze ?? u.saetze).map { alt in
                var s = alt
                s.ok = true
                return s
            }
        }
        return u.saetze.enumerated().map { i, p in
            var s = p.alsPlan
            if vorher.indices.contains(i) {
                s.kg = vorher[i].kg
                s.wdh = vorher[i].wdh
            }
            return s
        }
    }

    /// Die abgehakten Sätze derselben Übung aus der letzten Einheit davor. Katalog-Übungen über die
    /// Katalog-id (egal an welchem Tag), eigene über ihren Plan-Eintrag.
    static func vorherige(_ u: PlanUebung, in frueher: [GymSession]) -> [PlanSatz] {
        for s in frueher {
            for l in s.laeufe.reversed() {
                guard u.uebung == PlanUebung.eigen ? l.plan == u.id : l.uebung == u.uebung else { continue }
                let gemacht = l.stand?.filter { $0.ok == true } ?? (l.fertig ? l.saetze ?? [] : [])
                if !gemacht.isEmpty { return gemacht }
            }
        }
        return []
    }

    /// Der erste offene Satz in Reihenfolge: welche Übung, welcher Satz. nil = alles fertig.
    static func dran(_ liste: [WorkoutUebung]) -> (uebung: Int, satz: Int)? {
        for (i, u) in liste.enumerated() where !u.fertig && !u.ausgelassen {
            if u.planUebung.istCardio { return (i, 0) }
            if let j = u.saetze.firstIndex(where: { $0.ok != true }) { return (i, j) }
        }
        return nil
    }

    static func volumen(_ liste: [WorkoutUebung]) -> Double {
        liste.flatMap(\.saetze).filter(\.zaehlt).reduce(0) { $0 + ($1.kg ?? 0) * Double($1.wdh) }
    }

    static func saetzeZahl(_ liste: [WorkoutUebung]) -> Int {
        liste.flatMap(\.saetze).filter { $0.ok == true }.count
    }

    /// Der Plantag, wie er nach diesem Training aussähe. nil, wenn sich am Aufbau nichts geändert
    /// hat (gleiche Übungen, gleich viele Sätze, gleiche Satztypen): dann wird nicht gefragt.
    static func neuerTag(_ tag: TrainingsTag, _ liste: [WorkoutUebung]) -> TrainingsTag? {
        var neu = tag
        var anders = false
        // Ohne Sätze (ausgelassen): die Plan-Sätze bleiben, sonst löschte "Plan aktualisieren" sie.
        for u in liste where !u.planUebung.istCardio && !u.saetze.isEmpty && u.ersatzFuer == nil {
            let saetze = u.saetze.map(\.alsPlan)
            if let i = neu.uebungen.firstIndex(where: { $0.id == u.id }) {
                if neu.uebungen[i].saetze.map(\.kuerzel) != saetze.map(\.kuerzel) { anders = true }
                neu.uebungen[i].saetze = saetze
            } else if u.fertigZahl > 0 {
                var dazu = u.planUebung
                dazu.saetze = saetze
                neu.uebungen.append(dazu)
                anders = true
            }
        }
        return anders ? neu : nil
    }

    /// Haken von Hand in einer beendeten Einheit (nachtragen, Tippfehler korrigieren): ohne Uhr und
    /// ohne Pause. Der Haken weg nimmt auch die Zeiten mit, wie beim laufenden Training.
    static func hakenNachtrag(_ saetze: [PlanSatz], _ i: Int) -> [PlanSatz] {
        guard saetze.indices.contains(i) else { return saetze }
        var neu = saetze
        if neu[i].ok == true {
            neu[i].ok = nil
            neu[i].sek = nil
            neu[i].pause = nil
        } else {
            neu[i].ok = true
        }
        return neu
    }

    /// Ein ohne Trainingstag gemachtes Training als neuer, flexibler Tag (ohne Wochentag). Nur Übungen
    /// mit etwas Abgehaktem, Sätze ohne Haken; die Plan-ids bleiben, damit "Vorher" und Rekorde
    /// weiter zu denselben Übungen gehören. nil, wenn nichts abgehakt ist.
    static func alsTag(_ liste: [WorkoutUebung], name: String, id: String = UUID().uuidString) -> TrainingsTag? {
        let gemacht = liste.filter { $0.fertigZahl > 0 }.map { u -> PlanUebung in
            var p = u.planUebung
            if !p.istCardio { p.saetze = u.saetze.map(\.alsPlan) }
            return p
        }
        guard !gemacht.isEmpty else { return nil }
        let titel = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return TrainingsTag(id: id, name: titel.isEmpty ? "Freies Training" : titel, wochentage: [], uebungen: gemacht)
    }

    /// Den Trainingstag darf man wechseln, solange nichts abgehakt ist. Sonst blieben abgehakte
    /// Übungen des alten Tages als Extras im neuen und "Plan aktualisieren" hängte sie an.
    static func tagWechselbar(_ liste: [WorkoutUebung]) -> Bool {
        liste.allSatisfy { $0.fertigZahl == 0 }
    }

    /// Die Läufe der Übungen dieses Tages in der Einheit (beim Wechseln werden sie entfernt).
    static func laeufeDesTages(_ s: GymSession, _ tag: TrainingsTag?) -> [UebungsLauf] {
        let ids = Set(tag?.uebungen.map(\.id) ?? [])
        return s.laeufe.filter { ids.contains($0.plan) }
    }

    /// "1", "2" für normale Sätze (Aufwärmsätze zählen nicht mit), sonst "W", "D", "F".
    static func nummer(_ saetze: [PlanSatz], _ i: Int) -> String {
        guard saetze.indices.contains(i) else { return "" }
        return saetze[i].kuerzel ?? String(saetze[...i].filter { $0.typ != "w" }.count)
    }

    /// Kopie von Satz `i` direkt darunter: gleiche Art, Wdh und kg, ohne Haken und Zeiten.
    static func kopieren(_ saetze: [PlanSatz], _ i: Int) -> [PlanSatz] {
        guard saetze.indices.contains(i) else { return saetze }
        var neu = saetze
        neu.insert(saetze[i].alsPlan, at: i + 1)
        return neu
    }

    /// Pausenziel nach "+15 s" / "−15 s": nie unter 15 Sekunden.
    static func pauseZiel(_ ziel: Int, um sek: Int) -> Int { max(15, ziel + sek) }

    /// Drei Aufwärmsätze aus dem Arbeitsgewicht: 40 % × 10, 60 % × 5, 80 % × 3, auf 2,5 kg gerundet (`AufwaermRechner`).
    static func aufwaermen(arbeit: Double) -> [PlanSatz] { AufwaermRechner.saetze(arbeit: arbeit) }

    /// "32 kg × 12", ohne Gewicht "12 Wdh".
    static func satzText(_ s: PlanSatz) -> String {
        s.kg.map { "\(TrainingLogik.kgText($0)) kg × \(s.wdh)" } ?? String(localized: "\(s.wdh) Wdh")
    }

    /// "Satz 0:42 · Pause 1:58"; "Satz" nur mit Schalter. Gespeicherte Werte bleiben, sie werden nur ausgeblendet.
    static func zeitenText(sek: Double?, pause: Double?, satzzeit: Bool) -> String? {
        let teile = [satzzeit ? sek.map { String(localized: "Satz \(zeitText($0))") } : nil, pause.map { String(localized: "Pause \(zeitText($0))") }].compactMap { $0 }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    /// "1:05".
    static func zeitText(_ sekunden: Double) -> String {
        let s = max(0, Int(sekunden.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "2:00", bei 0 "aus".
    static func pauseText(_ sekunden: Int) -> String {
        sekunden == 0 ? String(localized: "aus") : zeitText(Double(sekunden))
    }
}

/// Anstrengung eines Satzes nach RIR (Wiederholungen, die noch gegangen wären), Stufen wie in openGym.
/// Gespeichert wird als RPE = 10 − RIR in `PlanSatz.rpe`.
enum Anstrengung: CaseIterable, Sendable {
    case versagen, fastVersagen, eineNoch, zweiNoch, dreiNoch, leicht

    var rir: Double {
        switch self {
        case .versagen: 0
        case .fastVersagen: 0.5
        case .eineNoch: 1
        case .zweiNoch: 2
        case .dreiNoch: 3
        case .leicht: 4
        }
    }

    var rpe: Double { 10 - rir }
    var rirText: String { self == .leicht ? "4+" : TrainingLogik.kgText(rir) }

    var titel: String {
        switch self {
        case .versagen: String(localized: "Nichts mehr drin, bis zum Versagen")
        case .fastVersagen: String(localized: "Vielleicht eine halbe Wiederholung übrig")
        case .eineNoch: String(localized: "Eine Wiederholung noch drin")
        case .zweiNoch: String(localized: "Zwei Wiederholungen noch drin")
        case .dreiNoch: String(localized: "Drei Wiederholungen noch drin")
        case .leicht: String(localized: "Leicht, Aufwärm-Bereich")
        }
    }

    /// Die Stufe, in die ein gespeicherter RPE fällt (auch 8,5 aus der alten Eingabe).
    static func stufe(rpe: Double) -> Anstrengung {
        switch 10 - rpe {
        case ...0: .versagen
        case ...0.5: .fastVersagen
        case ...1: .eineNoch
        case ...2: .zweiNoch
        case ...3: .dreiNoch
        default: .leicht
        }
    }
}
