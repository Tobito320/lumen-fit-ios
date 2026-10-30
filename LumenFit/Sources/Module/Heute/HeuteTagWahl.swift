// Quelle: Lovea Health/Heute/HeuteView.swift (Tag wählen: Pfeile, Wischen, Kalender, Zurück zu heute)
import Foundation

/// Reine Logik der Tagwahl im Heute-Tab. Tage sind `yyyy-MM-dd`-Texte. Die Zukunft ist gesperrt, die Vergangenheit reicht ein Jahr zurück
/// (so weit liest Health). Nichts hier kennt eine Uhr: `heute` kommt immer von außen, so lässt sich alles mit festem Datum prüfen.
enum HeuteTagWahl {
    /// Wie weit der Blick in die Vergangenheit geht.
    nonisolated static let maxTageZurueck = 365

    /// Der älteste wählbare Tag.
    static func aeltester(heute: String) -> String { Datum.addTage(heute, -maxTageZurueck) }

    /// Hält `tag` zwischen dem ältesten wählbaren Tag und heute.
    static func begrenze(_ tag: String, heute: String) -> String {
        let alt = aeltester(heute: heute)
        if tag > heute { return heute }
        if tag < alt { return alt }
        return tag
    }

    /// `tage` Tage weiter (negativ: zurück), an den Grenzen gestoppt.
    static func schritt(_ tag: String, tage: Int, heute: String) -> String {
        begrenze(Datum.addTage(tag, tage), heute: heute)
    }

    static func kannZurueck(_ tag: String, heute: String) -> Bool { tag > aeltester(heute: heute) }

    static func kannVor(_ tag: String, heute: String) -> Bool { tag < heute }

    /// +1 = später (nach vorn), -1 = früher, 0 = gleich. Bestimmt, woher der neue Inhalt gleitet.
    static func richtung(von alt: String, nach neu: String) -> Int {
        alt == neu ? 0 : (neu > alt ? 1 : -1)
    }

    /// Wischen nach links zeigt den nächsten Tag, nach rechts den Tag davor. Nur ein klar waagerechter, langer Zug zählt
    /// (sonst stört er das Scrollen). nil = keine Wahl.
    static func wischSchritt(breite: Double, hoehe: Double, mindestens: Double = 60) -> Int? {
        guard abs(breite) >= mindestens, abs(breite) > abs(hoehe) * 1.5 else { return nil }
        return breite < 0 ? 1 : -1
    }

    /// Montag der Woche von `tag` (die Woche, in der der Wochenstreifen und die Gewohnheits-Quadrate liegen).
    static func wochenstart(_ tag: String) -> String { Datum.montagDerWoche(tag) }

    /// "Heute", "Gestern" oder "Mittwoch, 23. September".
    static func titel(_ tag: String, heute: String) -> String {
        if tag == heute { return "Heute" }
        if tag == Datum.addTage(heute, -1) { return "Gestern" }
        return Datum.anzeige(tag)
    }

    /// Das Datum zu "Heute" und "Gestern" in einem Satz für VoiceOver und die zweite Zeile.
    static func untertitel(_ tag: String, heute: String) -> String? {
        tag == heute || tag == Datum.addTage(heute, -1) ? Datum.anzeige(tag) : nil
    }
}
