// Quelle: Lovea Zyklus/ZyklusHeuteView.swift, ZyklusKalenderView.swift, ZyklusEinstellungenBlatt.swift, ZyklusEintragBlatt.swift, ZyklusRoot.swift (nur die reine Logik)
import Foundation

struct ZyklusRingText: Equatable, Sendable {
    var titel: String
    var untertitel: String
    var phase: ZyklusPhase?
    var fortschritt: Double
}

struct ZyklusEintragZeile: Equatable, Identifiable, Sendable {
    var symbol: String
    var titel: String
    var id: String { titel }
}

/// Reine Texte und Rechnungen der Heute-Ansicht.
enum ZyklusHeuteLogik {
    static func tageBis(_ von: String, _ bis: String) -> Int {
        Datum.kalender.dateComponents([.day], from: Datum.datum(von), to: Datum.datum(bis)).day ?? 0
    }

    static func ringText(logik: ZyklusLogik, heute: String) -> ZyklusRingText {
        guard let nummer = logik.zyklusTagNummer(am: heute), let phase = logik.phase(am: heute) else {
            if let d = logik.verspaetung {
                return ZyklusRingText(titel: "Spät dran", untertitel: d == 1 ? "Periode 1 Tag später" : "Periode \(d) Tage später", phase: .luteal, fortschritt: 1)
            }
            return ZyklusRingText(titel: "Hallo", untertitel: "Trag deine erste Periode ein", phase: nil, fortschritt: 0)
        }
        let fortschritt = Double(nummer) / Double(max(logik.mittlereZyklusLaenge, 1))
        let untertitel: String
        switch phase {
        case .eisprung:
            untertitel = "Eisprung"
        case .fruchtbar:
            untertitel = "Fruchtbar"
        case .periode:
            untertitel = "Periode"
        case .follikel, .luteal:
            if let d = logik.verspaetung {
                untertitel = d == 1 ? "Periode 1 Tag später" : "Periode \(d) Tage später"
            } else if let n = logik.naechstePeriode {
                let tage = tageBis(heute, n)
                untertitel = tage <= 0 ? "Periode kommt heute" : (tage == 1 ? "Periode in 1 Tag" : "Periode in \(tage) Tagen")
            } else {
                untertitel = "Periode bald"
            }
        }
        return ZyklusRingText(titel: "Tag \(nummer)", untertitel: untertitel, phase: phase, fortschritt: min(fortschritt, 1))
    }

    static func eintraege(_ tag: ZyklusTag?) -> [ZyklusEintragZeile] {
        guard let t = tag else { return [] }
        var z: [ZyklusEintragZeile] = []
        if let b = t.blutung {
            let n: String
            switch b {
            case .schmierblutung: n = "Schmierblutung"
            case .leicht: n = "Leichte Blutung"
            case .mittel: n = "Mittlere Blutung"
            case .stark: n = "Starke Blutung"
            }
            z.append(ZyklusEintragZeile(symbol: "drop.fill", titel: n))
        }
        for s in ZyklusSymptom.allCases where t.symptome.contains(s) {
            z.append(ZyklusEintragZeile(symbol: "cross.case.fill", titel: symptomName(s)))
        }
        for s in ZyklusStimmung.allCases where t.stimmung.contains(s) {
            z.append(ZyklusEintragZeile(symbol: "face.smiling", titel: stimmungName(s)))
        }
        if let a = t.ausfluss, a != .keiner {
            z.append(ZyklusEintragZeile(symbol: "sparkles", titel: "Ausfluss \(ausflussName(a))"))
        }
        if let g = t.temperatur {
            z.append(ZyklusEintragZeile(symbol: "thermometer.medium", titel: String(format: "%.2f Grad", g).replacingOccurrences(of: ".", with: ",")))
        }
        if let e = t.eisprungTest {
            z.append(ZyklusEintragZeile(symbol: "checkmark.circle", titel: e == .positiv ? "Eisprungtest positiv" : "Eisprungtest negativ"))
        }
        if let e = t.schwangerschaftsTest {
            z.append(ZyklusEintragZeile(symbol: "checkmark.circle", titel: e == .positiv ? "Schwangerschaftstest positiv" : "Schwangerschaftstest negativ"))
        }
        if let s = t.sex {
            z.append(ZyklusEintragZeile(symbol: "heart.fill", titel: s == .geschuetzt ? "Zweisamkeit geschützt" : "Zweisamkeit ungeschützt"))
        }
        if t.pille == true { z.append(ZyklusEintragZeile(symbol: "pills.fill", titel: "Pille genommen")) }
        if let w = t.wasserMl { z.append(ZyklusEintragZeile(symbol: "drop", titel: "\(w) ml Wasser")) }
        if let m = t.schlafMin { z.append(ZyklusEintragZeile(symbol: "bed.double.fill", titel: "\(m / 60) Std \(m % 60) Min Schlaf")) }
        if let g = t.gewicht {
            z.append(ZyklusEintragZeile(symbol: "scalemass.fill", titel: String(format: "%.1f kg", g).replacingOccurrences(of: ".", with: ",")))
        }
        return z
    }

    static func symptomName(_ s: ZyklusSymptom) -> String {
        switch s {
        case .kopfschmerzen: "Kopfschmerzen"
        case .kraempfe: "Krämpfe"
        case .rueckenschmerzen: "Rückenschmerzen"
        case .brustspannen: "Brustspannen"
        case .uebelkeit: "Übelkeit"
        case .blaehbauch: "Blähbauch"
        case .akne: "Unreine Haut"
        case .muedigkeit: "Müde"
        case .heisshunger: "Heißhunger"
        case .schwindel: "Schwindel"
        case .verstopfung: "Verstopfung"
        case .durchfall: "Durchfall"
        }
    }

    static func stimmungName(_ s: ZyklusStimmung) -> String {
        switch s {
        case .froehlich: "Fröhlich"
        case .ruhig: "Ruhig"
        case .energiegeladen: "Voller Energie"
        case .empfindlich: "Empfindlich"
        case .gereizt: "Gereizt"
        case .traurig: "Traurig"
        case .aengstlich: "Ängstlich"
        case .gestresst: "Gestresst"
        }
    }

    static func ausflussName(_ a: ZyklusAusfluss) -> String {
        switch a {
        case .keiner: "keiner"
        case .klebrig: "klebrig"
        case .cremig: "cremig"
        case .waessrig: "wässrig"
        case .eiweissartig: "eiweißartig"
        }
    }

    /// Schnellknopf: Periode beginnt an diesem Tag. Ändert nur, wenn noch keine Blutung steht.
    static func periodeStart(_ id: String, tage: [String: ZyklusTag]) -> ZyklusTag? {
        var t = tage[id] ?? ZyklusTag(id: id)
        guard t.blutung == nil else { return nil }
        t.blutung = .mittel
        return t
    }
}

struct ZyklusTagStatus: Equatable, Sendable {
    var periode = false
    var vorhersage = false
    var fruchtbar = false
    var eisprung = false
    var log = false
}

enum ZyklusKalenderModus: Equatable, Sendable {
    case eintragen, periodeStart, periodeEnde
}

/// Reine Kalender-Rechnung: Monatsraster, Tagesstatus, nachträgliche Perioden-Änderungen.
enum ZyklusKalenderLogik {
    static func monatsStart(_ tag: String) -> String {
        let k = Datum.kalender.dateComponents([.year, .month], from: Datum.datum(tag))
        return String(format: "%04d-%02d-01", k.year ?? 2000, k.month ?? 1)
    }

    static func monatVerschieben(_ monat: String, um schritte: Int) -> String {
        let d = Datum.kalender.date(byAdding: .month, value: schritte, to: Datum.datum(monatsStart(monat)))!
        return Datum.text(d)
    }

    static func tagVerschieben(_ tag: String, um tage: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: tage, to: Datum.datum(tag))!)
    }

    /// Wochen als Zeilen zu je 7 Zellen, Montag zuerst. Leere Zellen sind nil.
    static func raster(monat: String) -> [[String?]] {
        let start = Datum.datum(monatsStart(monat))
        let kal = Datum.kalender
        let tageImMonat = kal.range(of: .day, in: .month, for: start)?.count ?? 30
        let wochentag = kal.component(.weekday, from: start) // 1 = Sonntag
        let vorlauf = (wochentag + 5) % 7
        var zellen: [String?] = Array(repeating: nil, count: vorlauf)
        for i in 0..<tageImMonat { zellen.append(Datum.text(kal.date(byAdding: .day, value: i, to: start)!)) }
        while zellen.count % 7 != 0 { zellen.append(nil) }
        return stride(from: 0, to: zellen.count, by: 7).map { Array(zellen[$0..<$0 + 7]) }
    }

    static func status(_ id: String, logik: ZyklusLogik, tage: [String: ZyklusTag], heute: String) -> ZyklusTagStatus {
        let t = tage[id]
        let phase = logik.phase(am: id)
        var s = ZyklusTagStatus()
        s.periode = t?.blutung != nil
        s.vorhersage = !s.periode && phase == .periode && id >= heute
        s.fruchtbar = phase == .fruchtbar || phase == .eisprung
        s.eisprung = phase == .eisprung
        s.log = t.map { !$0.istLeer } ?? false
        return s
    }

    /// Periode beginnt an diesem Tag. Nil, wenn dort schon eine Blutung steht.
    static func startSetzen(_ id: String, tage: [String: ZyklusTag]) -> ZyklusTag? {
        ZyklusHeuteLogik.periodeStart(id, tage: tage)
    }

    /// Periode endet an diesem Tag: Tage vom Start bis hier bluten, spätere Blutungstage danach fallen weg.
    /// Gibt nur geänderte Tage zurück. Leer, wenn keine Periode davor liegt oder sie länger als 14 Tage her ist.
    static func endeSetzen(_ id: String, tage: [String: ZyklusTag], logik: ZyklusLogik) -> [ZyklusTag] {
        guard let start = logik.periodenStarts.last(where: { $0 <= id }),
              ZyklusHeuteLogik.tageBis(start, id) <= 14 else { return [] }
        var geaendert: [ZyklusTag] = []
        var tag = start
        while tag <= id {
            var t = tage[tag] ?? ZyklusTag(id: tag)
            if t.blutung == nil {
                t.blutung = .leicht
                geaendert.append(t)
            }
            tag = tagVerschieben(tag, um: 1)
        }
        var n = 0
        while n < 14, var t = tage[tag], t.blutung != nil {
            t.blutung = nil
            geaendert.append(t)
            tag = tagVerschieben(tag, um: 1)
            n += 1
        }
        return geaendert
    }

    static func monatTitel(_ monat: String) -> String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        return Datum.datum(monat).formatted(stil.month(.wide).year())
    }

    static func tagBeschreibung(_ id: String, status s: ZyklusTagStatus) -> String {
        var teile = [Datum.anzeige(id)]
        if s.periode { teile.append("Periode") }
        if s.vorhersage { teile.append("Periode erwartet") }
        if s.eisprung { teile.append("Eisprung") } else if s.fruchtbar { teile.append("Fruchtbar") }
        if s.log { teile.append("Eintrag vorhanden") }
        return teile.joined(separator: ", ")
    }
}

enum ZyklusEinstellungenLogik {
    static let zyklusGrenzen = 20...45
    static let periodenGrenzen = 2...10

    static func begrenzt(_ e: ZyklusEinstellung) -> ZyklusEinstellung {
        var r = e
        r.zyklusLaenge = min(max(e.zyklusLaenge, zyklusGrenzen.lowerBound), zyklusGrenzen.upperBound)
        r.periodenLaenge = min(max(e.periodenLaenge, periodenGrenzen.lowerBound), periodenGrenzen.upperBound)
        return r
    }

    static func modusName(_ m: ZyklusModus) -> String {
        switch m {
        case .zyklus: return "Zyklus"
        case .schwanger: return "Schwanger"
        case .kinderwunsch: return "Kinderwunsch"
        case .pille: return "Pille"
        }
    }

    /// Alle Tage als Text, ältester zuerst.
    static func export(tage: [String: ZyklusTag], einstellung: ZyklusEinstellung) -> String {
        var z = ["Lumen Fit Zyklus", "Modus: \(modusName(einstellung.modus))",
                 "Zykluslänge: \(einstellung.zyklusLaenge) Tage", "Periodenlänge: \(einstellung.periodenLaenge) Tage", ""]
        for id in tage.keys.sorted() {
            guard let t = tage[id] else { continue }
            var teile = ZyklusHeuteLogik.eintraege(t).map(\.titel)
            if let n = t.notiz, !n.isEmpty, !teile.contains(where: { $0.contains(n) }) { teile.append("Notiz: \(n)") }
            z.append("\(id): " + (teile.isEmpty ? "-" : teile.joined(separator: ", ")))
        }
        return z.joined(separator: "\n")
    }
}

/// Bearbeitbare Kopie eines Tages. Zahlenfelder sind Text, solange getippt wird.
struct ZyklusEintragEntwurf: Equatable, Sendable {
    var id: String
    var blutung: ZyklusBlutung?
    var symptome: Set<ZyklusSymptom> = []
    var stimmung: Set<ZyklusStimmung> = []
    var ausfluss: ZyklusAusfluss?
    var temperaturText = ""
    var eisprungTest: ZyklusTest?
    var schwangerschaftsTest: ZyklusTest?
    var sex: ZyklusSex?
    var pille: Bool?
    var wasserMl: Int?
    var schlafMin: Int?
    var gewichtText = ""
    var notiz = ""

    init(id: String, tag: ZyklusTag? = nil) {
        self.id = id
        guard let tag else { return }
        blutung = tag.blutung
        symptome = tag.symptome
        stimmung = tag.stimmung
        ausfluss = tag.ausfluss
        temperaturText = Self.text(tag.temperatur, stellen: 2)
        eisprungTest = tag.eisprungTest
        schwangerschaftsTest = tag.schwangerschaftsTest
        sex = tag.sex
        pille = tag.pille
        wasserMl = tag.wasserMl
        schlafMin = tag.schlafMin
        gewichtText = Self.text(tag.gewicht, stellen: 1)
        notiz = tag.notiz ?? ""
    }

    var tag: ZyklusTag {
        let notizBereinigt = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        return ZyklusTag(
            id: id,
            blutung: blutung,
            symptome: symptome,
            stimmung: stimmung,
            ausfluss: ausfluss,
            temperatur: Self.zahl(temperaturText),
            eisprungTest: eisprungTest,
            schwangerschaftsTest: schwangerschaftsTest,
            sex: sex,
            pille: pille,
            wasserMl: wasserMl,
            schlafMin: schlafMin,
            gewicht: Self.zahl(gewichtText),
            notiz: notizBereinigt.isEmpty ? nil : notizBereinigt
        )
    }

    /// 36,6 und 36.6 gelten gleich. Leer, Unsinn und Werte bis 0 ergeben nil.
    static func zahl(_ text: String) -> Double? {
        let sauber = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let wert = Double(sauber), wert.isFinite, wert > 0 else { return nil }
        return wert
    }

    static func text(_ wert: Double?, stellen: Int) -> String {
        guard let wert else { return "" }
        var text = String(format: "%.\(stellen)f", wert)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    /// Schritt für Wasser und Schlaf. Bei 0 oder darunter wird der Wert wieder "nicht eingetragen".
    static func schritt(_ wert: Int?, delta: Int, grenze: Int) -> Int? {
        let neu = (wert ?? 0) + delta
        return neu <= 0 ? nil : min(neu, grenze)
    }

    @MainActor
    func speichern(in store: ZyklusStore) {
        store.setze(tag)
    }
}

enum ZyklusReiter: String, CaseIterable, Identifiable, Sendable {
    case heute, modus, kalender, insights
    var id: String { rawValue }
    var titel: String {
        switch self {
        case .heute, .modus: return "Heute"
        case .kalender: return "Kalender"
        case .insights: return "Insights"
        }
    }
}

enum ZyklusRootLogik {
    /// Zyklus: wie bisher. Die anderen Modi ersetzen "Heute" durch ihre eigene Ansicht.
    static func reiter(_ modus: ZyklusModus) -> [ZyklusReiter] {
        modus == .zyklus ? [.heute, .kalender, .insights] : [.modus, .kalender, .insights]
    }

    static func titel(_ reiter: ZyklusReiter, modus: ZyklusModus) -> String {
        reiter == .modus ? ZyklusEinstellungenLogik.modusName(modus) : reiter.titel
    }

    /// Ein gemerkter Reiter, den der Modus nicht hat, fällt auf den ersten des Modus zurück.
    static func gueltig(_ reiter: ZyklusReiter, modus: ZyklusModus) -> ZyklusReiter {
        let r = Self.reiter(modus)
        return r.contains(reiter) ? reiter : r[0]
    }
}


/// Die Abschnitte des Phasen-Rings: jede Phase als Bereich 0...1 des Zyklus, aus denselben Regeln wie `ZyklusLogik.phase(am:)`.
enum ZyklusRingLogik {
    struct Abschnitt: Equatable, Sendable {
        let phase: ZyklusPhase
        let von: Double
        let bis: Double
        let tage: Int
    }

    static func abschnitte(laenge: Int, periodenLaenge: Int) -> [Abschnitt] {
        let n = max(laenge, 1)
        var liste: [(phase: ZyklusPhase, von: Int, bis: Int)] = []
        for nummer in 1...n {
            let p = ZyklusLogik.phase(nummer: nummer, laenge: n, periodenLaenge: periodenLaenge)
            if let letzter = liste.last, letzter.phase == p {
                liste[liste.count - 1].bis = nummer
            } else {
                liste.append((p, nummer, nummer))
            }
        }
        return liste.map { Abschnitt(phase: $0.phase, von: Double($0.von - 1) / Double(n), bis: Double($0.bis) / Double(n), tage: $0.bis - $0.von + 1) }
    }

    /// Ein einziger Abschnitt über den ganzen Ring (Schwangerschaft, Kinderwunsch).
    static func einfach(_ phase: ZyklusPhase) -> [Abschnitt] {
        [Abschnitt(phase: phase, von: 0, bis: 1, tage: 1)]
    }

    /// Pillenpackung: Wirkstofftage und Pause (21 und 7 Tage oder 28 durchgehend mit Platzhaltern in den letzten 7).
    static func pille() -> [Abschnitt] {
        let ganz = Double(ZyklusModiLogik.packungsTage)
        let grenze = Double(ZyklusModiLogik.wirkstoffTage) / ganz
        return [Abschnitt(phase: .follikel, von: 0, bis: grenze, tage: ZyklusModiLogik.wirkstoffTage),
                Abschnitt(phase: .periode, von: grenze, bis: 1, tage: ZyklusModiLogik.packungsTage - ZyklusModiLogik.wirkstoffTage)]
    }
}
