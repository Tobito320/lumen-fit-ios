import Foundation

/// Der Vorschlag "aus deinen Körperdaten" (Idee 49): Kalorien und Protein aus Größe, Alter, Geschlecht, Gewicht, Aktivität und Ziel.
struct ZielVorschlag: Equatable, Sendable {
    /// Die vollständigen Ernährungsziele; nil, solange Angaben fehlen.
    let ziele: ErnaehrungsZiele?
    let grundumsatz: Int
    let bedarf: Int
    /// kcal pro Tag mehr (aufbauen) oder weniger (abnehmen) als der Bedarf.
    let aenderung: Int
    /// Was fehlt, in Worten für den Nutzer ("Größe", "Geburtsjahr", "Gewicht").
    let fehlt: [String]
    let erklaerung: String
}

enum ZielKarteLogik {
    /// `Zielart` (aufbauen, halten, abnehmen) gegen `ErnaehrungsZiele.richtung` (0 abnehmen, 1 halten, 2 zunehmen): die Reihenfolge ist umgekehrt.
    static func richtung(_ art: Zielart) -> Int {
        switch art {
        case .abnehmen: 0
        case .halten: 1
        case .aufbauen: 2
        }
    }

    /// Alter in Jahren aus dem Geburtsjahr (ohne Geburtstag: das Jahr genügt für die Rechnung).
    static func alter(geburtsjahr: Int, heute: Date) -> Int {
        max(0, Datum.kalender.component(.year, from: heute) - geburtsjahr)
    }

    /// Rechnet nur mit echten Angaben. Fehlt Größe, Geburtsjahr, Geschlecht oder Gewicht, steht es in `fehlt` und `ziele` ist nil.
    /// `aktuell` liefert Aktivität und die übrigen Einstellungen (Fasten, flexible Tage), die bleiben erhalten.
    static func vorschlag(koerper: Koerperdaten, art: Zielart, kg: Double?, aktuell: ErnaehrungsZiele, heute: Date) -> ZielVorschlag {
        // `fehlt` bleibt deutsch (die Karte vergleicht "Gewicht"), `fehltText` ist die Anzeige.
        var fehlt: [String] = []
        var fehltText: [String] = []
        if koerper.groesseCm == nil { fehlt.append("Größe"); fehltText.append(String(localized: "Größe")) }
        if koerper.geburtsjahr == nil { fehlt.append("Geburtsjahr"); fehltText.append(String(localized: "Geburtsjahr")) }
        if koerper.geschlecht == nil { fehlt.append("Geschlecht"); fehltText.append(String(localized: "Geschlecht")) }
        if kg == nil || (kg ?? 0) <= 0 { fehlt.append("Gewicht"); fehltText.append(String(localized: "Gewicht")) }
        guard fehlt.isEmpty, let groesse = koerper.groesseCm, let jahr = koerper.geburtsjahr, let geschlecht = koerper.geschlecht, let kg else {
            return ZielVorschlag(ziele: nil, grundumsatz: 0, bedarf: 0, aenderung: 0, fehlt: fehlt,
                                 erklaerung: String(localized: "Für die Rechnung fehlt noch: \(fehltText.joined(separator: ", "))"))
        }
        var z = aktuell
        z.groesseCm = groesse
        z.alter = alter(geburtsjahr: jahr, heute: heute)
        z.richtung = richtung(art)
        z.tempo = art == .aufbauen ? 250 : 500
        // Aufbauen und Abnehmen: proteinreich (mindestens 2 g je kg), Halten: ausgewogen.
        z.makroProfil = art == .halten ? 0 : 1
        let faktor = ErnaehrungLogik.aktivitaeten[min(max(z.aktivitaet, 0), ErnaehrungLogik.aktivitaeten.count - 1)].faktor
        let ergebnis: ErnaehrungsZiele
        let grundumsatz: Double
        switch geschlecht {
        case .maennlich:
            z.geschlecht = 0
            ergebnis = ErnaehrungLogik.berechnet(z, kg: kg)
            grundumsatz = ErnaehrungLogik.grundumsatz(frau: false, kg: kg, cm: Double(groesse), alter: z.alter)
        case .weiblich:
            z.geschlecht = 1
            ergebnis = ErnaehrungLogik.berechnet(z, kg: kg)
            grundumsatz = ErnaehrungLogik.grundumsatz(frau: true, kg: kg, cm: Double(groesse), alter: z.alter)
        case .divers:
            // Mifflin-St Jeor kennt nur zwei Formeln: bei "divers" der Mittelwert beider.
            var mann = z; mann.geschlecht = 0
            var frau = z; frau.geschlecht = 1
            let a = ErnaehrungLogik.berechnet(mann, kg: kg), b = ErnaehrungLogik.berechnet(frau, kg: kg)
            var mitte = a
            mitte.kcal = Int((Double(a.kcal + b.kcal) / 20).rounded()) * 10
            let makros = ErnaehrungLogik.makros(kcal: mitte.kcal, kg: kg, profil: z.makroProfil)
            mitte.protein = makros.protein; mitte.kohlenhydrate = makros.kohlenhydrate; mitte.fett = makros.fett
            ergebnis = mitte
            grundumsatz = (ErnaehrungLogik.grundumsatz(frau: false, kg: kg, cm: Double(groesse), alter: z.alter)
                           + ErnaehrungLogik.grundumsatz(frau: true, kg: kg, cm: Double(groesse), alter: z.alter)) / 2
        }
        let bedarf = grundumsatz * faktor
        let aenderung = Int((Double(z.tempo) * 1.1 * Double(z.richtung - 1)).rounded())
        return ZielVorschlag(ziele: ergebnis, grundumsatz: Int(grundumsatz.rounded()), bedarf: Int(bedarf.rounded()), aenderung: aenderung, fehlt: [],
                             erklaerung: erklaerung(art: art, grundumsatz: grundumsatz, faktor: faktor, bedarf: bedarf, aenderung: aenderung, kg: kg, ergebnis: ergebnis))
    }

    /// Eigene Werte über dem Vorschlag: Kalorien und Protein sind frei, Fett aus dem Makroprofil, Kohlenhydrate füllen den Rest.
    static func angepasst(_ z: ErnaehrungsZiele, kcal: Int, protein: Int, kg: Double) -> ErnaehrungsZiele {
        var neu = z
        neu.kcal = kcal
        neu.protein = protein
        let m = ErnaehrungLogik.makros(kcal: kcal, kg: kg, profil: z.makroProfil)
        neu.fett = m.fett
        neu.kohlenhydrate = Int((max(0, Double(kcal) - Double(protein) * 4 - Double(m.fett) * 9) / 4).rounded())
        return neu
    }

    private static func erklaerung(art: Zielart, grundumsatz: Double, faktor: Double, bedarf: Double, aenderung: Int, kg: Double, ergebnis: ErnaehrungsZiele) -> String {
        let faktorText = faktor.formatted(.number.precision(.fractionLength(0...3)).locale(Datum.anzeigeLocale))
        var text = String(localized: "Dein Grundumsatz ist rund \(tausend(Int(grundumsatz.rounded()))) kcal (Mifflin-St Jeor). Mal Aktivität \(faktorText) ergibt einen Bedarf von \(tausend(Int(bedarf.rounded()))) kcal.")
        switch art {
        case .halten: text += " " + String(localized: "Du willst dein Gewicht halten, also isst du so viel.")
        case .aufbauen: text += " " + String(localized: "Zum Aufbauen kommen rund \(aenderung) kcal dazu.")
        case .abnehmen: text += " " + String(localized: "Zum Abnehmen gehen rund \(-aenderung) kcal ab.")
        }
        text += " " + String(localized: "Protein: \(ergebnis.protein) g, bei \(Int(kg.rounded())) kg etwa \(ErnaehrungLogik.zahl(Double(ergebnis.protein) / kg)) g je kg.")

        return text
    }

    private static func tausend(_ n: Int) -> String { n.formatted(.number.grouping(.automatic).locale(Datum.anzeigeLocale)) }
}
