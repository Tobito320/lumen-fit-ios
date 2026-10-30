import Foundation

/// Die Vorschau "das sieht dein Partner" (Idee 84): zeigt aus der Zusammenfassung, die wirklich geschrieben würde, genau die Zeilen, die der Partner bekommt.
/// Gleiche Zeilen wie die Partner-Karte (`PartnerAnzeige`), damit Vorschau und Wirklichkeit nie auseinanderlaufen.
enum FreigabenVorschau {
    static func zeilen(_ datei: ZusammenfassungDatei) -> [PartnerAnzeige.Zeile] {
        var liste = PartnerAnzeige.zeilen(datei, bereich: .heute) + PartnerAnzeige.zeilen(datei, bereich: .schlaf)
        if let satz = PartnerAnzeige.energieSatz(datei) { liste.append(.init(titel: "Energie", wert: satz, symbol: "bolt.fill")) }
        liste += ansichtsZeilen(datei)
        return liste
    }

    /// Je freigegebener Ansicht des Partners eine Zeile mit genau dem Kern, den der Partner dort sieht (nur wenn die Datei etwas dazu enthält).
    static func ansichtsZeilen(_ datei: ZusammenfassungDatei) -> [PartnerAnzeige.Zeile] {
        var liste: [PartnerAnzeige.Zeile] = []
        let frei = Set(datei.freigaben)
        if frei.contains(.plan), let plan = datei.heute.plan {
            let tage = PartnerAnsichtLogik.trainingsTage(plan)
            liste.append(.init(titel: "Trainingsplan", wert: tage == 1 ? "1 Tag" : "\(tage) Tage", symbol: PartnerAnsichtLogik.symbol(.plan)))
        }
        if frei.contains(.verlauf), let v = datei.heute.verlauf {
            let wert = v.imGym == true ? "Im Gym" : "\(v.trainings.count) letzte"
            liste.append(.init(titel: "Training", wert: wert, symbol: PartnerAnsichtLogik.symbol(.verlauf)))
        }
        if frei.contains(.tagebuch), let tage = datei.heute.tagebuch, !tage.isEmpty {
            liste.append(.init(titel: "Tagebuch", wert: tage.count == 1 ? "1 Tag" : "\(tage.count) Tage", symbol: PartnerAnsichtLogik.symbol(.tagebuch)))
        }
        let arten = PartnerAnsichtLogik.koerperArten(datei)
        if frei.contains(.koerper), !arten.isEmpty {
            let gewicht = PartnerAnsichtLogik.punkte(datei, .gewicht).last.map { MessArt.gewicht.text($0.zehntel) }
            let anzahl = arten.count == 1 ? "1 Wert" : "\(arten.count) Werte"
            liste.append(.init(titel: "Körperwerte", wert: gewicht ?? anzahl, symbol: PartnerAnsichtLogik.symbol(.koerper)))
        }
        return liste
    }

    static func name(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: "Schritte"
        case .gym: "Gym"
        case .schlaf: "Schlaf"
        case .essen: "Essen"
        case .plan: "Trainingsplan"
        case .verlauf: "Training und Verlauf"
        case .tagebuch: "Tagebuch"
        case .koerper: "Körperwerte"
        }
    }

    static func erklaerung(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: "Wie viele Schritte du heute und an jedem Tag dieser Woche hast und wenn du dein Schrittziel erreichst."
        case .gym: "An wie vielen Tagen du diese Woche trainiert hast, an welchen, wann du im Gym bist und wenn du einen Rekord schaffst."
        case .schlaf: "Wie lange du diese Woche geschlafen hast, wie viel Energie du heute hast und wenn du gut geschlafen hast."
        case .essen: "Nur deine Kalorien von heute und ob du dein Wasserziel erreicht hast, nie was du gegessen hast."
        case .plan: "Name deines Plans, deine Trainingstage und die Namen der Übungen. Keine Gewichte, keine Sätze."
        case .verlauf: "Ob du gerade im Gym bist und eine Zusammenfassung deiner letzten zehn Trainings: Tag, Dauer, Zahl der Sätze. Keine Gewichte."
        case .tagebuch: "Was du in den letzten sieben Tagen gegessen hast: Namen, Kalorien und Makros. Keine Fotos, keine Mengen."
        case .koerper: "Dein Gewicht und deine Körpermaße mit dem Verlauf der letzten Monate."
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
        }
    }
}
