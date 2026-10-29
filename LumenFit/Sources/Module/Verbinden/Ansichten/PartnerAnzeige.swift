import Foundation

/// Was die Partner-Karte zeigt (Idee 82): nur Felder, die der Partner freigegeben hat und die in der Datei stehen, und nur im Stand `verbunden`.
/// Sonst nichts, nicht einmal einen Platzhalter. Rein und ohne Oberfläche testbar.
enum PartnerAnzeige {
    struct Zeile: Identifiable, Equatable, Sendable {
        var titel: String
        var wert: String
        var symbol: String
        var id: String { titel }
    }

    /// Die Zusammenfassung nur im Stand `verbunden` (veraltet, unbekannte Version und nicht verbunden zeigen nichts).
    static func zusammenfassung(_ stand: PartnerStand) -> ZusammenfassungDatei? {
        if case .verbunden(let datei) = stand { datei } else { nil }
    }

    /// Die Zeilen für Heute (Schritte, Gym, Essen) oder Schlaf. Eine Zeile gibt es nur, wenn die Art freigegeben ist und der Wert in der Datei steht.
    static func zeilen(_ datei: ZusammenfassungDatei, bereich: PartnerBereich) -> [Zeile] {
        let frei = Set(datei.freigaben)
        var liste: [Zeile] = []
        switch bereich {
        case .heute:
            if frei.contains(.schritte), let s = datei.heute.schritte {
                liste.append(Zeile(titel: "Schritte", wert: s.formatted(), symbol: "figure.walk"))
            }
            if frei.contains(.gym), let g = datei.heute.gymTageWoche {
                liste.append(Zeile(titel: "Gym diese Woche", wert: g == 1 ? "1 Tag" : "\(g) Tage", symbol: "dumbbell.fill"))
            }
            if frei.contains(.essen), let k = datei.heute.kcal {
                liste.append(Zeile(titel: "Essen", wert: "\(k.formatted()) kcal", symbol: "fork.knife"))
            }
        case .schlaf:
            if frei.contains(.schlaf), let m = datei.heute.schlafMinuten {
                liste.append(Zeile(titel: "Schlaf", wert: schlafText(m), symbol: "bed.double.fill"))
            }
        }
        return liste
    }

    /// "7 h 35 min", "8 h", "45 min".
    static func schlafText(_ minuten: Int) -> String {
        let h = minuten / 60, m = minuten % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}
