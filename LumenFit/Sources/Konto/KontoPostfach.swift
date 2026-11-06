import Foundation

/// Postfach für Agenten (Server `postfach.js`): ein Agent legt eine Op für dieses Konto ab, die App spielt sie hier über den
/// gewöhnlichen Weg ein (`gym.plan` -> `TrainingStore.planSichern`) und quittiert. Erlaubt ist nur, was unten im `switch` steht.
enum PostfachLogik {
    struct Eintrag: Decodable, Equatable {
        var id: Int
        var art: String
        var plan: TrainingsPlan?

        enum CodingKeys: String, CodingKey { case id, art, daten }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            art = try c.decode(String.self, forKey: .art)
            plan = nil
            if art == "gym.plan" { plan = try? c.decode(TrainingsPlan.self, forKey: .daten) }
        }
    }

    struct Antwort: Decodable {
        var ops: [Eintrag]
        /// Der Server will den Plan sehen (Schalter `planMelden` am Konto), damit ein Agent ihn lesen kann.
        var planMelden: Bool?
    }

    /// Spielt die Ops der Antwort ein, die in Reihenfolge der Ids kommen. Rückgabe: die Ids zum Quittieren.
    /// Unbekannte Arten und unlesbare Pläne bleiben im Postfach (eine neuere App kann sie vielleicht lesen) und ändern nichts.
    @MainActor
    static func anwenden(_ daten: Data, auf training: TrainingStore) -> (ids: [Int], planMelden: Bool) {
        guard let a = try? JSONDecoder().decode(Antwort.self, from: daten) else { return ([], false) }
        var fertig: [Int] = []
        for op in a.ops {
            switch op.art {
            case "gym.plan":
                guard let plan = op.plan else { continue }
                training.planSichern(plan)
                fertig.append(op.id)
            default:
                continue
            }
        }
        return (fertig, a.planMelden == true)
    }
}

extension KontoDienst {
    /// Holt das Postfach, spielt es ein, quittiert und meldet danach den Plan, wenn der Server das für dieses Konto will.
    /// Beim Start und beim Zurückkommen in den Vordergrund, ohne Pause und ohne Timer. Ohne angemeldetes Gerät oder Netz passiert nichts.
    func postfachAbgleichen(training: TrainingStore) async {
        guard let k = registrierteKennung(),
              let a = await sendeMitKonto("/postfach", methode: "GET", kennung: k), a.status == 200 else { return }
        let r = PostfachLogik.anwenden(a.daten, auf: training)
        if !r.ids.isEmpty, let koerper = try? JSONSerialization.data(withJSONObject: ["ids": r.ids]) {
            _ = await sendeMitKonto("/postfach/quittung", methode: "POST", body: koerper, kennung: k)
        }
        if r.planMelden, let koerper = try? JSONEncoder().encode(["plan": training.plan]) {
            _ = await sendeMitKonto("/postfach/plan", methode: "PUT", body: koerper, kennung: k)
        }
    }
}
