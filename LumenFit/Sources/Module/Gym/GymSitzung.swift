// Quelle: Lovea Health/Workout.swift (WorkoutAktion und WorkoutUhr, ersetzt: ein Objekt für das laufende Training), GymLive.swift
import Foundation
import Observation
import UIKit

/// Das laufende Training: Satzzeilen, Haken, Pause, Rekord, Live-Anzeige und Beenden. Auch der Steuerungsport der App
/// (`trainingSteuerung`): ein Intent, die Live Activity oder ein Kurzbefehl startet die App im Hintergrund und ruft `satzFertig()`,
/// ohne dass eine Oberfläche offen ist (SPEC 5.9, Vertrag 9). Dafür liest die Sitzung ihren Stand bei Bedarf aus dem `TrainingStore`
/// (`ladeWennNoetig`) und hält sonst nichts fest, was der Store nicht auch weiß.
///
/// Die Zeilen werden im Speicher geändert (Plus, Minus, Typ) und beim Haken gesendet; ohne Haken gehen sie 1,5 s nach dem letzten Tipp
/// als Entwurf raus (`entwurfSenden`; auch beim Sperren oder Verlassen der App, ohne dass eine Ansicht offen sein muss, und spätestens `entwurfHoechstens` nach dem ersten offenen Tipp),
/// damit Absturz, Beenden durch iOS oder ein Update nichts verlieren: ein Op je Haken oder Ruhepause.
/// Alle Zeiten kommen von `umgebung.uhr`. Kein Timer im Hintergrund: eine einzige schlafende Aufgabe bis zum Ende der Pause.
@MainActor @Observable
final class GymSitzung: TrainingSteuerung {
    @ObservationIgnored let umgebung: AppUmgebung
    @ObservationIgnored let puls: any GymPulsQuelle
    @ObservationIgnored private var pauseAufgabe: Task<Void, Never>?
    @ObservationIgnored private(set) var liveAufgabe: Task<Void, Never>?
    @ObservationIgnored private(set) var endeAufgabe: Task<Void, Never>?
    @ObservationIgnored private(set) var bandAufgabe: Task<Void, Never>?
    /// Schon gemeldete Rekorde dieses Trainings ("plan|art|wert"): jeder Rekord erscheint einmal, auch bei Haken weg und wieder dran.
    @ObservationIgnored private var gemeldet: Set<String> = []
    @ObservationIgnored private var pauseGemeldet = false
    /// Übungen (Plan-Ids) mit geänderten, noch nicht gesendeten Zeilen; `entwurfAufgabe` schreibt sie nach `entwurfVerzug`.
    @ObservationIgnored private var entwurfOffen: Set<String> = []
    @ObservationIgnored private(set) var entwurfAufgabe: Task<Void, Never>?
    /// Wie lange nach dem letzten Tipp ein Entwurf auf die Platte geht (Sekunden).
    nonisolated static let entwurfVerzug: TimeInterval = 1.5
    /// Spätestens so lange nach dem ersten offenen Tipp geht der Entwurf raus, auch wenn die Person ohne Pause weitertippt (Sekunden).
    nonisolated static let entwurfHoechstens: TimeInterval = 5
    /// Wann der erste noch nicht geschriebene Tipp kam (`umgebung.uhr`); nil ohne offenen Entwurf. Nur im Speicher.
    @ObservationIgnored private var entwurfErster: Date?
    /// Der Store, in dem der offene Entwurf entstand: ein Profilwechsel im Verzug schreibt ihn trotzdem in die Einheit des alten Profils. Nur im Speicher.
    @ObservationIgnored private var entwurfStore: TrainingStore?
    /// Der zuletzt gesetzte Haken (Plan-Id, Satz, Zeit): startet die Pause nach, wenn die Person bei der ersten Frage Ja zum Pausen-Timer sagt.
    @ObservationIgnored private var letzterHaken: (plan: String, satz: Int, zeit: Date)?
    /// Präferenz Pausen-Timer (Standard aus, 09.11.2026): ohne sie startet der Haken keine Pause.
    nonisolated static var pausenTimerAn: Bool { UserDefaults.standard.bool(forKey: GymAnzeige.pausenTimerSchluessel) }
    /// Je Raum, nicht je Profil: nach dem Wechsel A, B, A gibt es einen neuen Raum, ein Speicher am alten schriebe ins Leere.
    @ObservationIgnored private var eigeneStores: [ObjectIdentifier: GymEigeneStore] = [:]
    @ObservationIgnored private var cardioPulse: [ProfilID: GymCardioPuls] = [:]

    /// Das laufende Training, nil ohne.
    private(set) var sessionId: String?
    /// Die Übungen des laufenden Trainings mit ihren Satzzeilen.
    private(set) var liste: [WorkoutUebung] = []
    private(set) var pause: GymPauseStand?
    /// Zählt hoch, wenn eine Pause zu Ende ist: die Ansicht löst darauf die Haptik aus (`.haptik(.pauseEnde, bei:)`).
    private(set) var pauseEndeZaehler = 0
    /// Zählt hoch bei jedem Haken: Haptik `.satzFertig`.
    private(set) var hakenZaehler = 0
    /// Zählt hoch, wenn ein Haken zurückgenommen wird: leichte Haptik (`.haptik(.auswahl, bei:)`).
    private(set) var hakenZurueckZaehler = 0
    /// Der Satz, den jemand im Lovea-Aufbau mit "Übung starten" oder "Nächster Satz" gestartet hat; nil ohne. Im Lumen-Aufbau bleibt er immer nil.
    private(set) var satzLauf: SatzLauf?
    /// Zählt hoch, wenn ein Satz gestartet wird: Haptik `.start` (Lovea `Haptik.mittel`).
    private(set) var satzStartZaehler = 0
    /// Wann der nächste Satz begann (Ende der Pause oder Haken davor); nil = unbekannt. Aus der Zeit wird beim Haken die Satzdauer (`SatzUhrLogik`).
    private(set) var satzSeit: Date?
    /// Letztes Löschen oder Kopieren eines Satzes: die Leiste "Rückgängig" (5 s).
    private(set) var rueckgaengig: SatzRueckgaengig?
    /// Rekord-Beschriftung je Satz ("plan|zeile"), im Training gemerkt; die Zeile zeigt sie neben dem Haken.
    private(set) var rekordLabel: [String: String] = [:]
    /// Sets, zu denen "Wie war das Set?" schon beantwortet ist ("planId|satz"); nur im Speicher, die Antwort wirkt über das Gewicht.
    private(set) var gefuehlGegeben: Set<String> = []
    /// Der Rekord-Toast (`.lumenToast`); die Ansicht bindet ihn.
    var toast: ToastInhalt?

    init(umgebung: AppUmgebung, puls: any GymPulsQuelle = GymKeinePuls()) {
        self.umgebung = umgebung
        self.puls = puls
        // Sperren und Hintergrund schreiben offene Entwürfe von hier aus, nicht über eine Ansicht. `queue: nil`: der Rückruf läuft beim Senden
        // auf dem Hauptthread (UIKit sendet dort), so ist vor dem Einfrieren der App alles geschrieben. Ohne Abmelden: nach `deinit` bleibt `self` leer.
        for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification] {
            _ = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.entwurfSenden() }
            }
        }
    }

    /// Die Sitzung der App: im Betrieb die von `GymModul.start` gesetzte, sonst (Vorschau, Test-Host) eine frische ohne Puls.
    static func von(_ umgebung: AppUmgebung) -> GymSitzung {
        if let vorhanden = umgebung.trainingSteuerung as? GymSitzung { return vorhanden }
        let neu = GymSitzung(umgebung: umgebung)
        umgebung.trainingSteuerung = neu
        return neu
    }

    // MARK: - Lesen

    var daten: DatenSatz? { umgebung.daten }
    var training: TrainingStore? { daten?.training }
    var laufende: GymSession? { training?.laufende() }
    var tag: TrainingsTag? { training?.tag(id: laufende?.tag) }
    var einstellungen: Einstellungen { daten?.einstellungen.werte ?? Einstellungen() }

    /// Die eigenen Übungen des aktiven Profils (Op `fit.gym.uebung`); ein Objekt je Profil.
    var eigene: GymEigeneStore? {
        guard let d = daten else { return nil }
        let schluessel = ObjectIdentifier(d.raum)
        if let vorhanden = eigeneStores[schluessel] { return vorhanden }
        let neu = GymEigeneStore(raum: d.raum, uhr: umgebung.uhr)
        eigeneStores[schluessel] = neu
        return neu
    }

    /// Katalog- oder eigene Übung zu einem Planeintrag (`PlanUebung.katalog` kennt die eigenen nicht).
    func katalog(_ p: PlanUebung) -> Uebung? { p.katalog ?? eigene?.finde(p.uebung) }

    var cardioPuls: GymCardioPuls? {
        guard let d = daten else { return nil }
        if let vorhanden = cardioPulse[d.profil] { return vorhanden }
        let neu = GymCardioPuls(ordner: d.ordner)
        cardioPulse[d.profil] = neu
        return neu
    }

    /// Die nächste Übung und ihr Satz (mit Supersätzen); nil = alles fertig.
    var dran: (uebung: Int, satz: Int)? { SupersatzLogik.dran(liste) }
    var saetzeZahl: Int { WorkoutLogik.saetzeZahl(liste) }
    var volumen: Double { WorkoutLogik.volumen(liste) }

    /// Der Plantag, wie er nach diesem Training aussähe; nil, wenn sich am Aufbau nichts geändert hat (`WorkoutLogik.neuerTag`).
    var neuerTag: TrainingsTag? { tag.flatMap { WorkoutLogik.neuerTag($0, liste) } }

    private func fruehere(_ s: GymSession) -> [GymSession] {
        (training?.sessions ?? []).filter { $0.id != s.id && $0.start < s.start }
    }

    // MARK: - Laden

    /// Liest das laufende Training aus dem Store, wenn die Sitzung es noch nicht kennt (App-Start, Intent im Hintergrund, Profilwechsel).
    func ladeWennNoetig() {
        guard let s = laufende else {
            if sessionId != nil { zuruecksetzen() }
            puls.verwaisteBeenden()
            return
        }
        guard s.id != sessionId else { return }
        entwurfSenden()   // Entwürfe der alten Einheit zuerst schreiben, dann erst umschalten
        sessionId = s.id
        liste = WorkoutLogik.uebungen(s, tag: training?.tag(id: s.tag), frueher: fruehere(s))
        gemeldet = []
        pause = ladePause(s.id)
        satzLauf = ladeSatzLauf(s.id)
        planePause()
        liveSenden()
    }

    private func zuruecksetzen() {
        entwurfSenden()
        sessionId = nil
        liste = []
        pauseAufgabe?.cancel()
        pause = nil
        satzLauf = nil
        gemeldet = []
        gefuehlGegeben = []
    }

    // MARK: - Starten und Beenden

    /// Checkt ein (oder nimmt das laufende Training wieder auf): Gym-Häkchen, Plantag von heute, Studio-Hinweis, Puls.
    func starte(planTag: String?) { einchecken(planTag ?? daten?.training.heutigerTag()?.id) }

    /// Freies Training (Lovea ⋯ "Freies Training"): ohne Plantag, die Übungen kommen im Training dazu. `starte(planTag: nil)` nimmt dagegen den Tag von heute.
    func starteFrei() { einchecken(nil) }

    private func einchecken(_ gewaehlt: String?) {
        guard let d = daten else { return }
        if d.training.laufende() != nil {
            ladeWennNoetig()
            return
        }
        let jetzt = umgebung.uhr()
        _ = d.training.einchecken(tag: gewaehlt)
        d.habits.setzeGym(datum: Datum.text(jetzt), an: true)
        puls.leeren()
        puls.starten()
        ladeWennNoetig()
    }

    /// "Fortsetzen": das zuletzt beendete Training läuft weiter (`TrainingLogik.fortsetzbar`).
    func fortsetzen() {
        guard let d = daten, d.training.laufende() == nil, let s = d.training.fortsetzbare() else { return }
        d.training.auscheckenRueckgaengig(s.id)
        puls.starten()
        ladeWennNoetig()
    }

    /// Beendet das Training: Sätze, Rekorde, Energie und Puls (nur mit Sensor) gehen an `auschecken`; Health bekommt es nur mit dem Schalter.
    func beende() { beende(notiz: nil) }

    /// Wie `beende()`, mit einer Notiz zum ganzen Training (leer wird nicht gespeichert) und, wenn gewählt, einer eigenen Endzeit (Lovea-Aufbau "Endzeit ändern").
    func beende(notiz: String?, ende: Date? = nil) {
        ladeWennNoetig()
        guard let d = daten, let s = laufende, let sid = sessionId else { return }
        entwurfSenden()
        if let letzte = pauseAbschliessen(umgebung.uhr()) { sende(letzte) }
        let rekorde = RekordLogik.anzahl(liste, frueher: fruehere(s))
        d.training.auschecken(sid, ende: ende, saetze: saetzeZahl, rekorde: rekorde, kcal: puls.kcal, puls: puls.schnitt, notiz: notiz)
        let schreiben = d.einstellungen.werte.healthSchreiben
        let beendet = d.training.sessions.first { $0.id == sid }
        let schreiber = umgebung.healthSchreiber
        let quelle = puls
        endeAufgabe = Task {
            let selbstGeschrieben = await quelle.beenden(speichern: schreiben)
            if schreiben, !selbstGeschrieben, let beendet { _ = await schreiber.speichere(training: beendet) }
        }
        setzePause(nil)
        setzeSatzLauf(nil)
        zuruecksetzen()
        liveSenden()
    }

    /// Lovea-Aufbau "Endzeit ändern": Start und Ende von Hand setzen und das Training damit beenden (Lovea `ZeitenBlatt` auf dem laufenden Training).
    /// Läuft über `beende`, damit Sätze, Rekorde, Puls, Pause und Live-Anzeige wie sonst abgeschlossen werden.
    func beendeMitZeiten(start: Date, ende: Date) {
        ladeWennNoetig()
        guard let s = laufende else { return }
        if start != s.start { training?.zeitenAendern(s, start: start, ende: nil) }
        beende(notiz: nil, ende: max(ende, start))
    }

    /// Verwirft das laufende Training ganz (nichts wird gespeichert).
    func verwerfen() {
        guard let d = daten, let s = laufende else { return }
        d.training.loeschen(s)
        let quelle = puls
        endeAufgabe = Task { _ = await quelle.beenden(speichern: false) }
        setzePause(nil)
        setzeSatzLauf(nil)
        zuruecksetzen()
        liveSenden()
    }

    // MARK: - Satz: Haken

    /// Haken an Satz `i` der Übung `u`: setzt den Haken, startet die Pause von selbst (nicht im Supersatz, bis das Paar durch ist),
    /// prüft den Rekord und sendet die Zeilen. Noch einmal getippt nimmt er den Haken zurück.
    func haken(_ u: Int, _ i: Int) {
        ladeWennNoetig()
        guard let sid = sessionId, liste.indices.contains(u), liste[u].saetze.indices.contains(i), !liste[u].planUebung.istCardio else { return }
        let jetzt = umgebung.uhr()
        if liste[u].saetze[i].ok == true {
            liste[u].saetze[i].ok = nil
            liste[u].saetze[i].sek = nil
            liste[u].saetze[i].pause = nil
            rekordLabel["\(liste[u].id)|\(i)"] = nil
            if let p = pause, p.plan == liste[u].id, p.satz == i { setzePause(nil) }
            sende(u)
            hakenZurueckZaehler += 1
        } else {
            let andere = pauseAbschliessen(jetzt)
            // Ein gestarteter Satz misst ab dem Start, sonst (Lumen-Aufbau) ab dem Ende der Pause.
            let gestartet = satzLauf.flatMap { $0.plan == liste[u].id && $0.satz == i ? $0.seit : nil }
            liste[u].saetze[i].sek = SatzUhrLogik.dauer(seit: gestartet ?? satzSeit, jetzt: jetzt, an: UserDefaults.standard.bool(forKey: GymAnzeige.satzzeitSchluessel))
            satzSeit = nil
            setzeSatzLauf(nil)
            liste[u].saetze[i].ok = true
            let rekord = rekordPruefen(u, i)
            let ziel = PauseLogik.nach(uebung: u, in: liste.map(\.planUebung))
            letzterHaken = (liste[u].id, i, jetzt)
            setzePause(Self.pausenTimerAn ? ziel.map { GymPauseStand(session: sid, plan: liste[u].id, satz: i, seit: jetzt, ziel: $0) } : nil)
            if let andere, andere != u { sende(andere) }
            sende(u)
            hakenZaehler += 1
            umgebung.ereignisse.senden(.satzFertig(session: sid, rekord: rekord))
        }
        liveSenden()
    }

    /// Lovea-Aufbau "Übung starten" / "Nächster Satz": die Pause davor endet (ihre Länge geht an ihren Satz), die Zeilen gehen raus (auch ohne
    /// Pause, Lovea `satzStarten`), und die Uhr des Satzes `i` läuft ab jetzt.
    func satzStarten(_ u: Int, _ i: Int) {
        ladeWennNoetig()
        guard let sid = sessionId, liste.indices.contains(u), liste[u].saetze.indices.contains(i), !liste[u].planUebung.istCardio else { return }
        let jetzt = umgebung.uhr()
        if let andere = pauseAbschliessen(jetzt), andere != u { sende(andere) }
        sende(u)
        setzeSatzLauf(SatzLauf(session: sid, plan: liste[u].id, satz: i, seit: jetzt))
        satzStartZaehler += 1
        liveSenden()
    }

    /// Der gestartete Satz dieser Übung, wenn seine Uhr läuft und er noch nicht abgehakt ist (Lovea `laufenderSatz`).
    func laufenderSatz(_ u: Int) -> Int? {
        guard let l = satzLauf, liste.indices.contains(u), liste[u].id == l.plan, liste[u].saetze.indices.contains(l.satz), liste[u].saetze[l.satz].ok != true else { return nil }
        return l.satz
    }

    /// Verschieben sich die Zeilen einer Übung (löschen, kopieren, Aufwärmsätze, auslassen, entfernen, rückgängig), hört die Satz-Uhr auf: sie merkt
    /// sich Satznummern (Lovea `uhrAus`).
    private func satzLaufEnde(_ u: Int) {
        if liste.indices.contains(u), satzLauf?.plan == liste[u].id { setzeSatzLauf(nil) }
    }

    private func setzeSatzLauf(_ neu: SatzLauf?) {
        guard satzLauf != nil || neu != nil else { return }
        satzLauf = neu
        if let d = daten {
            let datei = JSONDatei<SatzLauf>(d.ordner.appendingPathComponent("gym-satz.json"))
            if let neu { datei.speichere(neu) } else { datei.loesche() }
        }
    }

    private func ladeSatzLauf(_ session: String) -> SatzLauf? {
        guard let d = daten, let l = JSONDatei<SatzLauf>(d.ordner.appendingPathComponent("gym-satz.json")).lade(), l.session == session else { return nil }
        return l
    }

    /// Der Knopf der Live Activity und der Kurzbefehl: der Satz, der dran ist, ist fertig. Ohne laufendes Training passiert nichts.
    func satzFertig() {
        ladeWennNoetig()
        guard let d = dran else { return }
        haken(d.uebung, d.satz)
    }

    /// Wie lange die laufende Pause schon dauerte, in die Zeile ihres Satzes schreiben. Gibt die Übung zurück, deren Zeilen sich geändert haben.
    @discardableResult
    private func pauseAbschliessen(_ jetzt: Date) -> Int? {
        guard let p = pause else { return nil }
        setzePause(nil)
        satzSeit = SatzUhrLogik.satzStart(pause: p, jetzt: jetzt)
        guard let u = liste.firstIndex(where: { $0.id == p.plan }), liste[u].saetze.indices.contains(p.satz) else { return nil }
        liste[u].saetze[p.satz].pause = PauseLogik.gedauert(p, jetzt: jetzt)
        return u
    }

    private func rekordPruefen(_ u: Int, _ i: Int) -> Bool {
        guard let s = laufende, let t = training else { return false }
        let w = liste[u]
        let satz = w.saetze[i]
        guard satz.typ != "w" else { return false }
        let tage = RekordLogik.tage(katalogId: w.planUebung.uebung, planId: w.id, in: t.sessions.filter { $0.id != s.id })
        let davor = w.saetze.enumerated().filter { $0.offset != i && $0.element.zaehlt }.map(\.element)
        let arten = RekordLogik.beimSatz(satz, davor: davor, gegen: tage)
        var neue: [RekordArt] = []
        for art in arten where gemeldet.insert("\(w.id)|\(art.rawValue)|\(RekordLogik.wert([satz], art) ?? 0)").inserted { neue.append(art) }
        guard let meldung = RekordLogik.toast(uebung: w.planUebung.anzeigeName, arten: neue, satz: satz) else { return false }
        toast = meldung
        rekordLabel["\(w.id)|\(i)"] = neue.map(\.kurz).joined(separator: ", ")
        return true
    }

    // MARK: - Satz: Zeilen ändern (im Speicher, gesendet wird beim Haken)

    private func aendere(_ u: Int, senden: Bool = false, _ f: ([PlanSatz]) -> [PlanSatz]) {
        ladeWennNoetig()
        guard liste.indices.contains(u) else { return }
        liste[u].saetze = f(liste[u].saetze)
        if senden { sende(u) } else { entwurfMerken(u) }
    }

    /// "Wie war das Set?" (erste Wochen): Leicht stellt das nächste offene Set eine Stufe schwerer, Schwer eine leichter, Passt lässt es.
    func satzGefuehl(_ u: Int, _ i: Int, _ g: SatzGefuehl) {
        guard liste.indices.contains(u), liste[u].saetze.indices.contains(i) else { return }
        gefuehlGegeben.insert("\(liste[u].id)|\(i)")
        guard g != .passt, let j = LaufHilfe.naechstesOffenes(liste[u].saetze, nach: i) else {
            toast = ToastInhalt(titel: String(localized: "Gut, das Gewicht bleibt"), zeile: nil, stimmung: .anfeuern)
            return
        }
        gewicht(u, j, richtung: g == .leicht ? 1 : -1)
        let kg = liste[u].saetze[j].kg.map { TrainingLogik.kgText($0) } ?? "–"
        toast = ToastInhalt(titel: String(localized: "Nächstes Set: \(kg) kg"), zeile: nil, stimmung: .anfeuern)
    }

    func gewicht(_ u: Int, _ i: Int, richtung: Int) {
        guard liste.indices.contains(u) else { return }
        let schritt = LetztesMal.kgSchritt(geraet: katalog(liste[u].planUebung)?.geraet)
        aendere(u) { LetztesMal.aendereKg($0, i, richtung: richtung, schritt: schritt) }
    }

    func wiederholungen(_ u: Int, _ i: Int, richtung: Int) {
        aendere(u) { LetztesMal.aendereWdh($0, i, richtung: richtung) }
    }

    /// Gewicht und Wiederholungen getippt (Lovea-Aufbau: Zahlenfelder statt Plus und Minus). Im Speicher; gesendet wird beim Haken
    /// oder mit `uebungSichern`.
    func werteSetzen(_ u: Int, _ i: Int, kg: Double?, wdh: Int) {
        aendere(u) { LetztesMal.setzeWerte($0, i, kg: kg, wdh: wdh) }
    }

    /// Sendet den Stand der Übung (die Ansicht verlässt die Übung oder geht in den Hintergrund).
    func uebungSichern(_ u: Int) { sende(u) }

    /// Tipp auf "Letztes Mal": Gewicht und Wiederholungen vom letzten Training in die Zeile.
    func letztesMalUebernehmen(_ u: Int, _ i: Int) {
        guard liste.indices.contains(u) else { return }
        let vorher = liste[u].vorher
        aendere(u) { LetztesMal.uebernehmen(zeile: i, in: $0, vorher: vorher) }
    }

    /// Satztyp: "" normal, "w" Aufwärmen, "d" Drop, "f" bis Versagen (`PlanSatz.setzeTyp`).
    func typ(_ u: Int, _ i: Int, _ typ: String) {
        aendere(u, senden: true) { saetze in
            guard saetze.indices.contains(i) else { return saetze }
            var neu = saetze
            neu[i].setzeTyp(typ)
            return neu
        }
    }

    /// RPE aus der Skala (`Anstrengung`); nil nimmt ihn weg.
    func rpe(_ u: Int, _ i: Int, _ stufe: Anstrengung?) {
        aendere(u, senden: true) { saetze in
            guard saetze.indices.contains(i) else { return saetze }
            var neu = saetze
            neu[i].rpe = stufe?.rpe
            return neu
        }
    }

    func satzKopieren(_ u: Int, _ i: Int) {
        satzLaufEnde(u)
        merkeRueckgaengig(u, i, .kopiert)
        aendere(u, senden: true) { WorkoutLogik.kopieren($0, i) }
    }

    /// Merkt die Zeilen vor dem Eingriff für "Rückgängig".
    private func merkeRueckgaengig(_ u: Int, _ i: Int, _ aktion: SatzRueckgaengigLogik.Aktion) {
        ladeWennNoetig()
        guard liste.indices.contains(u), liste[u].saetze.indices.contains(i) else { return }
        let nummer = liste[u].saetze[i].kuerzel ?? "\(liste[u].saetze[..<i].filter { $0.kuerzel == nil }.count + 1)"
        rueckgaengig = SatzRueckgaengig(text: SatzRueckgaengigLogik.text(aktion, nummer: nummer), plan: liste[u].id, vorher: liste[u].saetze)
    }

    /// "Rückgängig": die Zeilen von vorher zurück (samt Haken und Zeiten) und senden.
    func satzRueckgaengigMachen() {
        guard let r = rueckgaengig, let ziel = SatzRueckgaengigLogik.wiederherstellen(r, in: liste) else { rueckgaengig = nil; return }
        rueckgaengig = nil
        satzLaufEnde(ziel.index)
        aendere(ziel.index, senden: true) { _ in ziel.saetze }
        liveSenden()
    }

    func rueckgaengigVergessen() { rueckgaengig = nil }

    func satzDazu(_ u: Int) {
        aendere(u, senden: true) { saetze in
            var neu = saetze
            neu.append((saetze.last(where: { $0.typ != "w" }) ?? PlanSatz(wdh: 10, kg: nil, failure: false)).alsPlan)
            return neu
        }
    }

    func satzLoeschen(_ u: Int, _ i: Int) {
        satzLaufEnde(u)
        if liste.indices.contains(u), liste[u].saetze.count > 1 { merkeRueckgaengig(u, i, .geloescht) }
        aendere(u, senden: true) { saetze in
            guard saetze.indices.contains(i), saetze.count > 1 else { return saetze }
            var neu = saetze
            neu.remove(at: i)
            return neu
        }
    }

    // MARK: - Pause

    /// Nach dem Ja zur Frage "Pausen-Timer nutzen?": die Pause für den eben gesetzten Haken läuft ab seinem Zeitpunkt.
    func pauseNachholen() {
        guard let sid = sessionId, pause == nil, let l = letzterHaken, let u = liste.firstIndex(where: { $0.id == l.plan }),
              liste[u].saetze.indices.contains(l.satz), liste[u].saetze[l.satz].ok == true,
              let ziel = PauseLogik.nach(uebung: u, in: liste.map(\.planUebung)) else { return }
        setzePause(GymPauseStand(session: sid, plan: l.plan, satz: l.satz, seit: l.zeit, ziel: ziel))
        liveSenden()
    }

    /// "+15 s" oder "−15 s" auf die laufende Pause.
    func pauseAendern(sekunden: Int) {
        guard let p = pause else { return }
        setzePause(PauseLogik.aendern(p, um: sekunden))
        liveSenden()
    }

    /// Ein Tipp in der Pause (Knopf "Satz starten" in der App und in der Live Activity): Pause zu Ende, der nächste Satz läuft.
    /// Ist Cardio dran oder alles fertig, endet nur die Pause.
    func naechsterSatzStarten() {
        ladeWennNoetig()
        guard let d = dran, !liste[d.uebung].planUebung.istCardio else { return pauseUeberspringen() }
        satzStarten(d.uebung, d.satz)
    }

    /// Pause beenden (Tipp auf "Überspringen"): ihre Länge geht an den Satz.
    func pauseUeberspringen() {
        if let u = pauseAbschliessen(umgebung.uhr()) { sende(u) }
        liveSenden()
    }

    private func setzePause(_ neu: GymPauseStand?) {
        pause = neu
        pauseGemeldet = false
        pauseAufgabe?.cancel()
        pauseAufgabe = nil
        if let d = daten {
            let datei = JSONDatei<GymPauseStand>(d.ordner.appendingPathComponent("gym-pause.json"))
            if let neu { datei.speichere(neu) } else { datei.loesche() }
        }
        planePause()
    }

    private func ladePause(_ session: String) -> GymPauseStand? {
        guard let d = daten, let p = JSONDatei<GymPauseStand>(d.ordner.appendingPathComponent("gym-pause.json")).lade(), p.session == session else { return nil }
        return p
    }

    /// Eine einzige schlafende Aufgabe bis zum Ende der Pause (Akku): danach Haptik (über `pauseEndeZaehler`) und `band.vibriere(.pauseEnde)`.
    private func planePause() {
        pauseAufgabe?.cancel()
        guard let ende = pause?.ende else { return }
        let rest = ende.timeIntervalSince(umgebung.uhr())
        if rest <= 0 {
            pauseGemeldet = true // schon vorbei, etwa im Hintergrund: nicht nachträglich vibrieren
            return
        }
        pauseAufgabe = Task { [weak self] in
            try? await Task.sleep(for: .seconds(rest))
            guard !Task.isCancelled else { return }
            self?.pauseIstVorbei()
        }
    }

    /// Die Pause ist zu Ende: einmal melden. Die schlafende Aufgabe ruft es; Tests rufen es nach dem Vorstellen der Uhr.
    func pauseIstVorbei() {
        guard let p = pause, PauseLogik.vorbei(p, jetzt: umgebung.uhr()), !pauseGemeldet else { return }
        pauseGemeldet = true
        pauseEndeZaehler += 1
        // Annahme 32: kein geplanter Wecker für das Pausen-Ende. Hat iOS die App schlafen gelegt und weckt sie erst Minuten später, summt das Band nicht mehr nachträglich.
        if (p.ende.map { umgebung.uhr().timeIntervalSince($0) } ?? 0) <= Self.bandSpaetGrenze {
            let band = umgebung.band
            bandAufgabe = Task { await band.vibriere(.pauseEnde) }
        }
        liveSenden()
    }

    /// Wie spät das Pausen-Ende höchstens noch am Band summt (Sekunden).
    private static let bandSpaetGrenze: TimeInterval = 30

    // MARK: - Übungen im Training

    /// Übung dazunehmen (aus dem Katalog), ans Ende der Liste.
    func uebungDazu(_ k: Uebung) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training else { return }
        let neu = GymEigeneLogik.planUebung(k)
        liste.append(WorkoutUebung(planUebung: neu, saetze: neu.saetze, vorher: WorkoutLogik.vorherige(neu, in: laufende.map(fruehere) ?? []), extra: true))
        if !neu.istCardio { t.saetzeSenden(sid, neu, neu.saetze) } else { t.starten(sid, neu) }
        liveSenden()
    }

    /// Haken in "Übung hinzufügen" noch einmal antippen: die zuletzt dazugenommene Übung mit dieser Katalog-id geht wieder heraus (`uebungWeg`),
    /// solange nichts an ihr abgehakt ist. true = sie ist weg oder war nicht mehr da; false = sie bleibt, weil schon etwas eingetragen ist.
    func uebungDazuZurueck(_ katalogId: String) -> Bool {
        ladeWennNoetig()
        guard let i = liste.lastIndex(where: { $0.extra && $0.planUebung.uebung == katalogId }) else { return true }
        guard WorkoutLogik.entfernbar(liste[i]) else { return false }
        uebungWeg(i)
        return true
    }

    /// Eine im Training dazugekommene Übung wieder herausnehmen.
    func uebungWeg(_ u: Int) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training, liste.indices.contains(u), liste[u].extra else { return }
        satzLaufEnde(u)
        t.entfernen(sid, liste[u].planUebung)
        liste.remove(at: u)
        liveSenden()
    }

    /// Übung auslassen (Gerät besetzt, keine Zeit): ein leerer Stand. `wiederAufnehmen` stellt die Planzeilen wieder her.
    func auslassen(_ u: Int) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training, liste.indices.contains(u) else { return }
        satzLaufEnde(u)
        t.auslassen(sid, liste[u].planUebung)
        liste[u].ausgelassen = true
        liste[u].saetze = []
        liveSenden()
    }

    func wiederAufnehmen(_ u: Int) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training, liste.indices.contains(u), let s = laufende else { return }
        t.entfernen(sid, liste[u].planUebung) // "weg" nimmt den leeren Stand zurück: frische Zeilen aus dem Plan
        let vorher = WorkoutLogik.vorherige(liste[u].planUebung, in: fruehere(s))
        liste[u].ausgelassen = false
        liste[u].saetze = WorkoutLogik.zeilen(liste[u].planUebung, lauf: nil, vorher: vorher)
        liveSenden()
    }

    /// "Gerät besetzt": die Übung gegen eine Alternative tauschen, solange kein Haken gesetzt ist (`AusweichLogik`).
    func ausweichen(_ u: Int, zu neu: Uebung) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training, liste.indices.contains(u), AusweichLogik.tauschbar(liste[u], saetze: liste[u].saetze), let s = laufende else { return }
        let original = AusweichLogik.original(liste[u])
        var geaendert = liste[u].planUebung
        geaendert.uebung = neu.id
        geaendert.name = nil
        let vorher = WorkoutLogik.vorherige(geaendert, in: fruehere(s))
        let saetze = AusweichLogik.saetzeNachTausch(liste[u].saetze, vorher: vorher)
        let ersatz = neu.id == original ? nil : original // zurück zum Original: kein Ersatz mehr
        t.tauschen(sid, liste[u].planUebung, zu: neu.id, ersatzFuer: ersatz, saetze: saetze)
        liste[u].planUebung = geaendert
        liste[u].saetze = saetze
        liste[u].vorher = vorher
        liste[u].ersatzFuer = ersatz
        liveSenden()
    }

    /// Den Trainingstag wechseln ("heute Beine statt Push"), solange nichts abgehakt ist (`WorkoutLogik.tagWechselbar`).
    func tagWechseln(zu neu: TrainingsTag) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training, let s = laufende, WorkoutLogik.tagWechselbar(liste) else { return }
        for lauf in WorkoutLogik.laeufeDesTages(s, tag) {
            if let u = tag?.uebungen.first(where: { $0.id == lauf.plan }) { t.entfernen(sid, u) }
        }
        t.tagSetzen(s, neu.id)
        let aktuell = t.sessions.first { $0.id == s.id } ?? s
        liste = WorkoutLogik.uebungen(aktuell, tag: neu, frueher: fruehere(s))
        liveSenden()
    }

    // MARK: - Plan: Reihenfolge, Plan aktualisieren

    /// Ziehen und Ablegen: die Übung `von` (Plan-Id) kommt an die Stelle der Übung `auf`. Der Plantag bekommt dieselbe Reihenfolge, damit sie bleibt.
    func verschieben(_ von: String, auf: String) {
        ladeWennNoetig()
        guard let a = liste.firstIndex(where: { $0.id == von }), let b = liste.firstIndex(where: { $0.id == auf }), a != b else { return }
        liste = WorkoutLogik.verschieben(liste, von: a, nach: b)
        if let t = training, let alt = tag { t.planSichern(TrainingLogik.tagSetzen(t.plan, WorkoutLogik.tagInReihenfolge(alt, liste))) }
        liveSenden()
    }

    /// Blatt "Reihenfolge ändern": die Übungen in der Reihenfolge von `ids`; der Plantag zieht mit, wie beim Ziehen.
    func umordnen(_ ids: [String]) {
        ladeWennNoetig()
        let neu = WorkoutLogik.umordnen(liste, ids: ids)
        guard neu.map(\.id) != liste.map(\.id) else { return }
        liste = neu
        if let t = training, let alt = tag { t.planSichern(TrainingLogik.tagSetzen(t.plan, WorkoutLogik.tagInReihenfolge(alt, liste))) }
        liveSenden()
    }

    /// "Plan aktualisieren": der Tag bekommt den Aufbau dieses Trainings (`neuerTag`).
    func planAktualisieren() {
        guard let t = training, let neu = neuerTag else { return }
        t.planSichern(TrainingLogik.tagSetzen(t.plan, neu))
    }

    /// Ein Training ohne Plantag als neuen, flexiblen Tag speichern (`WorkoutLogik.alsTag`). Mit `einheitZuordnen` gehört die Einheit danach zu
    /// diesem Tag (Lovea `alsTagSpeichern`, `WorkoutView.swift:369`).
    func alsTagSpeichern(name: String, einheitZuordnen: Bool = false) {
        guard let t = training, let neu = WorkoutLogik.alsTag(liste, name: name) else { return }
        t.planSichern(TrainingLogik.tagSetzen(t.plan, neu))
        if einheitZuordnen, let s = laufende { t.tagSetzen(s, neu.id) }
    }

    // MARK: - Cardio

    /// Cardio-Übung abschließen: Dauer, Distanz, Energie und Puls (Idee 29). Das Laufband oder den Stairmaster trägt es zusätzlich als `CardioEintrag` ein.
    func cardioAbschliessen(_ u: Int, minuten: Int, km: Double?, kcal: Int?, puls pulswert: Int?) {
        var e = CardioEintrag(datum: "", geraet: "laufband", minuten: minuten, kcal: kcal, km: km)
        if liste.indices.contains(u), let g = TrainingLogik.cardioGeraet(liste[u].planUebung.katalog) { e.geraet = g }
        cardioAbschliessen(u, eintrag: e, puls: pulswert)
    }

    /// Cardio-Übung fertig mit allen Werten des Geräts (Dauer, Entfernung, Höhe, Stufen, Etagen, Steigung, Geschwindigkeit, Stufe).
    func cardioAbschliessen(_ u: Int, eintrag vorlage: CardioEintrag, puls pulswert: Int?) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training, liste.indices.contains(u), liste[u].planUebung.istCardio else { return }
        t.fertig(sid, liste[u].planUebung, saetze: [])
        liste[u].cardioFertig = true
        if let geraet = TrainingLogik.cardioGeraet(liste[u].planUebung.katalog) {
            var eintrag = vorlage
            eintrag.datum = Datum.text(umgebung.uhr())
            eintrag.geraet = geraet
            t.cardioSichern(eintrag)
            cardioPuls?.setze(eintrag.id, puls: pulswert)
        }
        liveSenden()
    }

    func cardioZurueck(_ u: Int) {
        guard let sid = sessionId, let t = training, liste.indices.contains(u) else { return }
        t.zuruecksetzen(sid, liste[u].planUebung)
        liste[u].cardioFertig = false
    }

    // MARK: - Senden

    private func sende(_ u: Int, in store: TrainingStore? = nil) {
        guard let t = store ?? training, let sid = sessionId, liste.indices.contains(u), !liste[u].planUebung.istCardio else { return }
        entwurfOffen.remove(liste[u].id)
        t.saetzeSenden(sid, liste[u].planUebung, liste[u].saetze)
    }

    /// Merkt die Übung als geändert und plant das Schreiben: eine schlafende Aufgabe, jeder weitere Tipp startet sie neu.
    private func entwurfMerken(_ u: Int) {
        guard liste.indices.contains(u) else { return }
        entwurfOffen.insert(liste[u].id)
        if entwurfStore == nil { entwurfStore = training }
        let jetzt = umgebung.uhr()
        let erster = entwurfErster ?? jetzt
        entwurfErster = erster
        let warte = Self.entwurfWartezeit(seitErstem: jetzt.timeIntervalSince(erster))
        guard warte > 0 else { return entwurfSenden() }
        entwurfAufgabe?.cancel()
        entwurfAufgabe = Task { [weak self] in
            try? await Task.sleep(for: .seconds(warte))
            guard !Task.isCancelled else { return }
            self?.entwurfSenden()
        }
    }

    /// Wie lange ein Entwurf nach diesem Tipp noch warten darf: der Verzug, aber nie über `entwurfHoechstens` seit dem ersten offenen Tipp. 0 oder weniger = jetzt schreiben.
    nonisolated static func entwurfWartezeit(seitErstem: TimeInterval) -> TimeInterval {
        min(entwurfVerzug, entwurfHoechstens - seitErstem)
    }

    /// Schreibt alle geänderten, noch nicht gesendeten Zeilen jetzt (Ende des Verzugs, Hintergrund, Beenden). Ohne Entwurf passiert nichts.
    func entwurfSenden() {
        entwurfAufgabe?.cancel()
        entwurfAufgabe = nil
        entwurfErster = nil
        let offen = entwurfOffen
        entwurfOffen = []
        let store = entwurfStore ?? training
        entwurfStore = nil
        // Nur in eine Einheit, die ihr Store noch kennt: eine verworfene bekäme sonst einen Geister-Eintrag. Der Store ist der, in dem der Entwurf
        // entstand, nicht der des jetzt aktiven Profils.
        guard !offen.isEmpty, let sid = sessionId, let t = store, t.sessions.contains(where: { $0.id == sid }) else { return }
        for id in offen { if let u = liste.firstIndex(where: { $0.id == id }) { sende(u, in: t) } }
    }

    /// Stellt die Live Activity auf den Stand des Trainings (nil beendet sie). Die Aufgaben laufen der Reihe nach.
    func liveSenden() {
        let anzeige = umgebung.liveAnzeige
        let stand = laufende.flatMap { GymLive.stand(session: $0, liste: liste, pause: pause, planName: tag?.name, jetzt: umgebung.uhr()) }
        let vorher = liveAufgabe
        liveAufgabe = Task {
            await vorher?.value
            await anzeige.training(stand)
        }
    }
}
