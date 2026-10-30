import Foundation

/// Die Regeln hinter den Ansichten des Partners (Trainingsplan, Verlauf, Tagebuch, Körperwerte): was zu sehen ist, wenn der Partner es freigibt, was bei
/// fehlender Freigabe oder veralteten Daten gilt und welche Worte dort stehen. Rein und ohne Oberfläche testbar.
enum PartnerAnsichtLogik {
    /// In welcher Lage ist die Ansicht einer Art: kein Partner, nicht freigegeben, freigegeben ohne Daten oder bereit (veraltet = älter als `LoveaVertrag.frist`).
    enum Lage: Equatable, Sendable {
        case keinPartner
        case nichtFreigegeben(String)
        case keineDaten(String)
        case bereit(ZusammenfassungDatei, veraltet: Bool)
    }

    /// Die Datei im Stand `verbunden` oder `veraltet` (die Ansichten zeigen auch ältere Daten, mit Hinweis); sonst nil.
    static func datei(_ stand: PartnerStand) -> ZusammenfassungDatei? {
        switch stand {
        case .verbunden(let d), .veraltet(let d): d
        case .nichtVerbunden, .unbekannteVersion: nil
        }
    }

    static func lage(_ stand: PartnerStand, art: FreigabeArt) -> Lage {
        let datei: ZusammenfassungDatei
        let veraltet: Bool
        switch stand {
        case .verbunden(let d): datei = d; veraltet = false
        case .veraltet(let d): datei = d; veraltet = true
        case .nichtVerbunden, .unbekannteVersion: return .keinPartner
        }
        guard datei.freigaben.contains(art) else { return .nichtFreigegeben(datei.profilName) }
        guard hatDaten(datei, art) else { return .keineDaten(datei.profilName) }
        return .bereit(datei, veraltet: veraltet)
    }

    /// Steht zu dieser Art etwas in der Datei? (Freigabe allein genügt nicht: ein neuer Partner hat vielleicht noch keinen Plan.)
    static func hatDaten(_ datei: ZusammenfassungDatei, _ art: FreigabeArt) -> Bool {
        switch art {
        case .plan: datei.heute.plan != nil
        case .verlauf: datei.heute.verlauf != nil
        case .tagebuch: !(datei.heute.tagebuch ?? []).isEmpty
        case .koerper: !(datei.heute.koerper ?? [:]).isEmpty
        case .schritte, .gym, .schlaf, .essen: true
        }
    }

    static let nichtFreigegebenSatz = "Dein Partner hat das nicht freigegeben."
    static let keinPartnerSatz = "Es ist noch kein Partner verbunden."

    static func leerSatz(_ lage: Lage, art: FreigabeArt) -> String {
        switch lage {
        case .keinPartner: keinPartnerSatz
        case .nichtFreigegeben: nichtFreigegebenSatz
        case .keineDaten(let name): "\(name) hat dazu noch nichts, \(leerGrund(art))."
        case .bereit: ""
        }
    }

    private static func leerGrund(_ art: FreigabeArt) -> String {
        switch art {
        case .plan: "zum Beispiel noch keinen Plan angelegt"
        case .verlauf: "zum Beispiel noch kein Training gemacht"
        case .tagebuch: "zum Beispiel in den letzten Tagen nichts eingetragen"
        case .koerper: "zum Beispiel noch keinen Messwert eingetragen"
        case .schritte, .gym, .schlaf, .essen: "noch keine Werte"
        }
    }

    /// Der Hinweis über den Daten, wenn der Stand älter als 48 Stunden ist. Sonst nil.
    static func veraltetHinweis(_ datei: ZusammenfassungDatei, veraltet: Bool) -> String? {
        guard veraltet else { return nil }
        return "Stand vom \(kurzDatum(Datum.text(datei.geschrieben))). \(datei.profilName) hat sich länger nicht gemeldet."
    }

    // MARK: Einstiege (Partner-Karte, Verbindungen)

    struct Einstieg: Identifiable, Equatable, Sendable {
        var art: FreigabeArt
        var titel: String
        var untertitel: String
        var symbol: String
        var id: String { art.rawValue }
    }

    nonisolated static let ansichtsArten: [FreigabeArt] = [.plan, .verlauf, .tagebuch, .koerper]

    /// Die Ansichten, die der Partner freigegeben hat und zu denen die Datei etwas enthält. Leer, wenn nichts davon freigegeben ist.
    static func einstiege(_ datei: ZusammenfassungDatei, jetzt: Date) -> [Einstieg] {
        ansichtsArten.compactMap { art -> Einstieg? in
            guard datei.freigaben.contains(art), hatDaten(datei, art) else { return nil }
            return Einstieg(art: art, titel: titel(art), untertitel: untertitel(datei, art, jetzt: jetzt), symbol: symbol(art))
        }
    }

    static func titel(_ art: FreigabeArt) -> String {
        switch art {
        case .plan: "Trainingsplan"
        case .verlauf: "Training und Verlauf"
        case .tagebuch: "Tagebuch"
        case .koerper: "Körperwerte"
        case .schritte: "Schritte"
        case .gym: "Gym"
        case .schlaf: "Schlaf"
        case .essen: "Essen"
        }
    }

    static func symbol(_ art: FreigabeArt) -> String {
        switch art {
        case .plan: "calendar"
        case .verlauf: "figure.strengthtraining.traditional"
        case .tagebuch: "book.closed"
        case .koerper: "scalemass"
        case .schritte: "figure.walk"
        case .gym: "dumbbell.fill"
        case .schlaf: "bed.double.fill"
        case .essen: "fork.knife"
        }
    }

    static func untertitel(_ datei: ZusammenfassungDatei, _ art: FreigabeArt, jetzt: Date) -> String {
        let heute = Datum.text(jetzt)
        switch art {
        case .plan:
            guard let plan = datei.heute.plan else { return "" }
            let tage = trainingsTage(plan)
            return [plan.name, tage == 1 ? "1 Trainingstag" : "\(tage) Trainingstage"].compactMap { $0 }.joined(separator: " · ")
        case .verlauf:
            guard let v = datei.heute.verlauf else { return "" }
            if let status = statusZeile(v, jetzt: jetzt) { return status }
            return (v.gesamt ?? v.trainings.count) == 1 ? "1 Training" : "\(v.gesamt ?? v.trainings.count) Trainings"
        case .tagebuch:
            let tage = tagebuchTage(datei)
            if let t = tage.first(where: { $0.tag == heute }) { return "Heute \(zahl(t.kcal)) kcal" }
            return tage.count == 1 ? "Ein Tag" : "Letzte \(tage.count) Tage"
        case .koerper:
            if let p = punkte(datei, .gewicht).last { return "Gewicht \(MessArt.gewicht.text(p.zehntel))" }
            let n = koerperArten(datei).count
            return n == 1 ? "1 Messung" : "\(n) Messungen"
        case .schritte, .gym, .schlaf, .essen:
            return ""
        }
    }

    // MARK: Plan

    struct Spalte: Identifiable, Equatable, Sendable {
        enum Art: Equatable, Sendable { case training(String), ruhe, offen }
        var wochentag: Int
        var art: Art
        var istHeute: Bool
        var id: Int { wochentag }
        var kuerzel: String { HabitLogik.wochentagKuerzel[wochentag - 1] }
        var langerName: String { TrainingLogik.wochentagName[wochentag - 1] }
        var titel: String {
            switch art {
            case .training(let n): n.isEmpty ? "Training" : n
            case .ruhe: "Ruhe"
            case .offen: "?"
            }
        }
        var beschreibung: String {
            switch art {
            case .training(let n): n.isEmpty ? "Training" : n
            case .ruhe: "Ruhetag"
            case .offen: "noch nicht geplant"
            }
        }
    }

    /// Mo bis So: Name des Trainingstags, "Ruhe" oder offen. `heute` ist der Wochentag von heute (1 bis 7).
    static func spalten(_ plan: PartnerPlan, heute: Int) -> [Spalte] {
        (1...7).map { w -> Spalte in
            let art: Spalte.Art
            if let t = plan.tage.first(where: { $0.wochentage.contains(w) }) { art = .training(t.name) }
            else if (plan.ruhetage ?? []).contains(w) { art = .ruhe }
            else { art = .offen }
            return Spalte(wochentag: w, art: art, istHeute: w == heute)
        }
    }

    static func trainingsTage(_ plan: PartnerPlan) -> Int {
        Set(plan.tage.flatMap(\.wochentage)).count
    }

    /// "Mo, Mi, Fr" oder "an jedem Tag möglich" für einen Tag ohne festen Wochentag.
    static func wochentageText(_ tag: PartnerPlanTag) -> String {
        tag.wochentage.isEmpty ? "an jedem Tag möglich" : TrainingLogik.wochentageText(tag.wochentage)
    }

    static func uebungText(_ u: PartnerPlanUebung) -> String {
        switch u.saetze {
        case ...0: "Cardio oder frei"
        case 1: "1 Satz"
        default: "\(u.saetze) Sätze"
        }
    }

    /// Der Tag des Plans, der heute dran ist (nil an Ruhetagen und offenen Tagen).
    static func heutigerTag(_ plan: PartnerPlan, wochentag: Int) -> PartnerPlanTag? {
        plan.tage.first { $0.wochentage.contains(wochentag) }
    }

    // MARK: Verlauf

    /// "Im Gym seit 45 min" solange die Einheit läuft. Nach drei Stunden gilt sie als vergessen (wie bei der eigenen Einheit) und die Zeile entfällt.
    static func statusZeile(_ v: PartnerVerlauf, jetzt: Date) -> String? {
        guard v.imGym == true, let seit = v.imGymSeit else { return nil }
        let dauer = jetzt.timeIntervalSince(seit)
        guard dauer < TrainingLogik.langNach else { return nil }
        let ort = v.imGymName.map { "Im Gym (\($0))" } ?? "Im Gym"
        let min = max(0, Int(dauer / 60))
        return min < 1 ? ort : "\(ort) seit \(min) min"
    }

    struct Kennzahl: Identifiable, Equatable, Sendable {
        var titel: String
        var wert: Int
        var id: String { titel }
    }

    static func kennzahlen(_ v: PartnerVerlauf) -> [Kennzahl] {
        [Kennzahl(titel: "Diese Woche", wert: v.woche ?? 0), Kennzahl(titel: "Serie in Wochen", wert: v.serieWochen ?? 0),
         Kennzahl(titel: "Gesamt", wert: v.gesamt ?? v.trainings.count)]
    }

    /// Titel und Detailzeile einer Einheit: "Push" und "Do 29.10. · 61 min · 18 Sätze · 5 Übungen".
    static func trainingZeile(_ t: PartnerTrainingKurz) -> (titel: String, detail: String) {
        var teile = ["\(HabitLogik.wochentagKuerzel[Datum.wochentag(t.tag) - 1]) \(kurzDatum(t.tag))"]
        if let m = t.minuten, m > 0 { teile.append("\(m) min") }
        teile.append(t.saetze == 1 ? "1 Satz" : "\(t.saetze) Sätze")
        if t.uebungen > 0 { teile.append(t.uebungen == 1 ? "1 Übung" : "\(t.uebungen) Übungen") }
        return (t.name ?? "Training", teile.joined(separator: " · "))
    }

    struct DauerPunkt: Identifiable, Equatable, Sendable {
        var tag: String
        var minuten: Int
        var id: String { tag }
    }

    /// Dauer der Einheiten für das Diagramm, älteste zuerst (nur Einheiten mit Dauer; zwei am selben Tag zählen zusammen).
    static func dauerPunkte(_ v: PartnerVerlauf) -> [DauerPunkt] {
        var jeTag: [String: Int] = [:]
        for t in v.trainings { if let m = t.minuten, m > 0 { jeTag[t.tag, default: 0] += m } }
        return jeTag.map { DauerPunkt(tag: $0.key, minuten: $0.value) }.sorted { $0.tag < $1.tag }
    }

    // MARK: Tagebuch

    /// Die Tage mit Einträgen, neuester zuerst (nur mit Freigabe tagebuch).
    static func tagebuchTage(_ datei: ZusammenfassungDatei) -> [PartnerTagebuchTag] {
        guard datei.freigaben.contains(.tagebuch) else { return [] }
        return (datei.heute.tagebuch ?? []).sorted { $0.tag > $1.tag }
    }

    /// Die sieben Tage, durch die man blättern kann: heute und die sechs davor, neuester zuerst.
    static func blaetterTage(heute: String) -> [String] {
        (0..<PartnerAnsichtsDaten.tagebuchTage).map { Datum.addTage(heute, -$0) }
    }

    /// Ein Schritt im Blättern: `richtung` -1 = ein Tag zurück, 1 = ein Tag vor. Bleibt in den sieben Tagen.
    static func blaettern(von tag: String, richtung: Int, heute: String) -> String {
        let tage = blaetterTage(heute: heute)
        guard let i = tage.firstIndex(of: tag) else { return heute }
        let neu = i - richtung
        return tage.indices.contains(neu) ? tage[neu] : tag
    }

    struct Gruppe: Identifiable, Equatable, Sendable {
        var mahlzeit: Mahlzeit
        var eintraege: [PartnerMahlzeitKurz]
        var kcal: Int
        var id: String { mahlzeit.rawValue }
    }

    /// Die Einträge eines Tages nach Mahlzeit in der Reihenfolge Frühstück bis Snack; leere Mahlzeiten fehlen.
    /// Eine unbekannte Mahlzeit (eine neuere App hat sie geschrieben) zählt zu "Snacks".
    static func gruppen(_ tag: PartnerTagebuchTag) -> [Gruppe] {
        var aus: [Gruppe] = []
        for m in Mahlzeit.allCases {
            var liste = tag.mahlzeiten.filter { $0.mahlzeit == m.rawValue }
            if m == .snack { liste += tag.mahlzeiten.filter { Mahlzeit(rawValue: $0.mahlzeit) == nil } }
            if !liste.isEmpty { aus.append(Gruppe(mahlzeit: m, eintraege: liste, kcal: liste.reduce(0) { $0 + $1.kcal })) }
        }
        return aus
    }

    /// Anteil am Ziel für einen Balken (0 bis 1; über dem Ziel bleibt er voll).
    static func anteil(_ wert: Int, ziel: Int) -> Double {
        guard ziel > 0 else { return 0 }
        return min(1, max(0, Double(wert) / Double(ziel)))
    }

    static func tagTitel(_ tag: String, heute: String) -> String {
        if tag == heute { return "Heute" }
        if tag == Datum.addTage(heute, -1) { return "Gestern" }
        return Datum.anzeige(tag)
    }

    // MARK: Körper

    /// Die Messarten, zu denen der Partner Werte geteilt hat, in der Reihenfolge von `MessArt` (nur mit Freigabe koerper).
    static func koerperArten(_ datei: ZusammenfassungDatei) -> [MessArt] {
        guard datei.freigaben.contains(.koerper) else { return [] }
        let koerper = datei.heute.koerper ?? [:]
        return MessArt.allCases.filter { !(koerper[$0.rawValue] ?? []).isEmpty }
    }

    /// Die Messpunkte einer Art, älteste zuerst; leer ohne Freigabe.
    static func punkte(_ datei: ZusammenfassungDatei, _ art: MessArt) -> [MessPunkt] {
        guard datei.freigaben.contains(.koerper) else { return [] }
        return (datei.heute.koerper?[art.rawValue] ?? []).filter { $0.zehntel > 0 }.map { MessPunkt(tag: $0.tag, zehntel: $0.zehntel) }.sorted { $0.tag < $1.tag }
    }

    /// Soll der Umschalter "Ich / Partner" in den Messungen erscheinen? Nur wenn der Partner Körperwerte freigegeben hat und etwas da ist.
    static func umschalterSichtbar(_ stand: PartnerStand) -> Bool {
        if case .bereit = lage(stand, art: .koerper) { true } else { false }
    }

    // MARK: Gemeinsames

    /// 1450 -> "1.450", immer deutsch (unabhängig von der Spracheinstellung des Geräts, damit Text und Test gleich bleiben).
    static func zahl(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }

    /// "29.10." aus "2026-10-29".
    static func kurzDatum(_ tag: String) -> String {
        let t = tag.split(separator: "-")
        guard t.count == 3, let m = Int(t[1]), let d = Int(t[2]) else { return tag }
        return "\(d).\(m)."
    }
}
