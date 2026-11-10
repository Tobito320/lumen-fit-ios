// Quelle: Lovea Health/GymNeu/WochenAbweichung.swift
import Foundation

/// Abweichung vom festen Plan für genau eine Kalenderwoche (Mo bis So). Schlüssel ist der Montag
/// (`Datum.montagDerWoche`, deutscher Kalender). Sie liegt im `TrainingsPlan` (`wochen`) und geht mit
/// `gym.plan` zum Partner. Eine Woche später gilt der feste Plan von selbst wieder, nichts muss
/// gelöscht werden; alte Einträge räumt `WochenLogik.aufraeumen` beim nächsten Schreiben weg.
struct WochenAbweichung: Codable, Equatable, Sendable {
    /// Verlegt: der Tag, der an `wochentag` (1 = Mo … 7 = So) trainiert wird; nil = frei.
    struct Platz: Codable, Equatable, Sendable {
        var wochentag: Int
        var tag: String?
    }

    /// Testwoche: die Einheiten eines anderen Splits mit festen Wochentagen ab `ab` (1 = Mo … 7 = So).
    /// Davor gilt noch der feste Plan. Die `tage` tragen frische ids, der feste Plan bleibt unberührt.
    struct Test: Codable, Equatable, Sendable {
        var split: String
        var ab: Int
        var tage: [TrainingsTag]
    }

    var montag: String
    var plaetze: [Platz] = []
    var test: Test? = nil
}

extension TrainingsPlan {
    /// Der Tag mit dieser id: im festen Plan, sonst unter den Einheiten einer Testwoche. So behält eine
    /// Einheit der Testwoche auch danach ihren Namen und ihre Übungen.
    func tag(id: String?) -> TrainingsTag? {
        guard let id else { return nil }
        if let t = tage.first(where: { $0.id == id }) { return t }
        for woche in wochen ?? [] {
            if let t = woche.test?.tage.first(where: { $0.id == id }) { return t }
        }
        return nil
    }
}

/// Verlegen und Testwoche. Alles ist reine Rechnung auf dem Plan: nichts läuft im Hintergrund, die
/// Woche wechselt von allein, weil der Schlüssel der Montag des Datums ist.
enum WochenLogik {
    /// So viele Wochen bleiben Einträge stehen (Testeinheiten geben alten Einheiten im Verlauf ihren Namen).
    static let behalteWochen = 8

    /// Ein Tag, auf den verlegt werden kann: `datum` und der Text im Menü.
    struct Ziel: Equatable, Sendable {
        var datum: String
        var text: String
    }

    // MARK: - Lesen

    static func abweichung(_ plan: TrainingsPlan, woche tag: String) -> WochenAbweichung? {
        guard let wochen = plan.wochen, !wochen.isEmpty else { return nil }
        let montag = Datum.montagDerWoche(tag)
        return wochen.first { $0.montag == montag }
    }

    /// Der Plan, wie er in der Woche von `tag` gilt: der feste Plan, darauf die Testwoche, darauf das
    /// Verlegte. Die eine Stelle, über die alle lesen (`TrainingLogik.tag`, Wochenleiste, Plantag-Karte).
    /// Ohne Abweichung kommt der feste Plan unverändert zurück, sonst ohne `wochen`.
    static func effektiverPlan(_ plan: TrainingsPlan, woche tag: String) -> TrainingsPlan {
        guard let a = abweichung(plan, woche: tag) else { return plan }
        var p = plan
        if let test = a.test { p = mitTest(p, test) }
        for platz in a.plaetze { p = mitPlatz(p, platz) }
        p.wochen = nil
        return p
    }

    /// Ab `test.ab` gelten die Test-Einheiten; feste Tage ohne Wochentag danach fallen weg, Tage, die von
    /// vornherein keinen hatten (flexibel), bleiben. Freie Tage ab `ab` sind Ruhetage.
    private static func mitTest(_ plan: TrainingsPlan, _ test: WochenAbweichung.Test) -> TrainingsPlan {
        guard (1...7).contains(test.ab) else { return plan }
        var p = plan
        for i in p.tage.indices { p.tage[i].wochentage.removeAll { $0 >= test.ab } }
        let hattenTage = Set(plan.tage.filter { !$0.wochentage.isEmpty }.map(\.id))
        p.tage.removeAll { $0.wochentage.isEmpty && hattenTage.contains($0.id) }
        p.tage += test.tage
        let belegt = Set(p.tage.flatMap(\.wochentage))
        let ruhe = plan.ruhetage ?? []
        p.ruhetage = (1...7).filter { !belegt.contains($0) && ($0 >= test.ab || ruhe.contains($0)) }
        return p
    }

    /// Setzt den Tag `platz.tag` auf den Wochentag (und nimmt ihn jedem anderen Tag weg), bei nil wird der
    /// Wochentag frei. Gibt es den Tag nicht mehr (Plan inzwischen geändert), bleibt der Plan, wie er ist.
    private static func mitPlatz(_ plan: TrainingsPlan, _ platz: WochenAbweichung.Platz) -> TrainingsPlan {
        let w = platz.wochentag
        let ziel = platz.tag.flatMap { id in plan.tage.firstIndex { $0.id == id } }
        if platz.tag != nil, ziel == nil { return plan }
        var p = plan
        for i in p.tage.indices { p.tage[i].wochentage.removeAll { $0 == w } }
        if let ziel {
            p.tage[ziel].wochentage = (p.tage[ziel].wochentage + [w]).sorted()
            p.ruhetage = p.ruhetage?.filter { $0 != w }
        } else {
            p.ruhetage = Set((p.ruhetage ?? []) + [w]).sorted()
        }
        return p
    }

    /// Tage zur Auswahl beim Anlegen einer Einheit: die des festen Plans und die der laufenden Testwoche.
    static func waehlbar(_ plan: TrainingsPlan, heute: String) -> [TrainingsTag] {
        plan.tage + (abweichung(plan, woche: heute)?.test?.tage ?? [])
    }

    /// "Testwoche: Push Pull Legs, ab Montag wieder Upper Lower", solange die laufende Woche getestet wird.
    static func testHinweis(_ plan: TrainingsPlan, heute: String) -> String? {
        guard let test = abweichung(plan, woche: heute)?.test else { return nil }
        return String(localized: "Testwoche: \(test.split), ab Montag wieder \(plan.splitName ?? String(localized: "dein Plan"))")
    }

    /// True, wenn in der laufenden Woche Tage verlegt sind.
    static func verlegt(_ plan: TrainingsPlan, heute: String) -> Bool {
        abweichung(plan, woche: heute)?.plaetze.isEmpty == false
    }

    // MARK: - Verlegen

    /// Wohin der Tag von `datum` diese Woche gehen kann ("Donnerstag · frei", "Freitag · tauscht mit Pull"):
    /// nur Tage ab `heute` derselben Woche, nur für einen Trainingstag ohne Einheit (`gemacht` = Tage mit
    /// Einheit). Ein verpasster Tag (vor `heute`) geht nur auf einen freien Tag, nie in die Vergangenheit.
    static func verlegeZiele(_ plan: TrainingsPlan, von datum: String, heute: String, gemacht: Set<String> = []) -> [Ziel] {
        let montag = Datum.montagDerWoche(heute)
        guard !gemacht.contains(datum), Datum.montagDerWoche(datum) == montag else { return [] }
        let jetzt = effektiverPlan(plan, woche: heute)
        guard let tag = TrainingLogik.tag(jetzt, datum: datum) else { return [] }
        return (0..<7).compactMap { i -> Ziel? in
            let ziel = Datum.addTage(montag, i)
            guard ziel >= heute, ziel != datum, !gemacht.contains(ziel) else { return nil }
            let dort = TrainingLogik.tag(jetzt, datum: ziel)
            guard dort?.id != tag.id, dort == nil || datum >= heute else { return nil }
            let name = TrainingLogik.wochentagName[i]
            guard let dort else { return Ziel(datum: ziel, text: String(localized: "\(name) · frei")) }
            return Ziel(datum: ziel, text: String(localized: "\(name) · tauscht mit \(dort.name.isEmpty ? String(localized: "Training") : dort.name)"))
        }
    }

    /// Verlegt den Tag von `von` auf `auf`; liegt dort schon ein Tag, tauschen beide. Nur diese Woche: der
    /// Eintrag hängt am Montag, ab nächster Woche gilt der feste Plan. nil, wenn es nicht erlaubt ist.
    static func verlegen(_ plan: TrainingsPlan, von: String, auf: String, heute: String, gemacht: Set<String> = []) -> TrainingsPlan? {
        guard verlegeZiele(plan, von: von, heute: heute, gemacht: gemacht).contains(where: { $0.datum == auf }) else { return nil }
        let jetzt = effektiverPlan(plan, woche: heute)
        guard let tagVon = TrainingLogik.tag(jetzt, datum: von) else { return nil }
        let neu = [WochenAbweichung.Platz(wochentag: Datum.wochentag(von), tag: TrainingLogik.tag(jetzt, datum: auf)?.id),
                   WochenAbweichung.Platz(wochentag: Datum.wochentag(auf), tag: tagVon.id)]
        return schreiben(plan, heute: heute) { a in
            a.plaetze.removeAll { alt in neu.contains { $0.wochentag == alt.wochentag } }
            a.plaetze += neu
        }
    }

    /// "Zurück auf Plan": die verlegten Tage der laufenden Woche gelten wieder wie im festen Plan.
    static func verlegungenLoeschen(_ plan: TrainingsPlan, heute: String) -> TrainingsPlan {
        schreiben(plan, heute: heute) { $0.plaetze = [] }
    }

    // MARK: - Testwoche

    /// Welche Einheit des Splits auf welchen Wochentag fällt. Die Einheiten stehen in der Reihenfolge ihrer
    /// Wochentage im Split, sie kommen der Reihe nach auf die Trainingstage des festen Plans ab `ab`. Zu viele
    /// Einheiten fallen weg, fehlende Einheiten machen den Tag zum Ruhetag. Hat der feste Plan ab `ab` keinen
    /// Trainingstag, gelten die Wochentage des Splits ab `ab`, sonst alle Tage bis Sonntag.
    static func zuordnung(_ plan: TrainingsPlan, vorlage v: SplitVorlage, ab: Int) -> [(einheit: Int, wochentag: Int)] {
        var folge: [(einheit: Int, wochentag: Int)] = []
        for (i, e) in v.einheiten.enumerated() {
            for w in e.wochentage { folge.append((einheit: i, wochentag: w)) }
        }
        folge.sort { ($0.wochentag, $0.einheit) < ($1.wochentag, $1.einheit) }
        var tage = Set(plan.tage.flatMap(\.wochentage)).filter { $0 >= ab }.sorted()
        if tage.isEmpty { tage = Set(v.einheiten.flatMap(\.wochentage)).filter { $0 >= ab }.sorted() }
        if tage.isEmpty { tage = Array(ab...7) }
        return zip(folge, tage).map { paar in (einheit: paar.0.einheit, wochentag: paar.1) }
    }

    /// Das Split `v` für den Rest der laufenden Woche (ab heute, ist heute schon trainiert, ab morgen).
    /// Der feste Plan und sein Split bleiben, verlegte Tage der Woche gehen verloren. nil, wenn in dieser
    /// Woche kein Tag mehr übrig ist.
    static func testStarten(_ plan: TrainingsPlan, vorlage v: SplitVorlage, heute: String, gemacht: Set<String> = [],
                            neueId: () -> String = { UUID().uuidString }) -> TrainingsPlan? {
        let ab = Datum.wochentag(heute) + (gemacht.contains(heute) ? 1 : 0)
        guard (1...7).contains(ab) else { return nil }
        var tage = SplitLogik.alsPlan(v, neueId: neueId).tage
        for i in tage.indices { tage[i].wochentage = [] }
        for z in zuordnung(plan, vorlage: v, ab: ab) { tage[z.einheit].wochentage.append(z.wochentag) }
        tage = tage.filter { !$0.wochentage.isEmpty }
        guard !tage.isEmpty else { return nil }
        let montag = Datum.montagDerWoche(heute)
        let test = WochenAbweichung.Test(split: v.name, ab: ab, tage: tage)
        return schreiben(plan, heute: heute) { a in a = WochenAbweichung(montag: montag, test: test) }
    }

    /// Testwoche abbrechen: die laufende Woche gilt wieder ganz wie im festen Plan, auch verlegte Tage.
    static func testAbbrechen(_ plan: TrainingsPlan, heute: String) -> TrainingsPlan {
        schreiben(plan, heute: heute) { a in
            a.plaetze = []
            a.test = nil
        }
    }

    // MARK: - Schreiben

    /// Ein Tag der Testwoche, der im Training geändert wurde ("Plan aktualisieren"), ersetzt nur seine
    /// Test-Einheit und nie den festen Plan. nil, wenn `tag` keine Test-Einheit ist.
    static func testTagErsetzen(_ plan: TrainingsPlan, _ tag: TrainingsTag) -> TrainingsPlan? {
        guard !plan.tage.contains(where: { $0.id == tag.id }), var wochen = plan.wochen else { return nil }
        var gefunden = false
        for w in wochen.indices {
            guard var test = wochen[w].test, let i = test.tage.firstIndex(where: { $0.id == tag.id }) else { continue }
            let wochentage = test.tage[i].wochentage
            test.tage[i] = tag
            test.tage[i].wochentage = wochentage
            wochen[w].test = test
            gefunden = true
        }
        guard gefunden else { return nil }
        var p = plan
        p.wochen = wochen
        return p
    }

    /// Der Eintrag der laufenden Woche, von `f` geändert; leere und alte Einträge fallen dabei weg.
    private static func schreiben(_ plan: TrainingsPlan, heute: String, _ f: (inout WochenAbweichung) -> Void) -> TrainingsPlan {
        let montag = Datum.montagDerWoche(heute)
        var a = (plan.wochen ?? []).first { $0.montag == montag } ?? WochenAbweichung(montag: montag)
        f(&a)
        var wochen = (plan.wochen ?? []).filter { $0.montag != montag }
        wochen.append(a)
        var p = plan
        p.wochen = aufraeumen(wochen, heute: heute)
        return p
    }

    /// Ohne leere Einträge und ohne die, die älter als `behalteWochen` Wochen sind; nil, wenn nichts bleibt.
    static func aufraeumen(_ wochen: [WochenAbweichung], heute: String) -> [WochenAbweichung]? {
        let grenze = Datum.addTage(Datum.montagDerWoche(heute), -7 * behalteWochen)
        let rest = wochen.filter { $0.montag >= grenze && ($0.test != nil || !$0.plaetze.isEmpty) }
        return rest.isEmpty ? nil : rest
    }
}
