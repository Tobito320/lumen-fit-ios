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
}

/// Der Motor, den die App benutzt (`AppUmgebung.coachMotor`): wählt je Frage, prüft die Antwort des Modells, fällt auf die Regeln zurück.
struct CoachWahlMotor: CoachMotor {
    let modell: any CoachMotor
    let regeln: any CoachMotor
    var frist: TimeInterval = CoachWahl.frist

    var name: String { "Automatisch" }

    func verfuegbar() async -> Bool { true }

    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
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
