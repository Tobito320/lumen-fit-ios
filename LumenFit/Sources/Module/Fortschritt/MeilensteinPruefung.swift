import Foundation

/// Alles, was die Prüfung der Medaillen braucht, als Werte (der Wächter liest sie aus den Stores, der Test baut sie von Hand).
struct MeilensteinDaten: Sendable {
    var sessions: [GymSession] = []
    /// Tag zu Wert der Gym-Gewohnheit (über 0 = abgehakt).
    var gymTage: [String: Int] = [:]
    var gymTageProWoche = 3
    var heute = "1970-01-01"
    /// Aufwachtag zu Schlafminuten.
    var schlafMinuten: [String: Int] = [:]
    var schlafZiel = 480
    /// Tag zu Zehntel-kg.
    var gewicht: [String: Int] = [:]
    var gewichtZielKg: Double?
    var essenTage: Set<String> = []
    /// Tage mit mindestens einem Frühstück-Eintrag.
    var fruehstueckTage = 0
    /// Tag zu Schritten (Health und Band).
    var schritte: [String: Int] = [:]
    var schrittZiel = 10_000
    /// Tag zu Kalorien und Protein samt dem Ziel dieses Tages (flexible Tage ändern es).
    var essenWerte: [String: EssenTagWerte] = [:]
    /// Hat die Person ihre Essensziele eingerichtet? Ohne sie gibt es keine Protein- und Kalorien-Medaillen.
    var essenZielDa = false

    /// Dieselben Daten ohne heute und später: so war der Stand gestern.
    var ohneHeute: MeilensteinDaten {
        var d = self
        d.sessions = sessions.filter { Datum.text($0.start) < heute }
        d.gymTage = gymTage.filter { $0.key < heute }
        d.schlafMinuten = schlafMinuten.filter { $0.key < heute }
        d.gewicht = gewicht.filter { $0.key < heute }
        d.essenTage = essenTage.filter { $0 < heute }
        d.schritte = schritte.filter { $0.key < heute }
        d.essenWerte = essenWerte.filter { $0.key < heute }
        return d
    }
}

struct EssenTagWerte: Equatable, Sendable {
    var kcal: Double
    var protein: Double
    var zielKcal: Int
    var zielProtein: Int
}

/// Die Zahlen hinter den Medaillen, einmal aus den Daten gerechnet.
struct MeilensteinZahlen: Equatable, Sendable {
    var gezaehlteSaetze = 0
    var gymTage = 0
    var volumenKg = 0.0
    var serieWochen = 0
    var rekorde = 0
    var wochenZielErreicht = false
    var ganzerKoerperInEinerWoche = false
    var langeEinheit = false
    var schlafSerie = 0
    var schlafNaechteImZiel = 0
    var gewichtGewogen = false
    var gewichtZielErreicht = false
    var essenTage = 0
    var fruehstueck = false
    /// Längste Folge von Wochen, in denen das Gym-Wochenziel erreicht war.
    var wochenzielSerie = 0
    var schrittSerie = 0
    var schrittTage = 0
    var proteinSerie = 0
    var proteinTage = 0
    var kalorienTage = 0
}

/// Idee 37: welche Medaillen sind fällig? Eine Funktion von den Daten zur Liste der Kennungen; vergeben wird einmal je Kennung (`MeilensteinStore.markiere`).
enum MeilensteinPruefung {
    /// Die sieben Gruppen, die "Ganzer Körper" in einer Woche verlangt (Nacken und Unterarme laufen mit, zählen aber nicht).
    static let ganzerKoerper: [MuskelGruppe] = [.brust, .ruecken, .schulter, .bizeps, .trizeps, .bauch, .beine]

    /// Fällige Kennungen in der Reihenfolge des Katalogs, ohne die, die schon erreicht sind.
    static func faellig(_ daten: MeilensteinDaten, schon: Set<String>, katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [String] {
        let offen = MeilensteinKatalog.alle.filter { !schon.contains($0.id) }
        guard !offen.isEmpty else { return [] }
        let z = zahlen(daten, katalog: katalog)
        return offen.map(\.id).filter { erfuellt($0, z) }
    }

    static func erfuellt(_ id: String, _ z: MeilensteinZahlen) -> Bool {
        switch id {
        case "erster-satz": z.gezaehlteSaetze >= 1
        case "erste-woche": z.wochenZielErreicht
        case "gym-10": z.gymTage >= 10
        case "gym-50": z.gymTage >= 50
        case "gym-100": z.gymTage >= 100
        case "gym-200": z.gymTage >= 200
        case "volumen-10000": z.volumenKg >= 10_000
        case "volumen-50000": z.volumenKg >= 50_000
        case "volumen-100000": z.volumenKg >= 100_000
        case "volumen-500000": z.volumenKg >= 500_000
        case "serie-4": z.serieWochen >= 4
        case "serie-12": z.serieWochen >= 12
        case "serie-26": z.serieWochen >= 26
        case "erster-rekord": z.rekorde >= 1
        case "rekorde-10": z.rekorde >= 10
        case "rekorde-25": z.rekorde >= 25
        case "ganzer-koerper": z.ganzerKoerperInEinerWoche
        case "lange-einheit": z.langeEinheit
        case "schlaf-7": z.schlafSerie >= 7
        case "schlaf-30": z.schlafNaechteImZiel >= 30
        case "wiegen-erste": z.gewichtGewogen
        case "gewicht-ziel": z.gewichtZielErreicht
        case "fruehstueck": z.fruehstueck
        case "tagebuch-7": z.essenTage >= 7
        case "tagebuch-30": z.essenTage >= 30
        case "wochenziel-4": z.wochenzielSerie >= 4
        case "wochenziel-12": z.wochenzielSerie >= 12
        case "wochenziel-26": z.wochenzielSerie >= 26
        case "schritte-7": z.schrittSerie >= 7
        case "schritte-30": z.schrittTage >= 30
        case "protein-7": z.proteinSerie >= 7
        case "protein-30": z.proteinTage >= 30
        case "kalorien-7": z.kalorienTage >= 7
        default: false
        }
    }

    static func zahlen(_ d: MeilensteinDaten, katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> MeilensteinZahlen {
        var z = MeilensteinZahlen()
        let tage = trainingsTage(d.sessions, gym: d.gymTage)
        z.gymTage = tage.count
        z.serieWochen = serieWochen(tage: tage, heute: d.heute)
        let proWoche = Dictionary(grouping: tage, by: { Datum.montagDerWoche($0) }).mapValues(\.count)
        z.wochenZielErreicht = proWoche.values.contains { $0 >= max(1, d.gymTageProWoche) }
        z.wochenzielSerie = laengsteFolge(proWoche.filter { $0.value >= max(1, d.gymTageProWoche) }.keys.sorted(), abstand: 7)

        let laeufe = d.sessions.flatMap(\.laeufe)
        z.gezaehlteSaetze = laeufe.reduce(0) { $0 + KonstanzRaster.gezaehlteSaetze($1) }
        z.volumenKg = laeufe.flatMap { KraftKurve.arbeitssaetze($0) }.reduce(0.0) { $0 + ($1.kg ?? 0) * Double($1.wdh) }
        z.rekorde = rekorde(d.sessions)
        z.ganzerKoerperInEinerWoche = hatGanzerKoerperWoche(d.sessions, katalog: katalog)
        z.langeEinheit = d.sessions.contains { s in
            guard let ende = s.ende else { return false }
            let dauer = ende.timeIntervalSince(s.start)
            return dauer >= 3600 && dauer <= TrainingLogik.langNach
        }

        z.schlafSerie = schlafSerie(d.schlafMinuten, ziel: d.schlafZiel)
        z.schlafNaechteImZiel = d.schlafZiel > 0 ? d.schlafMinuten.values.filter { $0 >= d.schlafZiel }.count : 0

        let punkte = MessLogik.punkte(d.gewicht)
        z.gewichtGewogen = !punkte.isEmpty
        if let ziel = d.gewichtZielKg, let erster = punkte.first, let jetzt = GewichtLogik.berechnet(d.gewicht) {
            // Wer schon am Ziel anfängt, hat nichts erreicht: der erste Wert lag mindestens 1 kg daneben.
            z.gewichtZielErreicht = abs(Double(erster.zehntel) / 10 - ziel) >= 1 && abs(Double(jetzt) / 10 - ziel) <= GewichtVerlauf.zielToleranz
        }

        z.essenTage = d.essenTage.count
        z.fruehstueck = d.fruehstueckTage >= 1

        let schrittTage = d.schrittZiel > 0 ? d.schritte.filter { $0.value >= d.schrittZiel }.keys.sorted() : []
        z.schrittTage = schrittTage.count
        z.schrittSerie = laengsteFolge(schrittTage, abstand: 1)
        if d.essenZielDa {
            let protein = d.essenWerte.filter { $0.value.zielProtein > 0 && $0.value.protein >= Double($0.value.zielProtein) }.keys.sorted()
            z.proteinTage = protein.count
            z.proteinSerie = laengsteFolge(protein, abstand: 1)
            // Im Rahmen heißt 85 bis 115 Prozent des Ziels, in beide Richtungen gleich. Heute zählt nie: der Tag ist noch nicht zu Ende.
            z.kalorienTage = d.essenWerte.filter {
                $0.key < d.heute && $0.value.zielKcal > 0 && (0.85...1.15).contains($0.value.kcal / Double($0.value.zielKcal))
            }.count
        }
        return z
    }

    /// Medaillen, die es ohne das nötige Ziel nicht gibt (Protein und Kalorien brauchen eingerichtete Essensziele).
    static func ohneZiel(essenZielDa: Bool) -> Set<String> { essenZielDa ? [] : ["protein-7", "protein-30", "kalorien-7"] }

    /// Ziel-Medaillen, die beim Prüfen schon aus früheren Tagen erfüllt waren (Update, neues Gerät, Health liefert spät Altdaten): sie werden vergeben, aber ohne Toast.
    static func stumm(_ neu: [String], _ d: MeilensteinDaten) -> Set<String> {
        let ziele = neu.filter { MeilensteinKatalog.neueIds.contains($0) }
        guard !ziele.isEmpty else { return [] }
        let gestern = zahlen(d.ohneHeute)
        return Set(ziele.filter { erfuellt($0, gestern) })
    }

    /// Längste Folge von Schlüsseln (Tage oder Wochenmontage, aufsteigend sortiert), die je `abstand` Tage auseinander liegen.
    static func laengsteFolge(_ sortiert: [String], abstand: Int) -> Int {
        var beste = 0, aktuell = 0
        var vorher: String?
        for tag in sortiert {
            if let v = vorher, Datum.addTage(v, abstand) == tag { aktuell += 1 } else { aktuell = 1 }
            beste = max(beste, aktuell)
            vorher = tag
        }
        return beste
    }

    /// Tage mit Training: Einheiten und Gym-Häkchen zusammen, jeder Tag einmal.
    static func trainingsTage(_ sessions: [GymSession], gym: [String: Int]) -> Set<String> {
        Set(sessions.map { Datum.text($0.start) }).union(gym.filter { $0.value > 0 }.keys)
    }

    /// Wochen in Folge mit mindestens einem Trainingstag (Mo bis So). Die laufende Woche zählt mit, wenn schon trainiert wurde; ist sie leer, bricht sie die Serie nicht.
    static func serieWochen(tage: Set<String>, heute: String) -> Int {
        let wochen = Set(tage.map { Datum.montagDerWoche($0) })
        var montag = Datum.montagDerWoche(heute)
        if !wochen.contains(montag) { montag = Datum.addTage(montag, -7) }
        var serie = 0
        while wochen.contains(montag) {
            serie += 1
            montag = Datum.addTage(montag, -7)
        }
        return serie
    }

    /// Wie oft ein Satz den bisherigen Bestwert (geschätztes 1RM) einer Übung geschlagen hat, je Einheit höchstens einmal je Übung. Das erste Mal ist kein Rekord.
    static func rekorde(_ sessions: [GymSession]) -> Int {
        var bestwert: [String: Double] = [:]
        var anzahl = 0
        for s in sessions.sorted(by: { $0.start < $1.start }) {
            var heutig: [String: Double] = [:]
            for lauf in s.laeufe {
                guard let e = KraftKurve.arbeitssaetze(lauf).compactMap(VerlaufLogik.e1rm).max() else { continue }
                heutig[lauf.uebung] = max(heutig[lauf.uebung] ?? 0, e)
            }
            for (uebung, e) in heutig {
                if let alt = bestwert[uebung], e > alt { anzahl += 1 }
                bestwert[uebung] = max(bestwert[uebung] ?? 0, e)
            }
        }
        return anzahl
    }

    /// Gab es eine Woche, in der alle Gruppen aus `ganzerKoerper` gezählte Sätze hatten?
    static func hatGanzerKoerperWoche(_ sessions: [GymSession], katalog: (String) -> Uebung?) -> Bool {
        let sauber = SaetzeProMuskel.ohneAufwaermen(sessions)
        // Einmal nach Woche gruppieren: je Woche alle Einheiten durchzugehen wuchs mit Wochen mal Einheiten (bei jedem Haken, Sekunden nach einem Jahr).
        let proWoche = Dictionary(grouping: sauber) { Datum.montagDerWoche(Datum.text($0.start)) }
        return proWoche.contains { woche in
            let teile = MuskelLogik.wochenSaetze(woche.value, woche: woche.key, katalog: katalog)
            let gruppen = Set(teile.filter { $0.value > 0 }.keys.map(\.gruppe))
            return ganzerKoerper.allSatisfy { gruppen.contains($0) }
        }
    }

    /// Längste Folge von Tagen hintereinander mit mindestens `ziel` Minuten Schlaf.
    static func schlafSerie(_ minuten: [String: Int], ziel: Int) -> Int {
        guard ziel > 0 else { return 0 }
        return laengsteFolge(minuten.filter { $0.value >= ziel }.keys.sorted(), abstand: 1)
    }
}

extension MeilensteinDaten {
    /// Liest alles aus dem Datensatz des Profils (der Wächter und die Seite brauchen dieselben Zahlen). `fruehstueckTage` kennt nur der Wächter.
    @MainActor
    static func aus(_ daten: DatenSatz, naechte: [String: SchlafNacht], schritte: [String: Int], heute: String, fruehstueckTage: Int = 0) -> MeilensteinDaten {
        let ziele = daten.ziele.ziele
        let essenZiele = daten.essen.ernaehrungsZiele
        var werte: [String: EssenTagWerte] = [:]
        if essenZiele.eingerichtet {
            for tag in daten.essen.tage {
                let summe = daten.essen.summe(tag)
                let ziel = daten.essen.ernaehrungsZiele(tag: tag)
                werte[tag] = EssenTagWerte(kcal: summe.kcal, protein: summe.protein, zielKcal: ziel.kcal, zielProtein: ziel.protein)
            }
        }
        return MeilensteinDaten(
            sessions: daten.training.sessions, gymTage: daten.habits.werte(Habit.gym.id), gymTageProWoche: ziele.gymTageProWoche, heute: heute,
            schlafMinuten: naechte.mapValues(\.schlafMinuten), schlafZiel: ziele.schlafMinuten,
            gewicht: daten.habits.werte(Habit.gewicht.id), gewichtZielKg: ziele.gewichtKg,
            essenTage: daten.essen.tage, fruehstueckTage: fruehstueckTage,
            schritte: schritte, schrittZiel: ziele.schritte, essenWerte: werte, essenZielDa: essenZiele.eingerichtet)
    }
}
