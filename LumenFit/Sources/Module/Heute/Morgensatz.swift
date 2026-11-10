import Foundation

/// Lumis Satz am Morgen (Idee 13) und Lumis Stimmung dazu. Reine Logik: aus dem Bereit-Score, dem heutigen Plan und dem Morgen-Check
/// (Op `fit.lumi.stimmung`, Wert 1 bis 5) entsteht ein kurzer Satz mit echten Zahlen. Stimmung und Satz folgen derselben Regel.
enum Morgensatz {
    struct Eingabe: Equatable, Sendable {
        var score: BereitScore.Ergebnis
        /// Antwort des Morgen-Checks von heute, 1 (schwer) bis 5 (top); nil = nicht beantwortet.
        var stimmungsWert: Int? = nil
        /// Name des heutigen Trainingstags; nil = keiner geplant.
        var planName: String? = nil
        var ruhetag = false
        var trainiert = false
        /// Alle drei Bögen der Ringplatte sind voll.
        var alleBoegenVoll = false
        /// Stunde in Berlin (0 bis 23).
        var stunde = 8
    }

    struct Ergebnis: Equatable, Sendable {
        var satz: String
        var stimmung: LumiStimmung
        /// Der Plan sollte heute leichter sein ("heute locker").
        var locker: Bool
    }

    /// Wert 1 oder 2 im Morgen-Check heißt schwerer Tag, 4 oder 5 guter.
    static func schwer(_ wert: Int?) -> Bool { (wert ?? 3) <= 2 }
    static func stark(_ wert: Int?) -> Bool { (wert ?? 3) >= 4 }

    static func sprich(_ e: Eingabe) -> Ergebnis {
        if e.stunde >= 23 || e.stunde < 5 {
            return Ergebnis(satz: String(localized: "Zeit zum Schlafen. Morgen geht es weiter."), stimmung: .schlaeft, locker: false)
        }
        if e.trainiert { return Ergebnis(satz: String(localized: "Training erledigt. Das war stark."), stimmung: .ziel, locker: false) }
        if e.alleBoegenVoll { return Ergebnis(satz: String(localized: "Alle drei Bögen sind voll. Ein runder Tag."), stimmung: .ziel, locker: false) }
        let plan = e.ruhetag ? nil : e.planName
        let schlaf = e.score.teil(.schlaf).map { " (\($0.kurz))" } ?? ""

        if schwer(e.stimmungsWert) {
            let weiter = plan.map { String(localized: "\($0) lieber leichter.") } ?? String(localized: "Ein Spaziergang reicht auch.")
            return Ergebnis(satz: String(localized: "Heute fühlt es sich schwer an. Dann heute locker. \(weiter)"), stimmung: .muede, locker: true)
        }
        switch e.score.stufe {
        case .keine:
            return Ergebnis(satz: String(localized: "Guten Morgen. Mir fehlen noch Daten für einen Score."), stimmung: .denkt, locker: false)
        case .bereit:
            let kopf = stark(e.stimmungsWert) ? String(localized: "Gut erholt\(schlaf), und du fühlst dich stark.") : String(localized: "Gut erholt\(schlaf).")
            let frage = plan.map { String(localized: "Heute \($0)?") } ?? (e.ruhetag ? String(localized: "Heute ist Ruhetag, gönn ihn dir.") : String(localized: "Bewegung tut dir heute gut."))
            return Ergebnis(satz: "\(kopf) \(frage)", stimmung: .bereit, locker: false)
        case .normal:
            let kopf = stark(e.stimmungsWert) ? String(localized: "Solide Basis\(schlaf), und du fühlst dich gut.") : String(localized: "Solide Basis\(schlaf).")
            let frage = plan.map { String(localized: "\($0) geht, im eigenen Tempo.") } ?? (e.ruhetag ? String(localized: "Heute ist Ruhetag.") : String(localized: "Eine Runde Bewegung tut gut."))
            return Ergebnis(satz: "\(kopf) \(frage)", stimmung: .bereit, locker: false)
        case .schonen:
            let weiter = plan.map { String(localized: "\($0) mit weniger Gewicht oder ein Satz weniger.") } ?? String(localized: "Geh es ruhig an.")
            let kopf = stark(e.stimmungsWert) ? String(localized: "Du fühlst dich gut, die Zahlen sagen Ruhe\(schlaf).") : String(localized: "Dein Körper will Ruhe\(schlaf).")
            return Ergebnis(satz: String(localized: "\(kopf) Heute locker. \(weiter)"), stimmung: .muede, locker: true)
        }
    }
}

/// Der heutige Trainingstag für die Plan-Karte (Idee 14): was ansteht, ein Tipp, ob "heute locker" gilt.
struct HeutePlan: Equatable, Sendable {
    enum Art: Sendable { case training, ruhetag, erledigt, keinPlan, keinTrainingHeute }
    var art: Art
    var tagID: String? = nil
    var name: String
    var uebungen = 0
    var locker = false
    var tipp: String
    /// Knopf-Text; nil = kein Knopf.
    var knopf: String? = nil
    /// Geschätzte Dauer in Minuten (auf 5 gerundet); 0 = unbekannt.
    var minuten = 0
    /// Das Ziel als Wort ("Muskelaufbau"); nil = nicht zeigen.
    var zielWort: String? = nil
}

enum HeutePlanLogik {
    static func vorschlag(plan: TrainingsPlan, heute: String, trainiert: Bool, locker: Bool, gymInFolge: Int) -> HeutePlan {
        if trainiert { return HeutePlan(art: .erledigt, name: String(localized: "Training erledigt"), tipp: String(localized: "Für heute ist es genug. Trink etwas und iss ordentlich.")) }
        if plan.tage.isEmpty { return HeutePlan(art: .keinPlan, name: String(localized: "Noch kein Plan"), tipp: String(localized: "Im Gym-Tab legst du einen Split fest."), knopf: String(localized: "Plan wählen")) }
        let effektiv = WochenLogik.effektiverPlan(plan, woche: heute)
        switch RuhetagLogik.art(effektiv, Datum.wochentag(heute)) {
        case .ruhe:
            return HeutePlan(art: .ruhetag, name: String(localized: "Ruhetag"), tipp: String(localized: "Muskeln wachsen in der Pause. Ein Spaziergang tut trotzdem gut."))
        case .offen:
            return HeutePlan(art: .keinTrainingHeute, name: String(localized: "Heute nichts geplant"), tipp: String(localized: "Du kannst trotzdem trainieren, wenn dir danach ist."), knopf: String(localized: "Training starten"))
        case .training(let tag):
            let schonen = locker || gymInFolge >= 3
            let tipp: String
            if locker {
                tipp = String(localized: "Heute locker: gleiche Übungen, einen Satz weniger und etwas weniger Gewicht.")
            } else if gymInFolge >= 3 {
                tipp = String(localized: "Schon \(gymInFolge) Tage am Stück. Heute lieber leichter.")
            } else {
                tipp = tag.uebungen.isEmpty ? String(localized: "Noch keine Übungen im Plan.") : String(localized: "\(tag.uebungen.count) Übungen. Fang mit der ersten an, der Rest folgt.")
            }
            return HeutePlan(art: .training, tagID: tag.id, name: tag.name, uebungen: tag.uebungen.count, locker: schonen, tipp: tipp, knopf: String(localized: "Training starten"))
        }
    }
}
