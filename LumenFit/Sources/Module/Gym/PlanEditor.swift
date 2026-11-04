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

    /// Übung `von` an die Stelle `nach` im Tag schieben. Nur die verschobene Übung verlässt ihren Supersatz (`SupersatzLogik.verschieben`).
    static func verschieben(_ tag: TrainingsTag, von: Int, nach: Int) -> TrainingsTag {
        guard tag.uebungen.indices.contains(von), tag.uebungen.indices.contains(nach), von != nach else { return tag }
        var t = tag
        t.uebungen = SupersatzLogik.verschieben(tag.uebungen, von: von, nach: nach).map { s in
            var u = tag.uebungen[s.index]
            u.supersatz = s.supersatz
            return u
        }
        return t
    }

    /// Die Übung `id` um `schritt` Stellen verschieben (-1 = eine nach oben). Am Rand oder bei unbekannter Id bleibt der Tag, wie er ist.
    static func schieben(_ tag: TrainingsTag, id: String, um schritt: Int) -> TrainingsTag {
        guard let i = tag.uebungen.firstIndex(where: { $0.id == id }) else { return tag }
        return verschieben(tag, von: i, nach: i + schritt)
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

    /// Die Übung direkt dahinter noch einmal, mit neuer Id (Doppeln per Wischen). Die Kopplung zur nächsten Übung gehört nur dem Original.
    static func duplizieren(_ tag: TrainingsTag, id: String, neueId: () -> String = { UUID().uuidString }) -> TrainingsTag {
        guard let i = tag.uebungen.firstIndex(where: { $0.id == id }) else { return tag }
        var t = tag
        var kopie = tag.uebungen[i]
        kopie.id = neueId()
        kopie.supersatz = nil
        t.uebungen.insert(kopie, at: i + 1)
        t.uebungen[i].supersatz = nil
        return t
    }

    /// Satz `i` einer Übung ändern: Wiederholungen, Gewicht (nil = ohne) und Versagen. Außerhalb der Liste passiert nichts.
    static func satzAendern(_ u: PlanUebung, _ i: Int, wdh: Int? = nil, kg: Double?? = nil, versagen: Bool? = nil) -> PlanUebung {
        guard u.saetze.indices.contains(i) else { return u }
        var neu = u
        if let wdh { neu.saetze[i].wdh = max(1, min(100, wdh)) }
        if let kg { neu.saetze[i].kg = kg.map { max(0, $0) } }
        if let versagen { neu.saetze[i].failure = versagen }
        return neu
    }

    /// Alle Übungen (oder nur die gewählten Ids) eines anderen Tages ans Ende dieses Tages, mit neuen Ids. Cardio und Kraft gleich.
    static func vonTagKopieren(_ ziel: TrainingsTag, quelle: TrainingsTag, nur ids: Set<String>? = nil, neueId: () -> String = { UUID().uuidString }) -> TrainingsTag {
        var t = ziel
        for u in quelle.uebungen where ids?.contains(u.id) ?? true {
            var kopie = u
            kopie.id = neueId()
            kopie.supersatz = nil
            t.uebungen.append(kopie)
        }
        return t
    }

    /// Eine Variante: dieselbe Stelle im Tag, aber ein anderes Gerät oder eine andere Übung; die Sätze bleiben. Nicht für Cardio.
    static func variante(_ tag: TrainingsTag, id: String, zu neu: Uebung) -> TrainingsTag {
        guard let i = tag.uebungen.firstIndex(where: { $0.id == id }), !tag.uebungen[i].istCardio, !neu.istCardio else { return tag }
        var t = tag
        t.uebungen[i].uebung = neu.id
        t.uebungen[i].name = nil
        return t
    }
}
