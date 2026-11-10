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

    /// Die Zeilen für Heute (Schritte, Gym, Essen), Schlaf, Essen oder Gym. Eine Zeile gibt es nur, wenn die Art freigegeben ist und der Wert in der Datei steht.
    static func zeilen(_ datei: ZusammenfassungDatei, bereich: PartnerBereich) -> [Zeile] {
        let frei = Set(datei.freigaben)
        var liste: [Zeile] = []
        switch bereich {
        case .heute:
            if frei.contains(.schritte), let s = datei.heute.schritte {
                liste.append(Zeile(titel: String(localized: "Schritte"), wert: s.formatted(), symbol: "figure.walk"))
            }
            if frei.contains(.gym), let g = datei.heute.gymTageWoche {
                liste.append(Zeile(titel: String(localized: "Gym diese Woche"), wert: g == 1 ? String(localized: "1 Tag") : String(localized: "\(g) Tage"), symbol: "dumbbell.fill"))
            }
            if frei.contains(.essen), let k = datei.heute.kcal {
                liste.append(Zeile(titel: String(localized: "Essen"), wert: "\(k.formatted()) kcal", symbol: "fork.knife"))
            }
            if frei.contains(.stimmung), let s = datei.heute.stimmung {
                liste.append(Zeile(titel: String(localized: "Stimmung"), wert: stimmungText(s), symbol: "face.smiling"))
            }
            if frei.contains(.gewohnheiten), let g = datei.heute.gewohnheiten, !g.isEmpty {
                liste.append(Zeile(titel: String(localized: "Gewohnheiten"), wert: String(localized: "\(g.filter(\.heute).count) von \(g.count) heute"), symbol: "checkmark.circle"))
            }
        case .essen:
            if frei.contains(.essen), let k = datei.heute.kcal {
                liste.append(Zeile(titel: String(localized: "Essen"), wert: "\(k.formatted()) kcal", symbol: "fork.knife"))
            }
        case .gym:
            if frei.contains(.gym), let g = datei.heute.gymTageWoche {
                liste.append(Zeile(titel: String(localized: "Gym diese Woche"), wert: g == 1 ? String(localized: "1 Tag") : String(localized: "\(g) Tage"), symbol: "dumbbell.fill"))
            }
        case .schlaf:
            if frei.contains(.schlaf), let m = datei.heute.schlafMinuten {
                liste.append(Zeile(titel: String(localized: "Schlaf"), wert: schlafText(m), symbol: "bed.double.fill"))
            }
        }
        return liste
    }

    /// Die Zusammenfassung des Partners für Oberflächen, die selbst keinen Stand halten (Demo vor Speicher).
    @MainActor
    static func aktuell(_ umgebung: AppUmgebung) -> ZusammenfassungDatei? {
        zusammenfassung(VerbindenDemo.partner ?? umgebung.daten?.verbindung.partner ?? .nichtVerbunden)
    }

    // MARK: Energie, Gewohnheiten, Wochenwerte (Gleichstand Health)

    /// Der Energie-Rat des Partners: nur mit Freigabe schlaf und bekannter Stufe. Der Gym-Satz zusätzlich nur mit Freigabe gym.
    static func energie(_ datei: ZusammenfassungDatei) -> (titel: String, gym: String?)? {
        guard datei.freigaben.contains(.schlaf), let stufe = datei.heute.energieStufe else { return nil }
        let titel: String
        switch stufe {
        case "hoch": titel = String(localized: "Viel Energie heute")
        case "mittel": titel = String(localized: "Normale Energie")
        case "niedrig": titel = String(localized: "Heute eher wenig Energie")
        default: return nil
        }
        return (titel, datei.freigaben.contains(.gym) ? datei.heute.energieGym : nil)
    }

    /// "Normale Energie, Gym ja" für die Zeile und VoiceOver.
    static func energieSatz(_ datei: ZusammenfassungDatei) -> String? {
        guard let e = energie(datei) else { return nil }
        return [e.titel, e.gym].compactMap { $0 }.joined(separator: ", ")
    }

    /// Hat der Partner diese eingebaute Gewohnheit (`gym`, `wasser`) heute erledigt? Nur mit der Freigabe der Art.
    static func habitFertig(_ datei: ZusammenfassungDatei, id: String) -> Bool {
        let art: FreigabeArt
        switch id {
        case "gym": art = .gym
        case "wasser": art = .essen
        default: return false
        }
        return datei.freigaben.contains(art) && (datei.heute.habitsFertig ?? []).contains(id)
    }

    /// Tage der Woche mit Gym beim Partner (leer ohne Freigabe gym).
    static func gymTage(_ datei: ZusammenfassungDatei) -> Set<String> {
        datei.freigaben.contains(.gym) ? Set(datei.heute.gymTage ?? []) : []
    }

    /// Die Antwort auf den Morgen-Check in Worten (1 schwer bis 5 top).
    static func stimmungText(_ wert: Int) -> String {
        switch wert {
        case ...1: String(localized: "Schwer")
        case 2: String(localized: "Müde")
        case 3: String(localized: "Okay")
        case 4: String(localized: "Gut")
        default: String(localized: "Top")
        }
    }

    /// Dieselbe Gewohnheit beim Partner: zuerst gleiche Kennung (Gym, Wasser), sonst gleicher Name (ohne Groß- und Kleinschreibung). Nur mit Freigabe gewohnheiten.
    static func gewohnheit(_ datei: ZusammenfassungDatei, id: String, name: String) -> GewohnheitStand? {
        guard datei.freigaben.contains(.gewohnheiten), let liste = datei.heute.gewohnheiten else { return nil }
        return liste.first { $0.id == id } ?? liste.first { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    /// "7 h 35 min", "8 h", "45 min".
    static func schlafText(_ minuten: Int) -> String {
        let h = minuten / 60, m = minuten % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}
