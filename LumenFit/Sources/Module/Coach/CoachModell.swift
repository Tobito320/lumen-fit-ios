import Foundation
import Observation

// Zustand des Coach-Tabs: Fluss einer Frage (Entwurf, Senden, Tippanzeige, Antwort, Fehler), Chips mit Handlung, Morgen-Check, Daumen und
// Merkliste. Vorbild war Loveas `CoachModell` (Fluss, Entwurf, Fehler); anders als dort geht die Frage an `AppUmgebung.coachMotor` statt an
// einen Server, und der Verlauf liegt im `CoachStore`. Die Tippanzeige steht höchstens `frist` Sekunden (15), danach kommt der Fehlertext
// "Gerade nicht erreichbar, ich merke mir deine Frage" mit Lumi und der Chip "Nochmal"; die Frage bleibt gemerkt und wird beim nächsten
// Öffnen der App noch einmal gestellt.

/// Eine bestätigte Handlung eines Chips mit Weg zurück (Rückgängig).
struct CoachHandlung: Identifiable {
    let id = UUID()
    let text: String
    let symbol: String
    let zurueck: (@MainActor () -> Void)?
}

@MainActor @Observable
final class CoachModell {
    /// Längste Frage in Zeichen.
    nonisolated static let maxZeichen = 1000

    var entwurf = ""
    private(set) var denkt = false
    private(set) var denkBeginn: Date?
    private(set) var handlung: CoachHandlung?
    private(set) var morgenCheckSichtbar = false
    private(set) var benutzteChips: Set<String> = []
    /// Eintrags-Marker der letzten Antwort, die auf "Eintragen" warten (`CoachTracking.eintraege`), und die Karte danach mit Rückgängig.
    private(set) var vorschlag: [CoachTracking.Eintrag] = []
    private(set) var bestaetigt: [CoachTracking.Zeile] = []
    /// Bestätigen hat nichts bewirkt (Training ohne Einheit, unbekannter Eintrag): die Karte sagt "Nicht geklappt".
    private(set) var nichtGeklappt = false
    /// Zähler für die Haptik der Oberfläche (`.haptik(art, bei:)`): jede Änderung ist ein Signal.
    private(set) var erfolgSignal = 0
    private(set) var warnungSignal = 0
    private(set) var auswahlSignal = 0

    @ObservationIgnored let umgebung: AppUmgebung
    @ObservationIgnored let frist: TimeInterval
    @ObservationIgnored private var aufgabe: Task<Void, Never>?
    @ObservationIgnored private var letzteZeit = Date.distantPast
    @ObservationIgnored private var rueckwege: [@MainActor () -> Void] = []
    /// Seit wann eine frische Antwort steht (Id der Nachricht): sie wird Wort für Wort eingeblendet. Nur im Speicher.
    @ObservationIgnored private var frisch: [String: Date] = [:]
    @ObservationIgnored private var einstellungenGeladen: (profil: ProfilID, wert: CoachEinstellungen)?
    @ObservationIgnored private var gedaechtnisGeladen: (profil: ProfilID, wert: CoachGedaechtnis)?

    init(umgebung: AppUmgebung, frist: TimeInterval = CoachLokal.denkGrenze) {
        self.umgebung = umgebung
        self.frist = frist
    }

    // MARK: - Lesen

    var daten: DatenSatz? { umgebung.daten }

    /// Lokale Einstellungen des aktiven Profils (`coach.json`); wechselt mit dem Profil.
    var einstellungen: CoachEinstellungen? {
        guard let daten else { return nil }
        if let geladen = einstellungenGeladen, geladen.profil == daten.profil { return geladen.wert }
        let neu = CoachEinstellungen(ordner: daten.ordner)
        einstellungenGeladen = (daten.profil, neu)
        return neu
    }

    /// Der Merkzettel des aktiven Profils.
    var gedaechtnis: CoachGedaechtnis? {
        guard let daten else { return nil }
        if let geladen = gedaechtnisGeladen, geladen.profil == daten.profil { return geladen.wert }
        let neu = CoachGedaechtnis(store: daten.coach)
        gedaechtnisGeladen = (daten.profil, neu)
        return neu
    }

    var verlauf: [CoachNachricht] { daten?.coach.verlauf ?? [] }

    var jetzt: Date { umgebung.uhr() }

    /// Der Verlauf ohne das, was die Person ausgeblendet hat (nur Anzeige; der Coach kennt die Nachrichten weiter).
    var sichtbarerVerlauf: [CoachNachricht] {
        guard let bis = einstellungen?.stand.ausgeblendetBis else { return verlauf }
        return verlauf.filter { $0.zeit > bis }
    }

    /// Der Chat zeigt nur heute; die Tage davor stehen im Verlauf (`CoachTage`).
    var heute: [CoachNachricht] { CoachTage.heute(sichtbarerVerlauf, beginn: CoachTage.beginn(jetzt: jetzt, kalender: Datum.kalender)) }

    var vergangeneTage: [CoachTage.Tag] {
        CoachTage.vergangene(sichtbarerVerlauf, beginn: CoachTage.beginn(jetzt: jetzt, kalender: Datum.kalender), kalender: Datum.kalender)
    }

    /// Beginn des heutigen Chats; Treffer der Suche davor öffnen den Tag im Verlauf.
    var tagBeginn: Date { CoachTage.beginn(jetzt: jetzt, kalender: Datum.kalender) }

    // MARK: - Wahl der Person (Chat-Menü)

    var pausiert: Bool { einstellungen?.stand.pause ?? false }
    var ton: String { einstellungen?.stand.ton ?? "" }
    var ziel: String { einstellungen?.stand.ziel ?? "" }
    var morgenAn: Bool { einstellungen?.stand.morgenAn ?? true }
    var disziplin: Bool { einstellungen?.stand.disziplin ?? false }

    func setzePause(_ an: Bool) {
        if an { aufgabe?.cancel() }
        einstellungen?.setzePause(an)
        auswahlSignal += 1
    }

    func setzeTon(_ wert: String) {
        einstellungen?.setzeTon(wert)
        auswahlSignal += 1
    }

    func setzeZiel(_ text: String) {
        einstellungen?.setzeZiel(text)
        auswahlSignal += 1
    }

    func setzeMorgen(_ an: Bool) {
        einstellungen?.setzeMorgen(an)
        if !an { morgenCheckSichtbar = false }
        auswahlSignal += 1
    }

    func setzeDisziplin(_ an: Bool) {
        einstellungen?.setzeDisziplin(an)
        auswahlSignal += 1
    }

    /// Blendet alles bis jetzt im Chat und im Verlauf aus. Die Nachrichten bleiben gespeichert, der Coach kennt die letzten weiter.
    func verlaufAusblenden() {
        let bis = max(jetzt, verlauf.last?.zeit ?? jetzt)
        letzteZeit = max(letzteZeit, bis)
        einstellungen?.blendeVerlaufAus(bis: bis)
        vorschlag = []
        bestaetigt = []
        rueckwege = []
        warnungSignal += 1
    }

    // MARK: - Antwort frisch, Aufgaben abhaken

    /// Seit wann die Antwort frisch ist; `nil` für alles, was nicht eben erst gekommen ist.
    func frischSeit(_ id: String) -> Date? { frisch[id] }

    private func merkeFrisch(_ id: String) {
        frisch[id] = jetzt
        if frisch.count > 20 { frisch = frisch.filter { jetzt.timeIntervalSince($0.value) < 60 } }
    }

    /// Eine Aufgabe ist an ihre Antwort gebunden: gleicher Satz in einer anderen Antwort ist eine andere Aufgabe.
    func hakenSchluessel(_ nachricht: CoachNachricht, _ zeile: String) -> String {
        CoachLokal.schluessel(nachricht.text) + "." + CoachLokal.schluessel(zeile)
    }

    func istAbgehakt(_ nachricht: CoachNachricht, _ zeile: String) -> Bool { einstellungen?.istAbgehakt(hakenSchluessel(nachricht, zeile)) ?? false }

    func schalteHaken(_ nachricht: CoachNachricht, _ zeile: String) {
        let schluessel = hakenSchluessel(nachricht, zeile)
        einstellungen?.haken(schluessel, an: !(einstellungen?.istAbgehakt(schluessel) ?? false))
        auswahlSignal += 1
    }

    // MARK: - Eintragen mit Bestätigung

    /// Die Zeilen des Vorschlags für die Karte "Eintragen?".
    var vorschlagZeilen: [CoachTracking.Zeile] {
        let stand = daten.map { CoachTrainingMarker.aktuellerStand($0, jetzt: jetzt) }
        return vorschlag.map { CoachTracking.zeile($0, stand: stand) }
    }

    var kannRueckgaengig: Bool { !rueckwege.isEmpty }

    /// Schlägt die Eintrags-Marker einer frischen Antwort vor. Ältere Vorschläge und Karten fallen weg.
    private func schlageVor(_ text: String) {
        let eintraege = CoachTracking.eintraege(CoachMarker.zerlegen(text).marker, stunde: Datum.kalender.component(.hour, from: jetzt))
        vorschlag = eintraege
        bestaetigt = []
        nichtGeklappt = false
        rueckwege = []
    }

    func vorschlagBestaetigen() {
        guard !vorschlag.isEmpty, let daten, let gedaechtnis else { return }
        let ergebnis = CoachTracking.speichern(vorschlag, daten: daten, gedaechtnis: gedaechtnis, jetzt: jetzt)
        vorschlag = []
        bestaetigt = ergebnis.zeilen
        rueckwege = ergebnis.zurueck
        nichtGeklappt = ergebnis.zeilen.isEmpty
        if nichtGeklappt { warnungSignal += 1 } else { erfolgSignal += 1 }
    }

    func vorschlagVerwerfen() {
        guard !vorschlag.isEmpty else { return }
        vorschlag = []
        auswahlSignal += 1
    }

    func eintragRueckgaengig() {
        for zurueck in rueckwege.reversed() { zurueck() }
        rueckwege = []
        bestaetigt = []
        nichtGeklappt = false
        erfolgSignal += 1
    }

    func karteSchliessen() {
        bestaetigt = []
        nichtGeklappt = false
        rueckwege = []
    }

    /// Schnellfragen nach Tageszeit, nur bis zur ersten eigenen Nachricht des Tages (Idee 68).
    var schnellfragen: [String] {
        let kalender = Datum.kalender
        guard CoachLokal.schnellfragenSichtbar(verlauf, jetzt: jetzt, kalender: kalender) else { return [] }
        let gefragt = CoachLokal.heuteGefragt(verlauf, jetzt: jetzt, kalender: kalender)
        return CoachLokal.schnellfragen(stunde: kalender.component(.hour, from: jetzt), wochentag: kalender.component(.weekday, from: jetzt), schonGefragt: gefragt)
    }

    var merkliste: [CoachNachricht] {
        let ids = einstellungen?.stand.merkliste ?? []
        return verlauf.filter { ids.contains($0.id) }
    }

    func istBenutzt(_ chip: CoachChip, in nachricht: CoachNachricht) -> Bool { benutzteChips.contains("\(nachricht.id)/\(chip.id)") }

    // MARK: - Fragen

    /// Sendet `text` (oder den Entwurf). Eine Frage nach der anderen: solange der Coach denkt, passiert nichts.
    func senden(_ roh: String? = nil) {
        let text = (roh ?? entwurf).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !denkt, !pausiert, text.count <= Self.maxZeichen, let daten else { return }
        if roh == nil { entwurf = "" }
        let bisher = daten.coach.verlauf
        daten.coach.haenge(nachricht(.nutzer, text))
        if let gemerkt = gedaechtnis?.merkeAusFrage(text) {
            daten.coach.haenge(nachricht(.coach, "Gemerkt: \(gemerkt). Im Gedächtnis kannst du es jederzeit löschen."))
            return
        }
        starte(text, bisher: bisher, daten: daten)
    }

    /// Stellt die gemerkte Frage noch einmal (Chip "Nochmal" oder Rückkehr in die App).
    func nochmal() {
        guard !denkt, !pausiert, let daten, let frage = einstellungen?.stand.wartendeFrage ?? verlauf.last(where: { $0.rolle == .nutzer })?.text else { return }
        starte(frage, bisher: daten.coach.verlauf, daten: daten)
    }

    /// Beim Zurückkehren in die App oder beim Öffnen des Tabs: eine gemerkte Frage wird noch einmal gestellt.
    func beiVordergrund() {
        if einstellungen?.stand.wartendeFrage != nil { nochmal() }
    }

    func abbrechen() {
        aufgabe?.cancel()
    }

    private func starte(_ frage: String, bisher: [CoachNachricht], daten: DatenSatz) {
        denkt = true
        denkBeginn = jetzt
        aufgabe = Task { [weak self] in await self?.beantworte(frage, bisher: bisher, daten: daten) }
    }

    private func beantworte(_ frage: String, bisher: [CoachNachricht], daten: DatenSatz) async {
        defer { denkt = false; denkBeginn = nil; aufgabe = nil }
        let anfrage = CoachAnfrage(frage: frage, verlauf: Array(bisher.suffix(12)), kontext: CoachDaten.kontext(umgebung, daten),
                                   ton: ton, ziel: ziel, disziplin: disziplin)
        let motor = umgebung.coachMotor
        let sekunden = frist
        let wache = CoachHintergrundWache()
        defer { wache.beenden() }
        do {
            let antwort = try await wache.fragenGeschuetzt {
                try await CoachWahlMotor.mitFrist(sekunden) { try await motor.antworte(anfrage) }
            }
            einstellungen?.merkeFrage(nil)
            let neu = nachricht(.coach, antwort.text, chips: antwort.chips)
            merkeFrisch(neu.id)
            daten.coach.haenge(neu)
            schlageVor(antwort.text)
        } catch is CancellationError {
            // Abgebrochen: nichts merken, nichts zeigen.
        } catch {
            // Nie ein rohes Fehlerwort: der ruhige Text mit Lumi und ein Chip zum Wiederholen.
            einstellungen?.merkeFrage(frage)
            daten.coach.haenge(nachricht(.coach, CoachPersona.fehlerText, chips: [CoachChip(id: "nochmal", text: "Nochmal", aktion: .antworten(frage))]))
        }
    }

    /// Streng wachsende Zeit, damit Frage und Antwort auch bei stehender Uhr (Tests) in der richtigen Reihenfolge stehen.
    private func naechsteZeit() -> Date {
        let t = max(jetzt, letzteZeit.addingTimeInterval(0.001))
        letzteZeit = t
        return t
    }

    private func nachricht(_ rolle: CoachRolle, _ text: String, chips: [CoachChip] = []) -> CoachNachricht {
        CoachNachricht(id: UUID().uuidString, rolle: rolle, text: text, zeit: naechsteZeit(), chips: chips, daumen: nil)
    }

    // MARK: - Chips mit Handlung

    func tippe(_ chip: CoachChip, in nachricht: CoachNachricht) {
        switch chip.aktion {
        case .antworten(let text):
            if chip.id == "nochmal" { nochmal() } else { senden(text) }
        case .nichts:
            break
        case .oeffne:
            guard let daten else { return }
            _ = CoachTracking.ausfuehren(chip, umgebung: umgebung, daten: daten)
        case .gewohnheitAnlegen, .planMorgenLeicht:
            guard let daten, benutzteChips.insert("\(nachricht.id)/\(chip.id)").inserted else { return }
            guard let ergebnis = CoachTracking.ausfuehren(chip, umgebung: umgebung, daten: daten) else { return }
            let neu = CoachHandlung(text: ergebnis.text, symbol: ergebnis.symbol, zurueck: ergebnis.zurueck)
            handlung = neu
            let id = neu.id
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                if self?.handlung?.id == id { self?.handlung = nil }
            }
        }
    }

    /// Nimmt die letzte Handlung zurück (Gewohnheit löschen, Plan wie vorher).
    func rueckgaengig() {
        handlung?.zurueck?()
        handlung = nil
    }

    // MARK: - Daumen und Merkliste

    /// Daumen hoch (`true`) oder runter (`false`); derselbe Daumen noch einmal nimmt ihn zurück. Der Coach lernt daraus Länge und Ton.
    func setzeDaumen(_ wert: Bool, an nachricht: CoachNachricht) {
        guard nachricht.rolle == .coach, let daten else { return }
        var neu = nachricht
        neu.daumen = nachricht.daumen == wert ? nil : wert
        daten.coach.haenge(neu)
        auswahlSignal += 1
    }

    func istGemerkt(_ nachricht: CoachNachricht) -> Bool { einstellungen?.istGemerkt(nachricht.id) ?? false }

    func schalteMerkliste(_ nachricht: CoachNachricht) {
        einstellungen?.merkeAntwort(nachricht.id, an: !istGemerkt(nachricht))
        auswahlSignal += 1
    }

    // MARK: - Morgen-Check

    /// Prüft beim Öffnen des Tabs, ob der Morgen-Check dran ist. Nur dann, nie als Mitteilung.
    func pruefeMorgenCheck() {
        guard let daten, let einstellungen, !einstellungen.stand.pause, einstellungen.stand.morgenAn else { morgenCheckSichtbar = false; return }
        let zeit = jetzt
        let stimmungen = daten.raum.ops(arten: [CoachDaten.stimmungArt]).compactMap { $0.daten(StimmungsEintrag.self) }
        morgenCheckSichtbar = CoachMorgenCheck.faellig(stunde: Datum.kalender.component(.hour, from: zeit), tag: Datum.text(zeit), stimmungen: stimmungen,
                                                      uebersprungen: einstellungen.stand.morgenUebersprungen)
    }

    /// Die Antwort 1 bis 5: setzt Lumis Stimmung (Op `fit.lumi.stimmung`) und der Coach antwortet kurz mit einem Vorschlag.
    func morgenCheckBeantworten(_ wert: Int) {
        guard let daten else { return }
        let eintrag = CoachMorgenCheck.eintrag(tag: Datum.text(jetzt), wert: wert)
        daten.raum.senden(CoachDaten.stimmungArt, eintrag)
        let stufe = CoachMorgenCheck.stufen.first { $0.wert == eintrag.wert }
        daten.coach.haenge(nachricht(.nutzer, "Heute früh: \(stufe?.name ?? "Okay") (\(eintrag.wert) von 5)"))
        let antwort = CoachMorgenCheck.antwort(wert: eintrag.wert, kontext: CoachDaten.kontext(umgebung, daten))
        let neu = nachricht(.coach, antwort.text, chips: antwort.chips)
        merkeFrisch(neu.id)
        daten.coach.haenge(neu)
        morgenCheckSichtbar = false
    }

    func morgenCheckUeberspringen() {
        einstellungen?.ueberspringeMorgen(tag: Datum.text(jetzt))
        morgenCheckSichtbar = false
    }
}
