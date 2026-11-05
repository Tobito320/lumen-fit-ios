import Foundation

/// Modul essen: Tagebuch, Scan, Quellen, Ampel, Fasten, Ziele, Analyse. Es fragt nie von selbst das Netz: der Server nur beim Tippen und Scannen,
/// Open Food Facts nur als Barcode-Rückfall, der BLS-Index lädt erst, wenn der Essen-Tab erscheint.
enum EssenModul {
    @MainActor private static var gemeinsam: (umgebung: ObjectIdentifier, suche: LebensmittelSuche)?

    /// Idempotent und synchron. Legt nur die Suche samt Quellen an (ohne Abfrage); der Limiter lebt damit so lange wie die App.
    @MainActor static func start(_ umgebung: AppUmgebung) {
        _ = suche(umgebung)
        EssenLiveModul.start(umgebung)
    }

    /// Die eine Suche der App: BLS lokal, Produkte vom Lumen-Server, Open Food Facts (Barcode-Rückfall, Rate-Limit) über `umgebung.http`, Barcodes aus dem Speicher des aktiven Profils.
    @MainActor static func suche(_ umgebung: AppUmgebung) -> LebensmittelSuche {
        let kennung = ObjectIdentifier(umgebung)
        if let vorhanden = gemeinsam, vorhanden.umgebung == kennung { return vorhanden.suche }
        let quelle = OpenFoodFactsQuelle(lader: umgebung.http, uhr: umgebung.uhr)
        let zugang = EssenKiKontoZugang(zugang: KontoZugang.lade(), schluesselbund: umgebung.schluesselbund, version: KontoDienst.appVersion)
        let neu = LebensmittelSuche(index: .shared, off: quelle, server: EssenServerQuelle(zugang: zugang, lader: umgebung.http), speicher: { [weak umgebung] code in umgebung?.daten?.essen.offline(barcode: code) })
        gemeinsam = (kennung, neu)
        return neu
    }

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte): eine Woche Tagebuch, Favoriten, ein Gericht, Fasten-Fenster und Körperdaten.
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {
        guard let daten = umgebung.daten else { return }
        let essen = daten.essen
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)

        if essen.gewichtKg == nil { essen.gewichtSetzen(zehntel: 782, datum: heute) }
        if daten.ziele.koerper == Koerperdaten() {
            daten.ziele.koerper = Koerperdaten(groesseCm: 181, geburtsjahr: 1998, geschlecht: .maennlich)
        }

        let hafer = Lebensmittel(id: "bls-C131000", name: "Hafer ganzes Korn, roh", fluessig: false,
                                 pro100: Naehrwerte(kcal: 343, protein: 11.4, kohlenhydrate: 53.7, fett: 7.1, zucker: 1.1, ballaststoffe: 9.3, salz: 0.02, gesFett: 1.4,
                                                    mikro: ["eisen": 4.2, "zink": 3.1, "magnesium": 140, "vitaminE": 1.3]), quelle: "bls")
        let ei = Lebensmittel(id: "bls-E111100", name: "Hühnerei roh", pro100: Naehrwerte(kcal: 135, protein: 13.2, kohlenhydrate: 0.3, fett: 9, zucker: 0.3, ballaststoffe: 0,
                                                                                           salz: 0.39, gesFett: 2.4, mikro: ["vitaminA": 262, "vitaminD": 1.8, "vitaminE": 1.2]),
                              portionMenge: 55, portionName: "ganze, mittelgroß", quelle: "bls")
        let skyr = Lebensmittel(id: "off-4311501679715", name: "Skyr Natur", marke: "Beispielmarke", barcode: "4311501679715",
                                pro100: Naehrwerte(kcal: 63, protein: 11, kohlenhydrate: 4, fett: 0.2, zucker: 3.8, ballaststoffe: 0, salz: 0.1),
                                portionMenge: 150, packungMenge: 450, quelle: "off", zutaten: "Magermilch, Joghurtkulturen, Lab")
        let reis = Lebensmittel(id: "bls-demo-reis", name: "Reis gekocht", pro100: Naehrwerte(kcal: 130, protein: 2.7, kohlenhydrate: 28, fett: 0.3, ballaststoffe: 0.4), quelle: "bls")
        let haehnchen = Lebensmittel(id: "bls-demo-haehnchen", name: "Hähnchenbrust, gebraten", pro100: Naehrwerte(kcal: 165, protein: 31, kohlenhydrate: 0, fett: 3.6, zucker: 0, salz: 0.2), quelle: "bls")
        let brokkoli = Lebensmittel(id: "bls-demo-brokkoli", name: "Brokkoli, gegart", pro100: Naehrwerte(kcal: 35, protein: 2.4, kohlenhydrate: 4, fett: 0.4, zucker: 1.7, ballaststoffe: 3.3,
                                                                                                   mikro: ["vitaminC": 64, "calcium": 40, "eisen": 0.7, "folat": 108]), quelle: "bls")
        let nuesse = Lebensmittel(id: "bls-demo-walnuss", name: "Walnuss", pro100: Naehrwerte(kcal: 700, protein: 15, kohlenhydrate: 7, fett: 66, zucker: 2.7, ballaststoffe: 6.7), quelle: "bls")

        func tagesplan(_ tag: String, skyrGramm: Double, haehnchenGramm: Double, mitFruehstueck: Bool) {
            if mitFruehstueck {
                essen.eintragen(hafer, menge: 60, einheit: .g, mahlzeit: .fruehstueck, datum: tag)
                essen.eintragen(skyr, menge: skyrGramm, einheit: .g, mahlzeit: .fruehstueck, datum: tag)
            }
            essen.eintragen(reis, menge: 180, einheit: .g, mahlzeit: .mittag, datum: tag)
            essen.eintragen(haehnchen, menge: haehnchenGramm, einheit: .g, mahlzeit: .mittag, datum: tag)
            essen.eintragen(brokkoli, menge: 150, einheit: .g, mahlzeit: .mittag, datum: tag)
        }
        // Sechs Tage davor mit wechselnder Menge, einer bleibt leer (Tage ohne Eintrag sind keine Null).
        let verlauf: [(Int, Double, Double)] = [(6, 150, 120), (5, 200, 150), (4, 250, 180), (2, 200, 100), (1, 300, 200)]
        for (zurueck, skyrGramm, haehnchenGramm) in verlauf {
            tagesplan(Datum.addTage(heute, -zurueck), skyrGramm: skyrGramm, haehnchenGramm: haehnchenGramm, mitFruehstueck: true)
        }
        // Heute: Frühstück und Mittag, dazu zwei Eier und ein Snack.
        tagesplan(heute, skyrGramm: 200, haehnchenGramm: 150, mitFruehstueck: true)
        essen.eintragen(ei, menge: 2, einheit: .portion, mahlzeit: .fruehstueck, datum: heute)
        essen.eintragen(nuesse, menge: 30, einheit: .g, mahlzeit: .snack, datum: heute)

        essen.favoritSetzen(skyr, an: true)
        essen.favoritSetzen(ei, an: true)
        let schale = Rezept(id: "demo-schale", name: "Haferschale mit Skyr", portionen: 1,
                            zutaten: [Zutat(id: "z1", lebensmittel: hafer, menge: 60, einheit: .g), Zutat(id: "z2", lebensmittel: skyr, menge: 200, einheit: .g)], art: .mahlzeit)
        essen.rezeptSichern(schale)
        essen.favoritSetzen(ErnaehrungLogik.alsLebensmittel(schale), an: true)

        // Fasten: drei beendete Fenster und eins, das seit fünf Stunden läuft.
        for (zurueck, stunden) in [(3, 16.5), (2, 15.0), (1, 17.0)] as [(Int, Double)] {
            let start = jetzt.addingTimeInterval(-Double(zurueck) * 86_400 - 6 * 3600)
            essen.fastenAendern(FastenEintrag(id: "demo-fasten-\(zurueck)", start: start, ende: start.addingTimeInterval(stunden * 3600), plan: FastenPlan.sechzehn.rawValue, geloescht: nil))
        }
        essen.fastenAendern(FastenEintrag(id: "demo-fasten-lauft", start: jetzt.addingTimeInterval(-5 * 3600), ende: nil, plan: FastenPlan.sechzehn.rawValue, geloescht: nil))
    }
}
