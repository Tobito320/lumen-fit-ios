import Foundation

/// Das Konstanz-Raster (Idee 35): 18 Wochen mal 7 Tage in vier Stufen. Jede Stufe hat ein Muster und eine Zahl, die Farbe trägt nie allein.
enum KonstanzRaster {
    static let wochen = 18

    /// 0 kein Training, 1 Besuch ohne Sätze (nur Gym-Häkchen oder Einheit ohne gezählten Satz), 2 Training, 3 starkes Training (ab `starkAb` Sätzen oder zwei Einheiten).
    enum Stufe: Int, CaseIterable, Sendable {
        case kein = 0, besuch, training, stark

        var name: String {
            switch self {
            case .kein: String(localized: "Kein Training")
            case .besuch: String(localized: "Besuch")
            case .training: String(localized: "Training")
            case .stark: String(localized: "Starkes Training")
            }
        }
    }

    /// Ab so vielen gezählten Sätzen an einem Tag gilt das Training als stark.
    static let starkAb = 16

    struct Zelle: Equatable, Identifiable, Sendable {
        let tag: String
        let stufe: Stufe
        let saetze: Int
        let zukunft: Bool
        var id: String { tag }

        /// "Montag, 12. Oktober: Training, 14 Sätze" für VoiceOver.
        var sprechtext: String {
            if zukunft { return String(localized: "\(Datum.anzeige(tag)): noch nicht dran") }
            switch stufe {
            case .kein: return String(localized: "\(Datum.anzeige(tag)): kein Training")
            case .besuch: return String(localized: "\(Datum.anzeige(tag)): Besuch ohne Sätze")
            case .training, .stark: return String(localized: "\(Datum.anzeige(tag)): \(stufe.name), \(saetze) Sätze")
            }
        }
    }

    /// Die Spalten sind Wochen (älteste links), jede Spalte hat sieben Zellen Mo bis So. Die letzte Spalte ist die Woche von `heute`.
    struct Gitter: Equatable, Sendable {
        let spalten: [[Zelle]]

        var zellen: [Zelle] { spalten.flatMap { $0 } }
        /// Tage mit mindestens einem Besuch oder Training.
        var trainingstage: Int { zellen.filter { $0.stufe != .kein }.count }
        /// Wochen mit mindestens einem Training.
        var aktiveWochen: Int { spalten.filter { $0.contains { $0.stufe != .kein } }.count }
    }

    /// Gezählte Sätze eines fertigen Laufs ohne Aufwärmen (auch ohne Gewicht: Körpergewicht zählt).
    static func gezaehlteSaetze(_ lauf: UebungsLauf) -> Int {
        lauf.fertig ? (lauf.saetze ?? []).filter { $0.typ != "w" }.count : 0
    }

    static func stufe(saetze: Int, einheiten: Int, besuch: Bool) -> Stufe {
        if saetze >= starkAb || (einheiten >= 2 && saetze > 0) { return .stark }
        if saetze > 0 { return .training }
        return einheiten > 0 || besuch ? .besuch : .kein
    }

    /// `gym`: Tag zu Wert der Gym-Gewohnheit (über 0 = abgehakt).
    static func gitter(_ sessions: [GymSession], gym: [String: Int], heute: String) -> Gitter {
        let montag = Datum.montagDerWoche(heute)
        let start = Datum.addTage(montag, -7 * (wochen - 1))
        var einheiten: [String: Int] = [:]
        var saetze: [String: Int] = [:]
        for s in sessions {
            let tag = Datum.text(s.start)
            einheiten[tag, default: 0] += 1
            saetze[tag, default: 0] += s.laeufe.reduce(0) { $0 + gezaehlteSaetze($1) }
        }
        let spalten = (0..<wochen).map { w in
            (0..<7).map { z -> Zelle in
                let tag = Datum.addTage(start, w * 7 + z)
                let n = saetze[tag] ?? 0
                return Zelle(tag: tag, stufe: stufe(saetze: n, einheiten: einheiten[tag] ?? 0, besuch: (gym[tag] ?? 0) > 0),
                             saetze: n, zukunft: tag > heute)
            }
        }
        return Gitter(spalten: spalten)
    }

    /// Die Aussage als Titel: "12 Trainingstage in 18 Wochen" oder der Leerzustand.
    static func aussage(_ g: Gitter) -> String {
        guard g.trainingstage > 0 else { return String(localized: "Noch kein Training in den letzten 18 Wochen") }
        return String(localized: "\(g.trainingstage) \(g.trainingstage == 1 ? String(localized: "Trainingstag") : String(localized: "Trainingstage")) in \(wochen) Wochen")
    }

    /// Die Kernzeile: in wie vielen der Wochen du trainiert hast.
    static func kernzeile(_ g: Gitter) -> String {
        guard g.trainingstage > 0 else { return String(localized: "Tipp auf Starten, Lumi zählt mit.") }
        return String(localized: "In \(g.aktiveWochen) von \(wochen) Wochen warst du dabei.")
    }
}
