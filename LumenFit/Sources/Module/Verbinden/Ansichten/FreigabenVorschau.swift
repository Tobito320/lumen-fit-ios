import Foundation

/// Die Vorschau "das sieht dein Partner" (Idee 84): zeigt aus der Zusammenfassung, die wirklich geschrieben würde, genau die Zeilen, die der Partner bekommt.
/// Gleiche Zeilen wie die Partner-Karte (`PartnerAnzeige`), damit Vorschau und Wirklichkeit nie auseinanderlaufen.
enum FreigabenVorschau {
    static func zeilen(_ datei: ZusammenfassungDatei) -> [PartnerAnzeige.Zeile] {
        var liste = PartnerAnzeige.zeilen(datei, bereich: .heute) + PartnerAnzeige.zeilen(datei, bereich: .schlaf)
        if let satz = PartnerAnzeige.energieSatz(datei) { liste.append(.init(titel: String(localized: "Energie"), wert: satz, symbol: "bolt.fill")) }
        liste += ansichtsZeilen(datei)
        return liste
    }

    /// Je freigegebener Ansicht des Partners eine Zeile mit genau dem Kern, den der Partner dort sieht (nur wenn die Datei etwas dazu enthält).
    static func ansichtsZeilen(_ datei: ZusammenfassungDatei) -> [PartnerAnzeige.Zeile] {
        var liste: [PartnerAnzeige.Zeile] = []
        let frei = Set(datei.freigaben)
        if frei.contains(.plan), let plan = datei.heute.plan {
            let tage = PartnerAnsichtLogik.trainingsTage(plan)
            liste.append(.init(titel: String(localized: "Trainingsplan"), wert: tage == 1 ? String(localized: "1 Tag") : String(localized: "\(tage) Tage"), symbol: PartnerAnsichtLogik.symbol(.plan)))
        }
        if frei.contains(.verlauf), let v = datei.heute.verlauf {
            let wert = v.imGym == true ? String(localized: "Im Gym") : String(localized: "\(v.trainings.count) letzte")
            liste.append(.init(titel: String(localized: "Training"), wert: wert, symbol: PartnerAnsichtLogik.symbol(.verlauf)))
        }
        if frei.contains(.tagebuch), let tage = datei.heute.tagebuch, !tage.isEmpty {
            liste.append(.init(titel: String(localized: "Tagebuch"), wert: tage.count == 1 ? String(localized: "1 Tag") : String(localized: "\(tage.count) Tage"), symbol: PartnerAnsichtLogik.symbol(.tagebuch)))
        }
        let arten = PartnerAnsichtLogik.koerperArten(datei)
        if frei.contains(.koerper), !arten.isEmpty {
            let gewicht = PartnerAnsichtLogik.punkte(datei, .gewicht).last.map { MessArt.gewicht.text($0.zehntel) }
            let anzahl = arten.count == 1 ? String(localized: "1 Wert") : String(localized: "\(arten.count) Werte")
            liste.append(.init(titel: String(localized: "Körperwerte"), wert: gewicht ?? anzahl, symbol: PartnerAnsichtLogik.symbol(.koerper)))
        }
        return liste
    }

    static func name(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: String(localized: "Schritte")
        case .gym: String(localized: "Gym")
        case .schlaf: String(localized: "Schlaf")
        case .essen: String(localized: "Essen")
        case .plan: String(localized: "Trainingsplan")
        case .verlauf: String(localized: "Training und Verlauf")
        case .tagebuch: String(localized: "Tagebuch")
        case .koerper: String(localized: "Körperwerte")
        case .stimmung: String(localized: "Stimmung")
        case .gewohnheiten: String(localized: "Gewohnheiten")
        }
    }

    static func erklaerung(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: String(localized: "Wie viele Schritte du heute und an jedem Tag dieser Woche hast und wenn du dein Schrittziel erreichst.")
        case .gym: String(localized: "An wie vielen Tagen du diese Woche trainiert hast, an welchen, wann du im Gym bist und wenn du einen Rekord schaffst.")
        case .schlaf: String(localized: "Wie lange du diese Woche geschlafen hast, wie viel Energie du heute hast und wenn du gut geschlafen hast.")
        case .essen: String(localized: "Nur deine Kalorien von heute und ob du dein Wasserziel erreicht hast, nie was du gegessen hast.")
        case .plan: String(localized: "Name deines Plans, deine Trainingstage und die Namen der Übungen. Keine Gewichte, keine Sätze.")
        case .verlauf: String(localized: "Ob du gerade im Gym bist und deine letzten zehn Trainings: Tag, Dauer, Zahl der Sätze. Zusammen mit Gym auch die Sätze mit Gewichten.")
        case .tagebuch: String(localized: "Was du in den letzten sieben Tagen gegessen hast: Namen, Kalorien und Makros. Keine Fotos, keine Mengen.")
        case .koerper: String(localized: "Dein Gewicht und deine Körpermaße mit dem Verlauf der letzten Monate.")
        case .stimmung: String(localized: "Deine Antwort auf den Morgen-Check von heute.")
        case .gewohnheiten: String(localized: "Alle deine Gewohnheiten mit Serie, Quote der letzten 30 Tage und ob sie heute erledigt sind.")
        }
    }

    static func symbol(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: "figure.walk"
        case .gym: "dumbbell.fill"
        case .schlaf: "bed.double.fill"
        case .essen: "fork.knife"
        case .plan: "calendar"
        case .verlauf: "figure.strengthtraining.traditional"
        case .tagebuch: "book.closed"
        case .koerper: "scalemass"
        case .stimmung: "face.smiling"
        case .gewohnheiten: "checkmark.circle"
        }
    }
}
