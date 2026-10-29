import Foundation

// Chips mit Handlung (Idee 65): "Mach ich" legt eine Gewohnheit an, "Morgen leicht" macht das Training von morgen leichter, "Zeig mir" öffnet
// eine Seite. Wie Loveas Tracking-Marker trägt der Coach nur ein, was die Person per Tipp bestätigt, und jede Handlung hat einen Weg zurück
// (Rückgängig in der Bestätigungszeile). Die Pläne sind reine Rechnung (`CoachPlan`), die Ausführung läuft über die Stores.
//
// Anders als in Lovea gibt es keine Marker für Wasser, Kreatin, Gewicht, Training und Wecker: das trägt die Person selbst ein.

/// Ein Training leichter machen, rein gerechnet.
enum CoachPlan {
    struct Aenderung: Equatable {
        let plan: TrainingsPlan
        let tagName: String
        /// Wie viele Arbeitssätze insgesamt wegfallen.
        let wenigerSaetze: Int
    }

    /// Der Plan, in dem der Trainingstag von `datum` leichter ist: jede Kraftübung mit drei oder mehr Arbeitssätzen verliert den letzten
    /// Arbeitssatz, Cardio wird 20 Prozent kürzer (mindestens 5 Minuten). Das Gewicht bleibt. `nil`, wenn an dem Tag nichts steht oder
    /// nichts zu kürzen ist (schon leicht).
    static func leichter(_ plan: TrainingsPlan, datum: String) -> Aenderung? {
        guard let tag = TrainingLogik.tag(plan, datum: datum), let i = plan.tage.firstIndex(where: { $0.id == tag.id }) else { return nil }
        var neu = plan
        var weg = 0
        for u in neu.tage[i].uebungen.indices {
            if let minuten = neu.tage[i].uebungen[u].minuten {
                let kuerzer = max(5, Int((Double(minuten) * 0.8).rounded()))
                if kuerzer < minuten { neu.tage[i].uebungen[u].minuten = kuerzer; weg += 1 }
                continue
            }
            let saetze = neu.tage[i].uebungen[u].saetze
            let arbeit = saetze.indices.filter { saetze[$0].typ != "w" }
            guard arbeit.count >= 3, let letzter = arbeit.last else { continue }
            neu.tage[i].uebungen[u].saetze.remove(at: letzter)
            weg += 1
        }
        return weg > 0 ? Aenderung(plan: neu, tagName: tag.name, wenigerSaetze: weg) : nil
    }
}

enum CoachTracking {
    /// Die Bestätigungszeile unter einer Antwort und der Weg zurück.
    struct Ergebnis {
        let text: String
        let symbol: String
        let zurueck: (@MainActor () -> Void)?
    }

    /// Das Symbol zu einer neuen Gewohnheit (alle aus den SF Symbols, die auch das Anlegen anbietet).
    static func symbol(fuerGewohnheit name: String) -> String {
        let klein = name.lowercased()
        if ["spazier", "geh", "schritt", "lauf"].contains(where: { klein.contains($0) }) { return "figure.walk" }
        if ["wasser", "trink"].contains(where: { klein.contains($0) }) { return "drop.fill" }
        if ["schlaf", "bett", "ruhe"].contains(where: { klein.contains($0) }) { return "bed.double.fill" }
        if ["dehn", "mobil", "stretch"].contains(where: { klein.contains($0) }) { return "figure.flexibility" }
        return "checkmark.circle.fill"
    }

    /// Kennung einer vom Coach angelegten Gewohnheit: gleicher Name, gleiche Kennung (zweimal "Mach ich" legt nur eine an).
    static func gewohnheitsId(_ name: String) -> String {
        "coach-" + CoachLokal.schluessel(name.lowercased())
    }

    /// Führt die Handlung eines Chips aus. `nil`: nichts zu bestätigen (Frage, Seite öffnen, nichts).
    @MainActor
    static func ausfuehren(_ chip: CoachChip, umgebung: AppUmgebung, daten: DatenSatz) -> Ergebnis? {
        switch chip.aktion {
        case .gewohnheitAnlegen(let name):
            return gewohnheitAnlegen(name, daten: daten)
        case .planMorgenLeicht:
            return morgenLeicht(umgebung: umgebung, daten: daten)
        case .oeffne(let route):
            umgebung.router.oeffne(route)
            return nil
        case .antworten, .nichts:
            return nil
        }
    }

    @MainActor
    static func gewohnheitAnlegen(_ roh: String, daten: DatenSatz) -> Ergebnis {
        let name = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = gewohnheitsId(name)
        if daten.habits.habits.values.contains(where: { $0.id == id || $0.name.lowercased() == name.lowercased() }) {
            return Ergebnis(text: "\(name) gibt es schon.", symbol: "checkmark.circle", zurueck: nil)
        }
        let habit = Habit(id: id, name: name, symbol: symbol(fuerGewohnheit: name), farbe: HabitFarbe.mint.rawValue, zaehlen: false,
                          tagesziel: nil, haeufigkeit: .taeglich, fuer: "ich")
        daten.habits.anlegen(habit)
        return Ergebnis(text: "Gewohnheit angelegt: \(name)", symbol: habit.symbol, zurueck: { [habits = daten.habits] in habits.loeschen(id) })
    }

    @MainActor
    static func morgenLeicht(umgebung: AppUmgebung, daten: DatenSatz) -> Ergebnis {
        let morgen = Datum.addTage(Datum.text(umgebung.uhr()), 1)
        let alt = daten.training.plan
        guard let tag = TrainingLogik.tag(alt, datum: morgen) else {
            return Ergebnis(text: "Morgen steht kein Training an.", symbol: "calendar", zurueck: nil)
        }
        guard let aenderung = CoachPlan.leichter(alt, datum: morgen) else {
            return Ergebnis(text: "\(tag.name) morgen ist schon leicht.", symbol: "checkmark.circle", zurueck: nil)
        }
        daten.training.planSichern(aenderung.plan)
        return Ergebnis(text: "\(aenderung.tagName) morgen ist leichter", symbol: "figure.strengthtraining.traditional",
                        zurueck: { [training = daten.training] in training.planSichern(alt) })
    }
}
