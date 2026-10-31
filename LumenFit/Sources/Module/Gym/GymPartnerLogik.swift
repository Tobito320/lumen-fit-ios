// Quelle: Lovea Health/GymNeu/GymStartView.swift (GymStartStand.bauen status(_:) :48, wer :110) und GymSession.swift (GymVerlaufView Picker :277)
import Foundation

/// Die Partner-Seite der Gym-Startseite im Lovea-Aufbau: die Zeile "Partner + Status" und der Ich/Partner-Wechsel im Verlauf.
/// Alles aus der Zusammenfassung des Partners (`ZusammenfassungDatei`): nie Sätze oder Gewichte, nur was die Person freigibt.
enum GymPartnerLogik {
    /// Was der Partner an `datum` macht oder vorhat, mit den Worten von Lovea (`GymStartLogik.status`): "gerade im Gym", "54 min · 27 Sätze",
    /// "geplant: Push", "Ruhetag", "noch nicht", "nicht im Gym". Ohne Freigabe verlauf "nicht freigegeben". Die Zusammenfassung kennt nur die letzten zehn
    /// Einheiten und den Plan von heute, für weiter zurück oder voraus gilt der Plan nach Wochentag.
    static func status(_ datei: ZusammenfassungDatei, datum: String, heute: String, jetzt: Date) -> String {
        guard datei.freigaben.contains(.verlauf) || datei.freigaben.contains(.plan) else { return "nicht freigegeben" }
        let verlauf = datei.freigaben.contains(.verlauf) ? datei.heute.verlauf : nil
        if datum == heute, let verlauf, PartnerAnsichtLogik.statusZeile(verlauf, jetzt: jetzt) != nil { return "gerade im Gym" }
        if let t = verlauf?.trainings.first(where: { $0.tag == datum }) {
            guard let min = t.minuten else { return "war im Gym" }
            let dauer = TrainingLogik.dauerText(TimeInterval(min * 60))
            return t.saetze > 0 ? "\(dauer) · \(t.saetze) \(t.saetze == 1 ? "Satz" : "Sätze")" : dauer
        }
        if datum > heute { return geplant(datei, datum: datum).map { "geplant: \($0)" } ?? (kenntPlan(datei) ? "Ruhetag" : "noch nicht") }
        return datum == heute ? "noch nicht" : "nicht im Gym"
    }

    private static func kenntPlan(_ datei: ZusammenfassungDatei) -> Bool {
        datei.freigaben.contains(.plan) && datei.heute.plan != nil
    }

    private static func geplant(_ datei: ZusammenfassungDatei, datum: String) -> String? {
        guard kenntPlan(datei), let plan = datei.heute.plan else { return nil }
        return PartnerAnsichtLogik.heutigerTag(plan, wochentag: Datum.wochentag(datum)).map { $0.name.isEmpty ? "Training" : $0.name }
    }

    /// Der Partner für die Zeile und den Wechsel: nur verbunden (auch mit älterem Stand), mit Namen. Sonst nil, dann gibt es weder Zeile noch Wechsel.
    static func partner(_ stand: PartnerStand) -> ZusammenfassungDatei? {
        guard let d = PartnerAnsichtLogik.datei(stand), !d.profilName.isEmpty else { return nil }
        return d
    }

    /// Die Einheiten des Partners für die Liste im Verlauf, neueste zuerst; leer ohne Freigabe verlauf.
    static func einheiten(_ datei: ZusammenfassungDatei) -> [PartnerTrainingKurz] {
        guard datei.freigaben.contains(.verlauf), let v = datei.heute.verlauf else { return [] }
        // Einheiten mit Sätzen, die nicht unter den letzten zehn stehen, kommen als Zeile dazu.
        let bekannt = Set(v.trainings.map(\.tag))
        let dazu = (v.einheiten ?? []).filter { !bekannt.contains($0.tag) }.map {
            PartnerTrainingKurz(tag: $0.tag, name: $0.name, minuten: $0.minuten, saetze: saetzeZahl($0), uebungen: $0.uebungen.count, kcal: $0.kcal)
        }
        return (v.trainings + dazu).sorted { $0.tag > $1.tag }
    }

    /// Die Tage mit Training im Monatsraster des Partners: alle Tage, die er mit Gym und Verlauf mitschickt, dazu die Tage der Einheiten (ältere Apps schicken nur die zehn).
    static func trainingstage(_ datei: ZusammenfassungDatei) -> Set<String> {
        guard datei.freigaben.contains(.verlauf), let v = datei.heute.verlauf else { return [] }
        return Set(v.tage ?? []).union(v.trainings.map(\.tag)).union((v.einheiten ?? []).map(\.tag))
    }

    /// Die Einheit zum Nachlesen an einem Tag; nil, wenn der Partner für den Tag keine Sätze mitschickt (zu alt oder keine Freigabe gym).
    static func einheit(am tag: String, in datei: ZusammenfassungDatei) -> PartnerEinheit? {
        guard datei.freigaben.contains(.verlauf) else { return nil }
        return datei.heute.verlauf?.einheiten?.first { $0.tag == tag }
    }

    /// Der Satz als `PlanSatz`, damit Nummer, Text und Volumen dieselbe Logik wie bei den eigenen Einheiten nutzen. Gewicht kommt in Zehnteln.
    static func satz(_ s: PartnerSatzKurz) -> PlanSatz {
        PlanSatz(wdh: s.wdh, kg: s.kg.map { Double($0) / 10 }, failure: s.typ == "f", typ: s.typ == "w" || s.typ == "d" ? s.typ : nil, ok: true)
    }

    /// Volumen in kg ohne Aufwärmsätze (wie `WorkoutLogik.volumen`).
    static func volumen(_ e: PartnerEinheit) -> Double {
        e.uebungen.flatMap(\.saetze).map(satz).filter(\.zaehlt).reduce(0) { $0 + ($1.kg ?? 0) * Double($1.wdh) }
    }

    static func saetzeZahl(_ e: PartnerEinheit) -> Int { e.uebungen.reduce(0) { $0 + $1.saetze.count } }
}
