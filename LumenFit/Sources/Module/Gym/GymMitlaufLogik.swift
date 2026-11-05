import Foundation

/// Der letzte Satz einer Person, die gerade im Gym ist (Mitlauf-Zeile). Gewicht in kg, `satzNr` zählt nur Arbeitssätze der Übung.
struct MitlaufSatz: Equatable, Sendable {
    var uebung: String
    var satzNr: Int
    var kg: Double?
    var wdh: Int
    var vorSekunden: Int
}

enum GymMitlaufLogik {
    /// Nur mit Freigabe gym und verlauf, `imGym` (jünger als `TrainingLogik.langNach`) und einer Einheit von heute mit Sätzen; sonst nil (keine Zeile, kein Platzhalter).
    /// Es zählt die letzte Übung mit einem Arbeitssatz (Aufwärmsätze `w` werden übersprungen); `vorSekunden` kommt aus `geschrieben` der Zusammenfassung.
    static func letzterSatz(_ datei: ZusammenfassungDatei, jetzt: Date) -> MitlaufSatz? {
        guard datei.freigaben.contains(.gym), datei.freigaben.contains(.verlauf), let v = datei.heute.verlauf,
              PartnerAnsichtLogik.statusZeile(v, jetzt: jetzt) != nil else { return nil }
        let heute = Datum.text(jetzt)
        for einheit in (v.einheiten ?? []) where einheit.tag == heute {
            for uebung in einheit.uebungen.reversed() {
                let arbeit = uebung.saetze.filter { $0.typ != "w" }
                guard let satz = arbeit.last else { continue }
                return MitlaufSatz(uebung: uebung.name, satzNr: arbeit.count, kg: satz.kg.map { Double($0) / 10 }, wdh: satz.wdh,
                                   vorSekunden: max(0, Int(jetzt.timeIntervalSince(datei.geschrieben))))
            }
        }
        return nil
    }

    /// "Bankdrücken · Satz 3 · 80 kg × 8 · vor 1 min"; ohne Gewicht "8 Wdh".
    static func text(_ s: MitlaufSatz) -> String {
        let last = s.kg.map { "\(TrainingLogik.kgText($0)) kg × \(s.wdh)" } ?? "\(s.wdh) Wdh"
        return "\(s.uebung) · Satz \(s.satzNr) · \(last) · \(vor(s.vorSekunden))"
    }

    private static func vor(_ sekunden: Int) -> String { sekunden < 60 ? "gerade eben" : "vor \(sekunden / 60) min" }
}
