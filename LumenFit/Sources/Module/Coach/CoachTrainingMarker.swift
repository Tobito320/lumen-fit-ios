// Quelle: Lovea Health/Coach/CoachTraining.swift (Marker starten, beenden, Satz, tauschen; ohne Übung dazu, Auslassen und Pausenuhr)
import Foundation

// Der Coach steuert das laufende Training, aber nur als bestätigter Vorschlag ("Eintragen?"): Einheit starten oder beenden, einen Satz eintragen,
// eine Übung tauschen. Die Marker (`CoachMarker`) werden hier gegen den Stand der Einheit geplant (reine Logik, `plan`) und dann über die
// `gym.*`-Ops des `TrainingStore` ausgeführt, genau wie die Trainingsansicht es tut. Marker ohne laufende Einheit (außer "start"), mit
// unbekannter Id oder gegen die Regeln der App (getauscht wird nur vor dem ersten Haken, nicht bei Cardio und eigenen Übungen) fallen still
// weg. Kein Timer, kein Hintergrund: es laufen nur Ops, wenn jemand bestätigt.
//
// Nicht übernommen: "Übung dazu" und "Auslassen" (die Ansicht dafür liegt im Modul gym) und die Pausenuhr.

enum CoachTrainingMarker {
    /// Alles, was die Planung über die Einheit wissen muss. `session` ist die laufende Einheit, `tag` ihr Plantag, `frueher` die
    /// älteren Einheiten (neueste zuerst, für "Vorher"), `tage` die wählbaren Trainingstage, `heute` der Plantag von heute.
    struct Stand: Equatable, Sendable {
        var session: GymSession?
        var tag: TrainingsTag?
        var frueher: [GymSession]
        var tage: [TrainingsTag]
        var heute: TrainingsTag?

        /// Die Übungen der Einheit wie in der Trainingsansicht; leer ohne Einheit.
        var uebungen: [WorkoutUebung] {
            guard let session else { return [] }
            return WorkoutLogik.uebungen(session, tag: tag, frueher: frueher)
        }
    }

    /// Die Übung vor der Änderung: damit macht "Rückgängig" den alten Stand wieder.
    struct Bisher: Equatable, Sendable {
        let uebung: WorkoutUebung
        let hatteLauf: Bool
    }

    /// Was ein Marker bewirkt, fertig berechnet.
    enum Aktion: Equatable, Sendable {
        /// `tag` nil: freies Training.
        case start(tag: TrainingsTag?)
        /// `neu` sind alle Satzzeilen der Übung nach dem Eintragen, `satz` die eingetragene Zeile.
        case satz(Bisher, neu: [PlanSatz], satz: PlanSatz)
        /// `ersatzFuer`: Katalog-Id der Plan-Übung; nil, wenn zurück auf die ursprüngliche getauscht wird.
        case tausche(Bisher, zu: Uebung, ersatzFuer: String?, neu: [PlanSatz])
        case ende
    }

    // MARK: - Reihenfolge

    /// Nur die Training-Marker einer Antwort: "start" zuerst, "ende" zuletzt, dazwischen in der Reihenfolge der Antwort.
    static func geordnet(_ marker: [CoachMarker.Art]) -> [CoachMarker.Art] {
        let eigene = marker.filter { istTraining($0) }
        let anfang = eigene.filter { istStart($0) }
        let mitte = eigene.filter { !istStart($0) && !istEnde($0) }
        let schluss = eigene.filter { istEnde($0) }
        return anfang + mitte + schluss
    }

    static func istTraining(_ art: CoachMarker.Art) -> Bool {
        switch art {
        case .trainingStart, .trainingEnde, .satz, .tausche: true
        default: false
        }
    }

    private static func istStart(_ art: CoachMarker.Art) -> Bool {
        if case .trainingStart = art { return true }
        return false
    }

    private static func istEnde(_ art: CoachMarker.Art) -> Bool {
        if case .trainingEnde = art { return true }
        return false
    }

    // MARK: - Planung

    /// Ein Marker gegen den Stand: die Aktion, oder nil, wenn er nicht passt (dann geschieht nichts).
    static func plan(_ art: CoachMarker.Art, stand: Stand) -> Aktion? {
        switch art {
        case .trainingStart(let name): return startPlan(name, stand)
        case .trainingEnde:
            guard stand.session != nil else { return nil }
            return .ende
        case .satz(let id, let kg, let wdh): return satzPlan(id, kg: kg, wdh: wdh, stand)
        case .tausche(let id, let roh): return tauschPlan(id, roh, stand)
        default: return nil
        }
    }

    private static func startPlan(_ name: String?, _ stand: Stand) -> Aktion? {
        guard stand.session == nil else { return nil }
        guard let name else { return .start(tag: stand.heute) }
        guard let tag = trainingstag(name, in: stand.tage) else { return nil }
        return .start(tag: tag)
    }

    private static func satzPlan(_ id: String, kg: Double, wdh: Int, _ stand: Stand) -> Aktion? {
        guard let u = stand.uebungen.first(where: { $0.id == id }), !u.planUebung.istCardio else { return nil }
        var zeilen = u.saetze
        let gewicht: Double? = kg > 0 ? kg : nil
        let satz: PlanSatz
        // Die erste offene Arbeitszeile; Aufwärmzeilen füllt der Coach nie von selbst.
        if let i = zeilen.firstIndex(where: { $0.ok != true && $0.typ != "w" }) {
            zeilen[i].kg = gewicht
            zeilen[i].wdh = wdh
            zeilen[i].ok = true
            satz = zeilen[i]
        } else {
            satz = PlanSatz(wdh: wdh, kg: gewicht, failure: false, ok: true)
            zeilen.append(satz)
        }
        return .satz(bisher(u, stand), neu: zeilen, satz: satz)
    }

    private static func tauschPlan(_ id: String, _ roh: String, _ stand: Stand) -> Aktion? {
        guard let u = stand.uebungen.first(where: { $0.id == id }), !u.ausgelassen,
              AusweichLogik.tauschbar(u, saetze: u.saetze),
              let zu = katalogUebung(roh), !zu.istCardio, zu.id != u.planUebung.uebung else { return nil }
        let original = AusweichLogik.original(u)
        var ersatz = u.planUebung
        ersatz.uebung = zu.id
        ersatz.name = nil
        let vorher = WorkoutLogik.vorherige(ersatz, in: stand.frueher)
        let neu = AusweichLogik.saetzeNachTausch(u.saetze, vorher: vorher)
        return .tausche(bisher(u, stand), zu: zu, ersatzFuer: zu.id == original ? nil : original, neu: neu)
    }

    private static func bisher(_ u: WorkoutUebung, _ stand: Stand) -> Bisher {
        let hatteLauf = stand.session?.laeufe.contains { $0.plan == u.id } == true
        return Bisher(uebung: u, hatteLauf: hatteLauf)
    }

    /// Eine Katalog-Übung nach Id oder nach ihrem ganzen Namen (Groß- und Kleinschreibung, Umlaute egal). Mehrdeutig oder unbekannt: nil.
    static func katalogUebung(_ roh: String, katalog: [Uebung] = UebungsKatalog.alle) -> Uebung? {
        if let treffer = katalog.first(where: { $0.id == roh }) { return treffer }
        let gesucht = UebungsKatalog.normal(roh).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gesucht.isEmpty else { return nil }
        let treffer = katalog.filter { UebungsKatalog.normal($0.name) == gesucht }
        return treffer.count == 1 ? treffer[0] : nil
    }

    /// Ein Trainingstag nach Id, ganzem Namen oder Teil des Namens ("pull" findet "Pull Day"). Die erste Stufe mit Treffern
    /// entscheidet; mehrere Treffer in ihr: nil, der Coach rät nicht.
    static func trainingstag(_ roh: String, in tage: [TrainingsTag]) -> TrainingsTag? {
        let kennung = roh.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = UebungsKatalog.normal(roh).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kennung.isEmpty, !name.isEmpty else { return nil }
        let stufen: [(TrainingsTag) -> Bool] = [
            { $0.id.lowercased() == kennung },
            { UebungsKatalog.normal($0.name) == name },
            { UebungsKatalog.normal($0.name).contains(name) },
        ]
        for passt in stufen {
            let treffer = tage.filter(passt)
            if !treffer.isEmpty { return treffer.count == 1 ? treffer[0] : nil }
        }
        return nil
    }

    // MARK: - Text

    /// Die Zeile eines Vorschlags vor dem Ausführen, ohne Stand ("Satz: 60 kg × 8") oder mit Namen, wenn die Übung bekannt ist.
    static func vorschlagText(_ art: CoachMarker.Art, stand: Stand?) -> String {
        switch art {
        case .trainingStart(let name): return name.map { "Training starten: \($0)" } ?? "Training starten"
        case .trainingEnde: return "Training beenden"
        case .satz(let id, let kg, let wdh):
            let satz = WorkoutLogik.satzText(PlanSatz(wdh: wdh, kg: kg > 0 ? kg : nil, failure: false))
            let name = stand?.uebungen.first { $0.id == id }?.planUebung.anzeigeName
            return "Satz: \(name.map { "\($0) " } ?? "")\(satz)"
        case .tausche(let id, let roh):
            let von = stand?.uebungen.first { $0.id == id }?.planUebung.anzeigeName ?? "Übung"
            let zu = katalogUebung(roh)?.name ?? roh
            return "Tauschen: \(von) → \(zu)"
        default: return "Training"
        }
    }

    /// Die Zeile nach dem Ausführen.
    static func zeilenText(_ aktion: Aktion) -> (text: String, symbol: String) {
        switch aktion {
        case .start(let tag):
            return (tag.map { "Training gestartet: \($0.name)" } ?? "Training gestartet", "figure.strengthtraining.traditional")
        case .satz(let bisher, _, let satz):
            return ("Satz: \(bisher.uebung.planUebung.anzeigeName) \(WorkoutLogik.satzText(satz))", "checkmark.circle.fill")
        case .tausche(let bisher, let zu, _, _):
            return ("Getauscht: \(bisher.uebung.planUebung.anzeigeName) → \(zu.name)", "arrow.left.arrow.right")
        case .ende:
            return ("Training beendet", "flag.checkered")
        }
    }

    // MARK: - Ausführen

    /// Die Karten-Zeile und der Weg zurück.
    struct Ergebnis {
        let text: String
        let symbol: String
        let zurueck: @MainActor () -> Void
    }

    /// Der Stand des aktiven Profils jetzt. Die Ops des Raums sind lokal sofort gelesen: ein Marker danach sieht, was der davor getan hat.
    @MainActor
    static func aktuellerStand(_ daten: DatenSatz, jetzt: Date) -> Stand {
        let training = daten.training
        let session = training.laufende(jetzt: jetzt)
        var frueher: [GymSession] = []
        if let session { frueher = training.sessions.filter { $0.start < session.start } }
        let tage = WochenLogik.waehlbar(training.plan, heute: Datum.text(jetzt))
        return Stand(session: session, tag: training.tag(id: session?.tag), frueher: frueher, tage: tage, heute: training.heutigerTag())
    }

    /// Führt einen Marker aus. nil: er passt nicht (keine Einheit, unbekannte Id, gegen die Regeln) und nichts ist geschehen.
    @MainActor
    static func ausfuehren(_ art: CoachMarker.Art, daten: DatenSatz, jetzt: Date) -> Ergebnis? {
        let stand = aktuellerStand(daten, jetzt: jetzt)
        guard let aktion = plan(art, stand: stand) else { return nil }
        let training = daten.training
        let zeile = zeilenText(aktion)
        if case .start(let tag) = aktion {
            let heute = Datum.text(jetzt)
            let warAbgehakt = daten.habits.gymAbgehakt(heute)
            let id = training.einchecken(tag: tag?.id)
            daten.habits.setzeGym(datum: heute, an: true)
            return Ergebnis(text: zeile.text, symbol: zeile.symbol, zurueck: {
                if let s = training.sessions.first(where: { $0.id == id }) { training.loeschen(s) }
                if !warAbgehakt { daten.habits.setzeGym(datum: heute, an: false) }
            })
        }
        guard let session = stand.session?.id else { return nil }
        switch aktion {
        case .start:
            return nil
        case .satz(let bisher, let neu, _):
            let u = bisher.uebung.planUebung
            training.saetzeSenden(session, u, neu)
            return Ergebnis(text: zeile.text, symbol: zeile.symbol, zurueck: { zuruecknehmen(bisher, session, training) })
        case .tausche(let bisher, let zu, let ersatzFuer, let neu):
            training.tauschen(session, bisher.uebung.planUebung, zu: zu.id, ersatzFuer: ersatzFuer, saetze: neu)
            return Ergebnis(text: zeile.text, symbol: zeile.symbol, zurueck: { tauschZuruecknehmen(bisher, session, training) })
        case .ende:
            training.auschecken(session, ende: jetzt)
            return Ergebnis(text: zeile.text, symbol: zeile.symbol, zurueck: { training.auscheckenRueckgaengig(session) })
        }
    }

    /// Satz zurück: der alte Stand der Zeilen, oder die Übung wieder heraus, wenn die Einheit sie vorher nicht kannte.
    @MainActor
    private static func zuruecknehmen(_ bisher: Bisher, _ session: String, _ training: TrainingStore) {
        let u = bisher.uebung.planUebung
        if bisher.hatteLauf { training.saetzeSenden(session, u, bisher.uebung.saetze) } else { training.entfernen(session, u) }
    }

    /// Tausch zurück: dieselbe Übung und dasselbe `ersatzFuer` wie vorher.
    @MainActor
    private static func tauschZuruecknehmen(_ bisher: Bisher, _ session: String, _ training: TrainingStore) {
        let u = bisher.uebung.planUebung
        guard bisher.hatteLauf else {
            training.entfernen(session, u)
            return
        }
        training.tauschen(session, u, zu: u.uebung, ersatzFuer: bisher.uebung.ersatzFuer, saetze: bisher.uebung.saetze)
    }
}
