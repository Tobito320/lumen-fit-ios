// Quelle: Lovea Health/Koerper/Messungen.swift (nur MessArt; MessPunkt, MessLogik, GewichtLogik liegen im Grundgerüst, Ansichten sind neu)
import Foundation

// `MessArt` und die Grenzen liegen in `Gemeinsam/Modelle/Koerpermasse.swift`.

/// Ein Wert, den das Blatt "Messung erfassen" speichern will.
struct MessWert: Equatable, Sendable {
    let art: MessArt
    let zehntel: Int
}

/// Das Blatt "Messung erfassen": aus den Textfeldern die Werte, die gespeichert werden, und die Felder, die nicht stimmen. Leere Felder bleiben unberührt.
enum MessErfassung {
    struct Ergebnis: Equatable, Sendable {
        let gueltig: [MessWert]
        let ungueltig: [MessArt]
    }

    static func pruefe(_ texte: [MessArt: String]) -> Ergebnis {
        var gueltig: [MessWert] = [], ungueltig: [MessArt] = []
        for art in MessArt.allCases {
            let roh = (texte[art] ?? "").trimmingCharacters(in: .whitespaces)
            guard !roh.isEmpty else { continue }
            if let zehntel = GewichtText.zehntel(roh), art.erlaubt.contains(zehntel) {
                gueltig.append(MessWert(art: art, zehntel: zehntel))
            } else {
                ungueltig.append(art)
            }
        }
        return Ergebnis(gueltig: gueltig, ungueltig: ungueltig)
    }

    /// Letzter Wert und die Änderung gegen den davor, z. B. "-0,4 kg seit 28.09."; nil bei weniger als zwei Punkten.
    static func aenderung(_ punkte: [MessPunkt], art: MessArt) -> String? {
        guard punkte.count >= 2, let letzter = punkte.last else { return nil }
        let davor = punkte[punkte.count - 2]
        let diff = letzter.zehntel - davor.zehntel
        let vorzeichen = diff > 0 ? "+" : diff < 0 ? "-" : ""
        let teile = davor.tag.split(separator: "-")
        let datum = teile.count == 3 ? "\(teile[2]).\(teile[1])." : davor.tag
        return "\(vorzeichen)\(abs(diff) / 10),\(abs(diff) % 10) \(art.einheit) seit \(datum)"
    }
}
