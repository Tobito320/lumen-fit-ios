import Foundation

/// Idee 58, Erholung in einfacher Sprache: ein bis drei kurze Sätze, rein aus Regeln (kein Modell, kein Netz).
/// Auf Wunsch erklärt der Coach es weiter (`coachFrage`).
///
/// Regeln:
/// 1. Die HRV gegen deinen Schnitt trägt den Kern. 5 Prozent darüber: bereit. 5 Prozent darunter: normal, bei Lage unter deinem Bereich: schonen.
/// 2. Ein Ruhepuls mehr als 5 Prozent über deinem Schnitt und über deinem Bereich nimmt "bereit" zurück auf "normal".
/// 3. Eine Nacht unter 6 Stunden nimmt "bereit" zurück auf "normal".
/// 4. Ohne HRV und Ruhepuls zählt nur die Nacht gegen dein Ziel. Ohne alles: "offen", kein erfundener Wert.
enum ErholungsKlartext {
    enum Stufe: Int, Comparable, Sendable {
        case bereit, normal, schonen, offen

        static func < (a: Stufe, b: Stufe) -> Bool { a.rawValue < b.rawValue }

        var name: String {
            switch self {
            case .bereit: "Bereit"
            case .normal: "Normal"
            case .schonen: "Schonen"
            case .offen: "Offen"
            }
        }

        var symbolName: String {
            switch self {
            case .bereit: "bolt.heart.fill"
            case .normal: "figure.mind.and.body"
            case .schonen: "moon.zzz.fill"
            case .offen: "waveform.path.ecg"
            }
        }

        /// Lumi ist nur beim Schonen müde.
        var lumi: LumiStimmung { self == .schonen ? .muede : .bereit }

        /// Mindestens "normal", wenn die Stufe besser war.
        fileprivate var hoechstensNormal: Stufe { self == .bereit ? .normal : self }
    }

    struct Ergebnis: Equatable, Sendable {
        let stufe: Stufe
        let satz: String

        /// Frage an den Coach, mit dem Satz als Grundlage.
        var coachFrage: String { "Erkläre mir bitte in einfachen Worten meine Erholung heute. Die App sagt: \(satz)" }
    }

    /// Schwelle in Prozent für "darüber" und "darunter".
    static let schwelleProzent = 5
    /// Unter 6 Stunden gilt eine Nacht als kurz.
    static let kurzeNacht = 360

    static func bewerte(hrv: PersoenlicherBereich?, ruhepuls: PersoenlicherBereich?, letzteNachtMinuten: Int?, ziel: Int) -> Ergebnis {
        var stufe: Stufe?
        var saetze: [String] = []
        if let hrv {
            let p = hrv.abweichungProzent
            if p >= schwelleProzent {
                stufe = .bereit
                saetze.append("Deine HRV liegt \(p) Prozent über deinem Schnitt, du bist bereit.")
            } else if p <= -schwelleProzent {
                if hrv.lage == .niedrig {
                    stufe = .schonen
                    saetze.append("Deine HRV liegt \(-p) Prozent unter deinem Schnitt. Heute lieber locker.")
                } else {
                    stufe = .normal
                    saetze.append("Deine HRV liegt \(-p) Prozent unter deinem Schnitt, aber noch in deinem Bereich. Hör auf dein Gefühl.")
                }
            } else {
                stufe = .normal
                saetze.append("Deine HRV liegt nah an deinem Schnitt. Ein ganz normaler Tag.")
            }
        }
        if let ruhepuls, ruhepuls.lage == .hoch, ruhepuls.abweichungProzent >= schwelleProzent {
            if hrv != nil {
                saetze.append("Dein Ruhepuls ist höher als sonst.")
                stufe = stufe?.hoechstensNormal
            } else {
                stufe = .normal
                saetze.append("Dein Ruhepuls liegt \(ruhepuls.abweichungProzent) Prozent über deinem Schnitt. Geh den Tag etwas ruhiger an.")
            }
        }
        if let nacht = letzteNachtMinuten {
            if let aktuell = stufe {
                if nacht < kurzeNacht {
                    saetze.append("Die Nacht war kurz.")
                    stufe = aktuell.hoechstensNormal
                }
            } else if nacht < kurzeNacht {
                stufe = .schonen
                saetze.append("Die Nacht war kurz. Geh den Tag ruhig an.")
            } else if ziel > 0, nacht >= ziel {
                stufe = .bereit
                saetze.append("Du hast dein Schlafziel erreicht.")
            } else {
                stufe = .normal
                saetze.append("Etwas weniger Schlaf als geplant, sonst gibt es noch nichts Auffälliges.")
            }
        }
        guard let stufe else {
            return Ergebnis(stufe: .offen, satz: "Für eine Einschätzung fehlen noch Werte. Eine Apple Watch liefert HRV und Ruhepuls.")
        }
        return Ergebnis(stufe: stufe, satz: saetze.joined(separator: " "))
    }
}
