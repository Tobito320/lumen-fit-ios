import Foundation

// Auswahl des Motors (Idee 61, 62): Apples Modell, wenn es bereit ist und Deutsch kann, sonst die Regeln. Gewählt wird bei jeder Frage neu
// (Apple Intelligence kann zwischendurch fertig werden oder ausgehen); das bisherige Gespräch geht im `CoachAnfrage` mit, deshalb gibt es
// beim Wechsel mitten im Gespräch keinen Verlust. Ein Fehler, eine Zeitüberschreitung oder eine Antwort, die die Persona-Regeln
// verletzt (`CoachAntwortPruefung`), lässt den Regelcoach antworten. Keine Anfrage verlässt das Gerät.

enum CoachWahl {
    /// Das Modell, wenn es verfügbar ist, sonst die Regeln.
    static func motor(modell: any CoachMotor, regeln: any CoachMotor) async -> any CoachMotor {
        await modell.verfuegbar() ? modell : regeln
    }

    /// So lange darf das Modell antworten. Kürzer als die Tippanzeige (`CoachLokal.denkGrenze`, 15 s): sonst laufen beide Fristen gleichzeitig ab,
    /// der Regelcoach käme nie zum Zug und die Person sähe den Fehlertext statt einer Antwort.
    nonisolated static let frist: TimeInterval = CoachLokal.denkGrenze - 3

    /// So lange darf das Modell am Server antworten: knapp unter der Tippanzeige, damit die ehrliche Meldung noch vor dem Fehlertext kommt.
    nonisolated static let serverFrist: TimeInterval = CoachLokal.denkGrenze - 2
}

/// Der Motor, den die App benutzt (`AppUmgebung.coachMotor`): wählt je Frage. Gibt der Server dem Konto das echte Modell frei (`server`), antwortet nur
/// das; fällt es aus, antworten die Regeln allein bei Fragen, die sie wirklich verstehen (`CoachAbsicht.versteht`), sonst geht der Fehler weiter und die
/// App sagt ehrlich, dass der Coach gerade nicht antworten kann (mit "Nochmal"). Ohne Server: Apples Modell, geprüft, sonst dieselbe Regel; versteht
/// sie die Frage nicht, kommt `nichtVerstanden`.
struct CoachWahlMotor: CoachMotor {
    let modell: any CoachMotor
    let regeln: any CoachMotor
    var frist: TimeInterval = CoachWahl.frist
    var server: (any CoachMotor)?
    var serverFrist: TimeInterval = CoachWahl.serverFrist

    var name: String { "Automatisch" }

    func verfuegbar() async -> Bool { true }

    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
        if let server, await server.verfuegbar() {
            do {
                return try await Self.mitFrist(serverFrist) { try await server.antworte(anfrage) }
            } catch is CancellationError {
                throw CancellationError()
            } catch let fehler {
                // Der Server war da und hat nicht geantwortet: nur eine Frage, die die Regeln wirklich verstehen, bekommt eine Regel-Antwort.
                // Sonst geht der Fehler weiter (ruhiger Text mit "Nochmal", die Frage bleibt gemerkt).
                guard CoachAbsicht.versteht(anfrage.frage) else { throw fehler }
                return try await regeln.antworte(anfrage)
            }
        }
        let gewaehlt = await CoachWahl.motor(modell: modell, regeln: regeln)
        if gewaehlt.name == modell.name, gewaehlt.name != regeln.name {
            do {
                let antwort = try await Self.mitFrist(frist) { try await gewaehlt.antworte(anfrage) }
                if CoachAntwortPruefung.ist(antwort.text, frage: anfrage.frage, kontext: anfrage.kontext) { return antwort }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Fehler oder Frist: der Regelcoach antwortet unten.
            }
        }
        return try await nurVerstandenes(anfrage)
    }

    /// Die Regeln antworten nur auf Fragen, die sie wirklich verstehen; alles andere wäre eine Scheinantwort.
    private func nurVerstandenes(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
        guard CoachAbsicht.versteht(anfrage.frage) else { throw CoachMotorFehler.nichtVerstanden }
        return try await regeln.antworte(anfrage)
    }

    /// Lässt `arbeit` höchstens `sekunden` laufen. Danach kommt `zeitUeberschritten` sofort, auch wenn die Arbeit sich nicht abbrechen lässt.
    static func mitFrist(_ sekunden: TimeInterval, _ arbeit: @escaping @Sendable () async throws -> CoachAntwort) async throws -> CoachAntwort {
        let ergebnis: Result<CoachAntwort, Error> = await withCheckedContinuation { fortsetzung in
            let einmal = CoachEinmal(fortsetzung)
            let lauf = Task {
                do { einmal.fertig(.success(try await arbeit())) } catch { einmal.fertig(.failure(error)) }
            }
            Task {
                try? await Task.sleep(for: .seconds(sekunden))
                if einmal.fertig(.failure(CoachMotorFehler.zeitUeberschritten)) { lauf.cancel() }
            }
        }
        return try ergebnis.get()
    }
}

/// Gibt das Ergebnis genau einmal weiter (Arbeit oder Frist, wer zuerst kommt).
// @unchecked Sendable: der Zustand `fortsetzung` wird nur unter dem Schloss gelesen und geleert.
final class CoachEinmal: @unchecked Sendable {
    private let schloss = NSLock()
    private var fortsetzung: CheckedContinuation<Result<CoachAntwort, Error>, Never>?

    init(_ fortsetzung: CheckedContinuation<Result<CoachAntwort, Error>, Never>) { self.fortsetzung = fortsetzung }

    /// true, wenn dieses Ergebnis das erste war.
    @discardableResult
    func fertig(_ ergebnis: Result<CoachAntwort, Error>) -> Bool {
        let nehmen: CheckedContinuation<Result<CoachAntwort, Error>, Never>? = schloss.withLock {
            let f = fortsetzung
            fortsetzung = nil
            return f
        }
        guard let nehmen else { return false }
        nehmen.resume(returning: ergebnis)
        return true
    }
}
