import Foundation

/// Ein neuer Rekord einer Person aus der Crew: Übung, Gewicht in kg, Wiederholungen, Tag.
struct PinnwandRekord: Equatable, Sendable {
    var name: String
    var uebung: String
    var kg: Double
    var wdh: Int
    var tag: String
}

enum GymRekordPinnwandLogik {
    nonisolated static let zeilenMax = 5
    nonisolated static let tage = 14

    /// Je Übung der beste Arbeitssatz (ohne `w`, `d`, mit Gewicht) der letzten 14 Tage; Rekord, wenn sein geschätztes 1RM (`RekordLogik.e1rm`, Epley) höher ist
    /// als jeder Satz aus Einheiten davor. Ohne frühere Einheit kein Rekord. Übungen gelten gleich bei gleichem Namen ohne Klammerzusatz, ohne Groß/Klein.
    /// Rechnet nur mit den Einheiten, die die Person mitschickt (höchstens 30), und nur mit Freigabe gym und verlauf.
    static func rekorde(_ datei: ZusammenfassungDatei, name: String? = nil, jetzt: Date) -> [PinnwandRekord] {
        guard datei.freigaben.contains(.gym), datei.freigaben.contains(.verlauf), let einheiten = datei.heute.verlauf?.einheiten else { return [] }
        let ab = Datum.addTage(Datum.text(jetzt), -tage)
        struct Treffer { var e1rm: Double; var anzeige: String; var satz: PartnerSatzKurz; var tag: String }
        var alle: [String: [Treffer]] = [:]
        for einheit in einheiten {
            for u in einheit.uebungen {
                for s in u.saetze where s.typ != "w" && s.typ != "d" {
                    guard let e = RekordLogik.e1rm(GymPartnerLogik.satz(s)) else { continue }
                    alle[normal(u.name), default: []].append(Treffer(e1rm: e, anzeige: anzeige(u.name), satz: s, tag: einheit.tag))
                }
            }
        }
        return alle.values.compactMap { treffer -> PinnwandRekord? in
            guard let best = treffer.filter({ $0.tag >= ab }).max(by: { ($0.e1rm, $0.tag) < ($1.e1rm, $1.tag) }),
                  let davor = treffer.filter({ $0.tag < best.tag }).map(\.e1rm).max(), best.e1rm > davor, let kg = best.satz.kg else { return nil }
            return PinnwandRekord(name: name ?? datei.profilName, uebung: best.anzeige, kg: Double(kg) / 10, wdh: best.satz.wdh, tag: best.tag)
        }
    }

    /// Die Pinnwand der Crew: aktive, nicht pausierte Personen, neueste Rekorde zuerst, höchstens fünf.
    static func pinnwand(eintraege: [VerbindungEintrag], jetzt: Date) -> [PinnwandRekord] {
        var gesehen: Set<String> = []
        let alle = eintraege.filter { $0.aktiv && !$0.ich.pause && gesehen.insert($0.id).inserted }.flatMap { e -> [PinnwandRekord] in
            guard let d = e.daten else { return [] }
            return rekorde(d, name: e.anzeigeName.isEmpty ? d.profilName : e.anzeigeName, jetzt: jetzt)
        }
        // Neueste zuerst; bei gleichem Tag nach Name, damit die Reihenfolge nicht vom Zufall abhängt.
        let sortiert = alle.sorted { $0.tag != $1.tag ? $0.tag > $1.tag : ($0.name, $0.uebung) < ($1.name, $1.uebung) }
        return Array(sortiert.prefix(zeilenMax))
    }

    /// "Kniebeuge 120 kg × 5 · vor 2 Tagen"
    static func text(_ r: PinnwandRekord, heute: String) -> String {
        let n = Datum.tageZwischen(r.tag, heute)
        let wann = n <= 0 ? "heute" : n == 1 ? "gestern" : "vor \(n) Tagen"
        return "\(r.uebung) \(TrainingLogik.kgText(r.kg)) kg × \(r.wdh) · \(wann)"
    }

    private static func anzeige(_ name: String) -> String {
        name.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normal(_ name: String) -> String { anzeige(name).lowercased() }
}
