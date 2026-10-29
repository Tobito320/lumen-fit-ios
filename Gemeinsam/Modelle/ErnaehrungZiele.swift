import Foundation

/// Speicherform der Ernährungsziele: ein Wörterbuch Feld -> Zahl (`ErnaehrungsZiele.felder`). Fehlende Felder behalten ihren Standard,
/// unbekannte werden ignoriert, so bleibt eine ältere oder neuere Datei lesbar.
extension ErnaehrungsZiele: Codable {
    init(from decoder: Decoder) throws {
        self.init()
        let werte = try decoder.singleValueContainer().decode([String: Int].self)
        for feld in Self.felder { if let w = werte[feld] { setzen(feld, w) } }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(Dictionary(uniqueKeysWithValues: Self.felder.map { ($0, wert($0)) }))
    }
}
