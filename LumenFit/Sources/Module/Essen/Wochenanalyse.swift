import Foundation

/// Ein Tag der Woche: Summen nur aus den Einträgen dieses Tages. Tage ohne Eintrag zählen nie als Null.
struct WochenTag: Identifiable, Equatable, Sendable {
    let tag: String
    let eintraege: Int
    let kcal: Double
    let protein: Double
    /// Ziel dieses Tages (flexible Tage eingerechnet).
    let proteinZiel: Int
    let zucker: Double?
    let ballaststoffe: Double?
    var id: String { tag }
    var hatEintraege: Bool { eintraege > 0 }
}

struct MikroLuecke: Equatable, Sendable {
    let mikro: Mikro
    /// Mittlerer Anteil an der EU-Tagesreferenz in Prozent, über die Tage mit Angaben.
    let prozent: Double
}

/// Auswertung der letzten sieben Tage in Klartext (Idee 50): Protein gegen Ziellinie, Zucker, Ballaststoffe, Mikronährstoff-Lücken.
struct Wochenanalyse: Equatable, Sendable {
    /// Ältester Tag zuerst, immer sieben.
    let tage: [WochenTag]
    let proteinSchnitt: Double?
    /// Ziellinie im Diagramm: das Protein-Ziel des letzten Tages.
    let proteinZiel: Int
    let tageImProteinZiel: Int
    let zuckerSchnitt: Double?
    /// Richtwert in Gramm aus der mittleren Energie (WHO: höchstens 10 % der Energie aus freiem Zucker).
    let zuckerRichtwert: Double?
    let ballaststoffSchnitt: Double?
    let luecken: [MikroLuecke]
    /// Hat mindestens ein Lebensmittel Angaben zu Vitaminen oder Mineralstoffen gemacht?
    let mikroAngaben: Bool

    var tageMitEintraegen: Int { tage.filter(\.hatEintraege).count }
    var istLeer: Bool { tageMitEintraegen == 0 }

    /// DGE: mindestens 30 g Ballaststoffe am Tag.
    static let ballaststoffRichtwert = 30.0
    /// Unter diesem Anteil der EU-Referenz gilt ein Mikronährstoff als Lücke.
    static let lueckenSchwelle = 50.0

    /// Die Zeilen der Ansicht, eine Aussage je Zeile.
    var klartext: [String] {
        if istLeer { return ["In den letzten sieben Tagen ist noch nichts eingetragen."] }
        var zeilen: [String] = []
        if let p = proteinSchnitt {
            zeilen.append("Protein: im Schnitt \(Int(p.rounded())) g am Tag, Ziel \(proteinZiel) g. Erreicht an \(tageImProteinZiel) von \(tageMitEintraegen) Tagen mit Einträgen.")
        }
        if let z = zuckerSchnitt {
            var satz = "Zucker: im Schnitt \(Int(z.rounded())) g am Tag"
            if let r = zuckerRichtwert { satz += ", Richtwert der WHO rund \(Int(r.rounded())) g (10 % der Energie, bei freiem Zucker)" }
            zeilen.append(satz + ".")
        } else {
            zeilen.append("Zucker: den Lebensmitteln fehlen Angaben.")
        }
        if let b = ballaststoffSchnitt {
            let rest = Self.ballaststoffRichtwert - b
            zeilen.append(rest > 0
                ? "Ballaststoffe: im Schnitt \(Int(b.rounded())) g am Tag, die DGE empfiehlt mindestens 30 g."
                : "Ballaststoffe: im Schnitt \(Int(b.rounded())) g am Tag, das reicht (DGE: mindestens 30 g).")
        } else {
            zeilen.append("Ballaststoffe: den Lebensmitteln fehlen Angaben.")
        }
        if !mikroAngaben {
            zeilen.append("Vitamine und Mineralstoffe: den Lebensmitteln fehlen Angaben, deshalb sage ich dazu nichts.")
        } else if luecken.isEmpty {
            zeilen.append("Vitamine und Mineralstoffe: bei allen Werten mit Angaben liegst du über der Hälfte der Tagesreferenz.")
        } else {
            let namen = luecken.map { FoodRating.kurzName($0.mikro) }.joined(separator: ", ")
            zeilen.append("Wenig drin: \(namen), im Schnitt unter der Hälfte der EU-Tagesreferenz. Es zählen nur Lebensmittel mit Angaben.")
        }
        return zeilen
    }
}

enum WochenanalyseLogik {
    /// Die sieben Tage bis einschließlich `bis`. `eintraege` und `ziele` liefern je Tag (der Aufrufer greift auf `EssenStore` zu).
    static func berechne(bis: String, eintraege: (String) -> [EssenEintrag], ziele: (String) -> ErnaehrungsZiele) -> Wochenanalyse {
        let tage: [WochenTag] = AnalyseLogik.tage(bis: bis, anzahl: 7).map { tag in
            let liste = eintraege(tag)
            let summe = ErnaehrungLogik.summe(liste)
            return WochenTag(tag: tag, eintraege: liste.count, kcal: summe.kcal, protein: summe.protein, proteinZiel: ziele(tag).protein,
                             zucker: summe.zucker, ballaststoffe: summe.ballaststoffe)
        }
        let mit = tage.filter(\.hatEintraege)
        let proteinSchnitt = mit.isEmpty ? nil : mit.map(\.protein).reduce(0, +) / Double(mit.count)
        let imZiel = mit.filter { $0.protein >= Double($0.proteinZiel) }.count
        let zucker = mit.compactMap(\.zucker)
        let zuckerSchnitt = zucker.isEmpty ? nil : zucker.reduce(0, +) / Double(zucker.count)
        let kcalSchnitt = mit.isEmpty ? 0 : mit.map(\.kcal).reduce(0, +) / Double(mit.count)
        let ballast = mit.compactMap(\.ballaststoffe)
        let ballastSchnitt = ballast.isEmpty ? nil : ballast.reduce(0, +) / Double(ballast.count)
        let (luecken, angaben) = mikroLuecken(tage: mit, eintraege: eintraege)
        return Wochenanalyse(tage: tage, proteinSchnitt: proteinSchnitt, proteinZiel: tage.last?.proteinZiel ?? 0, tageImProteinZiel: imZiel,
                             zuckerSchnitt: zuckerSchnitt, zuckerRichtwert: kcalSchnitt > 0 ? kcalSchnitt * 0.10 / 4 : nil,
                             ballaststoffSchnitt: ballastSchnitt, luecken: luecken, mikroAngaben: angaben)
    }

    /// Mikronährstoffe mit EU-Referenz (ohne Natrium, das ist ein Höchstwert): mittlerer Anteil nur über Tage mit Angaben, und nur,
    /// wenn mindestens die Hälfte der Tage mit Einträgen Angaben hat. Unbekannt ist keine Lücke. Die drei größten Lücken.
    static func mikroLuecken(tage: [WochenTag], eintraege: (String) -> [EssenEintrag]) -> (luecken: [MikroLuecke], angaben: Bool) {
        let summen = tage.map { ErnaehrungLogik.summe(eintraege($0.tag)) }
        var luecken: [MikroLuecke] = []
        var angaben = false
        for m in Mikro.allCases where m != .natrium && m.gruppe != .weitere {
            let werte = summen.compactMap { $0.wert(m) }
            guard !werte.isEmpty else { continue }
            angaben = true
            guard werte.count * 2 >= tage.count else { continue }
            let prozent = werte.compactMap { AnalyseLogik.prozentReferenz($0, m) }
            guard !prozent.isEmpty else { continue }
            let mittel = prozent.reduce(0, +) / Double(prozent.count)
            if mittel < Wochenanalyse.lueckenSchwelle { luecken.append(MikroLuecke(mikro: m, prozent: mittel)) }
        }
        return (Array(luecken.sorted { $0.prozent < $1.prozent }.prefix(3)), angaben)
    }
}
