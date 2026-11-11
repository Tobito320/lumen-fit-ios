import Foundation

/// Warum ein Spitzname nicht geht: so meldet ihn auch der Server (`spitzname_<grund>`).
enum StatsSpitznameGrund: String, Sendable {
    case laenge, zeichen, buchstaben, unpassend, vergeben
}

/// Eine Übung mit ihrem schwersten Gewicht (Katalog-Id).
struct StatsUebungKg: Equatable, Sendable {
    var id: String
    var kg: Double
}

/// Eigene Schritte für Stats: Kalendertag (Berlin), Schritte an dem Tag und Summe vom 1. des Monats bis zu dem Tag.
struct StatsSchritte: Equatable, Sendable {
    var tag: String
    var heute: Int
    var monat: Int
}

/// Was die Seite vom Gerät braucht, einmal gerechnet (nicht in jedem `body`): Zahlen dieser Woche, Trainingsjahr, Hauptübungen, Schritte (nil = nicht dabei).
struct StatsEigene: Equatable, Sendable {
    var zahlen = StatsZahlen()
    var jahr = 1
    var hauptuebungen: [StatsUebungKg] = []
    var schritte: StatsSchritte?
}

/// Reine Regeln für Stats: Plätze, Prozent, Ausschnitt der Liste, Trainingsjahr, Rekorde im Vergleich, Spitzname, was zum Server geht.
/// Privat rechnet alles auf dem Gerät; die Liste der Öffentlichen kommt vom Server (`StatsAntwort`).
enum StatsLogik {
    /// Ab so vielen anderen im selben Trainingsjahr vergleicht Alle nur mit ihnen ("Alle im 1. Jahr"), sonst mit allen.
    static let kohorteAb = 10
    /// Die ersten Plätze in Alle; darunter "···" und die Nachbarn um den eigenen Platz.
    static let oben = 5
    /// So viele Übungen gehen mit ihrem schwersten Gewicht zum Server (die am meisten gemachten).
    static let hauptuebungenGrenze = 20
    /// Mehr Schritte an einem Tag zählen nicht (gleiche Grenze wie `server/stats.js`).
    static let schritteJeTagGrenze = 100_000

    /// Zahl mit Tausenderpunkt ("187.300").
    static func zahl(_ n: Int) -> String { n.formatted(.number.locale(Datum.anzeigeLocale)) }

    // MARK: Plätze

    /// Ich und die anderen als Rangliste: höherer Wert vorn, gleicher Wert gleicher Platz, ich zuerst unter Gleichen (`CrewLogik.raenge`).
    /// Ohne eigenen Wert (Schritte nicht mitgezählt) stehe ich nicht drin.
    static func zeilen(ichName: String, ichWert: Int?, andere: [(id: String, name: String, wert: Int)]) -> [CrewRang] {
        CrewLogik.raenge((ichWert.map { [CrewRang(id: CrewRang.eigeneId, name: ichName, wert: $0, rang: 0, ich: true)] } ?? [])
            + andere.map { CrewRang(id: $0.id, name: $0.name, wert: $0.wert, rang: 0, ich: false) })
    }

    /// Mein Platz; nil, wenn ich nicht in der Liste stehe.
    static func platz(_ zeilen: [CrewRang]) -> (rang: Int?, von: Int) {
        (zeilen.first(where: \.ich)?.rang, max(zeilen.count, 1))
    }

    /// Satz unter dem Platz bei Freunden: wie viel bis zum nächsten Platz fehlt, oder dass ich vorn bin. Allein: nil.
    static func satzFreunde(_ zeilen: [CrewRang], mass: StatsMass) -> String? {
        guard zeilen.count > 1, let i = zeilen.firstIndex(where: \.ich) else { return nil }
        guard let vor = zeilen[..<i].last(where: { $0.wert > zeilen[i].wert }) else { return String(localized: "Du führst. Bleib dran.") }
        let n = vor.wert - zeilen[i].wert + 1
        let k = vor.rang
        switch mass {
        case .punkte: return n == 1 ? String(localized: "Noch 1 Punkt bis Platz \(k).") : String(localized: "Noch \(n) Punkte bis Platz \(k).")
        case .trainings: return n == 1 ? String(localized: "Noch 1 Training bis Platz \(k).") : String(localized: "Noch \(n) Trainings bis Platz \(k).")
        case .sets: return n == 1 ? String(localized: "Noch 1 Set bis Platz \(k).") : String(localized: "Noch \(n) Sets bis Platz \(k).")
        case .serie: return n == 1 ? String(localized: "Noch 1 Woche bis Platz \(k).") : String(localized: "Noch \(n) Wochen bis Platz \(k).")
        case .schritteHeute, .schritteMonat:
            return n == 1 ? String(localized: "Noch 1 Schritt bis Platz \(k).") : String(localized: "Noch \(zahl(n)) Schritte bis Platz \(k).")
        }
    }

    /// Anteil der anderen mit weniger als ich, abgerundet; ohne andere nil.
    static func prozent(mein: Double, andere: [Double]) -> Int? {
        guard !andere.isEmpty else { return nil }
        return Int((Double(andere.filter { $0 < mein }.count) / Double(andere.count) * 100).rounded(.down))
    }

    /// Dasselbe aus einer Verteilung [[Wert, Anzahl]] vom Server.
    static func prozent(mein: Double, verteilung: [[Double]]) -> Int? {
        let paare = verteilung.filter { $0.count == 2 && $0[1] > 0 }
        let gesamt = paare.reduce(0) { $0 + $1[1] }
        guard gesamt > 0 else { return nil }
        let weniger = paare.filter { $0[0] < mein }.reduce(0) { $0 + $1[1] }
        return Int((weniger / gesamt * 100).rounded(.down))
    }

    /// Satz unter dem Platz bei Alle: "Öfter dabei als 76 % der Leute im 1. Jahr."
    static func satzAlle(prozent p: Int, mass: StatsMass, jahr: Int?) -> String {
        if let jahr {
            let gruppe = jahrText(jahr)
            switch mass {
            case .punkte: return String(localized: "Mehr Punkte als \(p) % der Leute \(gruppe).")
            case .trainings: return String(localized: "Öfter dabei als \(p) % der Leute \(gruppe).")
            case .sets: return String(localized: "Mehr Sets als \(p) % der Leute \(gruppe).")
            case .serie: return String(localized: "Längere Serie als \(p) % der Leute \(gruppe).")
            case .schritteHeute, .schritteMonat: return String(localized: "Mehr Schritte als \(p) % der Leute \(gruppe).")
            }
        }
        switch mass {
        case .punkte: return String(localized: "Mehr Punkte als \(p) % der Leute.")
        case .trainings: return String(localized: "Öfter dabei als \(p) % der Leute.")
        case .sets: return String(localized: "Mehr Sets als \(p) % der Leute.")
        case .serie: return String(localized: "Längere Serie als \(p) % der Leute.")
        case .schritteHeute, .schritteMonat: return String(localized: "Mehr Schritte als \(p) % der Leute.")
        }
    }

    /// Welche Zeilen Alle zeigt: die ersten `oben`, dann eine Lücke (nil) und die Nachbarn um mich (Index `ich`). Fehlt nur eine Zeile, steht sie da.
    static func ausschnitt(anzahl: Int, ich: Int?, oben: Int = StatsLogik.oben) -> [Int?] {
        var drin = Set(0..<max(0, min(oben, anzahl)))
        if let ich { for i in (ich - 1)...(ich + 1) where i >= 0 && i < anzahl { drin.insert(i) } }
        var aus: [Int?] = []
        for i in drin.sorted() {
            if let letzte = aus.last, let l = letzte, i > l + 1 { aus.append(i == l + 2 ? l + 1 : nil) }
            aus.append(i)
        }
        return aus
    }

    // MARK: Trainingsjahr

    /// 1 = im ersten Jahr, höchstens 5 (ab dem 5. Jahr). Beginn: das erste Training in der App, früher, wenn die Antwort der Einführung mehr sagt.
    static func trainingsjahr(sessions: [GymSession], erfahrung: TrainingsErfahrung?, jetzt: Date) -> Int {
        let tage: Double = switch erfahrung {
        case .geradeAngefangen, nil: 0
        case .unterSechsMonate: 90
        case .bisZweiJahre: 456
        case .laenger: 800
        }
        let erstes = sessions.filter { s in s.laeufe.contains { !CrewLogik.saetze($0).isEmpty } }.map(\.start).min() ?? jetzt
        let beginn = min(erstes, jetzt.addingTimeInterval(-tage * 86400))
        return min(max(Int(jetzt.timeIntervalSince(beginn) / (365.25 * 86400)) + 1, 1), 5)
    }

    /// "im 1. Jahr" … "ab dem 5. Jahr".
    static func jahrText(_ jahr: Int) -> String {
        jahr >= 5 ? String(localized: "ab dem 5. Jahr") : String(localized: "im \(jahr). Jahr")
    }

    /// Mit wem Alle vergleicht: mit denen im selben Trainingsjahr, wenn es genug sind, sonst mit allen (jahr nil). Der eigene Eintrag fällt raus.
    /// Ohne Jahr (Schritte) immer mit allen.
    static func vergleich(_ alle: [StatsEintrag], jahr: Int?) -> (andere: [StatsEintrag], jahr: Int?) {
        let andere = alle.filter { !$0.ich }
        guard let jahr else { return (andere, nil) }
        let gleich = andere.filter { min($0.jahr ?? 1, 5) == jahr }
        if gleich.count >= kohorteAb { return (gleich, jahr) }
        return (andere, nil)
    }

    // MARK: Rekorde

    /// Die Übungen mit Gewicht, die man am meisten macht (aus dem Katalog, ohne Körpergewicht), mit dem schwersten Gewicht.
    static func hauptuebungen(_ sessions: [GymSession], grenze: Int = StatsLogik.hauptuebungenGrenze) -> [StatsUebungKg] {
        var anzahl: [String: Int] = [:]
        var bestes: [String: Double] = [:]
        for s in sessions {
            for l in s.laeufe where l.uebung != PlanUebung.eigen {
                guard UebungsKatalog.nachId[l.uebung].map({ $0.geraet != "Körpergewicht" }) == true,
                      let kg = RekordLogik.wert(CrewLogik.saetze(l), .gewicht) else { continue }
                anzahl[l.uebung, default: 0] += 1
                bestes[l.uebung] = max(bestes[l.uebung] ?? 0, kg)
            }
        }
        let sortiert = bestes.keys.sorted { a, b in
            let (x, y) = (anzahl[a] ?? 0, anzahl[b] ?? 0)
            return x != y ? x > y : a < b
        }
        return sortiert.prefix(grenze).map { StatsUebungKg(id: $0, kg: min(bestes[$0] ?? 0, 1000)) }
    }

    static func eigene(sessions: [GymSession], erfahrung: TrainingsErfahrung?, jetzt: Date) -> StatsEigene {
        StatsEigene(zahlen: StatsPunkte.zahlen(sessions, jetzt: jetzt), jahr: trainingsjahr(sessions: sessions, erfahrung: erfahrung, jetzt: jetzt),
                    hauptuebungen: hauptuebungen(sessions))
    }

    /// Mein Platz mit diesem Gewicht unter den Freunden, die die Übung auch machen.
    static func platzFreunde(kg: Double, uebung: String, freunde: [StatsFreund]) -> (rang: Int, von: Int) {
        let andere = freunde.compactMap { $0.rekorde[uebung] }
        return (1 + andere.filter { $0 > kg }.count, 1 + andere.count)
    }

    /// "Stärker als P %": aus der Verteilung des Trainingsjahrs, sonst aus der aller; ohne genug Leute nil.
    static func prozentAlle(kg: Double, uebung: String, rekorde: [String: [String: [[Double]]]], jahr: Int?) -> (prozent: Int, jahr: Int?)? {
        let gruppen = rekorde[uebung] ?? [:]
        if let jahr, let v = gruppen[String(jahr)], let p = prozent(mein: kg, verteilung: v) { return (p, jahr) }
        if let v = gruppen["alle"], let p = prozent(mein: kg, verteilung: v) { return (p, nil) }
        return nil
    }

    // MARK: Schritte

    /// Schritte aus Apple Health (Tagessummen, `GesundheitsStand.schritteAusHealth`; von Hand eingetragene zählen nicht): heute und seit dem 1.
    /// des Monats, ein Tag höchstens `schritteJeTagGrenze`. Nur mit der eigenen Zustimmung "Schritte teilen", Mitzählen > Schritte und Health-Freigabe;
    /// ohne einen Tag mit Schritten in Health (nicht erlaubt oder kein Gerät) nil.
    static func schritte(health: [String: Int], einstellungen e: Einstellungen, jetzt: Date) -> StatsSchritte? {
        guard e.statsSchritte, e.schritteMitzaehlen, e.healthGefragt, health.values.contains(where: { $0 > 0 }) else { return nil }
        let heute = Datum.text(jetzt)
        let monat = heute.prefix(7)
        let tag = { (n: Int) in min(max(n, 0), Self.schritteJeTagGrenze) }
        let summe = health.filter { $0.key.hasPrefix(monat) && $0.key <= heute }.values.reduce(0) { $0 + tag($1) }
        return StatsSchritte(tag: heute, heute: tag(health[heute] ?? 0), monat: summe)
    }

    // MARK: Zum Server

    /// Was `PUT /stats` bekommt. Privat (beide aus): nur die zwei Schalter, der Server löscht dann alles. Öffentlich nur mit Spitzname.
    /// Schritte nur nach `schritte(health:einstellungen:jetzt:)`, sonst fehlen die Felder (der Server löscht dann die alten).
    static func meldung(einstellungen e: Einstellungen, sessions: [GymSession], health: [String: Int] = [:], jetzt: Date) -> StatsMeldung {
        let oeffentlich = e.statsOeffentlich && e.statsSpitzname != nil
        guard e.statsFreunde || oeffentlich else { return .aus }
        let z = StatsPunkte.zahlen(sessions, jetzt: jetzt)
        let s = schritte(health: health, einstellungen: e, jetzt: jetzt)
        return StatsMeldung(
            freunde: e.statsFreunde, oeffentlich: oeffentlich, spitzname: oeffentlich ? e.statsSpitzname : nil,
            jahr: oeffentlich ? trainingsjahr(sessions: sessions, erfahrung: e.trainingsErfahrung, jetzt: jetzt) : nil,
            montag: Datum.wochenstart(Datum.text(jetzt)), trainings: min(z.trainings, 14), sets: min(z.sets, 500), rekordeNeu: min(z.rekorde, 100),
            serie: min(z.serie, 520), rekorde: Dictionary(hauptuebungen(sessions).map { ($0.id, $0.kg) }, uniquingKeysWith: { a, _ in a }),
            schritteTag: s?.tag, schritteHeute: s?.heute, schritteMonat: s?.monat)
    }

    // MARK: Spitzname

    /// Ohne Leerzeichen am Rand, mehrere Leerzeichen als eins (wie der Server).
    static func spitzname(_ roh: String) -> String {
        roh.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// Was das Gerät schon prüfen kann (Länge, Zeichen, zwei Buchstaben). Schimpfwörter und "vergeben" prüft nur der Server.
    static func spitznameGrund(_ roh: String) -> StatsSpitznameGrund? {
        let zeichen = spitzname(roh).precomposedStringWithCanonicalMapping.unicodeScalars
        guard (3...20).contains(zeichen.count) else { return .laenge }
        guard zeichen.allSatisfy(erlaubt) else { return .zeichen }
        guard zeichen.filter({ $0.properties.isAlphabetic }).count >= 2 else { return .buchstaben }
        return nil
    }

    /// Lateinische Buchstaben (mit Akzenten), Ziffern, Leerzeichen, Punkt, Binde- und Unterstrich.
    private static func erlaubt(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x20, 0x2E, 0x5F, 0x2D: true
        case 0xC0...0x24F, 0x1E00...0x1EFF: s.properties.isAlphabetic
        default: false
        }
    }

    static func spitznameText(_ grund: StatsSpitznameGrund) -> String {
        switch grund {
        case .laenge: String(localized: "Der Spitzname braucht 3 bis 20 Zeichen.")
        case .zeichen: String(localized: "Erlaubt sind Buchstaben, Ziffern, Leerzeichen, Punkt, Binde- und Unterstrich.")
        case .buchstaben: String(localized: "Der Spitzname braucht mindestens zwei Buchstaben.")
        case .unpassend: String(localized: "Dieser Spitzname geht nicht. Bitte wähle einen anderen.")
        case .vergeben: String(localized: "Diesen Spitznamen hat schon jemand.")
        }
    }

    /// Text zum Fehler-Code des Servers (`{"fehler": "..."}`); ohne Code oder unbekannt: keine Verbindung.
    static func fehlerText(_ code: String?) -> String {
        if let code, code.hasPrefix("spitzname_"), let g = StatsSpitznameGrund(rawValue: String(code.dropFirst("spitzname_".count))) { return spitznameText(g) }
        switch code ?? "" {
        case "tageslimit": return String(localized: "Für heute geht das nicht mehr. Morgen wieder.")
        case "zu_schnell": return String(localized: "Einen Moment bitte, dann nochmal.")
        default: return String(localized: "Das hat nicht geklappt. Prüfe die Verbindung und versuche es nochmal.")
        }
    }

    // MARK: Sichtbarkeit

    /// Wert rechts in Profil > Stats: Privat, Freunde oder Öffentlich.
    static func sichtbarkeitText(freunde: Bool, oeffentlich: Bool) -> String {
        oeffentlich ? String(localized: "Öffentlich") : freunde ? String(localized: "Freunde") : String(localized: "Privat")
    }

    static func sichtbarkeitText(_ e: Einstellungen) -> String {
        sichtbarkeitText(freunde: e.statsFreunde, oeffentlich: e.statsOeffentlich && e.statsSpitzname != nil)
    }
}
