// Quelle: Lovea Health/Ernaehrung/SuchZusammenfuehrung.swift
import Foundation

/// Stand einer laufenden Suche: `nummer` zählt jede Texteingabe, damit eine späte Antwort von Open Food Facts zu
/// einer schon überholten Eingabe erkannt und verworfen werden kann.
struct SuchStand: Equatable, Sendable {
    var nummer: Int = 0
    var lokal: [Lebensmittel] = []
    var server: [Lebensmittel] = []
    var sichtbar: [Lebensmittel] = []
}

/// Treffer des Servers kommen später als lokale. Sie werden nur hinten angehängt (Favoriten, Zuletzt, Eigene und BLS bleiben vorn,
/// nichts springt), und eine Antwort zu einer älteren Eingabe wird verworfen. Doppelt = gleiche id, gleicher Barcode oder gleicher
/// normalisierter Name samt Marke.
enum SuchZusammenfuehrung {
    static func server(_ s: SuchStand, antwort: [Lebensmittel], nummer: Int) -> SuchStand {
        guard nummer == s.nummer else { return s }
        var neu = s
        var ids = Set(s.sichtbar.map(\.id))
        var codes = Set(s.sichtbar.compactMap(\.barcode))
        var namen = Set(s.sichtbar.map(namensSchluessel))
        let dazu = antwort.filter { l in
            guard !ids.contains(l.id), l.barcode.map({ !codes.contains($0) }) ?? true, namen.insert(namensSchluessel(l)).inserted else { return false }
            ids.insert(l.id)
            if let c = l.barcode { codes.insert(c) }
            return true
        }
        neu.server = antwort
        neu.sichtbar = Array((s.sichtbar + dazu).prefix(80))
        return neu
    }

    private static func namensSchluessel(_ l: Lebensmittel) -> String { LebensmittelBasis.normal(l.name + " " + (l.marke ?? "")) }
}
