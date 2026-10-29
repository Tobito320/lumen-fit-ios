import Foundation

/// Kleine reine Änderungen am Plan (Idee 27). Das Ergebnis geht immer an `TrainingStore.planSichern` (`gym.plan`, der neueste gilt).
/// Ändern einer Übung geht über `TrainingLogik.aendern`, einen ganzen Tag ersetzt `TrainingLogik.tagSetzen`.
enum PlanEditor {
    /// Ein neuer Tag ohne Wochentag (flexibel, an jedem Tag trainierbar). Leerer Name wird "Tag N".
    static func neuerTag(_ plan: TrainingsPlan, name: String, neueId: () -> String = { UUID().uuidString }) -> TrainingsPlan {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = TrainingsTag(id: neueId(), name: sauber.isEmpty ? SplitFrei.standardName(plan.tage.count + 1) : sauber, wochentage: [], uebungen: [])
        return TrainingLogik.tagSetzen(plan, tag)
    }

    /// Der Tag fällt aus dem Plan; seine Wochentage werden wieder offen.
    static func tagWeg(_ plan: TrainingsPlan, id: String) -> TrainingsPlan {
        var p = plan
        p.tage.removeAll { $0.id == id }
        return p
    }

    /// Übung `von` an die Stelle `nach` im Tag schieben. Eine Kopplung (Supersatz) löst sich, wenn die Nachbarn wechseln.
    static func verschieben(_ tag: TrainingsTag, von: Int, nach: Int) -> TrainingsTag {
        guard tag.uebungen.indices.contains(von), tag.uebungen.indices.contains(nach), von != nach else { return tag }
        var t = tag
        let u = t.uebungen.remove(at: von)
        t.uebungen.insert(u, at: nach)
        for i in t.uebungen.indices { t.uebungen[i].supersatz = nil }
        return t
    }

    /// Eine Übung aus dem Tag nehmen; die Kopplung davor löst sich mit.
    static func weg(_ tag: TrainingsTag, id: String) -> TrainingsTag {
        var t = tag
        guard let i = t.uebungen.firstIndex(where: { $0.id == id }) else { return tag }
        t.uebungen.remove(at: i)
        if i > 0 { t.uebungen[i - 1].supersatz = nil }
        return t
    }

    /// Wochentag an- oder abwählen. Ein Wochentag gehört höchstens einem Tag: `tagSetzen` nimmt ihn den anderen.
    static func wochentag(_ tag: TrainingsTag, _ w: Int, an: Bool) -> TrainingsTag {
        var t = tag
        t.wochentage.removeAll { $0 == w }
        if an { t.wochentage = (t.wochentage + [w]).sorted() }
        return t
    }
}
