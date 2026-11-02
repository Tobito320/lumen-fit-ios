import Foundation

/// Ein Knoten im Pfad der Lumi-Seite: die Stufe und die Zahl Medaillen, ab der sie gilt.
struct LumiKnoten: Identifiable, Equatable, Sendable {
    let stufe: Int
    let ab: Int
    /// Erreicht oder gerade aktuell.
    let erreicht: Bool
    var id: Int { stufe }
}

/// Wo Lumi steht (Idee 38): Stufe 1 bis 9 aus der Zahl der Medaillen, der Pfad, das nächste Ziel mit Balken und die Serie in Wochen.
/// Die Stufe selbst rechnet `LumiStufe` im Grundgerüst; hier wird sie nur gezeigt.
struct LumiPfadStand: Equatable, Sendable {
    let erreicht: Int
    let stufe: Int
    let knoten: [LumiKnoten]
    /// Nil auf der höchsten Stufe.
    let naechsteStufe: Int?
    /// Medaillen bis zur nächsten Stufe; nil auf der höchsten.
    let fehlen: Int?
    /// 0 bis 1 innerhalb der aktuellen Stufe (auf der höchsten 1).
    let anteil: Double
    let serieWochen: Int

    /// "Noch 2 Medaillen bis Stufe 5".
    var ziel: String {
        guard let naechsteStufe, let fehlen else { return "Höchste Stufe erreicht" }
        return "Noch \(fehlen) \(fehlen == 1 ? "Medaille" : "Medaillen") bis Stufe \(naechsteStufe)"
    }

    /// "Serie: 12 Wochen".
    var serieText: String { "\(serieWochen) \(serieWochen == 1 ? "Woche" : "Wochen") in Folge" }
}

/// Das nächste Ziel auf einer Medaille: die, die am weitesten gediehen ist, mit Zahlen für den Balken.
struct MeilensteinZiel: Equatable, Sendable {
    let meilenstein: Meilenstein
    let aktuell: Double
    let ziel: Double
    /// "Tagen", "Wochen", "kg" und so weiter.
    let einheit: String

    var anteil: Double { ziel > 0 ? min(1, max(0, aktuell / ziel)) : 0 }

    /// "80 von 100 Tagen".
    var text: String {
        let zahl: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE"))) }
        return "\(zahl(aktuell.rounded(.down))) von \(zahl(ziel)) \(einheit)"
    }
}

enum LumiPfad {
    /// Der Pfad für `erreicht` Medaillen aus `LumiStufe.schwellen`.
    static func stand(erreicht: Int, serieWochen: Int) -> LumiPfadStand {
        let schwellen = LumiStufe.schwellen
        let stufe = LumiStufe.stufe(erreicht: erreicht)
        let knoten = schwellen.enumerated().map { LumiKnoten(stufe: $0.offset + 1, ab: $0.element, erreicht: $0.offset + 1 <= stufe) }
        guard stufe < schwellen.count else {
            return LumiPfadStand(erreicht: erreicht, stufe: stufe, knoten: knoten, naechsteStufe: nil, fehlen: nil, anteil: 1, serieWochen: serieWochen)
        }
        let von = schwellen[stufe - 1], bis = schwellen[stufe]
        let anteil = bis > von ? min(1, max(0, Double(erreicht - von) / Double(bis - von))) : 0
        return LumiPfadStand(erreicht: erreicht, stufe: stufe, knoten: knoten, naechsteStufe: stufe + 1, fehlen: max(0, bis - erreicht),
                             anteil: anteil, serieWochen: serieWochen)
    }

    /// Wie weit eine zählbare Medaille ist: Wert, Ziel und Einheit. Medaillen ohne Zähler (Ja oder Nein) geben nil.
    static func zaehler(_ id: String, _ z: MeilensteinZahlen) -> (aktuell: Double, ziel: Double, einheit: String)? {
        let teile = id.split(separator: "-")
        guard teile.count == 2, let ziel = Double(teile[1]) else {
            return nil
        }
        switch (teile[0], id) {
        case ("gym", _): return (Double(z.gymTage), ziel, "Tagen")
        case ("volumen", _): return (z.volumenKg, ziel, "kg")
        case ("serie", _): return (Double(z.serieWochen), ziel, "Wochen")
        case ("rekorde", _): return (Double(z.rekorde), ziel, "Rekorden")
        case ("tagebuch", _): return (Double(z.essenTage), ziel, "Tagen")
        case ("schlaf", "schlaf-7"): return (Double(z.schlafSerie), ziel, "Nächten in Folge")
        case ("schlaf", "schlaf-30"): return (Double(z.schlafNaechteImZiel), ziel, "Nächten")
        case ("wochenziel", _): return (Double(z.wochenzielSerie), ziel, "Wochen im Ziel")
        case ("schritte", "schritte-7"): return (Double(z.schrittSerie), ziel, "Tagen in Folge")
        case ("schritte", "schritte-30"): return (Double(z.schrittTage), ziel, "Tagen")
        case ("protein", "protein-7"): return (Double(z.proteinSerie), ziel, "Tagen in Folge")
        case ("protein", "protein-30"): return (Double(z.proteinTage), ziel, "Tagen")
        case ("kalorien", _): return (Double(z.kalorienTage), ziel, "Tagen")
        default: return nil
        }
    }

    /// Die zählbare Medaille, die am weitesten gediehen ist (größter Anteil, bei Gleichstand die erste im Katalog). Nil, wenn keine mehr offen ist.
    static func naechstesZiel(_ z: MeilensteinZahlen, schon: Set<String>) -> MeilensteinZiel? {
        var beste: MeilensteinZiel?
        // Nur die Medaillen, die Lumis Stufe zählt: ein Ziel-Medaillen-Balken stünde sonst als "nächstes Ziel" vor einer Stufe, die er nicht bewegt.
        for m in MeilensteinKatalog.alle where !schon.contains(m.id) && !MeilensteinKatalog.neueIds.contains(m.id) {
            guard let c = zaehler(m.id, z), c.aktuell < c.ziel else { continue }
            let kandidat = MeilensteinZiel(meilenstein: m, aktuell: c.aktuell, ziel: c.ziel, einheit: c.einheit)
            if kandidat.anteil > (beste?.anteil ?? -1) { beste = kandidat }
        }
        return beste
    }
}
