// Quelle: Lovea Health/Workout.swift (WorkoutAktion und WorkoutUhr, ersetzt: ein Objekt für das laufende Training), GymLive.swift
import Foundation
import Observation

/// Das laufende Training: Satzzeilen, Haken, Pause, Rekord, Live-Anzeige und Beenden. Auch der Steuerungsport der App
/// (`trainingSteuerung`): ein Intent, die Live Activity oder ein Kurzbefehl startet die App im Hintergrund und ruft `satzFertig()`,
/// ohne dass eine Oberfläche offen ist (SPEC 5.9, Vertrag 9). Dafür liest die Sitzung ihren Stand bei Bedarf aus dem `TrainingStore`
/// (`ladeWennNoetig`) und hält sonst nichts fest, was der Store nicht auch weiß.
///
/// Die Zeilen werden im Speicher geändert (Plus, Minus, Typ) und beim Haken gesendet, nicht bei jedem Tipp: ein Op je Haken.
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
    @ObservationIgnored private var studios: [ProfilID: StudioStore] = [:]
    @ObservationIgnored private var geraeteStores: [ProfilID: GeraeteStore] = [:]
    @ObservationIgnored private var defektStores: [ProfilID: DefektStore] = [:]
    @ObservationIgnored private var eigeneStores: [ProfilID: GymEigeneStore] = [:]
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
    /// Wann der nächste Satz begann (Ende der Pause oder Haken davor); nil = unbekannt. Aus der Zeit wird beim Haken die Satzdauer (`SatzUhrLogik`).
    private(set) var satzSeit: Date?
    /// Letztes Löschen oder Kopieren eines Satzes: die Leiste "Rückgängig" (5 s).
    private(set) var rueckgaengig: SatzRueckgaengig?
    /// Rekord-Beschriftung je Satz ("plan|zeile"), im Training gemerkt; die Zeile zeigt sie neben dem Haken.
    private(set) var rekordLabel: [String: String] = [:]
    /// Der Rekord-Toast (`.lumenToast`); die Ansicht bindet ihn.
    var toast: ToastInhalt?
    /// Das Studio hat beim Einchecken zu: einmalig anzeigen, dann `hinweisGelesen()`.
    private(set) var studioHinweis: String?

    init(umgebung: AppUmgebung, puls: any GymPulsQuelle = GymKeinePuls()) {
        self.umgebung = umgebung
        self.puls = puls
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

    /// Das Studio-Profil des aktiven Profils; ein Objekt je Profil.
    var studio: StudioStore? {
        guard let d = daten else { return nil }
        if let vorhanden = studios[d.profil] { return vorhanden }
        let neu = StudioStore(ordner: d.ordner)
        studios[d.profil] = neu
        return neu
    }

    /// Die Defekt-Notizen des aktiven Profils (`defekte.json`); ein Objekt je Profil.
    var defekte: DefektStore? {
        guard let d = daten else { return nil }
        if let vorhanden = defektStores[d.profil] { return vorhanden }
        let neu = DefektStore(ordner: d.ordner)
        defektStores[d.profil] = neu
        return neu
    }

    /// Die eigenen Übungen des aktiven Profils (Op `fit.gym.uebung`); ein Objekt je Profil.
    var eigene: GymEigeneStore? {
        guard let d = daten else { return nil }
        if let vorhanden = eigeneStores[d.profil] { return vorhanden }
        let neu = GymEigeneStore(raum: d.raum, uhr: umgebung.uhr)
        eigeneStores[d.profil] = neu
        return neu
    }

    /// Katalog- oder eigene Übung zu einem Planeintrag (`PlanUebung.katalog` kennt die eigenen nicht).
    func katalog(_ p: PlanUebung) -> Uebung? { p.katalog ?? eigene?.finde(p.uebung) }

    /// Die Geräte-Einstellungen des aktiven Profils (`geraete.json`); ein Objekt je Profil.
    var geraete: GeraeteStore? {
        guard let d = daten else { return nil }
        if let vorhanden = geraeteStores[d.profil] { return vorhanden }
        let neu = GeraeteStore(ordner: d.ordner)
        geraeteStores[d.profil] = neu
        return neu
    }

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
        sessionId = s.id
        liste = WorkoutLogik.uebungen(s, tag: training?.tag(id: s.tag), frueher: fruehere(s))
        gemeldet = []
        pause = ladePause(s.id)
        planePause()
        liveSenden()
    }

    private func zuruecksetzen() {
        sessionId = nil
        liste = []
        pauseAufgabe?.cancel()
        pause = nil
        gemeldet = []
    }

    // MARK: - Starten und Beenden

    /// Checkt ein (oder nimmt das laufende Training wieder auf): Gym-Häkchen, Plantag von heute, Studio-Hinweis, Puls.
    func starte(planTag: String?) {
        guard let d = daten else { return }
        if d.training.laufende() != nil {
            ladeWennNoetig()
            return
        }
        let jetzt = umgebung.uhr()
        let gewaehlt = planTag ?? d.training.heutigerTag()?.id
        _ = d.training.einchecken(tag: gewaehlt)
        d.habits.setzeGym(datum: Datum.text(jetzt), an: true)
        studioHinweis = studio.flatMap { GymOeffnung.hinweis($0.profil.oeffnung, jetzt: jetzt) }
        puls.leeren()
        puls.starten()
        ladeWennNoetig()
    }

    func hinweisGelesen() { studioHinweis = nil }

    /// "Fortsetzen": das zuletzt beendete Training läuft weiter (`TrainingLogik.fortsetzbar`).
    func fortsetzen() {
        guard let d = daten, d.training.laufende() == nil, let s = d.training.fortsetzbare() else { return }
        d.training.auscheckenRueckgaengig(s.id)
        puls.starten()
        ladeWennNoetig()
    }

    /// Beendet das Training: Sätze, Rekorde, Energie und Puls (nur mit Sensor) gehen an `auschecken`; Health bekommt es nur mit dem Schalter.
    func beende() { beende(notiz: nil) }

    /// Wie `beende()`, mit einer Notiz zum ganzen Training (leer wird nicht gespeichert).
    func beende(notiz: String?) {
        ladeWennNoetig()
        guard let d = daten, let s = laufende, let sid = sessionId else { return }
        if let letzte = pauseAbschliessen(umgebung.uhr()) { sende(letzte) }
        let rekorde = RekordLogik.anzahl(liste, frueher: fruehere(s))
        d.training.auschecken(sid, saetze: saetzeZahl, rekorde: rekorde, kcal: puls.kcal, puls: puls.schnitt, notiz: notiz)
        let schreiben = d.einstellungen.werte.healthSchreiben
        let beendet = d.training.sessions.first { $0.id == sid }
        let schreiber = umgebung.healthSchreiber
        let quelle = puls
        endeAufgabe = Task {
            let selbstGeschrieben = await quelle.beenden(speichern: schreiben)
            if schreiben, !selbstGeschrieben, let beendet { _ = await schreiber.speichere(training: beendet) }
        }
        setzePause(nil)
        zuruecksetzen()
        liveSenden()
    }

    /// Verwirft das laufende Training ganz (nichts wird gespeichert).
    func verwerfen() {
        guard let d = daten, let s = laufende else { return }
        d.training.loeschen(s)
        let quelle = puls
        endeAufgabe = Task { _ = await quelle.beenden(speichern: false) }
        setzePause(nil)
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
            liste[u].saetze[i].sek = SatzUhrLogik.dauer(seit: satzSeit, jetzt: jetzt, an: UserDefaults.standard.bool(forKey: GymAnzeige.satzzeitSchluessel))
            satzSeit = nil
            liste[u].saetze[i].ok = true
            let rekord = rekordPruefen(u, i)
            let ziel = PauseLogik.nach(uebung: u, in: liste.map(\.planUebung))
            setzePause(ziel.map { GymPauseStand(session: sid, plan: liste[u].id, satz: i, seit: jetzt, ziel: $0) })
            if let andere, andere != u { sende(andere) }
            sende(u)
            hakenZaehler += 1
            umgebung.ereignisse.senden(.satzFertig(session: sid, rekord: rekord))
        }
        liveSenden()
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
        if senden { sende(u) }
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
        if liste.indices.contains(u), liste[u].saetze.count > 1 { merkeRueckgaengig(u, i, .geloescht) }
        aendere(u, senden: true) { saetze in
            guard saetze.indices.contains(i), saetze.count > 1 else { return saetze }
            var neu = saetze
            neu.remove(at: i)
            return neu
        }
    }

    /// Aufwärmsätze aus dem Arbeitsgewicht der Übung (`AufwaermRechner`), vor die Arbeitssätze.
    func aufwaermen(_ u: Int, arbeit: Double, stufen: [AufwaermRechner.Stufe] = AufwaermRechner.standard) {
        aendere(u, senden: true) { AufwaermRechner.einfuegen(in: $0, arbeit: arbeit, stufen: stufen) }
    }

    // MARK: - Pause

    /// "+15 s" oder "−15 s" auf die laufende Pause.
    func pauseAendern(sekunden: Int) {
        guard let p = pause else { return }
        setzePause(PauseLogik.aendern(p, um: sekunden))
        liveSenden()
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

    /// Eine im Training dazugekommene Übung wieder herausnehmen.
    func uebungWeg(_ u: Int) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training, liste.indices.contains(u), liste[u].extra else { return }
        t.entfernen(sid, liste[u].planUebung)
        liste.remove(at: u)
        liveSenden()
    }

    /// Übung auslassen (Gerät besetzt, keine Zeit): ein leerer Stand. `wiederAufnehmen` stellt die Planzeilen wieder her.
    func auslassen(_ u: Int) {
        ladeWennNoetig()
        guard let sid = sessionId, let t = training, liste.indices.contains(u) else { return }
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

    // MARK: - Plan: Notiz, Pause je Übung, Supersatz, Plan aktualisieren

    /// Die Notiz bleibt an der Übung und steht beim nächsten Training wieder da.
    func notiz(_ u: Int, _ text: String) {
        guard let t = training, liste.indices.contains(u) else { return }
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wert: String? = sauber.isEmpty ? nil : sauber
        liste[u].planUebung.notiz = wert
        t.planSichern(TrainingLogik.aendern(t.plan, planUebung: liste[u].id) { $0.notiz = wert })
    }

    /// Eigene Pause der Übung in Sekunden (0 = ohne Ziel, nil = Standard).
    func pauseZiel(_ u: Int, _ sekunden: Int?) {
        guard let t = training, liste.indices.contains(u) else { return }
        liste[u].planUebung.pause = sekunden
        t.planSichern(TrainingLogik.aendern(t.plan, planUebung: liste[u].id) { $0.pause = sekunden })
    }

    /// Koppelt die Übung mit der nächsten im Tag (Supersatz) oder löst die Kopplung.
    func supersatz(_ u: Int, an: Bool) {
        guard let t = training, liste.indices.contains(u) else { return }
        let neu = SupersatzLogik.koppeln(liste.map(\.planUebung), u, an: an)
        for i in liste.indices { liste[i].planUebung.supersatz = neu[i].supersatz }
        if var tagNeu = tag {
            for k in tagNeu.uebungen.indices { tagNeu.uebungen[k].supersatz = liste.first { $0.id == tagNeu.uebungen[k].id }?.planUebung.supersatz }
            t.planSichern(TrainingLogik.tagSetzen(t.plan, tagNeu))
        }
    }

    /// "Plan aktualisieren": der Tag bekommt den Aufbau dieses Trainings (`neuerTag`).
    func planAktualisieren() {
        guard let t = training, let neu = neuerTag else { return }
        t.planSichern(TrainingLogik.tagSetzen(t.plan, neu))
    }

    /// Ein Training ohne Plantag als neuen, flexiblen Tag speichern (`WorkoutLogik.alsTag`).
    func alsTagSpeichern(name: String) {
        guard let t = training, let neu = WorkoutLogik.alsTag(liste, name: name) else { return }
        t.planSichern(TrainingLogik.tagSetzen(t.plan, neu))
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

    private func sende(_ u: Int) {
        guard let t = training, let sid = sessionId, liste.indices.contains(u), !liste[u].planUebung.istCardio else { return }
        t.saetzeSenden(sid, liste[u].planUebung, liste[u].saetze)
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
