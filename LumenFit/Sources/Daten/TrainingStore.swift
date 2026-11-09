// Quelle: Lovea Health/TrainingModell.swift (ohne Person, Singleton, Anwesenheit, Figur, Punkte, Pausenuhr)
import Foundation
import Observation

/// Plan und Einheiten des Profils (`TrainingFaltung`) und die `gym.*`- und `cardio.*`-Ops.
/// Was Lovea hier an Puls, Pausenuhr und Rekord-Zahlen mitrechnete, liefert das Modul gym beim Aufruf (`auschecken`).
@MainActor @Observable
final class TrainingStore {
    @ObservationIgnored private let raum: LokalerRaum
    @ObservationIgnored private let einstellungen: EinstellungenStore
    @ObservationIgnored private let ereignisse: EreignisKanal?
    @ObservationIgnored private let uhr: Uhr
    private var faltung = TrainingFaltung()
    private var cardioFaltung = CardioFaltung()
    /// Die abgeleiteten Einheiten, bis die nächste gym-Op kommt: `sessions` wurde je Haken bis zu neunmal gelesen und jedes Mal aus allen Ops neu gebaut.
    @ObservationIgnored private var sessionsGemerkt: [GymSession]?

    var ich: ProfilID { raum.profil }

    init(raum: LokalerRaum, einstellungen: EinstellungenStore, ereignisse: EreignisKanal? = nil, uhr: @escaping Uhr = { Date() }) {
        self.raum = raum
        self.einstellungen = einstellungen
        self.ereignisse = ereignisse
        self.uhr = uhr
        raum.beobachten(TrainingFaltung.arten) { [weak self] op in
            self?.faltung.anwenden(op)
            self?.sessionsGemerkt = nil
        }
        raum.beobachten(CardioFaltung.arten) { [weak self] op in self?.cardioFaltung.anwenden(op) }
    }

    // MARK: - Lesen

    var plan: TrainingsPlan { faltung.plaene[ich] ?? .leer }
    var sessions: [GymSession] {
        let f = faltung   // der Zugriff meldet die Abhängigkeit: jede Op ändert `faltung`, die Ansichten zeichnen dann neu
        if let s = sessionsGemerkt { return s }
        let s = f.sessions(ich)
        sessionsGemerkt = s
        return s
    }
    func laufende(jetzt: Date? = nil) -> GymSession? {
        let t = jetzt ?? uhr()
        return sessions.first { TrainingLogik.laufend($0, jetzt: t) }
    }
    func vergessene(jetzt: Date? = nil) -> GymSession? { TrainingLogik.vergessen(sessions, jetzt: jetzt ?? uhr()) }
    func fortsetzbare(jetzt: Date? = nil) -> GymSession? { TrainingLogik.fortsetzbar(sessions, jetzt: jetzt ?? uhr()) }
    /// Katalog-id der Übung, die gerade läuft; nil außerhalb einer laufenden Einheit.
    func aktiveUebung() -> String? { laufende()?.aktiv?.uebung }
    func heutigerTag() -> TrainingsTag? { TrainingLogik.tag(plan, datum: Datum.text(uhr())) }
    func tag(id: String?) -> TrainingsTag? { plan.tag(id: id) }
    func cardio(am tag: String) -> [CardioEintrag] { cardioFaltung.am(tag, von: ich) }

    // MARK: - Schreiben

    func planSichern(_ plan: TrainingsPlan) { raum.senden("gym.plan", plan) }

    /// Tage mit einer Einheit, damit Verlegen und Testwoche nichts anfassen, was schon trainiert ist.
    private var gemachteTage: Set<String> { Set(sessions.map { Datum.text($0.start) }) }

    /// Wohin der Plantag von `datum` diese Woche gehen kann; leer, wenn nichts mehr geht.
    func verlegeZiele(von datum: String) -> [WochenLogik.Ziel] {
        WochenLogik.verlegeZiele(plan, von: datum, heute: Datum.text(uhr()), gemacht: gemachteTage)
    }

    /// Verlegt den Plantag von `von` auf `auf` (nur diese Woche, tauscht bei Belegung). false, wenn nicht erlaubt.
    @discardableResult
    func verlegen(von: String, auf: String) -> Bool {
        guard let neu = WochenLogik.verlegen(plan, von: von, auf: auf, heute: Datum.text(uhr()), gemacht: gemachteTage) else { return false }
        planSichern(neu)
        return true
    }

    /// "Zurück auf Plan": verlegte Tage der laufenden Woche gelten wieder wie im festen Plan.
    func verlegungenLoeschen() { planSichern(WochenLogik.verlegungenLoeschen(plan, heute: Datum.text(uhr()))) }

    /// Das Split `v` nur für den Rest der laufenden Woche. false, wenn in dieser Woche kein Tag mehr übrig ist.
    @discardableResult
    func testwocheStarten(_ v: SplitVorlage) -> Bool {
        guard let neu = WochenLogik.testStarten(plan, vorlage: v, heute: Datum.text(uhr()), gemacht: gemachteTage) else { return false }
        planSichern(neu)
        return true
    }

    func testwocheAbbrechen() { planSichern(WochenLogik.testAbbrechen(plan, heute: Datum.text(uhr()))) }

    /// Startet eine Einheit. Das Abhaken des Gym-Habits übernimmt das Modul gym über den `HabitStore`.
    @discardableResult
    func einchecken(tag: String?) -> String {
        let id = UUID().uuidString
        raum.senden("gym.checkin", GymD(session: id, tag: tag, start: uhr()))
        ereignisse?.senden(.trainingGestartet(session: id))
        return id
    }

    /// Trainingstag nachträglich wählen: Check-in mit gleicher Zeit nochmal senden (neuester gilt).
    func tagSetzen(_ s: GymSession, _ tag: String) {
        raum.senden("gym.checkin", GymD(session: s.id, tag: tag, start: s.start))
    }

    func starten(_ session: String, _ u: PlanUebung) {
        raum.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "start"))
    }

    /// Fertig. Geänderte Sätze werden die Planwerte fürs nächste Mal.
    func fertig(_ session: String, _ u: PlanUebung, saetze: [PlanSatz]) {
        raum.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "fertig", saetze: u.istCardio ? nil : saetze))
        if !u.istCardio, saetze != u.saetze { planSichern(TrainingLogik.uebernehmen(plan, planUebung: u.id, saetze: saetze)) }
    }

    /// Der ganze Stand der Satzzeilen einer Übung. Bei jedem Haken, nicht bei jedem Tastendruck.
    func saetzeSenden(_ session: String, _ u: PlanUebung, _ saetze: [PlanSatz]) {
        raum.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "satz", saetze: saetze, name: u.name))
    }

    /// Tausch im Training: derselbe Plan-Eintrag, andere Katalog-Übung; `ersatzFuer` hält die ursprüngliche fest.
    func tauschen(_ session: String, _ u: PlanUebung, zu neu: String, ersatzFuer: String?, saetze: [PlanSatz]) {
        raum.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: neu, status: "satz", saetze: saetze, ersatzFuer: ersatzFuer))
    }

    /// Übung auslassen: ein leerer Stand. `entfernen` nimmt sie wieder auf.
    func auslassen(_ session: String, _ u: PlanUebung) { saetzeSenden(session, u, []) }

    func entfernen(_ session: String, _ u: PlanUebung) {
        raum.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "weg"))
    }

    func zuruecksetzen(_ session: String, _ u: PlanUebung) {
        raum.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "offen"))
    }

    /// Beendet die Einheit. `saetze`, `rekorde`, `kcal` und `puls` rechnet das Modul gym (Workout- und Rekordlogik) und reicht sie her.
    func auschecken(_ session: String, ende: Date? = nil, saetze: Int? = nil, rekorde: Int? = nil, kcal: Int? = nil, puls: Int? = nil, notiz: String? = nil) {
        let ende = ende ?? uhr()
        let start = sessions.first { $0.id == session }?.start
        let minuten = start.map { max(1, Int(ende.timeIntervalSince($0) / 60)) }
        raum.senden("gym.checkout", GymD(session: session, ende: ende, status: "ende", minuten: minuten, zahl: saetze, rekorde: rekorde, kcal: kcal, puls: puls,
                                                   notiz: TrainingLogik.notiz(notiz)))
        ereignisse?.senden(.trainingBeendet(session: session))
    }

    /// Notiz zum Training ändern (Idee 28): ein Checkout nur mit `notiz`, die Zeiten bleiben. Leer löscht die Notiz.
    func notizAendern(_ s: GymSession, _ text: String) {
        raum.senden("gym.checkout", GymD(session: s.id, notiz: TrainingLogik.notiz(text) ?? ""))
    }

    /// Auschecken rückgängig: die Einheit läuft weiter (`TrainingLogik.session`, Status "wieder").
    func auscheckenRueckgaengig(_ session: String) {
        raum.senden("gym.checkout", GymD(session: session, status: "wieder"))
    }

    /// Spätere Korrektur: sendet Check-in und/oder Check-out neu (der neueste gilt).
    func zeitenAendern(_ s: GymSession, start: Date, ende: Date?) {
        if start != s.start { raum.senden("gym.checkin", GymD(session: s.id, tag: s.tag, start: start)) }
        // kcal und Puls mitschicken: die neueste Ende-Zeile gilt, sonst gingen sie bei jeder Zeitkorrektur verloren.
        if let ende, ende != s.ende { raum.senden("gym.checkout", GymD(session: s.id, ende: ende, kcal: s.kcal, puls: s.puls)) }
    }

    /// Ein Training von Hand nachtragen: Start und Ende, ohne einzuchecken.
    func nachtragen(tag: String?, start: Date, ende: Date) {
        let id = UUID().uuidString
        raum.senden("gym.checkin", GymD(session: id, tag: tag, start: start))
        raum.senden("gym.checkout", GymD(session: id, ende: ende))
    }

    func loeschen(_ s: GymSession) { raum.senden("gym.loeschen", GymD(session: s.id)) }

    // MARK: - Cardio

    func cardioSichern(_ e: CardioEintrag) { raum.senden("cardio.setzen", e) }
    func cardioLoeschen(_ e: CardioEintrag) { raum.senden("cardio.loeschen", ["id": e.id]) }
}
