import Foundation

// Health-Coach kennt den Tag: Schlaf, Schritte, Bereitschaft, letztes Training, Stimmung und Ziele werden zu einem `CoachKontext`; dazu die
// reichere `CoachEingabe` für die Regeln (Essen, Gewicht, Wochensätze). Anders als Loveas `CoachGesundheit` fragt dieser Teil HealthKit nie
// selbst: alles kommt aus `GesundheitsStand` und den Stores, und nichts verlässt das Gerät. Die Rechnung ist rein, der Lader steht unten.

enum CoachGesundheit {
    /// "7 h 30 min", "45 min": Dauer für Antworten des Coachs (ohne Punkte, damit die Satzzählung nicht stolpert).
    static func dauer(minuten: Int) -> String {
        let m = max(0, minuten)
        if m < 60 { return "\(m) min" }
        return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min"
    }

    /// Bereitschaft 0 bis 100 aus Schlaf, Herzfrequenzvariabilität und Ruhepuls. Fehlende Teile zählen nicht, ohne jeden Teil `nil`.
    /// Schlaf 60 Prozent (Dauer gegen das Ziel), HRV 25 Prozent (gegen den eigenen Schnitt), Ruhepuls 15 Prozent (niedriger als üblich ist besser).
    /// Das ist eine grobe Schätzung des Coachs, kein medizinischer Wert.
    static func bereitschaft(schlafMinuten: Int?, schlafZiel: Int, hrv: Double?, hrvSchnitt: Double?, ruhepuls: Double?, ruhepulsSchnitt: Double?) -> Int? {
        var summe = 0.0
        var gewicht = 0.0
        if let schlaf = schlafMinuten, schlafZiel > 0 {
            summe += 0.6 * min(1, Double(schlaf) / Double(schlafZiel)) * 100
            gewicht += 0.6
        }
        if let hrv, let schnitt = hrvSchnitt, schnitt > 0 {
            summe += 0.25 * min(max(50 + (hrv / schnitt - 1) * 150, 0), 100)
            gewicht += 0.25
        }
        if let puls = ruhepuls, let schnitt = ruhepulsSchnitt {
            summe += 0.15 * min(max(50 + (schnitt - puls) * 5, 0), 100)
            gewicht += 0.15
        }
        guard gewicht > 0 else { return nil }
        return Int((summe / gewicht).rounded())
    }

    /// Mittel der Messwerte der Art an den 14 Tagen vor `heute` (ohne heute). `nil` unter drei Werten.
    static func schnitt(_ werte: [VitalMesswert], heute: String) -> Double? {
        let ab = Datum.addTage(heute, -14)
        let liste = werte.filter { $0.tag >= ab && $0.tag < heute }.map(\.wert)
        guard liste.count >= 3 else { return nil }
        return liste.reduce(0, +) / Double(liste.count)
    }

    static func wert(_ werte: [VitalMesswert], tag: String) -> Double? { werte.last { $0.tag == tag }?.wert }
}

/// Lädt Kontext und Eingabe aus den Stores des aktiven Profils. Lesen nur, schreibt nie.
@MainActor
enum CoachDaten {
    nonisolated static let stimmungArt = "fit.lumi.stimmung"

    /// Die Stimmung von heute (letzte Op des Tages), falls der Morgen-Check beantwortet wurde.
    static func stimmungHeute(_ daten: DatenSatz, tag: String) -> StimmungsEintrag? {
        daten.raum.ops(arten: [stimmungArt]).compactMap { $0.daten(StimmungsEintrag.self) }.last { $0.tag == tag }
    }

    /// Schlafminuten je Aufwachtag der letzten 14 Tage, aus denselben Quellen wie der Schlaf-Tab (Health, Band, von Hand eingetragen).
    /// Nur Health zu lesen ließ den Coach "Daten fehlen" sagen, obwohl der Tab die Nacht zeigte.
    static func naechte(_ umgebung: AppUmgebung, heute: String) -> [String: Int] {
        let ab = Datum.addTage(heute, -14)
        let u = SchlafDaten.uebersicht(umgebung, band: SchlafDaten.bandOps(umgebung))
        return Dictionary(u.naechte.filter { $0.nacht.tag >= ab }.map { ($0.nacht.tag, $0.nacht.schlafMinuten) }, uniquingKeysWith: { $1 })
    }

    static func kontext(_ umgebung: AppUmgebung, _ daten: DatenSatz) -> CoachKontext {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let schlaf = naechte(umgebung, heute: heute)[heute]
        let ruhepuls = umgebung.gesundheit.vitale[.ruhepuls] ?? []
        let hrv = umgebung.gesundheit.vitale[.hrv] ?? []
        let bereit = CoachGesundheit.bereitschaft(
            schlafMinuten: schlaf, schlafZiel: daten.ziele.ziele.schlafMinuten,
            hrv: CoachGesundheit.wert(hrv, tag: heute), hrvSchnitt: CoachGesundheit.schnitt(hrv, heute: heute),
            ruhepuls: CoachGesundheit.wert(ruhepuls, tag: heute), ruhepulsSchnitt: CoachGesundheit.schnitt(ruhepuls, heute: heute))
        let schritte = umgebung.gesundheit.tage[heute]?.schritte
        return CoachKontext(
            tag: heute, bereitschaft: bereit, schlafMinuten: schlaf, schritte: schritte,
            letztesTraining: CoachTraining.letztesTraining(daten.training.sessions, plan: daten.training.plan, jetzt: jetzt),
            stimmung: stimmungHeute(daten, tag: heute)?.stimmung ?? .bereit,
            ziele: daten.ziele.ziele, merkzettel: daten.coach.merkzettel)
    }

    static func eingabe(_ umgebung: AppUmgebung, _ daten: DatenSatz) -> CoachEingabe {
        let heute = Datum.text(umgebung.uhr())
        var e = CoachEingabe(heute: heute)
        let ziele = daten.ziele.ziele
        e.geschlecht = daten.ziele.koerper.geschlecht == .weiblich ? 1 : 0
        e.zieleEingerichtet = ziele != Ziele()
        e.proteinZiel = ziele.proteinGramm
        e.schrittZiel = ziele.schritte
        for zurueck in 0...CoachRegeln.fensterTage {
            let tag = Datum.addTage(heute, -zurueck)
            let summe = daten.essen.summe(tag)
            if summe.kcal > 0 { e.essenKcal[tag] = summe.kcal; e.essenProtein[tag] = summe.protein }
        }
        e.gewicht = daten.habits.werte(Habit.gewicht.id)
        e.schritte = umgebung.gesundheit.tage.mapValues(\.schritte)
        e.schlaf = naechte(umgebung, heute: heute)
        let sessions = daten.training.sessions
        e.gruppen = CoachTraining.gruppen(sessions, heute: heute)
        e.uebungen = CoachTraining.uebungen(sessions)
        return e
    }
}
