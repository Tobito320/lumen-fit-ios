import Foundation
import Observation

/// Zustand des Heute-Tabs. Liest den Datensatz des aktiven Profils und den Gesundheitsstand, rechnet alles einmal in `HeuteStand` und rechnet
/// neu, wenn ein Ereignis es nötig macht (Haken, Gewicht, Training, Vordergrund, neue Health-Daten). Kein Timer: Bewegung nur bei Ereignissen.
@MainActor @Observable
final class HeuteModell {
    private(set) var stand: HeuteStand?
    /// Der gewählte vergangene Tag; nil = heute (folgt der Uhr, auch über Mitternacht).
    private(set) var gewaehlterTag: String?

    @ObservationIgnored private let umgebung: AppUmgebung
    @ObservationIgnored private var kontext: Kontext?

    /// Je Profil: die weggewischten Karten und die Gefühls-Einträge der Energie-Bank.
    @MainActor private final class Kontext {
        let profil: ProfilID
        let hinweise: TagesHinweisSpeicher
        let gefuehl: TagesformSpeicher
        init(daten: DatenSatz) {
            profil = daten.profil
            hinweise = TagesHinweisSpeicher(ordner: daten.ordner)
            gefuehl = TagesformSpeicher(datei: daten.ordner.appendingPathComponent(TagesformGefuehl.dateiname))
        }
    }

    init(umgebung: AppUmgebung) {
        self.umgebung = umgebung
    }

    // MARK: - Laden

    /// Health lesen (beim Erscheinen und im Vordergrund), dann neu rechnen.
    func lade() async {
        await umgebung.gesundheit.aktualisiere()
        berechne()
    }

    /// Rechnet jetzt und danach bei jedem passenden Ereignis neu. Läuft, solange der Tab sichtbar ist (`.task`).
    func beobachte() async {
        berechne()
        for await ereignis in umgebung.ereignisse.strom() { await verarbeite(ereignis) }
    }

    /// `.healthAktualisiert` kommt erst nach dem Health-Abruf (`AppUmgebung.abrufEinmal`) oder nach einem Eintrag von Hand: dann nur neu rechnen,
    /// nicht nochmal 13 Health-Abfragen starten (Akku, Tempo-Prüfung 10.11.2026).
    func verarbeite(_ ereignis: Ereignis) async {
        switch ereignis {
        case .vordergrund: await lade()
        case .healthAktualisiert, .habitGeaendert, .gewichtGespeichert, .trainingBeendet, .trainingGestartet, .mahlzeitGespeichert, .einstellungenGeaendert,
             .profilGewechselt, .profilGeloescht, .partnerAktualisiert, .meilensteinErreicht:
            berechne()
        case .satzFertig, .speichernFehlgeschlagen: break
        }
    }

    // MARK: - Tag wählen

    /// Zeigt `tag` (Zukunft und mehr als ein Jahr zurück werden gekappt). Heute setzt auf "folgt der Uhr" zurück.
    func waehleTag(_ tag: String) {
        let heute = Datum.text(umgebung.uhr())
        let neu = HeuteTagWahl.begrenze(tag, heute: heute)
        gewaehlterTag = neu == heute ? nil : neu
        berechne()
    }

    func zuHeute() { waehleTag(Datum.text(umgebung.uhr())) }

    // MARK: - Handeln

    /// Haken per Tipp (nicht zählende Gewohnheit) oder ein Schritt weiter bei einer Zähl-Gewohnheit (Wasser).
    func tippe(_ zeile: HeuteHabitZeile) {
        guard let daten = umgebung.daten, let s = stand else { return }
        if zeile.habit.zaehlen {
            daten.habits.setze(zeile.habit.id, datum: s.tag, wert: zeile.wert + 1)
        } else {
            daten.habits.setze(zeile.habit.id, datum: s.tag, wert: zeile.erledigt ? 0 : 1)
        }
        berechne()
    }

    /// Ein Schritt zurück bei einer Zähl-Gewohnheit.
    func weniger(_ zeile: HeuteHabitZeile) {
        guard let daten = umgebung.daten, let s = stand, zeile.habit.zaehlen, zeile.wert > 0 else { return }
        daten.habits.setze(zeile.habit.id, datum: s.tag, wert: zeile.wert - 1)
        berechne()
    }

    func wischeHinweis(_ id: String) {
        kontext?.hinweise.wische(id)
        berechne()
    }

    /// Das Gefühl (1 bis 5) zur Zahl von heute, mit den Rohwerten, damit sich später vergleichen lässt.
    func speichereGefuehl(_ gefuehl: Int) {
        guard let daten = umgebung.daten, let k = kontext, let s = stand, s.istHeute else { return }
        let jetzt = umgebung.uhr()
        let eingabe = TagesformQuellen.eingabe(daten: daten, gesundheit: umgebung.gesundheit, tag: s.tag, jetzt: jetzt)
        let eintrag = TagesformEintrag(tag: s.tag, gefuehl: TagesformGefuehl.stufe(gefuehl), akku: s.energie.ergebnis.akku,
                                       formel: TagesformRechnung.version, eingabe: eingabe, gespeichert: jetzt)
        k.gefuehl.setzen(eintrag)
        berechne()
    }

    /// Speichert das Gewicht (Zehntel-kg) für `tag` und immer auch nach Health (Besitzer 10.11.2026: "speichert immer automatisch", kein Schalter mehr;
    /// `healthSchreiben` gilt weiter für Trainings). false, wenn der Wert nicht passt.
    @discardableResult
    func speichereGewicht(zehntel: Int, tag: String? = nil) async -> Bool {
        guard let daten = umgebung.daten, HeuteQuellen.gewichtBereich.contains(zehntel) else { return false }
        let jetzt = umgebung.uhr()
        let datum = tag ?? Datum.text(jetzt)
        daten.habits.setze(Habit.gewicht.id, datum: datum, wert: zehntel)
        umgebung.ereignisse.senden(.gewichtGespeichert(tag: datum))
        let zeit = datum == Datum.text(jetzt) ? jetzt : Datum.datum(datum).addingTimeInterval(12 * 3600)
        _ = await umgebung.healthSchreiber.speichere(gewichtKg: Double(zehntel) / 10, am: zeit)
        berechne()
        return true
    }

    /// Setzt das Gewichtsziel (kg, nil = keins), dieselbe Einstellung wie Präferenzen > Ziele.
    func setzeGewichtsziel(_ kg: Double?) {
        guard let daten = umgebung.daten else { return }
        var ziele = daten.ziele.ziele
        ziele.gewichtKg = kg
        daten.ziele.setze(ziele)
        berechne()
    }

    /// Nimmt den eigenen Gewichts-Eintrag eines Tages weg (0 = kein Eintrag). Messungen aus Health bleiben.
    func loescheGewicht(tag: String) {
        guard let daten = umgebung.daten else { return }
        daten.habits.setze(Habit.gewicht.id, datum: tag, wert: 0)
        umgebung.ereignisse.senden(.gewichtGespeichert(tag: tag))
        berechne()
    }

    /// Fragt Health an (der erste Aufruf zeigt die Rechte-Abfrage). true, wenn danach Daten da sind.
    @discardableResult
    func healthErlauben() async -> Bool {
        await lade()
        return stand?.hatGesundheit ?? false
    }

    // MARK: - Rechnen

    private func kontextFuer(_ daten: DatenSatz) -> Kontext {
        if let k = kontext, k.profil == daten.profil { return k }
        let neu = Kontext(daten: daten)
        kontext = neu
        return neu
    }

    func berechne() {
        guard let daten = umgebung.daten else {
            stand = nil
            kontext = nil
            return
        }
        let k = kontextFuer(daten)
        let jetzt = umgebung.uhr()
        let echtHeute = Datum.text(jetzt)
        // Ein gewählter Tag ersetzt "heute" überall; ein Tag, der inzwischen heute oder Zukunft ist, fällt auf heute zurück.
        let heute = gewaehlterTag.map { HeuteTagWahl.begrenze($0, heute: echtHeute) } ?? echtHeute
        let istHeute = heute == echtHeute
        let gestern = Datum.addTage(heute, -1)
        // Ein vergangener Tag ist zu Ende: Stunde 23, so rechnen Hinweise, Verlauf und Sätze mit dem ganzen Tag.
        let stunde = istHeute ? Datum.kalender.component(.hour, from: jetzt) : 23
        let tagesEnde = istHeute ? jetzt : Datum.datum(heute).addingTimeInterval(23 * 3600 + 59 * 60)
        let gesundheit = umgebung.gesundheit
        let tage = gesundheit.tage
        let ziele = daten.ziele.ziele
        let schlafZiel = SchlafZielLogik.ziel(basis: ziele.schlafMinuten, extra: SchlafZielLogik.extra(ops: daten.raum.ops(arten: [SchlafZielLogik.art])), tag: heute)
        let sessions = daten.training.sessions
        let gymHaken = daten.habits.werte(Habit.gym.id)
        let gymTage = WochenStreifenLogik.gymTage(sessions: sessions, haken: gymHaken)
        let trainiert = gymTage.contains(heute)
        let folge = EnergieLogik.inFolge(heute: heute) { gymTage.contains($0) }

        // Schlaf der Woche (je Aufwachtag): Hand, Band, Health
        let naechte = TagesformQuellen.naechte(daten: daten, gesundheit: gesundheit)
        var schlafWoche: [String: Int] = [:]
        for tag in HabitLogik.wochenTage(heute: heute) {
            if let n = naechte[tag] { schlafWoche[tag] = n.minuten }
        }
        let nacht = naechte[heute]

        // Morgen-Check von heute
        var stimmungsWert: Int?
        var stimmungsTage: Set<String> = []
        for op in daten.raum.ops(arten: ["fit.lumi.stimmung"]) {
            guard let s = op.daten(StimmungsEintrag.self) else { continue }
            stimmungsTage.insert(s.tag)
            if s.tag == heute { stimmungsWert = s.wert }
        }

        // Bereit-Score
        let ruhe = HeuteQuellen.vital(gesundheit.vitale[.ruhepuls] ?? [], heute: heute)
        let hrv = HeuteQuellen.vital(gesundheit.vitale[.hrv] ?? [], heute: heute)
        let last = HeuteQuellen.tageslast(heute: heute, tage: tage, saetze: HeuteQuellen.saetzeProTag(sessions))
        let score = BereitScore.rechnen(BereitScore.Eingabe(schlafMinuten: nacht?.minuten, schlafZiel: schlafZiel, hrv: hrv.aktuell,
                                                            hrvBasis: hrv.basis, ruhepuls: ruhe.aktuell, ruhepulsBasis: ruhe.basis, last: last))

        // Plan
        let locker = Morgensatz.schwer(stimmungsWert) || score.stufe == .schonen
        var plan = HeutePlanLogik.vorschlag(plan: daten.training.plan, heute: heute, trainiert: trainiert, locker: locker, gymInFolge: folge)
        if let id = plan.tagID, let tag = daten.training.plan.tage.first(where: { $0.id == id }) { plan.minuten = HeuteKartenLogik.minuten(tag) }
        plan.zielWort = HeuteKartenLogik.zielWort(ziele.art)

        // Bögen
        let schritteHeute = tage[heute]?.schritte ?? 0
        let gymWoche = WochenStreifenLogik.gymTageDerWoche(heute: heute, sessions: sessions, haken: gymHaken).count
        let gymZiel = max(1, ziele.gymTageProWoche)
        let schlafMin = nacht?.minuten ?? 0
        // Nur die gewählten Bereiche: ein ausgeschalteter Bogen fehlt hier, in der Ansage und in der Rechnung "alle voll".
        let bereiche = umgebung.bereicheWirksam
        var boegen: [BogenWert] = [
            BogenWert(id: .bewegen, anteil: anteil(schritteHeute, ziele.schritte), zahl: HeuteQuellen.zahl(schritteHeute),
                      beschriftung: "Schritte von \(HeuteQuellen.zahl(ziele.schritte))"),
        ]
        var boegenTexte = ["Schritte: \(HeuteQuellen.zahl(schritteHeute)) von \(HeuteQuellen.zahl(ziele.schritte))"]
        if bereiche.gymAn {
            boegen.append(BogenWert(id: .trainieren, anteil: anteil(gymWoche, gymZiel), zahl: "\(gymWoche) von \(gymZiel)", beschriftung: "Gym-Tage der Woche"))
            boegenTexte.append("Gym: \(gymWoche) von \(gymZiel) Tagen")
        }
        if bereiche.schlafAn {
            boegen.append(BogenWert(id: .erholen, anteil: anteil(schlafMin, schlafZiel), zahl: nacht == nil ? "–" : BereitScore.stunden(schlafMin),
                                    beschriftung: "Schlaf von \(BereitScore.stunden(schlafZiel))"))
            boegenTexte.append(nacht == nil ? "Schlaf: keine Daten" : "Schlaf: \(BereitScore.stunden(schlafMin)) von \(BereitScore.stunden(schlafZiel))")
        }
        let boegenSatz = boegenTexte.joined(separator: ". ") + "."
        let voll = boegen.allSatisfy { $0.anteil >= 1 }

        // Lumis Satz und Stimmung
        let satz = Morgensatz.sprich(Morgensatz.Eingabe(score: score, stimmungsWert: stimmungsWert, planName: plan.art == .training ? plan.name : nil,
                                                         ruhetag: plan.art == .ruhetag, trainiert: trainiert, alleBoegenVoll: voll, stunde: stunde))

        // Energie-Bank
        let wasserHeute = daten.habits.wert(Habit.wasser.id, heute)
        let wasserZiel = daten.habits.habitZiel(Habit.wasser.id) ?? 8
        let eingabe = TagesformQuellen.eingabe(daten: daten, gesundheit: gesundheit, tag: heute, jetzt: tagesEnde)
        let rechnung = TagesformRechnung.rechnen(eingabe)
        let schritteGestern: Int? = tage[gestern].flatMap { $0.schritte > 0 ? $0.schritte : nil }
        let energiePlan = EnergieEingabe(naechte: Array(eingabe.schlaf.prefix(3)), wasser: wasserHeute, wasserZiel: wasserZiel, stunde: stunde,
                                         schritteGestern: schritteGestern, trainingstag: plan.art == .training, ruhetag: plan.art == .ruhetag,
                                         planLeer: daten.training.plan.tage.isEmpty, gymInFolge: folge, heuteSchonGym: trainiert)
        let energie = HeuteEnergie(ergebnis: rechnung, klartext: TagesformKlartext.inhalt(eingabe, rechnung, plan: energiePlan),
                                   verlauf: energieVerlauf(daten: daten, tag: heute, stunde: stunde, jetzt: tagesEnde),
                                   gefuehl: k.gefuehl.eintrag(heute)?.gefuehl, vergleich: TagesformGefuehl.vergleich(k.gefuehl.eintraege, bis: heute))

        // Gewohnheiten
        // Gym- und Protein-Gewohnheit gehören zu ihrem Bereich und fehlen mit ihm (die Werte bleiben gespeichert).
        // Creatin ist eine "nur Heute"-Gewohnheit: sie erscheint, wenn sie unter Präferenzen > Mitzählen an ist.
        let creatin = daten.einstellungen.werte.creatinMitzaehlen ? [Habit.creatin] : []
        let habits: [HeuteHabitZeile] = (daten.habits.sichtbar + creatin).filter { ($0.id != Habit.gym.id || bereiche.gymAn) && ($0.id != Habit.protein.id || bereiche.essenAn) }.map { h in
            let wert = daten.habits.wert(h.id, heute)
            let ziel = daten.habits.habitZiel(h.id)
            let werte = daten.habits.werte(h.id)
            return HeuteHabitZeile(habit: h, wert: wert, ziel: ziel, erledigt: HabitLogik.erledigt(h, wert: wert, ziel: ziel),
                                   anteil: HabitLogik.anteil(h, wert: wert, ziel: ziel),
                                   serie: HabitLogik.serie(h, werte: werte, ziel: ziel, heute: heute),
                                   woche: HabitRaster.wochenAnteile(h, werte: werte, ziel: ziel, heute: heute), heuteIndex: Datum.wochentag(heute) - 1)
        }

        // Gewicht
        // Ein vergangener Tag zeigt das Gewicht, das damals galt, nicht das von heute.
        let gw = HeuteQuellen.gewichtWerte(health: gesundheit.gewichte, manuell: daten.habits.werte(Habit.gewicht.id)).filter { $0.key <= heute }
        let ab = Datum.addTage(heute, -89)
        let startFeld = GewichtLogik.startFeld(gw, tag: heute)
        let gewicht = HeuteGewicht(aktuellKg: GewichtLogik.berechnet(gw).map { Double($0) / 10 },
                                   aenderung: HeuteKartenLogik.aenderungZurVorwoche(gw).map(HeuteKartenLogik.vorwocheText)
                                       ?? GewichtLogik.aenderung(gw).map { GewichtText.aenderung($0.zehntel, seit: $0.seit) },
                                   zielKg: ziele.gewichtKg,
                                   punkte: MessLogik.punkte(gw).filter { $0.tag >= ab }.map { HeuteGewichtPunkt(tag: $0.tag, kg: Double($0.zehntel) / 10) },
                                   heuteEingetragen: gw[heute] != nil,
                                   startZehntel: min(max(GewichtText.zehntel(startFeld) ?? 750, HeuteQuellen.gewichtBereich.lowerBound), HeuteQuellen.gewichtBereich.upperBound))

        // Hinweise
        let schlafAlle = gesundheit.naechte.mapValues { $0.schlafMinuten }
        var regelEingabe = TagesHinweisLogik.Eingabe(heute: heute)
        regelEingabe.stunde = stunde
        regelEingabe.schlafMinuten = schlafAlle.merging(schlafWoche) { _, neu in neu }
        regelEingabe.schritte = tage.mapValues { $0.schritte }
        regelEingabe.schritteZiel = ziele.schritte
        regelEingabe.gymTage = gymTage
        regelEingabe.gymZielWoche = ziele.gymTageProWoche
        regelEingabe.gymInFolge = folge
        regelEingabe.wasserHeute = wasserHeute
        regelEingabe.wasserZiel = wasserZiel
        regelEingabe.gewichtTage = Array(gw.keys)
        let einsichten = HeuteHinweisLogik.alle(HeuteHinweisEingabe(sessions: sessions, schlafMinuten: schlafAlle, wasser: daten.habits.werte(Habit.wasser.id),
                                                                    gymTage: gymTage, stimmungTage: stimmungsTage.count, prio: MuskelGruppe.standardPrio, heute: heute))
            .filter { $0.bereich.map(bereiche.zeigt) ?? true }
        regelEingabe.bereiche = bereiche
        let hinweise = TagesHinweisLogik.zeige(TagesHinweisLogik.regeln(regelEingabe),
                                               weggewischt: k.hinweise.ids)

        let tagesWerte = tage[heute]
        let habitGesetzt = habits.contains { $0.wert > 0 }
        let gesundheitTag = tagesWerte.map { $0.schritte > 0 || $0.distanzMeter > 0 || $0.etagen > 0 } ?? false
        let hatGewicht: Bool = gw[heute] != nil
        let hatStimmung: Bool = stimmungsWert != nil
        let hatNacht: Bool = nacht != nil
        let hatTagesdaten: Bool = istHeute || hatNacht || trainiert || hatStimmung || hatGewicht || habitGesetzt || gesundheitTag
        // Lumis Zustand aus der Lage des Tages (LumiLogik); der Morgensatz bleibt, wenn er zum Zustand passt, sonst spricht Lumi den Satz des Zustands.
        // Ein ausgeschalteter Bereich (Gym, Schlaf) fließt nicht ein.
        let lumiTage: Set<String> = bereiche.gymAn ? gymTage : []
        let lumiSchlaf: Int? = bereiche.schlafAn ? nacht?.minuten : nil
        let wochenziel: Bool = bereiche.gymAn && gymWoche >= gymZiel
        let lage = lumiLage(heute: heute, stunde: stunde, sessions: sessions, gymTage: lumiTage, trainiert: trainiert && bereiche.gymAn,
                            gymWocheErreicht: wochenziel, voll: voll, schlafMinuten: lumiSchlaf, morgenCheck: stimmungsWert,
                            gefuehl: k.gefuehl.eintrag(heute)?.gefuehl, ruhetag: plan.art == .ruhetag, basis: satz.stimmung)
        let zustand: LumiStimmung = istHeute ? LumiLogik.zustand(lage) : satz.stimmung
        let stimmungAnzeige: LumiStimmung = istHeute ? zustand : (voll ? .ziel : .denkt)
        let satzAnzeige = istHeute ? (zustand == satz.stimmung ? satz.satz : zustand.satz)
                                   : (voll ? "An diesem Tag waren alle Bögen voll." : "So sah dieser Tag aus.")
        // Bei Bereit und Ruhetag spricht Lumi über den Fortschritt (größtes Plus einer Übung), sonst bleibt der Satz des Zustands.
        let fortschritt: String? = istHeute && bereiche.gymAn && (zustand == .bereit || zustand == .ruhetag)
            ? HeuteKartenLogik.fortschrittsSatz(FortschrittLogik.gewichte(sessions, plan: daten.training.plan, heute: heute), ruhetag: zustand == .ruhetag)
            : nil

        stand = HeuteStand(tag: heute, stunde: stunde, hatGesundheit: !tage.isEmpty || !gesundheit.naechte.isEmpty,
                           healthGeprueft: gesundheit.letzteAktualisierung != nil || gesundheit.zugriff == .nichtVerfuegbar, boegen: boegen, boegenSatz: boegenSatz,
                           boegenVoll: voll, stimmung: stimmungAnzeige, morgensatz: satzAnzeige, stimmungsWert: stimmungsWert, score: score, plan: plan,
                           energie: energie, habits: habits, gewicht: gewicht,
                           schritte: HeuteSchritte(schritte: schritteHeute, ziel: ziele.schritte, distanzKm: (tage[heute]?.distanzMeter ?? 0) / 1000,
                                                   etagen: tage[heute]?.etagen ?? 0),
                           hinweise: hinweise,
                           woche: WochenStreifenLogik.woche(heute: heute, schritte: tage.mapValues { $0.schritte }, schlafMinuten: schlafWoche,
                                                            gymTage: gymTage, schritteZiel: ziele.schritte, schlafZiel: ziele.schlafMinuten),
                           einsichten: einsichten, istHeute: istHeute, hatTagesdaten: hatTagesdaten, bereiche: bereiche,
                           lumiSatz: fortschritt ?? satzAnzeige,
                           planWoche: HeuteKartenLogik.planWoche(heute: heute, plan: daten.training.plan, gymTage: gymTage),
                           serieWochen: MeilensteinPruefung.serieWochen(tage: gymTage, heute: heute),
                           einheitHeute: trainiert ? GymTageLogik.einheit(am: heute, in: sessions)?.id : nil)
    }

    /// Die Lage für `LumiLogik`: Rekord, Dauer und Anstrengung (RPE) nur aus den Einheiten von heute; der Rekord wird nur gesucht, wenn heute trainiert wurde.
    private func lumiLage(heute: String, stunde: Int, sessions: [GymSession], gymTage: Set<String>, trainiert: Bool, gymWocheErreicht: Bool, voll: Bool,
                          schlafMinuten: Int?, morgenCheck: Int?, gefuehl: Int?, ruhetag: Bool, basis: LumiStimmung) -> LumiLage {
        var lage = LumiLage(heute: heute, stunde: stunde, trainingsTage: gymTage)
        let heutige = sessions.filter { ($0.tag ?? Datum.text($0.start)) == heute }
        if trainiert, !heutige.isEmpty {
            let frueher = sessions.filter { ($0.tag ?? Datum.text($0.start)) != heute }
            lage.rekordHeute = MeilensteinPruefung.rekorde(sessions) > MeilensteinPruefung.rekorde(frueher)
            lage.minutenHeute = Int(heutige.compactMap { $0.ende?.timeIntervalSince($0.start) }.reduce(0, +) / 60)
            let rpe = heutige.flatMap(\.laeufe).flatMap { $0.saetze ?? [] }.compactMap(\.rpe)
            lage.rpeSchnittHeute = rpe.isEmpty ? nil : rpe.reduce(0, +) / Double(rpe.count)
        }
        lage.gefuehlHeute = gefuehl
        lage.serieWochen = MeilensteinPruefung.serieWochen(tage: gymTage, heute: heute)
        lage.wochenzielErreicht = gymWocheErreicht
        lage.boegenVoll = voll
        lage.schlafMinuten = schlafMinuten
        lage.morgenCheck = morgenCheck
        lage.ruhetag = ruhetag
        lage.basis = basis
        return lage
    }

    private func anteil(_ ist: Int, _ ziel: Int) -> Double { ziel > 0 ? min(1, max(0, Double(ist) / Double(ziel))) : 0 }

    /// Die Zahl der Energie-Bank zu den Stunden bis jetzt: alle drei Stunden ab 6 Uhr, dazu jetzt. Jede Stunde rechnet mit dem, was damals schon bekannt war.
    private func energieVerlauf(daten: DatenSatz, tag: String, stunde: Int, jetzt: Date) -> [HeuteEnergiePunkt] {
        var stunden = Array(stride(from: 6, through: stunde, by: 3))
        if stunden.last != stunde { stunden.append(stunde) }
        var punkte: [HeuteEnergiePunkt] = []
        for h in stunden where h >= 6 && h <= stunde {
            let zeit: Date = h == stunde ? jetzt : (Datum.kalender.date(bySettingHour: h, minute: 0, second: 0, of: Datum.datum(tag)) ?? jetzt)
            let e = TagesformQuellen.eingabe(daten: daten, gesundheit: umgebung.gesundheit, tag: tag, jetzt: zeit)
            if let akku = TagesformRechnung.rechnen(e).akku { punkte.append(HeuteEnergiePunkt(stunde: h, akku: akku)) }
        }
        return punkte
    }
}
