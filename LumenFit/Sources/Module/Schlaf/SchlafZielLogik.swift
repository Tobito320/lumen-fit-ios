// Quelle: Lovea Health/SchlafCard.swift (Schlafziel-Karte), Lovea Health/SchlafAutomatik.swift (istExtraTag)
import Foundation

/// Extra-Tage des Schlafziels: an den gewählten Wochentagen gilt das Ziel plus `extraMinuten` (auch minus). `extraTage` ist die Bitmaske
/// (Montag Bit 0 ... Sonntag Bit 6). Gespeichert als Op `fit.schlaf.ziel`, weil `Ziele` des Grundgerüsts noch keine Extra-Tage hat.
struct SchlafZielExtra: Codable, Equatable, Sendable {
    var extraMinuten = 0
    var extraTage = 0
}

enum SchlafZielLogik {
    nonisolated static let art = "fit.schlaf.ziel"
    nonisolated static let extraGrenze = 120

    /// Die zuletzt eingetroffene Op gilt; ohne Op: keine Extra-Tage.
    static func extra(ops: [Op]) -> SchlafZielExtra {
        var ergebnis = SchlafZielExtra()
        for op in ops { if let e = op.daten(SchlafZielExtra.self) { ergebnis = geklemmt(e) } }
        return ergebnis
    }

    static func geklemmt(_ e: SchlafZielExtra) -> SchlafZielExtra {
        SchlafZielExtra(extraMinuten: min(max(e.extraMinuten, -extraGrenze), extraGrenze), extraTage: e.extraTage & 0b1111111)
    }

    /// Ziel in Minuten für die Nacht mit Aufwachtag `tag`.
    static func ziel(basis: Int, extra: SchlafZielExtra, tag: String) -> Int {
        SchlafLogik.ziel(basis: basis, extraMinuten: extra.extraMinuten, extraTage: extra.extraTage, wochentag: Datum.wochentag(tag))
    }

    /// Wochentag 1 (Montag) bis 7 (Sonntag) umschalten.
    static func umgeschaltet(_ tage: Int, wochentag: Int) -> Int { tage ^ (1 << (wochentag - 1)) }

    /// "+30 min", "-15 min", "±0 min".
    static func extraText(_ minuten: Int) -> String { minuten == 0 ? "±0 min" : (minuten > 0 ? "+\(minuten) min" : "\(minuten) min") }
}
