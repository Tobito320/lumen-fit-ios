import Foundation

/// Die Vorschau "das sieht dein Partner" (Idee 84): zeigt aus der Zusammenfassung, die wirklich geschrieben würde, genau die Zeilen, die der Partner bekommt.
/// Gleiche Zeilen wie die Partner-Karte (`PartnerAnzeige`), damit Vorschau und Wirklichkeit nie auseinanderlaufen.
enum FreigabenVorschau {
    static func zeilen(_ datei: ZusammenfassungDatei) -> [PartnerAnzeige.Zeile] {
        PartnerAnzeige.zeilen(datei, bereich: .heute) + PartnerAnzeige.zeilen(datei, bereich: .schlaf)
    }

    static func name(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: "Schritte"
        case .gym: "Gym"
        case .schlaf: "Schlaf"
        case .essen: "Essen"
        }
    }

    static func erklaerung(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: "Wie viele Schritte du heute hast und wenn du dein Schrittziel erreichst."
        case .gym: "An wie vielen Tagen du diese Woche trainiert hast, wann du im Gym bist und wenn du einen Rekord schaffst."
        case .schlaf: "Wie lange du letzte Nacht geschlafen hast und wenn du gut geschlafen hast."
        case .essen: "Nur deine Kalorien von heute, nie was du gegessen hast."
        }
    }

    static func symbol(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: "figure.walk"
        case .gym: "dumbbell.fill"
        case .schlaf: "bed.double.fill"
        case .essen: "fork.knife"
        }
    }
}
