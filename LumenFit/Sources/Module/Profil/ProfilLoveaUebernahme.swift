import Foundation

/// Zahlen einer Gruppe von Dingen, die nicht als eigene Op-Art aus Lovea kommen (`abgabe.*` aus Loveas Abgabe, `coach.*`, Vorräte, Wecker).
/// Eine Einheit ist ein Schlüssel (bei `abgabe.tagesform.gefuehl.<tag>` ein Tag, bei Ops ohne Schlüssel die Op). Von mehreren Ops derselben Einheit
/// zählt die neueste, die älteren stehen unter `aelter`. Nur Zahlen, nie Inhalte.
struct ProfilLoveaUebernahmeBeleg: Codable, Equatable, Sendable {
    /// Ops dieser Gruppe in Lovea (bis `seqMax`).
    var geholt = 0
    var aelter = 0
    /// Einheiten, von denen mindestens ein Eintrag in einem Speicher von Lumen Fit steht (sichtbar).
    var uebernommen = 0
    /// Einheiten, bei denen lokal schon alles da war: nichts überschrieben (Neueres bleibt).
    var vorhanden = 0
    /// Einheiten, die nur im Log liegen, weil Lumen Fit dafür keine Ansicht hat (bewusst, nicht verloren).
    var roh = 0
    /// Einheiten, deren Inhalt nicht gelesen oder nicht geschrieben werden konnte: der Beleg ist dann unvollständig.
    var unlesbar = 0
    /// Einträge in den Einheiten (zum Beispiel Geräte mit Einstellung) und davon geschriebene.
    var eintraege = 0
    var geschrieben = 0

    var stimmt: Bool { unlesbar == 0 && geholt == aelter + uebernommen + vorhanden + roh && geschrieben <= eintraege }
}

/// Was aus Loveas Abgabe (PR "Abgabe": `einstellung.setzen` mit Schlüssel `abgabe.*`) und den Arten ohne Leser in Lumen Fit wird.
/// Sichtbar: Studio-Profil, Geräte-Einstellung, Defekt-Notizen, Tagesform-Gefühl, Band-Regeln, Coach-Verlauf. Roh im Log: Wecker, Erinnerungen
/// (Zuhause ist Lumen Alarm, Lumen Fit ist nur Health), Band-Tage und -Nächte, Coach-Schalter (Datei im Speicher gehalten), Einkaufsliste, Kühlschrank.
/// Lumen Fit überschreibt nie, was lokal schon steht.
enum ProfilLoveaUebernahme {
    static let abgabePraefix = "abgabe."
    static let gefuehlPraefix = "abgabe.tagesform.gefuehl."
    /// Arten, die als Einheit je Op gezählt werden.
    static let opArten: Set<String> = ["coach.nachricht", "wecker.setzen", "einkauf.liste", "kuehl.setzen", "kuehl.weg"]

    /// Lovea-Schlüssel der Band-Regeln → UserDefaults-Schlüssel in Lumen Fit. Nicht dabei: Gerätename (die Kopplung ist hier neu) und Coach-Lesen.
    static let bandSchluessel: [String: String] = [
        "lovea.tracker.band.akku.schwelle": "fit.band.akku.schwelle",
        "lovea.tracker.band.ruhe.nacht": "fit.band.ruhe.nacht",
        "lovea.tracker.band.ruhe.fenster": "fit.band.ruhe.fenster",
        "lovea.tracker.band.ruhe.ausnahme": "fit.band.ruhe.ausnahme",
        "lovea.tracker.band.sitzen.von": "fit.band.sitzen.von",
        "lovea.tracker.band.sitzen.bis": "fit.band.sitzen.bis",
        "lovea.tracker.band.gymPuls.ziel": "fit.band.gymPuls.ziel",
        "lovea.tracker.schritte": "fit.band.schritte",
        "lovea.tracker.akkuwarnung": "fit.band.akkuwarnung",
        "lovea.tracker.modus": "fit.band.modus",
    ]

    struct Einheit {
        var gruppe: String
        var schluessel: String
    }

    /// Gruppe und Einheit einer Op; nil, wenn sie hier nichts angeht (alles andere regeln `ProfilLoveaArten` und die Falter).
    static func einordnen(_ op: Op) -> Einheit? {
        if opArten.contains(op.art) { return Einheit(gruppe: op.art, schluessel: op.id) }
        guard op.art == "einstellung.setzen", let k = ProfilLoveaArten.einstellungSchluessel(op.d) else { return nil }
        if k.hasPrefix(gefuehlPraefix) { return Einheit(gruppe: "abgabe.tagesform.gefuehl", schluessel: k) }
        if k.hasPrefix(abgabePraefix) { return Einheit(gruppe: ProfilLoveaBeleg.gueltigeArt(k) ? k : "abgabe.andere", schluessel: k) }
        if k.hasPrefix("coach.") { return Einheit(gruppe: "einstellung.coach", schluessel: k) }
        return nil
    }

    private struct EinstellungD: Decodable {
        var schluessel: String?
        var wert: JSONValue?
    }

    private static func wert(_ op: Op) -> JSONValue? { (try? JSONDecoder().decode(EinstellungD.self, from: op.d))?.wert }

    /// Von jeder Einheit die neueste Op (Zeit, bei Gleichstand die größere Kennung), dazu die Zahl der älteren je Gruppe.
    static func neuesteJeEinheit(_ ops: [Op]) -> (neueste: [(Einheit, Op)], beleg: [String: ProfilLoveaUebernahmeBeleg]) {
        var beste: [String: (Einheit, Op)] = [:]
        var beleg: [String: ProfilLoveaUebernahmeBeleg] = [:]
        for op in ops {
            guard let e = einordnen(op) else { continue }
            beleg[e.gruppe, default: .init()].geholt += 1
            let schluessel = e.gruppe + "\u{1}" + e.schluessel
            if let alt = beste[schluessel] {
                beleg[e.gruppe, default: .init()].aelter += 1
                if (op.zeit, op.id) > (alt.1.zeit, alt.1.id) { beste[schluessel] = (e, op) }
            } else {
                beste[schluessel] = (e, op)
            }
        }
        return (beste.values.sorted { ($0.0.gruppe, $0.0.schluessel) < ($1.0.gruppe, $1.0.schluessel) }, beleg)
    }

    // MARK: - Anwenden

    @MainActor
    static func uebernehme(_ ops: [Op], in daten: DatenSatz, defaults: UserDefaults = .standard) -> [String: ProfilLoveaUebernahmeBeleg] {
        let (neueste, start) = neuesteJeEinheit(ops)
        var beleg = start
        var gefuehl: [(Einheit, Op)] = []
        for (e, op) in neueste {
            if e.gruppe == "abgabe.tagesform.gefuehl" { gefuehl.append((e, op)); continue }
            let r = einzeln(e, op, daten: daten, defaults: defaults)
            vermerke(r, in: &beleg[e.gruppe, default: .init()])
        }
        if !gefuehl.isEmpty {
            var g = beleg["abgabe.tagesform.gefuehl", default: .init()]
            gefuehlUebernehmen(gefuehl.map { $0.1 }, ordner: daten.ordner, in: &g)
            beleg["abgabe.tagesform.gefuehl"] = g
        }
        return beleg
    }

    /// Ergebnis einer Einheit: wie viele Einträge sie hat, wie viele davon geschrieben wurden, ob es einen Leser gibt, ob etwas schiefging.
    struct Einzel {
        var eintraege = 0
        var geschrieben = 0
        var hatLeser = true
        var kaputt = false
    }

    private static func vermerke(_ r: Einzel, in b: inout ProfilLoveaUebernahmeBeleg) {
        b.eintraege += r.eintraege
        b.geschrieben += r.geschrieben
        if r.kaputt { b.unlesbar += 1 } else if !r.hatLeser { b.roh += 1 } else if r.geschrieben > 0 { b.uebernommen += 1 } else { b.vorhanden += 1 }
    }

    @MainActor
    private static func einzeln(_ e: Einheit, _ op: Op, daten: DatenSatz, defaults: UserDefaults) -> Einzel {
        switch e.gruppe {
        case "coach.nachricht": return coachNachricht(op, daten: daten)
        case "abgabe.lovea.gym.studioprofil": return studio(wert(op), ordner: daten.ordner)
        case "abgabe.lovea.gym.einstellungen": return geraete(wert(op), ordner: daten.ordner)
        case "abgabe.lovea.gym.defekt": return defekt(wert(op), ordner: daten.ordner)
        case "abgabe.einstellungen": return band(wert(op), defaults: defaults)
        default:
            // Wecker, Erinnerungen, Band-Tage und -Nächte, Coach-Schalter, Einkaufsliste, Kühlschrank: bleiben unverändert im Log.
            return Einzel(eintraege: zaehle(wert(op)), geschrieben: 0, hatLeser: false, kaputt: false)
        }
    }

    private static func zaehle(_ w: JSONValue?) -> Int {
        switch w {
        case .object(let o)?: return o.count
        case .array(let a)?: return a.count
        case nil, .null?: return 0
        default: return 1
        }
    }

    /// JSON → Swift-Typ über die Bytes, damit die tolerante Dekodierung der Lumen-Typen greift.
    private static func dekodiere<T: Decodable>(_ w: JSONValue?, _ typ: T.Type) -> T? {
        guard let w, let bytes = try? JSONEncoder().encode(w) else { return nil }
        return try? JSONDecoder().decode(T.self, from: bytes)
    }

    private struct Huelle<T: Decodable>: Decodable {
        var eintraege: [String: T]
        var studios: [String: String]
    }

    // MARK: Studio-Profil

    private struct LoveaStudio: Decodable {
        var studio: String?
        var slotStart: Int?
        var dauer: Int?
    }

    /// Nur wenn lokal noch kein Studio gewählt ist. Die Op enthält nur die Einträge der Person, der sie gehört.
    static func studio(_ w: JSONValue?, ordner: URL) -> Einzel {
        guard let h = dekodiere(w, Huelle<LoveaStudio>.self), let alt = h.eintraege.values.first else { return Einzel(kaputt: true) }
        guard let kennung = alt.studio, let name = h.studios[kennung], !name.isEmpty else { return Einzel(eintraege: 1, kaputt: true) }
        let datei = JSONDatei<StudioProfil>(ordner.appendingPathComponent("studio.json"))
        if let lokal = datei.lade(), lokal.hatStudio { return Einzel(eintraege: 1) }
        let ok = datei.speichere(StudioProfil(name: name, slotStart: alt.slotStart, dauer: alt.dauer ?? 45))
        return Einzel(eintraege: 1, geschrieben: ok ? 1 : 0, kaputt: !ok)
    }

    // MARK: Geräte-Einstellung und Defekt

    private struct LoveaGeraet: Decodable {
        var bankstufe: Int?
        var sitzhoehe: Int?
        var polster: Int?
        var notiz: String?
    }

    /// "person|studio|übung" → (Studio-Name, Übung). Der mittlere Teil ist die Studio-Kennung, bei Defekt mit Vorsatz `studio.`.
    static func teile(_ schluessel: String, studios: [String: String]) -> (studio: String, uebung: String)? {
        let t = schluessel.components(separatedBy: "|")
        guard t.count >= 3 else { return nil }
        let kennung = t[1].hasPrefix("studio.") ? String(t[1].dropFirst("studio.".count)) : t[1]
        guard let name = studios[kennung], !name.isEmpty else { return nil }
        return (name, t.dropFirst(2).joined(separator: "|"))
    }

    static func geraete(_ w: JSONValue?, ordner: URL) -> Einzel {
        guard let h = dekodiere(w, Huelle<LoveaGeraet>.self) else { return Einzel(kaputt: true) }
        let datei = GeraeteEinstellungDatei.datei(ordner)
        var stand = datei.lade() ?? GeraeteEinstellungDatei()
        var r = Einzel()
        for (schluessel, g) in h.eintraege.sorted(by: { $0.key < $1.key }) {
            r.eintraege += 1
            guard let t = teile(schluessel, studios: h.studios) else { r.kaputt = true; continue }
            let neu = GeraeteWerte(stufe: g.bankstufe.map(String.init), sitz: g.sitzhoehe.map(String.init), polster: g.polster.map(String.init), notiz: g.notiz).bereinigt
            let k = DefektLogik.schluessel(studio: t.studio, uebung: t.uebung)
            if neu.istLeer || stand.eintraege[k] != nil { continue }
            stand.eintraege[k] = neu
            r.geschrieben += 1
        }
        if r.geschrieben > 0, !datei.speichere(stand) { r.kaputt = true }
        return r
    }

    static func defekt(_ w: JSONValue?, ordner: URL) -> Einzel {
        guard let h = dekodiere(w, Huelle<DefektNotiz>.self) else { return Einzel(kaputt: true) }
        let datei = JSONDatei<[String: DefektNotiz]>(ordner.appendingPathComponent("defekte.json"))
        var stand = datei.lade() ?? [:]
        var r = Einzel()
        for (schluessel, n) in h.eintraege.sorted(by: { $0.key < $1.key }) {
            r.eintraege += 1
            guard let t = teile(schluessel, studios: h.studios) else { r.kaputt = true; continue }
            let k = DefektLogik.schluessel(studio: t.studio, uebung: t.uebung)
            if stand[k] != nil { continue }
            stand[k] = n
            r.geschrieben += 1
        }
        if r.geschrieben > 0, !datei.speichere(stand) { r.kaputt = true }
        return r
    }

    // MARK: Tagesform-Gefühl (eine Op je Tag)

    /// Fehlende Tage kommen dazu, vorhandene bleiben. Nach dem Schreiben wird nachgelesen: was nicht in der Datei steht, zählt als nicht übernommen.
    static func gefuehlUebernehmen(_ ops: [Op], ordner: URL, in b: inout ProfilLoveaUebernahmeBeleg) {
        let datei = ordner.appendingPathComponent(TagesformGefuehl.dateiname)
        var liste = TagesformGefuehl.laden(datei)
        var neu: [String] = []
        for op in ops {
            b.eintraege += 1
            guard let eintrag = dekodiere(wert(op), TagesformEintrag.self) else { b.unlesbar += 1; continue }
            if liste.contains(where: { $0.tag == eintrag.tag }) { b.vorhanden += 1; continue }
            liste = TagesformGefuehl.einsetzen(liste, eintrag)
            neu.append(eintrag.tag)
        }
        guard !neu.isEmpty else { return }
        TagesformGefuehl.speichern(liste, in: datei)
        let danach = Set(TagesformGefuehl.laden(datei).map(\.tag))
        for tag in neu { if danach.contains(tag) { b.uebernommen += 1; b.geschrieben += 1 } else { b.unlesbar += 1 } }
    }

    // MARK: Band-Regeln

    /// Setzt nur, was in Lumen Fit noch nicht gewählt wurde (`object(forKey:)` ist nil).
    static func band(_ w: JSONValue?, defaults: UserDefaults) -> Einzel {
        guard case .object(let o)? = w else { return Einzel(kaputt: true) }
        var r = Einzel(eintraege: o.count)
        var gemappt = 0
        for (schluessel, wert) in o {
            guard let ziel = bandSchluessel[schluessel] else { continue }
            gemappt += 1
            guard defaults.object(forKey: ziel) == nil else { continue }
            switch wert {
            case .bool(let b): defaults.set(b, forKey: ziel)
            case .string(let s): defaults.set(s, forKey: ziel)
            case .number(let n): if n == n.rounded(), abs(n) < 1e9 { defaults.set(Int(n), forKey: ziel) } else { defaults.set(n, forKey: ziel) }
            default: continue
            }
            r.geschrieben += 1
        }
        // Ohne eine einzige Band-Regel in der Abgabe gibt es nichts zu zeigen: die Gruppe bleibt roh.
        r.hatLeser = gemappt > 0
        return r
    }

    // MARK: Coach-Verlauf

    private struct LoveaCoachNachricht: Decodable {
        var rolle: String?
        var text: String?
    }

    /// Wird zur Lumen-Op `fit.coach.nachricht` mit fester Kennung (ein zweiter Lauf legt nichts doppelt an).
    @MainActor
    static func coachNachricht(_ op: Op, daten: DatenSatz) -> Einzel {
        guard let d = try? JSONDecoder().decode(LoveaCoachNachricht.self, from: op.d),
              let text = d.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return Einzel(eintraege: 1, kaputt: true) }
        let id = "lovea-" + op.id
        guard !daten.raum.ops(arten: [CoachStore.nachrichtArt]).contains(where: { $0.id == id }) else { return Einzel(eintraege: 1) }
        let n = CoachNachricht(id: id, rolle: d.rolle == "du" ? .nutzer : .coach, text: text, zeit: op.zeit, chips: [], daumen: nil)
        daten.raum.einreihen(Op(id: id, art: CoachStore.nachrichtArt, von: daten.profil, zeit: op.zeit, d: Op.neu(CoachStore.nachrichtArt, n, von: daten.profil, zeit: op.zeit).d))
        let da = daten.raum.ops(arten: [CoachStore.nachrichtArt]).contains { $0.id == id }
        return Einzel(eintraege: 1, geschrieben: da ? 1 : 0, kaputt: !da)
    }
}
