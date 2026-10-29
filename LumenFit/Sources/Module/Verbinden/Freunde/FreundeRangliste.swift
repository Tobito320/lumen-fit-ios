import Foundation

/// Die eigene Wochenkarte und die Wochen-Rangliste aus importierten Freundeskarten (Idee 89, 90). Rein, ohne Stores und Oberfläche.
/// "Respekt" statt Like: ein stilles Zeichen an die Karte eines Freundes, nur auf diesem Gerät gemerkt (`FreundKarte.respekt`), kein Zähler, keine Zahl bei anderen.
enum FreundeRangliste {
    struct Zeile: Identifiable, Equatable, Sendable {
        var karte: FreundKarte
        var platz: Int
        var eigene: Bool
        var id: String { karte.id }
    }

    /// Die Karte der aktuellen Woche (Montag bis heute): Schritte summiert, Gym-Tage gezählt, Schlaf im Schnitt der Nächte mit Wert.
    static func eigene(name: String, absender: String, jetzt: Date, schritteJeTag: [String: Int], gymTage: Int, schlafMinutenJeTag: [String: Int]) -> FreundKarte {
        let heute = Datum.text(jetzt)
        let start = Datum.wochenstart(heute)
        let schritte = schritteJeTag.filter { $0.key >= start && $0.key <= heute }.values.reduce(0, +)
        let nachte = schlafMinutenJeTag.filter { $0.key >= start && $0.key <= heute && $0.value > 0 }.values
        let schnitt = nachte.isEmpty ? nil : Int((Double(nachte.reduce(0, +)) / Double(nachte.count)).rounded())
        return FreundKarte(id: "\(absender)-\(start)", name: FreundeKarteCodec.bereinigt(name), woche: start, schritte: schritte, gymTage: min(7, max(0, gymTage)),
                           schlafSchnittMinuten: schnitt, erstellt: jetzt, respekt: false)
    }

    /// Nimmt eine Karte auf: gleiche `id` (gleiche Person, gleiche Woche) wird ersetzt, wenn die neue jünger ist; ein gegebener Respekt bleibt.
    static func aufnehmen(_ neu: FreundKarte, in karten: [FreundKarte]) -> [FreundKarte] {
        var liste = karten
        if let i = liste.firstIndex(where: { $0.id == neu.id }) {
            guard neu.erstellt >= liste[i].erstellt else { return karten }
            var ersatz = neu
            ersatz.respekt = liste[i].respekt
            liste[i] = ersatz
        } else {
            liste.append(neu)
        }
        return liste
    }

    /// Die Woche der Rangliste: die jüngste Woche, zu der es eine Karte gibt (eigene eingeschlossen).
    static func woche(_ karten: [FreundKarte], eigene: FreundKarte?) -> String? {
        (karten + [eigene].compactMap { $0 }).map(\.woche).max()
    }

    /// Rangliste einer Woche: Schritte, dann Gym-Tage; bei Gleichstand dasselbe Platz. Die eigene Karte läuft mit, wenn sie zur Woche gehört.
    static func rangliste(_ karten: [FreundKarte], eigene: FreundKarte?, woche: String) -> [Zeile] {
        var alle = karten.filter { $0.woche == woche }.map { (karte: $0, eigene: false) }
        if let eigene, eigene.woche == woche { alle.append((eigene, true)) }
        alle.sort {
            if $0.karte.schritte != $1.karte.schritte { return $0.karte.schritte > $1.karte.schritte }
            if $0.karte.gymTage != $1.karte.gymTage { return $0.karte.gymTage > $1.karte.gymTage }
            return $0.karte.name < $1.karte.name
        }
        var platz = 0
        var vorher: (Int, Int)?
        return alle.enumerated().map { index, eintrag in
            let wert = (eintrag.karte.schritte, eintrag.karte.gymTage)
            if vorher.map({ $0 != wert }) ?? true { platz = index + 1 }
            vorher = wert
            return Zeile(karte: eintrag.karte, platz: platz, eigene: eintrag.eigene)
        }
    }
}
