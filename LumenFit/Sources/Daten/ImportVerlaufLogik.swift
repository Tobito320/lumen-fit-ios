// Quelle: Lovea Health/HealthModell.swift (schritteOpAnwenden, schlafOpAnwenden, schlafZeitenAnwenden), Lovea Kalender/KalenderModell.swift (stimmung.setzen)
import Foundation

// Leser für die Ops, die der einmalige Lovea-Import ins Log legt: `schritte.setzen`, `schlaf.setzen`, `schlaf.zeiten`, `stimmung.setzen`.
// Reine Faltung ohne Oberfläche; `ImportVerlaufStore` hängt sie an den Raum, `GesundheitsStand` führt das Ergebnis mit Health und Band zusammen.

/// `schritte.setzen {datum, anzahl, km?, etagen?, kcal?, aktivMinuten?, nachgetragen?}` (Lovea, Felder exakt).
struct ImportSchritteD: Codable, Sendable, Equatable {
    var datum: String
    var anzahl: Int
    var km: Double?
    var etagen: Int?
    var kcal: Int?
    var aktivMinuten: Int?
}

/// `schlaf.setzen {datum, minuten, von, bis, quelle?}`; `von` und `bis` sind ISO-8601-Text, `datum` der Aufwachtag.
struct ImportSchlafD: Codable, Sendable, Equatable {
    var datum: String
    var minuten: Int
    var von: String
    var bis: String
    var quelle: String?
}

/// `stimmung.setzen {datum, stimmung, brauche?, satz?, teil?}`; `stimmung` ist "gut", "mittel" oder "schlecht".
struct ImportStimmungD: Codable, Sendable, Equatable {
    var datum: String
    var stimmung: String
    var brauche: String?
    var satz: String?
    var teil: Bool?
}

/// Was Lumen Fit schreibt, wenn die Stimmung eines Tages gesetzt wird: dieselbe Teil-Op wie Lovea (`teil`, "Brauche" und Satz bleiben).
struct StimmungSetzenD: Codable, Sendable, Equatable {
    var datum: String
    var stimmung: String
    var teil: Bool = true
}

/// Die Stimmung eines Tages in drei Stufen (Lovea: "gut", "mittel", "schlecht").
enum StimmungStufe: String, CaseIterable, Sendable {
    case schlecht, mittel, gut

    var name: String {
        switch self {
        case .schlecht: "Mies"
        case .mittel: "Geht so"
        case .gut: "Richtig gut"
        }
    }

    var symbolName: String {
        switch self {
        case .schlecht: "cloud.rain.fill"
        case .mittel: "cloud.fill"
        case .gut: "sun.max.fill"
        }
    }

    /// 1 bis 3, für das Diagramm.
    var wert: Int {
        switch self {
        case .schlecht: 1
        case .mittel: 2
        case .gut: 3
        }
    }
}

struct ImportSchritteTag: Equatable, Sendable {
    var anzahl: Int
    var meter: Double
    var etagen: Int
    var kcal: Double
    var aktivMinuten: Int
}

struct ImportStimmung: Equatable, Sendable {
    /// Der Rohtext der Op; `stufe` ist nil bei einem Text, den Lumen Fit nicht kennt.
    var roh: String
    var brauche: String?
    var satz: String?

    var stufe: StimmungStufe? { StimmungStufe(rawValue: roh) }
}

/// Alles, was die vier Arten ergeben: je Tag der Stand der neuesten Op (bei gleicher Zeit gewinnt die später ins Log gekommene).
struct ImportVerlaufStand: Equatable, Sendable {
    var schritte: [String: ImportSchritteTag] = [:]
    /// `schlaf.setzen`: die automatisch erkannte Nacht je Aufwachtag, schon als `SchlafNacht` gebaut (die Zusammenführung liest bei jedem Zugriff).
    var schlafAutomatik: [String: SchlafNacht] = [:]
    /// `schlaf.zeiten`: die von Hand eingetragene Nacht je Aufwachtag.
    var schlafEigen: [String: SchlafNacht] = [:]
    /// Tage, an denen ein eigener Eintrag auf 0 Minuten gesetzt wurde (gelöscht): sperrt die Nacht, auch gegen Health.
    var schlafGesperrt: Set<String> = []
    var stimmung: [String: ImportStimmung] = [:]
    /// Zeit der Op, die den Wert je Schlüssel ("art|tag") gesetzt hat.
    fileprivate var zeiten: [String: Date] = [:]
}

enum ImportVerlaufLogik {
    nonisolated static let arten: Set<String> = ["schritte.setzen", "schlaf.setzen", "schlaf.zeiten", "stimmung.setzen"]

    // MARK: - Falten

    /// Nimmt eine Op auf. Ältere Ops als der schon gesetzte Wert des Tages ändern nichts; unlesbare Ops und kaputte Tage werden übersprungen.
    static func nimmAuf(_ op: Op, in stand: inout ImportVerlaufStand) {
        switch op.art {
        case "schritte.setzen":
            guard let d = op.daten(ImportSchritteD.self), neuer(&stand, op, d.datum) else { return }
            stand.schritte[d.datum] = ImportSchritteTag(anzahl: max(0, d.anzahl), meter: max(0, ((d.km ?? 0) * 1000).rounded()), etagen: max(0, d.etagen ?? 0),
                                                        kcal: Double(max(0, d.kcal ?? 0)), aktivMinuten: max(0, d.aktivMinuten ?? 0))
        case "schlaf.setzen":
            // Ohne lesbare Zeiten bleibt die Op außen vor (wie in Lovea).
            guard let d = op.daten(ImportSchlafD.self), let von = isoDatum(d.von), let bis = isoDatum(d.bis), neuer(&stand, op, d.datum) else { return }
            stand.schlafAutomatik[d.datum] = nacht(tag: d.datum, minuten: d.minuten, von: von, bis: bis)
        case "schlaf.zeiten":
            guard let d = op.daten(SchlafZeitenD.self), neuer(&stand, op, d.datum) else { return }
            // Nur die Uhrzeiten zählen (der Wähler behält das Datum, mit dem er begann); `auf` ist der Aufwachzeitpunkt.
            let minuten = EnergieLogik.imBett(d)
            stand.schlafEigen[d.datum] = nacht(tag: d.datum, minuten: minuten, von: d.auf.addingTimeInterval(-Double(minuten) * 60), bis: d.auf)
            if minuten > 0 { stand.schlafGesperrt.remove(d.datum) } else { stand.schlafGesperrt.insert(d.datum) }
        case "stimmung.setzen":
            guard let d = op.daten(ImportStimmungD.self), neuer(&stand, op, d.datum) else { return }
            // `teil`: fehlende Felder bleiben wie im Eintrag des Tages; ohne `teil` ersetzt die Op den Eintrag (Lovea KalenderModell).
            let alt = d.teil == true ? stand.stimmung[d.datum] : nil
            stand.stimmung[d.datum] = ImportStimmung(roh: d.stimmung, brauche: d.brauche ?? alt?.brauche, satz: d.satz ?? alt?.satz)
        default:
            break
        }
    }

    /// Gültiger Tag und nicht älter als der gesetzte Wert; merkt sich die Zeit.
    private static func neuer(_ stand: inout ImportVerlaufStand, _ op: Op, _ tag: String) -> Bool {
        guard SchlafNachtLogik.gueltigerTag(tag) else { return false }
        let schluessel = "\(op.art)|\(tag)"
        if let alt = stand.zeiten[schluessel], alt > op.zeit { return false }
        stand.zeiten[schluessel] = op.zeit
        return true
    }

    // MARK: - Zusammenführen

    /// Schritte, Meter, Etagen, aktive Energie und Trainingsminuten: je Tag das Maximum aus Health/Band und Import, nie die Summe
    /// (alle zählen dieselben Schritte). So füllt der Import die Tage vor den 60 Tagen, die Health liefert.
    static func tage(_ tage: [String: TagesWerte], stand: ImportVerlaufStand) -> [String: TagesWerte] {
        guard !stand.schritte.isEmpty else { return tage }
        var ergebnis = tage
        for (tag, s) in stand.schritte {
            var t = ergebnis[tag] ?? TagesWerte(tag: tag)
            t.schritte = max(t.schritte, s.anzahl)
            t.distanzMeter = max(t.distanzMeter, s.meter)
            t.etagen = max(t.etagen, s.etagen)
            t.aktiveKcal = max(t.aktiveKcal, s.kcal)
            t.trainingMinuten = max(t.trainingMinuten, s.aktivMinuten)
            ergebnis[tag] = t
        }
        return ergebnis
    }

    /// Nächte nach Loveas Vorrang (`schlafMinuten`): ein eigener Eintrag zuerst (auch ein gelöschter mit 0 Minuten sperrt die Nacht),
    /// dann Health, und die importierte automatische Nacht füllt nur Tage, an denen Health nichts hat.
    static func naechte(health: [String: SchlafNacht], stand: ImportVerlaufStand) -> [String: SchlafNacht] {
        guard !stand.schlafAutomatik.isEmpty || !stand.schlafEigen.isEmpty || !stand.schlafGesperrt.isEmpty else { return health }
        var ergebnis = stand.schlafAutomatik
        ergebnis.merge(health) { _, h in h }
        ergebnis.merge(stand.schlafEigen) { _, e in e }
        for tag in stand.schlafGesperrt { ergebnis[tag] = nil }
        return ergebnis
    }

    /// Eine Nacht ohne Phasen: ein Abschnitt "Schlaf" von `minuten`, davor die übrige Zeit als wach, damit die Abschnitte lückenlos sind und die
    /// Schlaf-Abschnitte zu `schlafMinuten` passen. nil ohne Minuten oder mit Ende vor Beginn.
    // shortcut: die Wachzeit steht am Anfang (Einschlafen); wo sie wirklich lag, sagt `schlaf.setzen` nicht. Mit Phasen aus Health wäre sie genau.
    static func nacht(tag: String, minuten: Int, von: Date, bis: Date) -> SchlafNacht? {
        guard minuten > 0, bis > von else { return nil }
        let schlafBeginn = max(von, bis.addingTimeInterval(-Double(minuten) * 60))
        var abschnitte = [SchlafAbschnitt(phase: .unbestimmt, von: schlafBeginn, bis: bis)]
        if schlafBeginn > von { abschnitte.insert(SchlafAbschnitt(phase: .wach, von: von, bis: schlafBeginn), at: 0) }
        return SchlafNacht(tag: tag, von: von, bis: bis, abschnitte: abschnitte, schlafMinuten: minuten)
    }

    // MARK: - Stimmung

    struct StimmungPunkt: Equatable, Sendable {
        var tag: String
        var stufe: StimmungStufe
    }

    /// Die letzten `anzahl` Tage bis einschließlich `heute`, nur Tage mit bekannter Stufe, ältester zuerst.
    static func stimmungReihe(_ stand: ImportVerlaufStand, heute: String, anzahl: Int = 14) -> [StimmungPunkt] {
        (0..<max(0, anzahl)).reversed().compactMap { zurueck in
            let tag = Datum.addTage(heute, -zurueck)
            return stand.stimmung[tag]?.stufe.map { StimmungPunkt(tag: tag, stufe: $0) }
        }
    }

    /// Eine Zeile fürs Diagramm und VoiceOver: wie oft welche Stufe, sonst ein Hinweis.
    static func stimmungAussage(_ reihe: [StimmungPunkt]) -> String {
        guard !reihe.isEmpty else { return "Noch keine Stimmung eingetragen" }
        let teile = StimmungStufe.allCases.reversed().compactMap { stufe -> String? in
            let n = reihe.filter { $0.stufe == stufe }.count
            return n > 0 ? "\(n) mal \(stufe.name.lowercased())" : nil
        }
        return "Letzte \(reihe.count) Einträge: " + teile.joined(separator: ", ")
    }

    // MARK: - Zeit

    // shortcut: zwei geteilte Formatierer wie in `Op`; ISO8601DateFormatter ist threadsicher, `nonisolated(unsafe)` nur wegen der fehlenden Sendable-Marke.
    private nonisolated(unsafe) static let isoFraktional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private nonisolated(unsafe) static let isoGanz = ISO8601DateFormatter()

    static func isoDatum(_ text: String) -> Date? {
        isoFraktional.date(from: text) ?? isoGanz.date(from: text)
    }
}
