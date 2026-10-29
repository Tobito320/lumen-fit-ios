import Foundation

/// Vorschläge für die Ziele aus Körperdaten und Zielart (Idee 76 und 77). Rechnet mit `ErnaehrungLogik` (Mifflin-St Jeor), nie mit eigenen Formeln.
/// Geschlecht ist optional und nur für die Formel da; ohne Angabe gilt der Mann-Wert wie im Essen-Store.
enum ProfilZielVorschlag {
    /// Ohne eingetragenes Gewicht rechnet auch `EssenStore` mit diesen Werten.
    static func gewichtOderStandard(_ kg: Double?, geschlecht: Geschlecht?) -> Double { kg ?? (geschlecht == .weiblich ? 62 : 78) }

    static func alter(geburtsjahr: Int?, jahr: Int) -> Int? {
        guard let geburtsjahr, geburtsjahr > 1900, geburtsjahr <= jahr else { return nil }
        return jahr - geburtsjahr
    }

    /// Aktivitätsstufe (Index in `ErnaehrungLogik.aktivitaeten`) aus den Gym-Tagen je Woche.
    static func aktivitaet(gymTage: Int) -> Int {
        switch gymTage {
        case ...1: 1
        case 2...3: 2
        case 4...5: 3
        default: 4
        }
    }

    /// 0 = abnehmen, 1 = halten, 2 = zunehmen (wie `ErnaehrungsZiele.richtung`).
    static func richtung(_ art: Zielart) -> Int {
        switch art {
        case .abnehmen: 0
        case .halten: 1
        case .aufbauen: 2
        }
    }

    /// Ernährungsziele mit neu berechneten Kalorien und Makros. `bisher` behält Felder wie Fastenfenster und flexible Tage.
    static func ernaehrung(koerper: Koerperdaten, art: Zielart, gymTage: Int, kg: Double?, jahr: Int, bisher: ErnaehrungsZiele = ErnaehrungsZiele()) -> ErnaehrungsZiele {
        var z = bisher
        z.geschlecht = koerper.geschlecht == .weiblich ? 1 : 0
        if let cm = koerper.groesseCm, cm > 0 { z.groesseCm = cm }
        if let alter = alter(geburtsjahr: koerper.geburtsjahr, jahr: jahr) { z.alter = alter }
        z.richtung = richtung(art)
        z.aktivitaet = aktivitaet(gymTage: gymTage)
        z.makroProfil = art == .aufbauen ? 1 : 0
        return ErnaehrungLogik.berechnet(z, kg: gewichtOderStandard(kg, geschlecht: koerper.geschlecht))
    }

    /// Die vorgeschlagenen Ziele. Das Gewichtsziel (`gewichtKg`) schlägt die App nie vor, das entscheidet der Mensch.
    static func vorschlag(koerper: Koerperdaten, art: Zielart, gymTage: Int, kg: Double?, jahr: Int, bisher: Ziele = Ziele()) -> Ziele {
        let essen = ernaehrung(koerper: koerper, art: art, gymTage: gymTage, kg: kg, jahr: jahr)
        var z = bisher
        z.art = art
        z.gymTageProWoche = min(max(gymTage, 1), 7)
        z.kalorien = essen.kcal
        z.proteinGramm = essen.protein
        z.schritte = art == .aufbauen ? 8_000 : 10_000
        z.schlafMinuten = 480
        if let kg { z.wasserMl = min(max(Int((kg * 35 / 100).rounded()) * 100, 1_500), 4_000) }
        return z
    }

    /// Spiegelt die Ziele in die Ernährungsziele des Essen-Moduls (`essen-ziele.json`): Kalorien und Protein wie eingegeben,
    /// Fett 30 Prozent der Kalorien, Kohlenhydrate der Rest.
    static func ernaehrungsZiele(aus ziele: Ziele, koerper: Koerperdaten, bisher: ErnaehrungsZiele, jahr: Int) -> ErnaehrungsZiele {
        var z = bisher
        z.kcal = ziele.kalorien
        z.protein = ziele.proteinGramm
        let fett = Double(ziele.kalorien) * 0.30 / 9
        z.fett = Int(fett.rounded())
        z.kohlenhydrate = max(0, Int(((Double(ziele.kalorien) - Double(ziele.proteinGramm) * 4 - fett * 9) / 4).rounded()))
        z.richtung = richtung(ziele.art)
        z.geschlecht = koerper.geschlecht == .weiblich ? 1 : 0
        if let cm = koerper.groesseCm, cm > 0 { z.groesseCm = cm }
        if let alter = alter(geburtsjahr: koerper.geburtsjahr, jahr: jahr) { z.alter = alter }
        return z
    }
}

/// Schreibt Ziele und Körperdaten an beide Orte, die sie lesen: `ZieleStore` und die Ernährungsziele im `EssenStore`.
@MainActor
enum ProfilZielSpeicher {
    static func sichere(ziele: Ziele, koerper: Koerperdaten, in daten: DatenSatz, jahr: Int) {
        daten.ziele.setze(ziele)
        daten.ziele.setzeKoerper(koerper)
        let bisher = daten.essen.ernaehrungsZiele
        daten.essen.zieleSichern(ProfilZielVorschlag.ernaehrungsZiele(aus: ziele, koerper: koerper, bisher: bisher, jahr: jahr))
    }

    static func jahr(_ jetzt: Date) -> Int { Datum.kalender.component(.year, from: jetzt) }
}
