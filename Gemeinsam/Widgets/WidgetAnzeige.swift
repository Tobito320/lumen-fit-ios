import Foundation

/// Reine Anzeige-Rechnung der Widgets (getestet ohne Widget-Umgebung): Bögen, Essen, Plan, Gewohnheiten, Tageswechsel, Vorlesetext.
/// Alle Werte kommen aus dem `WidgetSnapshot`; Werte "von heute" gelten nur, wenn der Tag des Snapshots der heutige ist.
enum WidgetAnzeige {
    // MARK: - Tag

    /// Stimmt der Tag des Snapshots mit heute überein? Nach Mitternacht zeigt das Widget "von heute"-Werte nicht mehr als heutig.
    static func istVonHeute(_ snapshot: WidgetSnapshot?, jetzt: Date) -> Bool {
        guard let tag = snapshot?.tag else { return false }
        return tag == Datum.text(jetzt)
    }

    /// Die nächste Berliner Mitternacht: dann lädt das Widget spätestens neu, auch wenn die App nichts schreibt.
    static func naechsteMitternacht(_ jetzt: Date) -> Date {
        let start = Datum.kalender.startOfDay(for: jetzt)
        return Datum.kalender.date(byAdding: .day, value: 1, to: start) ?? jetzt.addingTimeInterval(3600)
    }

    /// Dunkel, wenn die Person es so gewählt hat; bei "System" folgt es dem System.
    static func dunkel(erscheinung: Erscheinung?, system: Bool) -> Bool {
        switch erscheinung ?? .system {
        case .system: system
        case .hell: false
        case .dunkel: true
        }
    }

    // MARK: - Bögen

    /// Die drei Bögen: Bewegen (Schritte), Trainieren (Trainingstage der Woche), Erholen (Schlaf). Ohne Wert ein leerer Bogen und ein Strich.
    static func boegen(_ snapshot: WidgetSnapshot?, jetzt: Date) -> [BogenWert] {
        let werte = istVonHeute(snapshot, jetzt: jetzt) ? snapshot?.boegen : nil
        return [
            BogenWert(id: .bewegen, anteil: anteil(werte?.schritte, werte?.schritteZiel), zahl: werte?.schritte.map(zahlText) ?? "–", beschriftung: String(localized: "Schritte")),
            BogenWert(id: .trainieren, anteil: anteil(werte?.trainingTage, werte?.trainingZiel),
                      zahl: werte?.trainingTage.map { String(localized: "\($0) von \(max(werte?.trainingZiel ?? 0, 1))") } ?? "–", beschriftung: String(localized: "Training")),
            BogenWert(id: .erholen, anteil: anteil(werte?.schlafMinuten, werte?.schlafZiel),
                      zahl: werte?.schlafMinuten.map { LockscreenLogik.schlafText(minuten: $0) + " h" } ?? "–", beschriftung: String(localized: "Schlaf")),
        ]
    }

    /// 0 bis 1, ohne Wert oder ohne Ziel 0.
    static func anteil(_ wert: Int?, _ ziel: Int?) -> Double {
        guard let wert, let ziel, ziel > 0 else { return 0 }
        return min(max(Double(wert) / Double(ziel), 0), 1)
    }

    /// 8412 -> "8.412" (deutsche Tausenderpunkte, ohne statischen Formatierer).
    static func zahlText(_ wert: Int) -> String {
        wert.formatted(.number.grouping(.automatic).locale(Locale(identifier: "de_DE")))
    }

    /// Ein Satz für VoiceOver über alle drei Bögen.
    static func sprechtext(_ snapshot: WidgetSnapshot?, jetzt: Date) -> String {
        guard istVonHeute(snapshot, jetzt: jetzt), let b = snapshot?.boegen else { return String(localized: "Lumen Fit: noch keine Werte von heute") }
        var teile: [String] = []
        if let s = b.schritte { teile.append(b.schritteZiel.map { String(localized: "Schritte \(zahlText(s)) von \(zahlText($0))") } ?? String(localized: "Schritte \(zahlText(s))")) }
        if let t = b.trainingTage { teile.append(String(localized: "Training \(t) von \(max(b.trainingZiel ?? 0, 1)) Tagen in dieser Woche")) }
        if let m = b.schlafMinuten { teile.append(b.schlafZiel.map { String(localized: "Schlaf \(m / 60) Stunden \(m % 60) Minuten von \($0 / 60) Stunden") } ?? String(localized: "Schlaf \(m / 60) Stunden \(m % 60) Minuten")) }
        return teile.isEmpty ? String(localized: "Lumen Fit: noch keine Werte von heute") : teile.joined(separator: ", ")
    }

    // MARK: - Plan und Serie

    /// Titel und Zeitpunkt des nächsten Trainings: ("Push", "heute"), ("Pull", "morgen"), ("Beine", "in 3 Tagen"); ohne Plan ("Kein Training geplant", nil).
    static func planText(_ plan: WidgetPlanTag?, jetzt: Date) -> (titel: String, wann: String?) {
        guard let plan, let tage = LockscreenLogik.tageBis(tag: plan.tag, heute: Datum.text(jetzt)) else { return (String(localized: "Kein Training geplant"), nil) }
        return (plan.name, LockscreenLogik.countdownText(tage: tage))
    }

    /// "4 Wochen in Folge", "1 Woche in Folge", ohne Serie "Noch keine Serie".
    static func serieText(_ wochen: Int?) -> String {
        switch wochen ?? 0 {
        case ...0: String(localized: "Noch keine Serie")
        case 1: String(localized: "1 Woche in Folge")
        default: String(localized: "\(wochen ?? 0) Wochen in Folge")
        }
    }

    // MARK: - Essen

    struct EssenRest: Equatable, Sendable {
        /// Verbleibende Kalorien; negativ, wenn das Ziel überschritten ist.
        var kcal: Int
        var protein: Int
        var anteil: Double
    }

    /// Rest-Kalorien und Rest-Protein heute; ohne Eintrag oder von gestern nil.
    static func essenRest(_ snapshot: WidgetSnapshot?, jetzt: Date) -> EssenRest? {
        guard istVonHeute(snapshot, jetzt: jetzt), let e = snapshot?.essen else { return nil }
        return EssenRest(kcal: e.kcalZiel - e.kcal, protein: max(0, e.proteinZiel - e.protein), anteil: anteil(e.kcal, e.kcalZiel))
    }

    // MARK: - Gewohnheiten

    /// Der Wert, den ein Tipp setzt: zählende Gewohnheiten +1 und nach dem Ziel zurück auf 0, andere wechseln zwischen 0 und 1.
    /// Fester Wert statt "plus eins": ein zweiter Tipp vor dem Neuzeichnen setzt denselben Wert und zählt nicht doppelt.
    static func naechsterWert(zaehlen: Bool, heute: Int, ziel: Int) -> Int {
        zaehlen ? (heute >= max(ziel, 1) ? 0 : heute + 1) : (heute > 0 ? 0 : 1)
    }

    static func erledigt(_ habit: WidgetHabitKachel, wert: Int) -> Bool { habit.zaehlen ? wert >= max(habit.ziel, 1) : wert > 0 }

    /// Wert heute: nach Mitternacht (alter Snapshot) 0.
    static func wertHeute(_ habit: WidgetHabitKachel, snapshot: WidgetSnapshot?, jetzt: Date) -> Int {
        istVonHeute(snapshot, jetzt: jetzt) ? habit.heute : 0
    }

    /// "3 von 8" bei zählenden, "Erledigt" oder "Offen" bei den anderen.
    static func habitText(_ habit: WidgetHabitKachel, wert: Int) -> String {
        habit.zaehlen ? String(localized: "\(String(wert)) von \(String(max(habit.ziel, 1)))") : (wert > 0 ? String(localized: "Erledigt") : String(localized: "Offen"))
    }

    // MARK: - Sperrbildschirm

    /// Schlaf und Erholung für die rechteckige Zeile: "7:12 h" und "HRV 68 ms".
    static func schlafZeile(_ snapshot: WidgetSnapshot?, jetzt: Date) -> (schlaf: String?, erholung: String?, anteil: Double) {
        guard istVonHeute(snapshot, jetzt: jetzt), let b = snapshot?.boegen else { return (nil, nil, 0) }
        return (b.schlafMinuten.map { LockscreenLogik.schlafText(minuten: $0) + " h" }, b.hrv.map { "HRV \($0) ms" }, anteil(b.schlafMinuten, b.schlafZiel))
    }

    // MARK: - Gym-Woche und Duell

    /// Die sieben Tage der Woche von `jetzt` (Montag bis Sonntag). Gespeicherte Tage einer anderen Woche zählen nicht: nach dem Wochenwechsel startet sie leer.
    static func gymWoche(_ snapshot: WidgetSnapshot?, jetzt: Date) -> [WidgetGymTag] {
        let fertig = Set((snapshot?.gymWoche ?? []).filter(\.erledigt).map(\.tag))
        return HabitLogik.wochenTage(heute: Datum.text(jetzt)).map { WidgetGymTag(tag: $0, erledigt: fertig.contains($0)) }
    }

    /// Tage mit Gym bis heute (spätere Tage der Woche zählen nicht).
    static func gymZahl(_ tage: [WidgetGymTag], jetzt: Date) -> Int {
        let heute = Datum.text(jetzt)
        return tage.filter { $0.erledigt && $0.tag <= heute }.count
    }

    static func gymHeuteErledigt(_ snapshot: WidgetSnapshot?, jetzt: Date) -> Bool {
        let heute = Datum.text(jetzt)
        return gymWoche(snapshot, jetzt: jetzt).first { $0.tag == heute }?.erledigt ?? false
    }

    /// Das Gym-Ziel der Woche aus dem Snapshot (mindestens 1).
    static func gymZiel(_ snapshot: WidgetSnapshot?) -> Int { max(snapshot?.boegen?.trainingZiel ?? 3, 1) }

    /// Der Partner, wie das Widget ihn zeigt: nur wenn der Snapshot zu heute gehört. Seine Schritte und sein Schlaf gelten nur, wenn seine Datei von heute ist
    /// (sonst fehlen sie, nie ein gestriger Wert als heutiger); seine Gym-Tage tragen ihr eigenes Datum.
    static func partner(_ snapshot: WidgetSnapshot?, jetzt: Date) -> WidgetPartnerStand? {
        guard istVonHeute(snapshot, jetzt: jetzt), var p = snapshot?.partner else { return nil }
        if p.tag != Datum.text(jetzt) { p.schritte = nil; p.schlafMinuten = nil }
        return p
    }

    /// Die Gym-Woche des Partners; nil, wenn er Gym nicht teilt.
    static func partnerGymWoche(_ partner: WidgetPartnerStand, jetzt: Date) -> [WidgetGymTag]? {
        guard let tage = partner.gymTage else { return nil }
        let fertig = Set(tage)
        return HabitLogik.wochenTage(heute: Datum.text(jetzt)).map { WidgetGymTag(tag: $0, erledigt: fertig.contains($0)) }
    }

    /// Sprechtext einer Gym-Woche: "Du: 2 von 3 Tagen, heute erledigt".
    static func gymSprechtext(name: String, tage: [WidgetGymTag], ziel: Int, jetzt: Date) -> String {
        let heute = Datum.text(jetzt)
        let heuteFertig = tage.first { $0.tag == heute }?.erledigt ?? false
        let zahl = gymZahl(tage, jetzt: jetzt), soll = max(ziel, 1)
        return heuteFertig ? String(localized: "\(name): \(zahl) von \(soll) Tagen, heute erledigt") : String(localized: "\(name): \(zahl) von \(soll) Tagen")
    }

    // MARK: - Schlaf auf dem Sperrbildschirm

    /// "Schlaf 7:12 h" für die Inline-Zeile; ohne Wert von heute "Schlaf –".
    static func schlafInline(_ snapshot: WidgetSnapshot?, jetzt: Date) -> String {
        guard istVonHeute(snapshot, jetzt: jetzt), let m = snapshot?.boegen?.schlafMinuten else { return String(localized: "Schlaf –") }
        return String(localized: "Schlaf \(LockscreenLogik.schlafText(minuten: m)) h")
    }

    // MARK: - Einzelne Gewohnheit

    /// Die gewählte Gewohnheit; ohne Wahl oder wenn sie nicht mehr da ist die erste.
    static func habit(id: String?, snapshot: WidgetSnapshot?) -> WidgetHabitKachel? {
        let liste = snapshot?.habits ?? []
        return liste.first { $0.id == id } ?? liste.first
    }
}
