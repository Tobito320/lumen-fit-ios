// Quelle: Lovea Health/Heute/Tagesform/TagesformRechnung.swift
import Foundation

// Tagesform (W-028). Reine Logik: Eingabe rein, Zahl mit Gründen raus. Kein Raum, kein HealthKit, kein Netz, keine KI.
// Nur so lässt sich die Zahl erklären und später nachrechnen. Die Quellen sammelt `TagesformQuellen`.
// Löst die alte Rechnung (`TagesformLogik.tagesform`) ab.

// MARK: - Eingabe

/// Der Vortag, der am Vormittag noch mitzählt (`TagesformRechnung.tagesmass`). `ziel` ist sein ganzes Tagesziel,
/// `anteil` wie viel von der Zahl dieses Faktors er noch ausmacht (0 bis 1).
struct TagesformDavor: Codable, Equatable, Sendable {
    var ist: Double
    var ziel: Double
    var anteil: Double
}

/// Ein Messwert gegen sein Ziel. Bei `.bisJetzt` ist `ziel` schon das Soll für die Tageszeit.
struct TagesformMass: Codable, Equatable, Sendable {
    enum Bezug: String, Codable, Sendable { case vortag, bisJetzt, tag }
    var ist: Double
    var ziel: Double
    var bezug: Bezug
    /// Nur bei `.bisJetzt` am Vormittag: der Vortag zählt noch mit, damit die Zahl nicht auf einmal springt. Sonst nil.
    var davor: TagesformDavor? = nil
}

/// Erholung eines trainierten Muskelteils in Prozent, mit dem Namen der Gruppe für den Text.
struct TagesformMuskel: Codable, Equatable, Sendable {
    var gruppe: String
    var prozent: Int
}

/// Alle Rohwerte eines Tages. Fehlt eine Quelle, ist sie leer oder `nil`: dann fällt sie aus der Rechnung.
/// Wird mit dem Gefühl gespeichert (`TagesformEintrag`). Neue Felder nur optional oder mit eigenem `init(from:)`,
/// sonst lassen sich gespeicherte Einträge nicht mehr lesen.
struct TagesformEingabe: Codable, Equatable, Sendable {
    /// Stunde des Tages (0 bis 24) für "bis jetzt". 24 = der Tag ist vorbei.
    var stunde = 24
    var schlafZiel = 480
    /// Schlafminuten je Nacht, Index 0 = die Nacht vor dem Tag, dann je eine Nacht weiter zurück (bis 14). nil = keine Daten.
    var schlaf: [Int?] = []
    /// Bettzeit je Nacht (Index wie `schlaf`, bis 7) in Minuten ab 12 Uhr: 22:00 = 600, 00:30 = 750.
    var bett: [Int?] = []
    /// Wie sicher der Schlafwert ist, 0,5 bis 1 (Uhr und eigener Eintrag = 1, Schätzung weniger).
    var schlafSicherheit = 1.0
    var schlafHinweis: String? = nil
    /// Tageswerte aus Apple Health, Index 0 = der Tag selbst, dann bis zu 28 Tage davor. nil = kein Wert.
    var ruhepuls: [Double?] = []
    var hrv: [Double?] = []
    /// Trainierte Muskelteile mit ihrer Erholung (nur die unter 100 Prozent).
    var muskeln: [TagesformMuskel] = []
    /// Gezählte Sätze je Tag, Index 0 = der Tag selbst, dann bis zu 28 Tage davor.
    var saetze: [Int] = []
    var schritte: TagesformMass? = nil
    var wasser: TagesformMass? = nil
    var kalorien: TagesformMass? = nil
    var eiweiss: TagesformMass? = nil
}

// MARK: - Ergebnis

enum TagesformArt: String, CaseIterable, Sendable {
    case schlaf, rhythmus, hrv, ruhepuls, erholung, last, kalorien, eiweiss, schritte, wasser

    var titel: String {
        switch self {
        case .schlaf: String(localized: "Schlaf")
        case .rhythmus: String(localized: "Bettzeit")
        case .hrv: "HRV"
        case .ruhepuls: String(localized: "Ruhepuls")
        case .erholung: String(localized: "Muskeln")
        case .last: String(localized: "Training")
        case .kalorien: String(localized: "Kalorien")
        case .eiweiss: String(localized: "Eiweiß")
        case .schritte: String(localized: "Schritte")
        case .wasser: String(localized: "Wasser")
        }
    }

    var einheit: String {
        switch self {
        case .kalorien: "kcal"
        case .eiweiss: "g"
        case .wasser: String(localized: "Gläser")
        default: ""
        }
    }

    var symbol: String {
        switch self {
        case .schlaf: "bed.double.fill"
        case .rhythmus: "clock"
        case .hrv: "waveform.path.ecg"
        case .ruhepuls: "heart.fill"
        case .erholung: "bolt.heart.fill"
        case .last: "dumbbell.fill"
        case .kalorien: "flame.fill"
        case .eiweiss: "fork.knife"
        case .schritte: "figure.walk"
        case .wasser: "drop.fill"
        }
    }

    /// Anteil an der Tagesform, wenn alle Quellen da sind (Summe 1). Schlaf und die Erholungswerte des Körpers
    /// (HRV, Ruhepuls) tragen zusammen mehr als die Hälfte, Training, Essen und Bewegung den Rest. Wasser zählt am
    /// wenigsten: der alte Fehler war, dass Trinken die Zahl trotz kaum Schlaf hob.
    var gewicht: Double {
        switch self {
        case .schlaf: 0.26      // letzte Nacht gegen das Ziel, dazu die zwei Nächte davor
        case .rhythmus: 0.05    // wie gleichmäßig die Bettzeit der letzten Nächte ist
        case .hrv: 0.16         // stärkstes Signal für Erholung, gegen den eigenen Schnitt
        case .ruhepuls: 0.10    // erhöht bei Stress, Krankheit, zu wenig Erholung
        case .erholung: 0.13    // die müdesten Muskelteile (`MuskelLogik.erholung`)
        case .last: 0.08        // Sätze der letzten 3 Tage gegen die letzten 28
        case .kalorien: 0.06    // Essen vom Vortag, der Tag ist vollständig
        case .eiweiss: 0.05
        case .schritte: 0.07
        case .wasser: 0.04
        }
    }

    /// Punkte eines normalen Tages. Der Einfluss eines Faktors ist sein Anteil mal der Abstand dazu. Schlaf (7 von 8 Stunden),
    /// HRV und Ruhepuls (genau dein Schnitt) liegen bei `TagesformRechnung.neutral`. Was ein Ziel misst, ist bei erreichtem Ziel
    /// normal (100) und kann dann nicht mehr helfen, nur bremsen: so steht "Hilft" nur bei dem, was besser ist als sonst.
    var normal: Double {
        switch self {
        case .schlaf, .hrv, .ruhepuls: TagesformRechnung.neutral
        default: 100
        }
    }

    /// Was der Faktor braucht, damit er zählt. Steht im Detail unter "Ohne Daten" hinter dem Titel ("Schlaf: die letzte Nacht ..."),
    /// damit klar ist, woran es liegt.
    var braucht: String {
        switch self {
        case .schlaf: String(localized: "die letzte Nacht, eingetragen oder aus Apple Health")
        case .rhythmus: String(localized: "Bettzeiten von vier der letzten sieben Nächte")
        case .hrv: String(localized: "ein Wert von heute aus Apple Health und fünf Tage zum Vergleichen (das Band liefert ihn noch nicht)")
        case .ruhepuls: String(localized: "ein Wert von heute aus Apple Health und fünf Tage zum Vergleichen (das Band liefert ihn noch nicht)")
        case .erholung: String(localized: "ein Training in den letzten vier Wochen")
        case .last: String(localized: "Sätze aus den vier Wochen vor heute")
        case .kalorien: String(localized: "ein Essens-Tagebuch vom Vortag mit mindestens 40 % deines Kalorienziels")
        case .eiweiss: String(localized: "ein Essens-Tagebuch vom Vortag mit mindestens 40 % deines Kalorienziels")
        case .schritte: String(localized: "Daten vom iPhone oder vom Band")
        case .wasser: String(localized: "ein Eintrag in den letzten acht Tagen")
        }
    }

    var reihenfolge: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static var gesamtGewicht: Double { allCases.reduce(0.0) { $0 + $1.gewicht } }
}

struct TagesformFaktor: Equatable, Sendable, Identifiable {
    var art: TagesformArt
    /// 0 bis 100: wie gut dieser Teil gerade ist.
    var wert: Double
    /// Anteil an der Zahl nach dem Umverteilen; alle Faktoren zusammen sind 1.
    var gewicht: Double
    /// Punkte, die der Faktor die Zahl über (+) oder unter (-) einen normalen Tag zieht: sein Anteil mal der Abstand zu `art.normal`.
    var einfluss: Double
    /// Eine Zeile für die Karte, z. B. "Schlaf 6:10 h, unter deinem Schnitt".
    var kurz: String
    var detail: String?

    var id: String { art.rawValue }
}

/// Eine Obergrenze, die die Zahl zusätzlich deckelt (zu wenig Schlaf, doppeltes Warnsignal).
struct TagesformKappe: Equatable, Sendable {
    var grenze: Int
    var text: String
    /// Der Faktor, auf den der Text sich bezieht (Schlaf); er steht dann nicht noch einmal als Grund im Satz.
    var art: TagesformArt? = nil
}

struct TagesformErgebnis: Equatable, Sendable {
    /// nil = zu wenig Daten für eine Zahl.
    var akku: Int?
    var urteil: String
    /// Alle Faktoren mit Daten, in der Reihenfolge von `TagesformArt`.
    var faktoren: [TagesformFaktor]
    /// Die wichtigsten Gründe, größter Einfluss zuerst.
    var gruende: [TagesformFaktor]
    /// Nur gesetzt, wenn die Obergrenze die Zahl wirklich senkt.
    var kappe: TagesformKappe?
    /// Anteil der Gewichte mit Daten (Schlafsicherheit eingerechnet), 0 bis 1.
    var deckung: Double
    var fehlend: [TagesformArt]
    /// Gründe als Zeilen für die Karte.
    var satz: String

    var datenlage: String { TagesformRechnung.datenlage(deckung) }

    /// Für die Karte aus Heute (`TagesformKarte`), die diese Form seit der ersten Fassung kennt.
    var alsTagesform: Tagesform { Tagesform(akku: akku, urteil: urteil, satz: satz) }
}

// MARK: - Rechnung

enum TagesformRechnung {
    /// Zählt hoch, wenn Gewichte oder Regeln sich ändern. Gespeicherte Einträge merken sich ihre Fassung.
    static let version = 2
    /// Weichen zwei Schlafquellen um so viele Minuten ab, sinkt die Sicherheit (Lumen Fit kennt nur den Aufruf mit `abweichung: nil`, siehe `TagesformQuellen`).
    static let ausreisserMindestens = 45.0
    /// Punkte eines Faktors, der genau deinem Schnitt entspricht (HRV, Ruhepuls) oder 7 von 8 Stunden Schlaf. Ein normaler Tag
    /// pro Faktor steht in `TagesformArt.normal`; der Einfluss eines Faktors ist sein Anteil mal der Abstand dazu.
    static let neutral = 75.0
    /// Unter diesem Anteil an Daten gibt es keine Zahl. Schlaf allein reicht nur, wenn er sicher ist (Uhr oder eigener Eintrag:
    /// 0,26); eine Schätzung allein (höchstens 0,23) reicht nicht, HRV allein auch nicht.
    static let mindestDeckung = 0.25
    /// Ab diesem Anteil gilt die Datenlage als gut, ab dem zweiten als mittel.
    static let gutDeckung = 0.8
    static let mittelDeckung = 0.55
    static let hoechstGruende = 3
    /// Kleinere Einflüsse (Punkte) sind kein Grund.
    static let mindestEinfluss = 1.0
    /// Letzte Nacht zählt so viel, die zwei Nächte davor den Rest: eine einzelne schlechte Nacht nach guten ist weniger schlimm.
    static let letzteNachtAnteil = 0.65
    /// Unter dieser Sicherheit nennt die Schlaf-Obergrenze den Schlaf "unsicher": sie deckelt trotzdem hart, aber man sieht, worauf sie beruht.
    static let schlafUnsicherUnter = 0.85
    /// Schritte und Wasser: so viele Stunden braucht heute, bis es den Vortag ganz ersetzt (siehe `tagesmass`).
    static let uebergangStunden = 6
    /// Bettzeit: bis 30 Minuten Streuung volle Punkte, ab 120 keine.
    static let streuungGut = 30.0
    static let streuungSchlecht = 120.0
    static let mindestNaechteBett = 4
    /// HRV und Ruhepuls gegen die letzten 28 Tage, mindestens so viele Tage Vergleich.
    static let mindestBasisTage = 5
    /// HRV: Punkte je Standardabweichung über oder unter dem Schnitt. Die Streuung hat einen Boden von 8 % des Schnitts.
    static let hrvSteigung = 20.0
    static let hrvStreuungBoden = 0.08
    /// Ruhepuls: Punkte je Schlag über (-) oder unter (+) dem Schnitt.
    static let ruhepulsSteigung = 6.0
    /// Beide unter diesem Wert: doppeltes Warnsignal, die Zahl bleibt unter `warnGrenze`.
    static let warnWert = 40.0
    static let warnGrenze = 60
    /// Erholung: Mittel der müdesten Muskelteile (von allen 27; nicht trainierte zählen 100).
    static let muedeTeile = 6
    /// Last: Sätze/Tag der letzten 3 Tage gegen die letzten 28. Bis 1,3 voll, ab 2 deutlich weniger, ab 3 null.
    static let lastGrenze = 1.3

    // MARK: Hilfen für die Quellen

    /// Anteil des Tagesziels, der bis `stunde` erreicht sein sollte: 0 vor 8 Uhr, 1 ab 22 Uhr, dazwischen linear
    /// (wie `EnergieLogik.wasserSoll`).
    static func sollAnteil(stunde: Int) -> Double { min(max(Double(stunde - 8) / 14, 0), 1) }

    /// Wie viel von heute zählt: bis `ab` Uhr nichts (nur der Vortag), danach steigt es linear und ist nach `uebergangStunden`
    /// Stunden ganz da. Dazwischen zählt der Vortag noch den Rest, damit die Zahl nicht zu einer festen Stunde springt.
    static func heuteAnteil(stunde: Int, ab: Int) -> Double {
        min(max(Double(stunde - ab) / Double(uebergangStunden), 0), 1)
    }

    /// Welcher Stand eines Tagesziels zählt: ein vergangener Tag ganz (`stunde` 24); heute gegen das Soll bis jetzt, ab `ab` Uhr
    /// langsam eingeblendet (`heuteAnteil`), der Vortag zählt bis dahin den Rest; vor `ab` der Vortag allein. `nil`, wenn nichts
    /// bekannt ist oder das Ziel fehlt.
    /// `ab` 24 heißt: heute nie, nur Vortag (Essen wird von Hand eingetragen, ein halber Tag wäre ein falsches Minus).
    static func tagesmass(heute: Double?, vortag: Double?, ziel: Double, stunde: Int, ab: Int) -> TagesformMass? {
        guard ziel > 0 else { return nil }
        if stunde >= 24, let heute { return TagesformMass(ist: heute, ziel: ziel, bezug: .tag) }
        let anteil: Double = stunde < 24 ? heuteAnteil(stunde: stunde, ab: ab) : 0
        let soll: Double = ziel * sollAnteil(stunde: stunde)
        if anteil > 0, soll > 0, let heute {
            var m = TagesformMass(ist: heute, ziel: soll, bezug: .bisJetzt)
            if anteil < 1, let vortag { m.davor = TagesformDavor(ist: vortag, ziel: ziel, anteil: 1 - anteil) }
            return m
        }
        if let vortag { return TagesformMass(ist: vortag, ziel: ziel, bezug: .vortag) }
        return nil
    }

    /// Stunde des Tages: heute die echte Uhrzeit (Berlin), jeder andere Tag zählt voll.
    static func stunde(tag: String, jetzt: Date) -> Int {
        guard tag == Datum.text(jetzt) else { return 24 }
        return Datum.kalender.component(.hour, from: jetzt)
    }

    /// Bettzeit in Minuten ab 12 Uhr, damit Mitternacht mitten in der Skala liegt (Mitternacht liegt dann nicht am Rand der Skala).
    static func bettMinuten(_ bett: Date) -> Int {
        let c = Datum.kalender.dateComponents([.hour, .minute], from: bett)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return (m - 720 + 1440) % 1440
    }

    /// Wie sehr dem Schlafwert zu trauen ist. Uhr, Armband und eigener Eintrag voll, das Punktesystem weniger, und weichen
    /// Uhr und Schätzung stark ab (`ausreisserMindestens`), noch einmal weniger. Ein eigener Eintrag ist die
    /// Wahrheit: er verliert nichts, auch wenn Uhr und Schätzung auseinanderliegen.
    static func schlafSicherheit(quelle: String?, abweichung: Int?) -> Double {
        var s = 0.8
        if let q = quelle {
            if q == TagesformSchlafQuelle.eingetragen.rawValue || q == TagesformSchlafQuelle.appleWatch.rawValue || q == TagesformSchlafQuelle.armband.rawValue {
                s = 1
            } else if q.contains("unsicher") {
                s = 0.65
            } else if q.contains("wahrscheinlich") {
                s = 0.8
            } else if q.contains("sicher") {
                s = 0.9
            }
        }
        if weichtAb(quelle: quelle, abweichung: abweichung) { s *= 0.85 }
        return s
    }

    static func schlafHinweis(quelle: String?, abweichung: Int?) -> String? {
        guard let quelle else { return nil }
        var text = String(localized: "Quelle: \(quelle)")
        if weichtAb(quelle: quelle, abweichung: abweichung), let a = abweichung {
            text += String(localized: ". Uhr und Schätzung weichen \(abs(a)) min ab")
        }
        return text
    }

    /// Uhr und Schätzung liegen stark auseinander und der Wert ist nicht der eigene Eintrag.
    private static func weichtAb(quelle: String?, abweichung: Int?) -> Bool {
        guard quelle != TagesformSchlafQuelle.eingetragen.rawValue, let a = abweichung else { return false }
        return Double(abs(a)) >= ausreisserMindestens
    }

    static func datenlage(_ deckung: Double) -> String {
        deckung >= gutDeckung ? String(localized: "gut") : (deckung >= mittelDeckung ? String(localized: "mittel") : String(localized: "dünn"))
    }

    // MARK: Rechnen

    private struct Teil {
        let art: TagesformArt
        let wert: Double
        let sicherheit: Double
        let kurz: String
        let detail: String?
    }

    static func rechnen(_ e: TagesformEingabe) -> TagesformErgebnis {
        var teile: [Teil] = []
        var fehlend: [TagesformArt] = []
        for art in TagesformArt.allCases {
            if let t = teil(art, e) { teile.append(t) } else { fehlend.append(art) }
        }
        let gewichte: [Double] = teile.map { $0.art.gewicht * $0.sicherheit }
        let summe: Double = gewichte.reduce(0, +)
        let deckung: Double = summe / TagesformArt.gesamtGewicht

        var faktoren: [TagesformFaktor] = []
        var roh = 0.0
        for (i, t) in teile.enumerated() {
            let anteil: Double = summe > 0 ? gewichte[i] / summe : 0
            roh += anteil * t.wert
            let einfluss: Double = anteil * (t.wert - t.art.normal)
            faktoren.append(TagesformFaktor(art: t.art, wert: t.wert, gewicht: anteil, einfluss: einfluss, kurz: t.kurz, detail: t.detail))
        }
        // Ohne Zahl zeigt die Liste trotzdem, was da ist, aber ohne Gewicht.
        let ohneGewicht: [TagesformFaktor] = faktoren.map {
            TagesformFaktor(art: $0.art, wert: $0.wert, gewicht: 0, einfluss: 0, kurz: $0.kurz, detail: $0.detail)
        }
        guard summe > 0, deckung >= mindestDeckung else {
            return TagesformErgebnis(akku: nil, urteil: String(localized: "Zu wenig Daten"), faktoren: ohneGewicht, gruende: [], kappe: nil,
                                     deckung: deckung, fehlend: fehlend,
                                     satz: String(localized: "Trag deinen Schlaf ein oder erlaube Apple Health, dann rechnet Lumen Fit deine Tagesform."))
        }
        // Schlaf ist Pflicht: er ist die Obergrenze der Zahl. Ohne ihn hebt ein voller Tag (oder Wasser) die Zahl über das,
        // was die Nacht hergibt (der gemeldete Fehler), und die Karte würde "Voll geladen" zeigen, obwohl die Uhr noch nicht synchron ist.
        guard !fehlend.contains(.schlaf) else {
            return TagesformErgebnis(akku: nil, urteil: String(localized: "Schlaf fehlt"), faktoren: ohneGewicht, gruende: [], kappe: nil,
                                     deckung: deckung, fehlend: fehlend,
                                     satz: String(localized: "Ohne Schlafwert gibt es keine Tagesform. Trag deinen Schlaf ein oder erlaube Apple Health."))
        }

        let kandidaten: [TagesformKappe?] = [schlafKappe(e), warnKappe(faktoren)]
        let kappen: [TagesformKappe] = kandidaten.compactMap { $0 }
        let strengste: TagesformKappe? = kappen.min { $0.grenze < $1.grenze }
        let begrenzt: Double = min(roh, Double(strengste?.grenze ?? 100))
        let akku = Int(klemmen(begrenzt).rounded())
        var wirkt: TagesformKappe? = nil
        if let k = strengste, Double(k.grenze) < roh { wirkt = k }

        let nachEinfluss: [TagesformFaktor] = faktoren.sorted { a, b in
            let x = abs(a.einfluss)
            let y = abs(b.einfluss)
            if x != y { return x > y }
            return a.art.reihenfolge < b.art.reihenfolge
        }
        let gruende: [TagesformFaktor] = Array(nachEinfluss.filter { abs($0.einfluss) >= mindestEinfluss }.prefix(hoechstGruende))
        return TagesformErgebnis(akku: akku, urteil: TagesformLogik.urteil(akku), faktoren: faktoren, gruende: gruende, kappe: wirkt,
                                 deckung: deckung, fehlend: fehlend, satz: satz(gruende: gruende, kappe: wirkt, deckung: deckung))
    }

    /// "Bremst: ..." und "Hilft: ..." je Zeile, höchstens `hoechstGruende`. Eine wirkende Obergrenze steht zuerst und
    /// ersetzt den Grund, den sie schon nennt.
    static func satz(gruende: [TagesformFaktor], kappe: TagesformKappe?, deckung: Double) -> String {
        var zeilen: [String] = []
        if let kappe { zeilen.append(String(localized: "Bremst: \(kappe.text)")) }
        let uebrige: [TagesformFaktor] = gruende.filter { $0.art != kappe?.art }
        let platz = max(0, hoechstGruende - zeilen.count)
        for g in uebrige.prefix(platz) {
            zeilen.append(g.einfluss < 0 ? String(localized: "Bremst: \(g.kurz)") : String(localized: "Hilft: \(g.kurz)"))
        }
        if zeilen.isEmpty { zeilen.append(String(localized: "Alles im normalen Bereich.")) }
        if deckung < mittelDeckung { zeilen.append(String(localized: "Wenig Daten, die Zahl ist grob.")) }
        return zeilen.joined(separator: "\n")
    }

    // MARK: Obergrenzen

    /// Schlaf ist eine harte Obergrenze (wie `server/tagesform.js` und die alte Rechnung): 15 bei 0 h bis 100 beim Ziel.
    /// Ist der Schlafwert nur geschätzt (`schlafUnsicherUnter`), deckelt sie genauso, nennt ihn aber "unsicher".
    private static func schlafKappe(_ e: TagesformEingabe) -> TagesformKappe? {
        let erste: Int? = e.schlaf.first.flatMap { $0 }
        guard let letzte = erste, e.schlafZiel > 0 else { return nil }
        let g = TagesformLogik.schlafGrenze(schlafMinuten: letzte, schlafZiel: e.schlafZiel)
        let unsicher: String = e.schlafSicherheit < schlafUnsicherUnter ? String(localized: " (unsicher)") : ""
        return TagesformKappe(grenze: g, text: String(localized: "Schlaf \(stunden(letzte))\(unsicher) deckelt dich bei \(g) %"), art: .schlaf)
    }

    private static func warnKappe(_ faktoren: [TagesformFaktor]) -> TagesformKappe? {
        let hrv = faktoren.first(where: { $0.art == .hrv })
        let puls = faktoren.first(where: { $0.art == .ruhepuls })
        guard let h = hrv, let r = puls, h.wert <= warnWert, r.wert <= warnWert else { return nil }
        return TagesformKappe(grenze: warnGrenze, text: String(localized: "HRV tief und Ruhepuls hoch, höchstens \(warnGrenze) %"))
    }

    // MARK: Faktoren

    private static func teil(_ art: TagesformArt, _ e: TagesformEingabe) -> Teil? {
        switch art {
        case .schlaf: return schlafTeil(e)
        case .rhythmus: return rhythmusTeil(e)
        case .hrv: return hrvTeil(e)
        case .ruhepuls: return ruhepulsTeil(e)
        case .erholung: return erholungTeil(e)
        case .last: return lastTeil(e)
        case .kalorien: return massTeil(e.kalorien, art: .kalorien, e: e)
        case .eiweiss: return massTeil(e.eiweiss, art: .eiweiss, e: e)
        case .schritte: return massTeil(e.schritte, art: .schritte, e: e)
        case .wasser: return massTeil(e.wasser, art: .wasser, e: e)
        }
    }

    private static func schlafTeil(_ e: TagesformEingabe) -> Teil? {
        let erste: Int? = e.schlaf.first.flatMap { $0 }
        guard let letzte = erste, e.schlafZiel > 0 else { return nil }
        let ziel = Double(e.schlafZiel)
        // Zu wenig Schlaf wirkt überproportional: 7 h von 8 h geben 77 Punkte, 6 h nur 56, 5 h nur 39 (Anteil zum Quadrat).
        func nacht(_ minuten: Double) -> Double {
            let anteil = min(1, max(0, minuten / ziel))
            return 100 * anteil * anteil
        }
        let davor: [Int] = e.schlaf.dropFirst().prefix(2).compactMap { $0 }
        var wert = nacht(Double(letzte))
        var detail: [String] = [String(localized: "Letzte Nacht \(stunden(letzte)) von \(stunden(e.schlafZiel)) Ziel")]
        if !davor.isEmpty {
            let schnittDavor = Double(davor.reduce(0, +)) / Double(davor.count)
            wert = letzteNachtAnteil * wert + (1 - letzteNachtAnteil) * nacht(schnittDavor)
            let nachtWort = davor.count == 1 ? String(localized: "Nacht") : String(localized: "Nächte")
            detail.append(String(localized: "die \(nachtWort) davor im Mittel \(stunden(Int(schnittDavor.rounded())))"))
        }
        if let hinweis = e.schlafHinweis { detail.append(hinweis) }

        let uebliche: [Int] = e.schlaf.dropFirst().compactMap { $0 }
        var kurz = String(localized: "Schlaf \(stunden(letzte))")
        if Double(letzte) >= 0.95 * ziel {
            kurz += String(localized: ", Ziel erreicht")
        } else if uebliche.count >= 3 {
            let schnitt = uebliche.reduce(0, +) / uebliche.count
            if letzte < schnitt - 20 {
                kurz += String(localized: ", unter deinem Schnitt")
            } else if letzte > schnitt + 20 {
                kurz += String(localized: ", über deinem Schnitt")
            } else {
                kurz += String(localized: ", wie dein Schnitt")
            }
            detail.append(String(localized: "dein Schnitt \(stunden(schnitt))"))
        } else {
            kurz += String(localized: " von \(stunden(e.schlafZiel))")
        }
        return Teil(art: .schlaf, wert: wert, sicherheit: min(1, max(0.5, e.schlafSicherheit)), kurz: kurz,
                    detail: detail.joined(separator: ", ") + ".")
    }

    private static func rhythmusTeil(_ e: TagesformEingabe) -> Teil? {
        let zeiten: [Double] = e.bett.prefix(7).compactMap { $0 }.map { Double($0) }
        guard zeiten.count >= mindestNaechteBett else { return nil }
        let sd = streuung(zeiten)
        let wert = klemmen(100 * (streuungSchlecht - sd) / (streuungSchlecht - streuungGut))
        let kurz = sd < 40 ? String(localized: "Bettzeit regelmäßig") : String(localized: "Bettzeit schwankt um \(zahl(sd)) min")
        return Teil(art: .rhythmus, wert: wert, sicherheit: 1, kurz: kurz,
                    detail: String(localized: "Streuung der letzten \(zeiten.count) Bettzeiten: \(zahl(sd)) min. Bis 30 min gibt es volle Punkte."))
    }

    private static func hrvTeil(_ e: TagesformEingabe) -> Teil? {
        guard let v = vergleich(e.hrv) else { return nil }
        let z = (v.heute - v.mittel) / max(v.streuung, hrvStreuungBoden * v.mittel)
        let wert = klemmen(neutral + hrvSteigung * z)
        let wort = z < -0.5 ? String(localized: "unter deinem Schnitt") : (z > 0.5 ? String(localized: "über deinem Schnitt") : String(localized: "wie dein Schnitt"))
        return Teil(art: .hrv, wert: wert, sicherheit: 1, kurz: String(localized: "HRV \(zahl(v.heute)) ms, \(wort)"),
                    detail: String(localized: "Dein Schnitt der letzten Tage: \(zahl(v.mittel)) ms (SDNN aus Apple Health)."))
    }

    private static func ruhepulsTeil(_ e: TagesformEingabe) -> Teil? {
        guard let v = vergleich(e.ruhepuls) else { return nil }
        let d = v.heute - v.mittel
        let wert = klemmen(neutral - ruhepulsSteigung * d)
        let kurz: String
        if d >= 1.5 {
            kurz = String(localized: "Ruhepuls \(zahl(v.heute)), \(zahl(d)) über deinem Schnitt")
        } else if d <= -1.5 {
            kurz = String(localized: "Ruhepuls \(zahl(v.heute)), \(zahl(-d)) unter deinem Schnitt")
        } else {
            kurz = String(localized: "Ruhepuls \(zahl(v.heute)), wie dein Schnitt")
        }
        return Teil(art: .ruhepuls, wert: wert, sicherheit: 1, kurz: kurz,
                    detail: String(localized: "Dein Schnitt der letzten Tage: \(zahl(v.mittel)) Schläge pro Minute."))
    }

    private static func erholungTeil(_ e: TagesformEingabe) -> Teil? {
        // Ohne ein einziges Training in 4 Wochen sagt die Muskelerholung nichts über die Form.
        guard e.saetze.contains(where: { $0 > 0 }) else { return nil }
        let bekannt: [Int] = e.muskeln.map { $0.prozent }
        let fehlt = max(0, MuskelTeil.allCases.count - bekannt.count)
        let alle: [Int] = (bekannt + Array(repeating: 100, count: fehlt)).sorted()
        let muedeste: [Int] = Array(alle.prefix(muedeTeile))
        let wert = klemmen(Double(muedeste.reduce(0, +)) / Double(max(1, muedeste.count)))

        var tiefste: [String: Int] = [:]
        for m in e.muskeln { tiefste[m.gruppe] = min(tiefste[m.gruppe] ?? 100, m.prozent) }
        let muede = tiefste.filter { $0.value < 90 }.sorted { a, b in
            a.value != b.value ? a.value < b.value : a.key < b.key
        }
        var kurz = String(localized: "Muskeln erholt")
        if !muede.isEmpty {
            let namen: [String] = muede.prefix(2).map { "\($0.key) \($0.value) %" }
            kurz = String(localized: "\(namen.joined(separator: ", ")) noch müde")
        }
        return Teil(art: .erholung, wert: wert, sicherheit: 1, kurz: kurz,
                    detail: String(localized: "Mittel der \(muedeTeile) müdesten von \(MuskelTeil.allCases.count) Muskelteilen: \(zahl(wert)) %."))
    }

    private static func lastTeil(_ e: TagesformEingabe) -> Teil? {
        func saetzeAm(_ i: Int) -> Int { i < e.saetze.count ? e.saetze[i] : 0 }
        let drei: Int = (1...3).reduce(0) { $0 + saetzeAm($1) }
        let achtundzwanzig: Int = (1...28).reduce(0) { $0 + saetzeAm($1) }
        guard achtundzwanzig > 0 else { return nil }
        let ueblich = Double(achtundzwanzig) / 28
        let r = (Double(drei) / 3) / ueblich
        let wert: Double
        if r <= lastGrenze {
            wert = 100
        } else if r <= 2 {
            wert = 100 - 60 * (r - lastGrenze) / (2 - lastGrenze)
        } else {
            wert = klemmen(40 - 40 * (r - 2))
        }
        let wort = r > lastGrenze ? String(localized: "mehr als sonst") : (r < 0.7 ? String(localized: "weniger als sonst") : String(localized: "wie sonst"))
        return Teil(art: .last, wert: wert, sicherheit: 1, kurz: String(localized: "Training \(drei) Sätze in 3 Tagen, \(wort)"),
                    detail: String(localized: "Dein Schnitt der letzten 4 Wochen: \(zahl(ueblich * 3)) Sätze je 3 Tage."))
    }

    private static func massTeil(_ m: TagesformMass?, art: TagesformArt, e: TagesformEingabe) -> Teil? {
        guard let m, m.ziel > 0, m.ziel.isFinite, m.ist.isFinite else { return nil }
        var wert: Double = massWert(art, ist: m.ist, ziel: m.ziel)
        var detail: String? = nil
        // Am Vormittag zählt der Vortag noch mit, in Punkten gemischt (nicht im Anteil: bei Schritten und Wasser kappt 100).
        if let d = m.davor, d.ziel > 0, d.ziel.isFinite, d.ist.isFinite {
            wert = (1 - d.anteil) * wert + d.anteil * massWert(art, ist: d.ist, ziel: d.ziel)
            detail = String(localized: "Am Vormittag zählt noch der Vortag: gestern \(zahl(d.ist)) von \(zahl(d.ziel)), zu \(Int((d.anteil * 100).rounded())) %.")
        }
        return Teil(art: art, wert: wert, sicherheit: 1, kurz: masstext(art, m, e), detail: detail)
    }

    /// Punkte (0 bis 100) für `ist` gegen `ziel`.
    private static func massWert(_ art: TagesformArt, ist: Double, ziel: Double) -> Double {
        let p = max(0, ist) / ziel
        switch art {
        case .kalorien: return kalorienWert(p)
        case .eiweiss: return klemmen(100 * (p - 0.4) / 0.6)
        default: return klemmen(100 * p)
        }
    }

    /// Auf Ziel (90 bis 110 Prozent) volle Punkte, darunter fällt es schnell (40 Prozent = 0), darüber langsam (200 Prozent = 0).
    private static func kalorienWert(_ p: Double) -> Double {
        if p < 0.9 { return klemmen(100 - (0.9 - p) * 200) }
        if p > 1.1 { return klemmen(100 - (p - 1.1) * 100 / 0.9) }
        return 100
    }

    private static func masstext(_ art: TagesformArt, _ m: TagesformMass, _ e: TagesformEingabe) -> String {
        let ist = zahl(m.ist)
        let ziel = zahl(m.ziel)
        let einheit = art.einheit.isEmpty ? "" : " " + art.einheit
        let vortag = e.stunde >= 24 ? String(localized: "am Vortag") : String(localized: "gestern")
        switch m.bezug {
        case .vortag: return String(localized: "\(art.titel) \(vortag) \(ist) von \(ziel)\(einheit)")
        case .bisJetzt: return String(localized: "\(art.titel) bis jetzt \(ist), Soll \(ziel)\(einheit)")
        case .tag: return String(localized: "\(art.titel) \(ist) von \(ziel)\(einheit)")
        }
    }

    // MARK: Zahlen

    /// Heute gegen den Schnitt der Tage davor (bis 28). nil ohne Wert von heute oder mit zu wenig Vergleich.
    private static func vergleich(_ werte: [Double?]) -> (heute: Double, mittel: Double, streuung: Double)? {
        let erster: Double? = werte.first.flatMap { $0 }
        guard let heute = erster, heute.isFinite else { return nil }
        let basis: [Double] = werte.dropFirst().prefix(28).compactMap { $0 }.filter { $0 > 0 && $0.isFinite }
        guard basis.count >= mindestBasisTage else { return nil }
        let mittel = basis.reduce(0, +) / Double(basis.count)
        guard mittel > 0 else { return nil }
        return (heute, mittel, streuung(basis))
    }

    private static func streuung(_ werte: [Double]) -> Double {
        guard !werte.isEmpty else { return 0 }
        let mittel = werte.reduce(0, +) / Double(werte.count)
        let quadrate: Double = werte.reduce(0.0) { $0 + ($1 - mittel) * ($1 - mittel) }
        return (quadrate / Double(werte.count)).squareRoot()
    }

    private static func klemmen(_ x: Double) -> Double { min(100, max(0, x)) }

    /// Ganzzahl mit deutschem Tausenderpunkt.
    private static func zahl(_ x: Double) -> String {
        guard x.isFinite, abs(x) < 1e12 else { return "0" }
        return Int(x.rounded()).formatted(.number.locale(Locale(identifier: "de_DE")))
    }

    /// "6:10 h".
    private static func stunden(_ minuten: Int) -> String {
        "\(minuten / 60):\(String(format: "%02d", minuten % 60)) h"
    }
}
