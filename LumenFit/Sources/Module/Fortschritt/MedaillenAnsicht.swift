import Foundation

/// Medaillen derselben Art in Stufen (Bronze, Silber, Gold) statt Einzelkacheln. Die Stufen stehen aufsteigend.
struct MedaillenReihe: Identifiable, Equatable, Sendable {
    let id: String
    let titel: String
    let stufen: [String]
}

enum MedaillenEintrag: Identifiable, Equatable, Sendable {
    case einzel(Meilenstein)
    case reihe(MedaillenReihe, [Meilenstein])

    var id: String {
        switch self {
        case .einzel(let m): m.id
        case .reihe(let r, _): "reihe-\(r.id)"
        }
    }
}

struct MedaillenAbschnitt: Identifiable, Equatable, Sendable {
    let gruppe: MedaillenGruppe
    let eintraege: [MedaillenEintrag]
    var id: String { gruppe.rawValue }
}

/// Was die Meilensteine-Seite zeigt, als Funktion: nach Bereich gruppiert, ausgeschaltete Bereiche weg, Medaillen ohne Ziel weg (erreichte bleiben), Reihen als Stufen.
enum MedaillenAnsicht {
    nonisolated static let reihen: [MedaillenReihe] = [
        MedaillenReihe(id: "gym", titel: "Gym-Tage", stufen: ["gym-10", "gym-50", "gym-100", "gym-200"]),
        MedaillenReihe(id: "volumen", titel: "Gewicht bewegt", stufen: ["volumen-10000", "volumen-50000", "volumen-100000", "volumen-500000"]),
        MedaillenReihe(id: "serie", titel: "Wochen in Folge", stufen: ["serie-4", "serie-12", "serie-26"]),
        MedaillenReihe(id: "wochenziel", titel: "Wochenziel", stufen: ["wochenziel-4", "wochenziel-12", "wochenziel-26"]),
        MedaillenReihe(id: "rekorde", titel: "Rekorde", stufen: ["erster-rekord", "rekorde-10", "rekorde-25"]),
        MedaillenReihe(id: "schlaf", titel: "Schlafziel", stufen: ["schlaf-7", "schlaf-30"]),
        MedaillenReihe(id: "schritte", titel: "Schrittziel", stufen: ["schritte-7", "schritte-30"]),
        MedaillenReihe(id: "protein", titel: "Proteinziel", stufen: ["protein-7", "protein-30"]),
        MedaillenReihe(id: "tagebuch", titel: "Tagebuch", stufen: ["tagebuch-7", "tagebuch-30"]),
    ]

    /// Name der Stufe: zwei Stufen Bronze und Gold, drei dazu Silber, vier dazu Platin zuoberst.
    nonisolated static func stufenName(_ index: Int, von anzahl: Int) -> String {
        let namen: [String]
        switch anzahl {
        case ...2: namen = ["Bronze", "Gold"]
        case 3: namen = ["Bronze", "Silber", "Gold"]
        default: namen = ["Bronze", "Silber", "Gold", "Platin"]
        }
        return namen[min(max(index, 0), namen.count - 1)]
    }

    /// Alles, was die Seite zeigt. `ohneZiel`: Medaillen, deren Ziel fehlt (nur erreichte bleiben sichtbar).
    nonisolated static func abschnitte(zeigt: (AppBereich) -> Bool, erreicht: Set<String>, ohneZiel: Set<String> = []) -> [MedaillenAbschnitt] {
        let sichtbar = MeilensteinKatalog.alle.filter { m in
            (m.gruppe.bereich.map(zeigt) ?? true) && (!ohneZiel.contains(m.id) || erreicht.contains(m.id))
        }
        let nachId = Dictionary(uniqueKeysWithValues: sichtbar.map { ($0.id, $0) })
        var reiheVon: [String: MedaillenReihe] = [:]
        for r in reihen { for id in r.stufen { reiheVon[id] = r } }
        return MedaillenGruppe.allCases.compactMap { gruppe in
            var eintraege: [MedaillenEintrag] = []
            var gesehen: Set<String> = []
            for m in sichtbar where m.gruppe == gruppe {
                guard let reihe = reiheVon[m.id] else { eintraege.append(.einzel(m)); continue }
                guard gesehen.insert(reihe.id).inserted else { continue }
                let stufen = reihe.stufen.compactMap { nachId[$0] }
                eintraege.append(stufen.count > 1 ? .reihe(reihe, stufen) : .einzel(m))
            }
            return eintraege.isEmpty ? nil : MedaillenAbschnitt(gruppe: gruppe, eintraege: eintraege)
        }
    }

    /// "5 von 31": erreichte und sichtbare Medaillen, nur was die Seite zeigt.
    nonisolated static func zaehlung(_ abschnitte: [MedaillenAbschnitt], erreicht: Set<String>) -> (erreicht: Int, gesamt: Int) {
        let ids = abschnitte.flatMap { a in
            a.eintraege.flatMap { e -> [String] in
                switch e {
                case .einzel(let m): [m.id]
                case .reihe(_, let ms): ms.map(\.id)
                }
            }
        }
        return (ids.filter(erreicht.contains).count, ids.count)
    }
}
