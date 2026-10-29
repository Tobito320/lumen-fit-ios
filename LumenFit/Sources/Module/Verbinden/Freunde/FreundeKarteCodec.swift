import CryptoKit
import Foundation

/// Die Freundeskarte als Text (Idee 89): eine Wochenzusammenfassung, die als Link `lumenfit://freund?d=<Nutzlast>` oder als QR-Code von Handy zu Handy geht,
/// ganz ohne Server. Die Nutzlast ist `base64url(JSON)` + "." + Prüfsumme (HMAC-SHA256, die ersten 8 Byte als Hex).
///
/// Die Prüfsumme schützt vor Beschädigung und Tippfehlern (ein abgeschnittener oder verwürfelter Link wird abgelehnt). Sie beweist NICHT die Herkunft: der Schlüssel
/// steht in der App, jeder könnte eine gültige Karte bauen (Annahme, SPEC Abschnitt 15). Darum nimmt `lies` nur plausible Werte an und zeigt die Karte vor dem Übernehmen.
enum FreundeKarteCodec {
    nonisolated static let version = 1
    nonisolated static let hoechsteSchritte = 400_000

    private struct Nutzlast: Codable {
        var v: Int
        var i: String      // Kennung des Absenders (Hash seines Profils), nie der Profilname
        var n: String      // Anzeigename
        var w: String      // Montag der Woche, yyyy-MM-dd
        var s: Int         // Schritte der Woche
        var g: Int         // Gym-Tage der Woche
        var m: Int?        // Schlaf im Schnitt, Minuten
        var e: Int         // erstellt, Sekunden seit 1970
    }

    enum Fehler: Error, Equatable, Sendable {
        case leer, format, pruefsumme, version, werte
    }

    // Berechnet statt gespeichert: ob SymmetricKey Sendable ist, hängt vom SDK ab (Swift 6: statische Konstante muss Sendable sein).
    private static var schluessel: SymmetricKey { SymmetricKey(data: Data("lumen-fit.freundeskarte.v1".utf8)) }

    // MARK: Erzeugen

    /// Text für den Link und den QR-Code. `karte.respekt` gehört dem Empfänger und geht nie mit.
    static func kodiere(_ karte: FreundKarte, absender: String) -> String {
        let nutzlast = Nutzlast(v: version, i: absender, n: bereinigt(karte.name), w: karte.woche, s: karte.schritte, g: karte.gymTage,
                                m: karte.schlafSchnittMinuten, e: Int(karte.erstellt.timeIntervalSince1970))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let daten = (try? encoder.encode(nutzlast)) ?? Data()
        let teil = base64url(daten)
        return teil + "." + summe(teil)
    }

    static func link(_ karte: FreundKarte, absender: String) -> URL {
        RouteURL.url(fuer: .freund(daten: kodiere(karte, absender: absender)))
    }

    // MARK: Lesen

    /// Liest die Nutzlast eines Links (`d=`) oder den Text allein. Manipuliertes, abgeschnittenes oder unplausibles wird abgelehnt.
    static func lies(_ text: String) -> Result<FreundKarte, Fehler> {
        let roh = nutzlastText(text)
        guard !roh.isEmpty else { return .failure(.leer) }
        guard let punkt = roh.lastIndex(of: ".") else { return .failure(.format) }
        let teil = String(roh[roh.startIndex..<punkt])
        let pruef = String(roh[roh.index(after: punkt)...])
        guard pruefsummeStimmt(teil, pruef) else { return .failure(.pruefsumme) }
        guard let daten = vonBase64url(teil), let nutzlast = try? JSONDecoder().decode(Nutzlast.self, from: daten) else { return .failure(.format) }
        guard nutzlast.v == version else { return .failure(.version) }
        let name = bereinigt(nutzlast.n)
        guard !name.isEmpty, !nutzlast.i.isEmpty, nutzlast.i.count <= 64, SchlafNachtLogik.gueltigerTag(nutzlast.w), Datum.wochentag(nutzlast.w) == 1,
              (0...hoechsteSchritte).contains(nutzlast.s), (0...7).contains(nutzlast.g), nutzlast.m.map({ (0...1440).contains($0) }) ?? true,
              nutzlast.e > 0 else { return .failure(.werte) }
        return .success(FreundKarte(id: "\(nutzlast.i)-\(nutzlast.w)", name: name, woche: nutzlast.w, schritte: nutzlast.s, gymTage: nutzlast.g,
                                    schlafSchnittMinuten: nutzlast.m, erstellt: Date(timeIntervalSince1970: TimeInterval(nutzlast.e)), respekt: false))
    }

    /// Aus einem ganzen `lumenfit://freund?d=...`-Link, einem Link ohne Schema oder der nackten Nutzlast die Nutzlast holen.
    static func nutzlastText(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: t), case .freund(let daten)? = RouteURL.route(aus: url) { return daten ?? "" }
        return t
    }

    /// Die Kennung des Absenders: ein Hash der Profil-Kennung, nie die Kennung selbst und nie der Name.
    static func absender(_ profil: ProfilID) -> String {
        SHA256.hash(data: Data(profil.rawValue.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Hilfen

    /// Keine Steuerzeichen, höchstens 24 Zeichen, Leerzeichen am Rand weg.
    nonisolated static func bereinigt(_ name: String) -> String {
        String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.map(Character.init).prefix(24))
            .trimmingCharacters(in: .whitespaces)
    }

    private static func summe(_ teil: String) -> String {
        HMAC<SHA256>.authenticationCode(for: Data(teil.utf8), using: schluessel).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// Die Prüfsumme ist kein Geheimnis (der Schlüssel steht in der App): ein einfacher Vergleich genügt.
    private static func pruefsummeStimmt(_ teil: String, _ pruef: String) -> Bool { pruef == summe(teil) }

    private static func base64url(_ daten: Data) -> String {
        daten.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private static func vonBase64url(_ text: String) -> Data? {
        var s = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }
}
