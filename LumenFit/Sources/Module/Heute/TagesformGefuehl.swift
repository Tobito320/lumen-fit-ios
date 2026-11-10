// Quelle: Lovea Health/Heute/Tagesform/TagesformGefuehl.swift
import Foundation
import Observation

// Das eigene Gefühl (1 bis 5) zum Tag, mit einem Antippen gespeichert. Dazu kommt, was die Rechnung damals sah
// (Rohwerte und Zahl), damit sich später vergleichen und mit anderen Gewichten nachstellen lässt.

struct TagesformEintrag: Codable, Equatable, Sendable, Identifiable {
    var tag: String
    /// 1 = leer bis 5 = voll.
    var gefuehl: Int
    /// Die Zahl von damals; nil, wenn es zu wenig Daten gab.
    var akku: Int?
    /// `TagesformRechnung.version` zur Zeit des Speicherns.
    var formel: Int
    var eingabe: TagesformEingabe
    var gespeichert: Date

    var id: String { tag }
}

/// Wie weit Rechnung und Gefühl in den letzten Einträgen auseinanderliegen.
struct TagesformVergleich: Equatable, Sendable {
    /// Mittel der Abweichungen in Punkten: positiv = die Rechnung liegt über dem Gefühl.
    var schnitt: Double
    var anzahl: Int
}

enum TagesformGefuehl {
    // Eine Datei im Profilordner (`tagesform-gefuehl.json`) statt der Einstellungen: mit den Rohwerten sind es bis zu 300 KB.
    static let dateiname = "tagesform-gefuehl.json"
    static let behalten = 120
    static let namen = [String(localized: "Leer"), String(localized: "Schwach"), String(localized: "Mittel"), String(localized: "Gut"), String(localized: "Voll")]
    /// Welche Zahl ein Gefühl bedeutet, passend zu den Urteilen der Karte (unter 50 Sparmodus, ab 70 gut, ab 85 voll).
    static let zielwerte = [20, 40, 60, 78, 92]
    /// Ab so vielen Einträgen gibt es einen Vergleich, über die letzten so vielen.
    static let mindestFuerVergleich = 3
    static let letzteFuerVergleich = 7
    /// Bis zu dieser mittleren Abweichung (Punkte) sagt die App, dass die Rechnung passt.
    static let passtBis = 8.0

    static func stufe(_ gefuehl: Int) -> Int { min(5, max(1, gefuehl)) }

    static func name(_ gefuehl: Int) -> String { namen[stufe(gefuehl) - 1] }

    static func zielwert(_ gefuehl: Int) -> Int { zielwerte[stufe(gefuehl) - 1] }

    /// Rechnung minus Gefühl in Punkten; nil, wenn es damals keine Zahl gab.
    static func abweichung(_ eintrag: TagesformEintrag) -> Int? {
        eintrag.akku.map { $0 - zielwert(eintrag.gefuehl) }
    }

    /// Ein Eintrag je Tag (der neue ersetzt den alten), nach Tag sortiert, die letzten `behalten`.
    static func einsetzen(_ liste: [TagesformEintrag], _ neu: TagesformEintrag) -> [TagesformEintrag] {
        let ohne: [TagesformEintrag] = liste.filter { $0.tag != neu.tag }
        let alle: [TagesformEintrag] = (ohne + [neu]).sorted { $0.tag < $1.tag }
        return Array(alle.suffix(behalten))
    }

    /// Die letzten Einträge bis einschließlich `tag`, die eine Zahl hatten. nil unter `mindestFuerVergleich`.
    static func vergleich(_ liste: [TagesformEintrag], bis tag: String) -> TagesformVergleich? {
        let neueste: [TagesformEintrag] = liste.filter { $0.tag <= tag }.sorted { $0.tag > $1.tag }
        var abweichungen: [Double] = []
        for e in neueste {
            guard abweichungen.count < letzteFuerVergleich else { break }
            if let a = abweichung(e) { abweichungen.append(Double(a)) }
        }
        guard abweichungen.count >= mindestFuerVergleich else { return nil }
        return TagesformVergleich(schnitt: abweichungen.reduce(0, +) / Double(abweichungen.count), anzahl: abweichungen.count)
    }

    /// Die Rechnung von damals mit den heutigen Gewichten und Regeln. Weicht sie von `eintrag.akku` ab, hat sich die Formel geändert.
    static func nachgestellt(_ eintrag: TagesformEintrag) -> TagesformErgebnis {
        TagesformRechnung.rechnen(eintrag.eingabe)
    }

    // MARK: Speicher

    /// Liest Eintrag für Eintrag: ein kaputter (neuere Fassung, halb geschrieben) kostet nicht alle anderen.
    private struct Lesbar: Decodable {
        let eintrag: TagesformEintrag?
        init(from decoder: Decoder) throws { eintrag = try? TagesformEintrag(from: decoder) }
    }

    static func laden(_ datei: URL) -> [TagesformEintrag] {
        guard let daten = try? Data(contentsOf: datei),
              let roh = try? JSONDecoder().decode([Lesbar].self, from: daten) else { return [] }
        return roh.compactMap { $0.eintrag }
    }

    static func speichern(_ liste: [TagesformEintrag], in datei: URL) {
        guard let daten = try? JSONEncoder().encode(liste) else { return }
        try? FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: datei, options: .atomic)
    }
}

/// Hält die Einträge im Speicher, damit die Karte sie nicht bei jedem Aufbau neu liest.
@MainActor
@Observable
final class TagesformSpeicher {
    private(set) var eintraege: [TagesformEintrag]
    private let datei: URL

    init(datei: URL) {
        self.datei = datei
        eintraege = TagesformGefuehl.laden(datei)
    }

    func eintrag(_ tag: String) -> TagesformEintrag? {
        eintraege.first { $0.tag == tag }
    }

    func setzen(_ neu: TagesformEintrag) {
        eintraege = TagesformGefuehl.einsetzen(TagesformGefuehl.laden(datei), neu)   // von der Platte: der Lovea-Import kann Tage dazugelegt haben
        TagesformGefuehl.speichern(eintraege, in: datei)
    }
}
