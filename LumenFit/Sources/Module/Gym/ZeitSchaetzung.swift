// Quelle: Lovea Health/Zeit/ZeitSchaetzung.swift (plus `umfang`, in Lovea `GymStartLogik.umfang`: dieser Typ gehört dem Grundgerüst); Regel 10 min + 3,5 min je Satz seit 10.11.2026
import Foundation

/// Was die Zeitschätzung dem Tag rät, wenn er über das Studio-Fenster geht.
enum ZeitTipp: Equatable, Sendable {
    /// Zwei Übungen nebeneinander abwechselnd machen: eine Pause statt zwei.
    case supersatz(erste: String, zweite: String, spart: Int)
    /// Die letzten Übungen weglassen.
    case streichen(namen: [String], spart: Int)

    var text: String {
        switch self {
        case let .supersatz(a, b, spart): String(localized: "Tipp: \(a) und \(b) als Supersatz, spart ca. \(spart) min.")
        case let .streichen(namen, spart): String(localized: "Tipp: \(namen.joined(separator: ", ")) weglassen, spart ca. \(spart) min.")
        }
    }
}

/// Schätzung für einen Trainingstag gegen das Zeitfenster des Studios (`slot` nil = kein festes Fenster).
struct ZeitUrteil: Equatable, Sendable {
    var minuten: Int
    var slot: Int?
    var tipp: ZeitTipp?

    var ueber: Int { slot.map { max(0, minuten - $0) } ?? 0 }
    var warnt: Bool { ueber > 0 }

    /// "ca. 52 min, 7 min über deinem Slot (45 min)", "ca. 38 min, passt in deinen Slot (45 min)", "ca. 38 min".
    var titel: String {
        guard let slot else { return String(localized: "ca. \(minuten) min") }
        return warnt ? String(localized: "ca. \(minuten) min, \(ueber) min über deinem Slot (\(slot) min)") : String(localized: "ca. \(minuten) min, passt in deinen Slot (\(slot) min)")
    }
}

/// Dauer eines Trainingstags: 10 min Aufwärmen plus 3,5 min je Satz (Pause und Wechsel inklusive), Cardio-Minuten extra, auf 5 min gerundet.
// ponytail: Die Zahlen sind die Regel aus dem Entwurf (5 Übungen × 3 Sätze = 65 min), nicht gemessen. Im Supersatz
// teilen sich zwei Übungen die Pause: die zweite kostet je Runde nur ihre Arbeit (ca. 1 min).
enum ZeitSchaetzung {
    static let aufwaermSekunden = 600
    static let satzSekunden = 210
    static let supersatzZweiterSekunden = 60
    static let kurzMinuten = 30

    /// Eine Übung allein oder ein Supersatz-Paar (`supersatz` an der ersten). Cardio zählt nie als Paar.
    static func bloecke(_ uebungen: [PlanUebung]) -> [[PlanUebung]] {
        var aus: [[PlanUebung]] = []
        var i = 0
        while i < uebungen.count {
            let u = uebungen[i]
            if u.supersatz == true, !u.istCardio, i + 1 < uebungen.count, !uebungen[i + 1].istCardio {
                aus.append([u, uebungen[i + 1]])
                i += 2
            } else {
                aus.append([u])
                i += 1
            }
        }
        return aus
    }

    /// Sekunden für einen Block ohne Aufwärmen. Paar: je Runde ein voller Satz, die übrigen Sätze nur ihre Arbeit.
    private static func sekunden(_ block: [PlanUebung]) -> Int {
        if block.count == 1, let c = block.first, c.istCardio { return (c.minuten ?? 0) * 60 }
        let runden = block.map { $0.saetze.count }.max() ?? 0
        let saetze = block.reduce(0) { $0 + $1.saetze.count }
        return runden * satzSekunden + (saetze - runden) * supersatzZweiterSekunden
    }

    /// Auf 5 min gerundet (halbe nach oben); etwas Zeit ist mindestens 5 min, nichts ist 0.
    private static func rund(sekunden: Int) -> Int {
        guard sekunden > 0 else { return 0 }
        return max(5, Int((Double(sekunden) / 300).rounded()) * 5)
    }

    /// "6 Übungen · etwa 75 min".
    static func umfang(_ tag: TrainingsTag) -> String {
        let n = tag.uebungen.count, min = minuten(tag)
        return n == 1 ? String(localized: "1 Übung · etwa \(min) min") : String(localized: "\(n) Übungen · etwa \(min) min")
    }

    /// Aufwärmen nur, wenn es Sätze gibt (Cardio allein wärmt selbst auf).
    static func sekunden(_ tag: TrainingsTag) -> Int {
        let aufwaermen = tag.uebungen.contains { !$0.istCardio && !$0.saetze.isEmpty } ? aufwaermSekunden : 0
        return aufwaermen + bloecke(tag.uebungen).reduce(0) { $0 + sekunden($1) }
    }

    /// Auf 5 min gerundet. Leerer Tag: 0.
    static func minuten(_ tag: TrainingsTag) -> Int { rund(sekunden: sekunden(tag)) }

    /// Wie viele Sätze in `minuten` passen (Umkehrung ohne Rundung): 45 min = 10 Sätze.
    static func saetze(inMinuten minuten: Int) -> Int { max(0, (minuten * 60 - aufwaermSekunden) / satzSekunden) }

    /// Kurzversion "Kurz · 30 min": die ersten Übungen (Paare bleiben zusammen), solange die Schätzung höchstens
    /// `kurzMinuten` ergibt; mindestens die erste Übung. Name und id bleiben, damit das Training zum Plantag zählt.
    static func kurzversion(_ tag: TrainingsTag, minuten grenze: Int = kurzMinuten) -> TrainingsTag {
        var kurz = tag
        kurz.uebungen = []
        for block in bloecke(tag.uebungen) {
            var probe = kurz
            probe.uebungen += block
            guard kurz.uebungen.isEmpty || minuten(probe) <= grenze else { break }
            kurz = probe
        }
        return kurz
    }

    /// Das Zeitfenster aus dem Studio-Profil: nur mit fester Uhrzeit (`slotStart`), sonst gibt es nichts zu überschreiten.
    static func slot(_ profil: StudioProfil) -> Int? { profil.slotStart != nil && profil.dauer > 0 ? profil.dauer : nil }

    /// Schätzung und, nur über dem Fenster, ein Vorschlag: erst das Supersatz-Paar, das allein reicht,
    /// sonst die letzten Übungen weglassen.
    static func urteil(_ tag: TrainingsTag, slotMinuten: Int?) -> ZeitUrteil {
        let fenster = (slotMinuten ?? 0) > 0 ? slotMinuten : nil
        let gesamt = sekunden(tag)
        let dauer = rund(sekunden: gesamt)
        guard let fenster, dauer > fenster else { return ZeitUrteil(minuten: dauer, slot: fenster, tipp: nil) }
        return ZeitUrteil(minuten: dauer, slot: fenster, tipp: tipp(tag, gesamt: gesamt, slot: fenster))
    }

    private static func tipp(_ tag: TrainingsTag, gesamt: Int, slot: Int) -> ZeitTipp? {
        let paare = bloecke(tag.uebungen)
        var bestes: (a: PlanUebung, b: PlanUebung, spart: Int)?
        for k in 0..<max(0, paare.count - 1) {
            guard paare[k].count == 1, paare[k + 1].count == 1, !paare[k][0].istCardio, !paare[k + 1][0].istCardio else { continue }
            let a = paare[k][0], b = paare[k + 1][0]
            let spart = sekunden([a]) + sekunden([b]) - sekunden([a, b])
            if spart > (bestes?.spart ?? 0) { bestes = (a, b, spart) }
        }
        if let bestes, rund(sekunden: gesamt - bestes.spart) <= slot {
            return .supersatz(erste: bestes.a.anzeigeName, zweite: bestes.b.anzeigeName,
                              spart: rund(sekunden: gesamt) - rund(sekunden: gesamt - bestes.spart))
        }
        var rest = gesamt
        var namen: [String] = []
        for block in paare.reversed() where rund(sekunden: rest) > slot {
            rest -= sekunden(block)
            namen.insert(contentsOf: block.map(\.anzeigeName), at: 0)
        }
        return namen.isEmpty ? nil : .streichen(namen: namen, spart: rund(sekunden: gesamt) - rund(sekunden: rest))
    }
}
