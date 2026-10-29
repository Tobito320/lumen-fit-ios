// Quelle: Lovea Health/Coach/CoachRegeln.swift
import Foundation

// Health-Coach, Ebene 1: reine Regeln ohne KI und ohne Netz. Aus den eigenen Zahlen der Person wird eine kurze
// Liste `CoachKarte`. Nichts hier liest Modelle oder die Uhr, alles kommt über `CoachEingabe`. Der Lader dazu steht in
// `CoachGesundheit.swift` (`CoachDaten`). In Lumen Fit ist das die Grundlage des Regelcoachs (`RegelCoachMotor`).
//
// Abweichungen von Lovea: `CoachNachricht`, `CoachVerlauf` und `CoachFehler` entfallen (der Verlauf liegt im `CoachStore`, es gibt keinen
// Server); `CoachUebung` trägt die Steigerung als eigenes `CoachSteigerung` (Loveas `KoerperLogik` gehört dem Modul fortschritt).
//
// Leitplanken (Plan "Lovea – Health-Coach"): nie ein Kalorien-Defizit empfehlen, nie unter die Untergrenze,
// Lücken im Essens-Log nie als echte Aufnahme behandeln, keine Streaks, ruhiger Ton, kein Lob und kein Alarm
// beim Gewicht.

// MARK: - Karten

struct CoachKarte: Equatable, Identifiable, Sendable {
    enum Art: String, Sendable { case sicherheit, essenLog, training, steigerung, protein, schritte, gewicht }

    let art: Art
    let titel: String
    let text: String
    var id: String { art.rawValue }
}

/// Eine Muskelgruppe der Woche: gemachte Sätze (Mitarbeit zählt halb) gegen das Satzziel.
struct CoachGruppe: Equatable, Sendable {
    let name: String
    let saetze: Double
    let ziel: Int
    /// Aus `KoerperLogik.faellig` (unter der Hälfte des Wochenziels), damit die Regel nur einmal existiert.
    let faellig: Bool
}

/// Vorschlag fürs nächste Mal (doppelte Progression), wie Loveas `KoerperLogik.naechstesMal`.
struct CoachSteigerung: Equatable, Sendable {
    let kg: Double?
    let wdh: Int
    let mehrGewicht: Bool

    /// Alle Sätze am oberen Ende: +2,5 kg und zurück auf `start` Wiederholungen. Sonst gleiches Gewicht und eine Wiederholung mehr als der
    /// schwächste Satz. Ohne Gewicht (Körpergewicht) gibt es nur Wiederholungen. Leer: nil.
    // ponytail: das obere Ende ist fest 12, der Plan speichert keinen Wiederholungsbereich.
    static func naechstesMal(_ saetze: [PlanSatz], oben: Int = 12, start: Int = 8) -> CoachSteigerung? {
        guard !saetze.isEmpty else { return nil }
        let kg = saetze.compactMap(\.kg).max()
        let arbeit = saetze.filter { $0.kg == kg }
        let schwach = arbeit.map(\.wdh).min() ?? 0
        if schwach >= oben { return CoachSteigerung(kg: kg.map { $0 + 2.5 }, wdh: kg == nil ? oben : start, mehrGewicht: true) }
        return CoachSteigerung(kg: kg, wdh: schwach + 1, mehrGewicht: false)
    }

    func text(oben: Int = 12) -> String {
        guard let kg else {
            return mehrGewicht ? "Alle Sätze bei \(oben). Nimm Zusatzgewicht." : "\(wdh) Wiederholungen. Bei \(oben) in jedem Satz: Zusatzgewicht."
        }
        if mehrGewicht { return "Alle Sätze bei \(oben). Nächstes Mal \(TrainingLogik.kgText(kg)) kg × \(wdh)." }
        return "\(TrainingLogik.kgText(kg)) kg × \(wdh). Bei \(oben) in jedem Satz: \(TrainingLogik.kgText(kg + 2.5)) kg."
    }
}

/// Eine zuletzt trainierte Übung samt Vorschlag fürs nächste Mal.
struct CoachUebung: Equatable, Sendable {
    let name: String
    let vorschlag: CoachSteigerung
}

struct CoachEingabe: Equatable, Sendable {
    /// "YYYY-MM-DD". Heute zählt in keinem Schnitt mit, der Tag ist noch nicht vorbei.
    var heute: String
    /// 0 = Mann, 1 = Frau (`ErnaehrungsZiele.geschlecht`).
    var geschlecht = 0
    /// Nur dann ist das Proteinziel ein echtes Ziel und kein Schätzwert aus dem Gewicht.
    var zieleEingerichtet = false
    var proteinZiel = 0
    /// Summe je Tag, nur Tage mit Einträgen.
    var essenKcal: [String: Double] = [:]
    var essenProtein: [String: Double] = [:]
    /// Zehntel kg je Tag (`Habit.gewicht`).
    var gewicht: [String: Int] = [:]
    var schritte: [String: Int] = [:]
    var schrittZiel = 0
    var gruppen: [CoachGruppe] = []
    /// Neueste zuerst.
    var uebungen: [CoachUebung] = []
}

/// Was das Essens-Log der letzten 14 Tage hergibt. Nur Tage mit echtem Essen zählen als geloggt.
struct CoachEssenStand: Equatable, Sendable {
    let geloggteTage: Int
    let kcalSchnitt: Double?
    let proteinSchnitt: Double?
    /// Weniger als 10 von 14 Tagen: der Schnitt ist keine echte Aufnahme.
    let lueckig: Bool
    /// Schnitt unter der Untergrenze, aber nur bei brauchbarem Log: wer selten trackt, hat keine Aufnahme, die man bewerten könnte.
    let sehrWenig: Bool
}

enum CoachRegeln {
    static let untergrenzeFrau = 1200
    static let untergrenzeMann = 1500
    static let fensterTage = 14
    static let mindestTageImLog = 10
    /// Ein Tag mit nur Kaffee (Koffein-Kachel schreibt einen Tagebuch-Eintrag, rund 4 kcal) ist kein geloggter Tag.
    static let mindestKcalProLogTag = 200.0

    static let schnellfragen = ["Tagesbericht", "Wie läuft mein Training?", "Was soll ich heute essen?"]

    /// Dieselbe Grenze wie in `ErnaehrungLogik.kalorienziel` (dort ein lokales `let minimum`, Ernaehrung.swift).
    static func untergrenze(geschlecht: Int) -> Int { geschlecht == 1 ? untergrenzeFrau : untergrenzeMann }

    /// "YYYY-MM-DD". `Datum.datum` stürzt bei allem anderen ab, deshalb prüft die Karte Schlüssel von außen vorher.
    static func istTag(_ text: String) -> Bool {
        let zeichen = Array(text)
        guard zeichen.count == 10 else { return false }
        return zeichen.enumerated().allSatisfy { stelle, c in
            stelle == 4 || stelle == 7 ? c == "-" : (c.isASCII && c.isNumber)
        }
    }

    // MARK: Essen

    static func essenStand(_ e: CoachEingabe) -> CoachEssenStand {
        let tage = (1...fensterTage).map { Datum.addTage(e.heute, -$0) }.filter { (e.essenKcal[$0] ?? 0) >= mindestKcalProLogTag }
        guard !tage.isEmpty else {
            return CoachEssenStand(geloggteTage: 0, kcalSchnitt: nil, proteinSchnitt: nil, lueckig: true, sehrWenig: false)
        }
        let n = Double(tage.count)
        let kcal = tage.reduce(0.0) { $0 + (e.essenKcal[$1] ?? 0) } / n
        let protein = tage.reduce(0.0) { $0 + (e.essenProtein[$1] ?? 0) } / n
        return CoachEssenStand(
            geloggteTage: tage.count, kcalSchnitt: kcal, proteinSchnitt: protein,
            lueckig: tage.count < mindestTageImLog,
            sehrWenig: tage.count >= mindestTageImLog && kcal < Double(untergrenze(geschlecht: e.geschlecht)))
    }

    // MARK: Karten

    /// Reihenfolge = Wichtigkeit. Leer, wenn nichts zu sagen ist.
    static func karten(_ e: CoachEingabe) -> [CoachKarte] {
        let essen = essenStand(e)
        var liste: [CoachKarte] = []
        if essen.sehrWenig, let kcal = essen.kcalSchnitt {
            liste.append(sicherheitsKarte(kcal: kcal, geschlecht: e.geschlecht))
        } else if essen.geloggteTage > 0 && essen.lueckig {
            liste.append(essenLogKarte(essen))
        }
        if let k = trainingKarte(e) { liste.append(k) }
        if let k = steigerungsKarte(e) { liste.append(k) }
        if !essen.sehrWenig && !essen.lueckig, let k = proteinKarte(e, essen) { liste.append(k) }
        if let k = schritteKarte(e) { liste.append(k) }
        if !essen.sehrWenig, let k = gewichtKarte(e) { liste.append(k) }
        return liste
    }

    private static func sicherheitsKarte(kcal: Double, geschlecht: Int) -> CoachKarte {
        let schnitt = CoachFormat.zahl(Int(kcal.rounded()))
        let grenze = CoachFormat.zahl(untergrenze(geschlecht: geschlecht))
        return CoachKarte(
            art: .sicherheit, titel: "Essen im Log",
            text: "Im Log liegst du im Schnitt bei etwa \(schnitt) kcal am Tag, unter \(grenze). Vielleicht fehlt nur Essen im Log. "
                + "Wenn du wirklich so wenig isst: bitte nicht weiter kürzen. Sprich dann mit einer Ärztin, einem Arzt oder einer Beratungsstelle. "
                + "Du musst das nicht allein klären.")
    }

    private static func essenLogKarte(_ essen: CoachEssenStand) -> CoachKarte {
        CoachKarte(
            art: .essenLog, titel: "Essens-Log",
            text: "Im Log sind \(essen.geloggteTage) von \(fensterTage) Tagen. Was fehlt, rechne ich nicht als echte Aufnahme. Du musst nichts nachtragen.")
    }

    /// Erst ab Donnerstag, vorher steht am Wochenanfang fast jede Gruppe unter der Hälfte.
    private static func trainingKarte(_ e: CoachEingabe) -> CoachKarte? {
        guard Datum.wochentag(e.heute) >= 4 else { return nil }
        let offen = e.gruppen.filter { $0.faellig && $0.ziel > 0 }.prefix(2)
        guard !offen.isEmpty else { return nil }
        let zeilen = offen.map { "\($0.name) \(TrainingLogik.kgText($0.saetze)) von \($0.ziel) Sätzen" }.joined(separator: ", ")
        return CoachKarte(art: .training, titel: "Wochensätze", text: "Diese Woche bisher: \(zeilen). Bis Sonntag ist noch Zeit.")
    }

    /// Die Übungen, bei denen die Steigerungsregel Mehrgewicht sagt, zuerst; höchstens zwei Zeilen.
    private static func steigerungsKarte(_ e: CoachEingabe) -> CoachKarte? {
        let bereit = e.uebungen.filter { $0.vorschlag.mehrGewicht }
        let rest = e.uebungen.filter { !$0.vorschlag.mehrGewicht }
        let auswahl = (bereit + rest).prefix(2)
        guard !auswahl.isEmpty else { return nil }
        let text = auswahl.map { "\($0.name): \($0.vorschlag.text())" }.joined(separator: "\n")
        return CoachKarte(art: .steigerung, titel: "Nächstes Mal", text: text)
    }

    private static func proteinKarte(_ e: CoachEingabe, _ essen: CoachEssenStand) -> CoachKarte? {
        guard e.zieleEingerichtet, e.proteinZiel > 0, let schnitt = essen.proteinSchnitt,
              schnitt < Double(e.proteinZiel) * 0.85 else { return nil }
        return CoachKarte(
            art: .protein, titel: "Protein",
            text: "Im Log liegst du bei etwa \(CoachFormat.zahl(Int(schnitt.rounded()))) g Protein am Tag, dein Ziel ist \(e.proteinZiel) g. "
                + "Eine proteinreiche Mahlzeit mehr, zum Beispiel Quark, Skyr oder Eier, schließt die Lücke.")
    }

    private static func schritteKarte(_ e: CoachEingabe) -> CoachKarte? {
        guard e.schrittZiel > 0 else { return nil }
        let werte = (1...7).compactMap { e.schritte[Datum.addTage(e.heute, -$0)] }.filter { $0 > 0 }
        guard werte.count >= 3 else { return nil }
        let schnitt = werte.reduce(0, +) / werte.count
        guard Double(schnitt) < Double(e.schrittZiel) * 0.7 else { return nil }
        return CoachKarte(
            art: .schritte, titel: "Schritte",
            text: "In den letzten Tagen lagst du im Schnitt bei \(CoachFormat.zahl(schnitt)) Schritten, dein Ziel ist \(CoachFormat.zahl(e.schrittZiel)). "
                + "Ein Spaziergang mehr in der Woche ist ein guter Anfang.")
    }

    /// Nur Zahlen, kein Lob und kein Alarm. Schnitt der 7 Tage bis zum letzten Eintrag (`GewichtLogik.berechnet`),
    /// daneben die Woche davor. Ein letzter Eintrag, der älter als 10 Tage ist, sagt nichts mehr über jetzt.
    private static func gewichtKarte(_ e: CoachEingabe) -> CoachKarte? {
        let gueltig = e.gewicht.filter { $0.value > 0 && istTag($0.key) }
        guard let neuester = gueltig.keys.max(), Datum.tageZwischen(neuester, e.heute) <= 10 else { return nil }
        let ab = Datum.addTage(neuester, -6)
        guard gueltig.filter({ $0.key >= ab }).count >= 2, let jetzt = GewichtLogik.berechnet(gueltig) else { return nil }
        var text = "Schnitt der letzten 7 Tage: \(GewichtText.anzeige(jetzt))."
        let davorEnde = Datum.addTage(neuester, -7)
        let davor = gueltig.filter { $0.key <= davorEnde && $0.key >= Datum.addTage(neuester, -13) }
        if davor.count >= 2, let frueher = GewichtLogik.berechnet(davor) {
            text += " Woche davor: \(GewichtText.anzeige(frueher))."
        }
        text += " Einzelne Tage schwanken, der Schnitt zählt."
        return CoachKarte(art: .gewicht, titel: "Gewicht", text: text)
    }
}

/// Zahlen für Texte des Coachs.
enum CoachFormat {
    /// 8200 -> "8.200" (deutsche Schreibweise).
    static func zahl(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }
}
