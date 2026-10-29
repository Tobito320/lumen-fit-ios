// Quelle: Lovea Health/Tracker/TrackerAkkuWarnung.swift
import Foundation

/// Wann Lumen Fit vor einem leeren Tracker-Akku warnt. Reine Regel, ohne Gerät testbar: einmal unter der Grenze,
/// erst nach dem Laden oder einer Erholung über `erholt` wieder (dazwischen kein zweites Mal, kein Flattern).
enum TrackerAkkuWarnung {
    static let grenze = 15
    static let erholt = 30

    enum Schritt: Equatable {
        case warnen, vergessen, nichts
    }

    /// `gewarnt`: Für diese Entladung ist schon gewarnt worden. `vergessen` löscht das Merken (geladen oder erholt).
    static func schritt(prozent: Int, laedt: Bool, gewarnt: Bool) -> Schritt {
        if laedt || prozent >= erholt { return gewarnt ? .vergessen : .nichts }
        return prozent <= grenze && !gewarnt ? .warnen : .nichts
    }

    /// Ist der Akku jetzt niedrig? Die Warnung ist ein Status in der App und im Band-Blatt, keine Mitteilung (SPEC 5.6).
    static func niedrig(prozent: Int, laedt: Bool) -> Bool { !laedt && prozent <= grenze }
}

/// Ob der Tracker lädt. Nach der Referenz (colmi_r02_client) steht das Ladebit in Byte 2 der Akku-Antwort; am echten
/// Gerät ist es nur im Ruhezustand belegt (27 %, Byte 2 = 0), nicht beim Laden. Reicht das Bit nicht, schließt Lumen Fit
/// aus dem Verlauf auf "vermutlich": der Akku steigt um mindestens 2 Punkte, oder er steht zweimal auf 100 % und das Band liegt ab.
enum TrackerLaden {
    enum Urteil: Equatable {
        case laedt, vermutlich, nein
    }

    /// So lange darf die vorige Messung her sein, damit ein Anstieg noch nach Laden aussieht.
    static let hoechstAbstand: TimeInterval = 30 * 60
    /// Um so viele Prozent muss der Akku gestiegen sein, damit ein Messsprung nicht als Laden zählt.
    static let anstieg = 2

    static func urteil(prozent: Int, byteLaedt: Bool, vorher: (prozent: Int, zeit: Date)?, jetzt: Date, abgelegt: Bool) -> Urteil {
        if byteLaedt { return .laedt }
        guard let vorher, jetzt.timeIntervalSince(vorher.zeit) <= hoechstAbstand else { return .nein }
        if prozent >= vorher.prozent + anstieg { return .vermutlich }
        return prozent == 100 && vorher.prozent == 100 && abgelegt ? .vermutlich : .nein
    }
}
