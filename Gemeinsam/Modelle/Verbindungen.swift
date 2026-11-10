import Foundation

/// Die Bereiche, die eine Verbindung einzeln zeigen kann: die zehn Freigaben. Die Namen sind die des Servers.
/// Ein unbekannter Name vom Server (auch ein alter) ist hier kein Bereich und fällt beim Lesen weg (`init(rawValue:)` liefert nil).
enum VerbindungBereich: String, CaseIterable, Sendable {
    case schritte, gym, schlaf, essen, plan, verlauf, tagebuch, koerper, stimmung, gewohnheiten

    var freigabe: FreigabeArt? { FreigabeArt(rawValue: rawValue) }

    var name: String {
        switch self {
        case .schritte: "Schritte"
        case .gym: "Gym"
        case .schlaf: "Schlaf"
        case .essen: "Essen"
        case .plan: "Trainingsplan"
        case .verlauf: "Training und Verlauf"
        case .tagebuch: "Tagebuch"
        case .koerper: "Körperwerte"
        case .stimmung: "Stimmung"
        case .gewohnheiten: "Gewohnheiten"
        }
    }

    var symbol: String {
        switch self {
        case .schritte: "figure.walk"
        case .gym: "dumbbell.fill"
        case .schlaf: "bed.double.fill"
        case .essen: "fork.knife"
        case .plan: "calendar"
        case .verlauf: "figure.strengthtraining.traditional"
        case .tagebuch: "book.closed"
        case .koerper: "scalemass"
        case .stimmung: "face.smiling"
        case .gewohnheiten: "checkmark.circle"
        }
    }

    var erklaerung: String {
        freigabe.map { Self.text($0) } ?? ""
    }

    private static func text(_ art: FreigabeArt) -> String {
        switch art {
        case .schritte: "Schritte heute und an jedem Tag dieser Woche."
        case .gym: "An wie vielen Tagen du diese Woche trainiert hast, ob du im Gym bist und wenn du einen Rekord schaffst."
        case .schlaf: "Wie lange du diese Woche geschlafen hast, deine Energie heute und wenn du gut geschlafen hast."
        case .essen: "Nur deine Kalorien von heute und ob du dein Wasserziel erreicht hast."
        case .plan: "Name deines Plans, Trainingstage und Namen der Übungen. Keine Gewichte."
        case .verlauf: "Ob du im Gym bist und deine letzten zehn Trainings. Zusammen mit Gym auch Sätze und Gewichte."
        case .tagebuch: "Was du in den letzten sieben Tagen gegessen hast: Namen, Kalorien, Makros. Keine Fotos."
        case .koerper: "Gewicht und Körpermaße mit dem Verlauf der letzten Monate."
        case .stimmung: "Deine Antwort auf den Morgen-Check von heute."
        case .gewohnheiten: "Alle Gewohnheiten mit Serie, Quote der letzten 30 Tage und ob sie heute erledigt sind."
        }
    }
}

/// Die Einstellungen EINER Seite einer Verbindung (so, wie der Server sie liefert). Die Listen sind Texte, damit ein Bereich, den eine neuere
/// App kennt, die ältere nicht kippt.
struct VerbindungEinstellung: Codable, Equatable, Sendable {
    /// Was ich dieser Person zeige.
    var zeigt: [String] = []
    /// Was ich von dieser Person nicht sehen will.
    var ausblenden: [String] = []
    /// Pause: nichts senden und nichts empfangen.
    var pause = false
    var mitteilungen = true
    var favorit = false
    /// Eigener Name für die Person, nur für meine Anzeige.
    var name = ""

    init(zeigt: [String] = [], ausblenden: [String] = [], pause: Bool = false, mitteilungen: Bool = true, favorit: Bool = false, name: String = "") {
        self.zeigt = zeigt; self.ausblenden = ausblenden; self.pause = pause; self.mitteilungen = mitteilungen; self.favorit = favorit; self.name = name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zeigt = (try? c.decodeIfPresent([String].self, forKey: .zeigt)) ?? []
        ausblenden = (try? c.decodeIfPresent([String].self, forKey: .ausblenden)) ?? []
        pause = (try? c.decodeIfPresent(Bool.self, forKey: .pause)) ?? false
        mitteilungen = (try? c.decodeIfPresent(Bool.self, forKey: .mitteilungen)) ?? true
        favorit = (try? c.decodeIfPresent(Bool.self, forKey: .favorit)) ?? false
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
    }

    enum CodingKeys: String, CodingKey { case zeigt, ausblenden, pause, mitteilungen, favorit, name }

    var zeigtBereiche: Set<VerbindungBereich> { Set(zeigt.compactMap(VerbindungBereich.init(rawValue:))) }
    var ausgeblendet: Set<VerbindungBereich> { Set(ausblenden.compactMap(VerbindungBereich.init(rawValue:))) }
}

enum VerbindungStatus: String, Sendable { case aktiv, anfrageEingehend, anfrageAusgehend }

/// Ein Eintrag der Verbindungsliste vom Server (`GET /verbindungen`). `daten` steht nur bei aktiven Verbindungen und ist schon vom Server auf
/// das begrenzt, was die Person dir zeigt und du sehen willst.
struct VerbindungEintrag: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var auto: Bool
    /// Die zwei Lovea-Konten: diese Person liegt im bisherigen Partner-Platz (Heute, Schlaf, Ansichten).
    var lovea: Bool
    var statusText: String
    var ich: VerbindungEinstellung
    /// Was ich von der Person sehe (nach Pause und Ausblenden).
    var siehst: [String]
    var zuletzt: Date?
    var daten: ZusammenfassungDatei?
    /// Seit wann verbunden (bei einer wieder aufgenommenen Verbindung der neue Zeitpunkt).
    var erstellt: Date?
    /// Die Person kam über meine Einladung (QR-Code oder Code): dann steht sie kurz unter "Für dich" als neu verbunden.
    var eingeladen: Bool

    enum CodingKeys: String, CodingKey { case id, name, auto, lovea, status, ich, siehst, zuletzt, daten, erstellt, eingeladen }

    init(id: String, name: String, auto: Bool = false, lovea: Bool = false, status: VerbindungStatus = .aktiv, ich: VerbindungEinstellung = VerbindungEinstellung(),
         siehst: [String] = [], zuletzt: Date? = nil, daten: ZusammenfassungDatei? = nil, erstellt: Date? = nil, eingeladen: Bool = false) {
        self.id = id; self.name = name; self.auto = auto; self.lovea = lovea; statusText = status.rawValue
        self.ich = ich; self.siehst = siehst; self.zuletzt = zuletzt; self.daten = daten; self.erstellt = erstellt; self.eingeladen = eingeladen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        auto = (try? c.decodeIfPresent(Bool.self, forKey: .auto)) ?? false
        lovea = (try? c.decodeIfPresent(Bool.self, forKey: .lovea)) ?? false
        statusText = (try? c.decode(String.self, forKey: .status)) ?? ""
        ich = (try? c.decodeIfPresent(VerbindungEinstellung.self, forKey: .ich)) ?? VerbindungEinstellung()
        siehst = (try? c.decodeIfPresent([String].self, forKey: .siehst)) ?? []
        zuletzt = try? c.decodeIfPresent(Date.self, forKey: .zuletzt)
        // Eine kaputte Zusammenfassung einer Person kippt nicht die ganze Liste.
        daten = try? c.decodeIfPresent(ZusammenfassungDatei.self, forKey: .daten)
        erstellt = try? c.decodeIfPresent(Date.self, forKey: .erstellt)
        eingeladen = (try? c.decodeIfPresent(Bool.self, forKey: .eingeladen)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(auto, forKey: .auto)
        try c.encode(lovea, forKey: .lovea)
        try c.encode(statusText, forKey: .status)
        try c.encode(ich, forKey: .ich)
        try c.encode(siehst, forKey: .siehst)
        try c.encodeIfPresent(zuletzt, forKey: .zuletzt)
        try c.encodeIfPresent(daten, forKey: .daten)
        try c.encodeIfPresent(erstellt, forKey: .erstellt)
        try c.encode(eingeladen, forKey: .eingeladen)
    }

    /// Unbekannter Status heißt "nicht aktiv": nichts anzeigen, was der Server nicht ausdrücklich als aktiv meldet.
    var status: VerbindungStatus? { VerbindungStatus(rawValue: statusText) }
    var aktiv: Bool { status == .aktiv }
    /// Anzeigename: mein eigener Name für die Person, sonst der des Servers.
    var anzeigeName: String { ich.name.isEmpty ? name : ich.name }
    var sichtbareBereiche: Set<VerbindungBereich> { Set(siehst.compactMap(VerbindungBereich.init(rawValue:))) }

    /// Der Stand dieser Person für die Ansichten: frisch, veraltet (älter als 48 Stunden), unbekannte Version oder keine Daten.
    func stand(jetzt: Date) -> PartnerStand {
        guard aktiv, let d = daten else { return .nichtVerbunden }
        guard d.version == LoveaVertrag.version else { return .unbekannteVersion }
        return jetzt.timeIntervalSince(d.geschrieben) <= LoveaVertrag.frist ? .verbunden(d) : .veraltet(d)
    }
}

/// Die ganze Antwort von `GET /verbindungen`. `teilen`: die Bereiche, die Lumen Fit hochladen darf (mindestens eine aktive, nicht pausierte Verbindung zeigt sie).
struct VerbindungenAntwort: Codable, Equatable, Sendable {
    var verbindungen: [VerbindungEintrag]
    var teilen: [String]

    init(verbindungen: [VerbindungEintrag] = [], teilen: [String] = []) { self.verbindungen = verbindungen; self.teilen = teilen }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Einzeln lesen: ein Eintrag, den diese App nicht versteht, fällt weg.
        struct Huelle: Decodable {
            let eintrag: VerbindungEintrag?
            init(from decoder: Decoder) throws { eintrag = try? VerbindungEintrag(from: decoder) }
        }
        verbindungen = (try c.decode([Huelle].self, forKey: .verbindungen)).compactMap(\.eintrag)
        teilen = (try? c.decodeIfPresent([String].self, forKey: .teilen)) ?? []
    }

    enum CodingKeys: String, CodingKey { case verbindungen, teilen }

    var teilenBereiche: Set<VerbindungBereich> { Set(teilen.compactMap(VerbindungBereich.init(rawValue:))) }
}

/// Reine Regeln rund um Einladungen und Verbindungen. Ohne Netz und Oberfläche testbar.
enum VerbindungenLogik {
    /// Neue Personen sehen zuerst nur das.
    nonisolated static let standardZeigt: Set<VerbindungBereich> = [.schritte, .gym]
    /// So lange gilt ein Code (der Server entscheidet; die App zeigt den Rest nur an).
    nonisolated static let codeSekunden = 600

    /// Das Token aus einem Link (`lumenfit://freund?d=<Token>`), der Seite des Servers (`https://…/f/<Token>`, so steht es im QR-Code) oder dem nackten
    /// Token. Ein Token hat genau 43 Zeichen aus `A-Za-z0-9_-` (32 Byte zufällig); alles andere (zum Beispiel eine alte Wochenkarte mit Punkt) ist keins.
    nonisolated static func token(aus text: String?) -> String? {
        guard let roh = text?.trimmingCharacters(in: .whitespacesAndNewlines), !roh.isEmpty else { return nil }
        var kandidat = roh
        if let url = URL(string: roh) {
            if case .freund(let daten)? = RouteURL.route(aus: url) {
                kandidat = daten ?? ""
            } else if url.scheme == "https", url.pathComponents.count == 3, url.pathComponents[1] == "f" {
                kandidat = url.pathComponents[2]
            }
        }
        return istToken(kandidat) ? kandidat : nil
    }

    /// Code zum Abtippen (ab Build 19, 24 Stunden): 8 Zeichen ohne Verwechsler (0 O 1 I L). Groß/Klein, Leerzeichen und Bindestriche sind egal;
    /// zurück kommt er in Großbuchstaben ohne Bindestrich, sonst nil.
    nonisolated static func code(aus text: String?) -> String? {
        guard let text else { return nil }
        let roh = text.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        return roh.count == 8 && roh.allSatisfy { codeZeichen.contains($0) } ? roh : nil
    }

    nonisolated static let codeZeichen = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    /// Was unter "Code eingeben" steht oder gescannt wurde: ein Token (Link, Seite, nackt) oder ein Code. nil, wenn es keins von beiden ist.
    nonisolated static func einladung(aus text: String?) -> String? { token(aus: text) ?? code(aus: text) }

    /// Der Inhalt des QR-Codes: die Einladungsseite. Die iPhone-Kamera öffnet sie; mit App startet sie Lumen Fit, ohne App zeigt sie den App Store.
    /// Beim Live-Server die öffentliche Webseite (leitet /f/ an den Server weiter), damit die Server-Adresse nicht im Link steht.
    nonisolated static func seite(server: URL, token: String) -> URL {
        let basis = server.host()?.hasPrefix("lumen-fit-live.") == true ? URL(string: "https://lumen-fit.pages.dev")! : server
        return basis.appendingPathComponent("f").appendingPathComponent(token)
    }

    nonisolated static func istToken(_ text: String) -> Bool {
        text.utf8.count == 43 && text.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95 }
    }

    nonisolated static func link(token: String) -> URL { RouteURL.url(fuer: .freund(daten: token)) }

    // MARK: Trainingspartner (Auftrag 09.11.2026: ein Freund, unabhängig von Lovea)

    /// Die Wahl auf diesem Gerät: Verbindungs-Id, `keinPartner` oder nichts (dann die Lovea-Person wie bisher).
    nonisolated static let partnerSchluessel = "fit.crew.partner"
    nonisolated static let keinPartner = "-"

    nonisolated static var gewaehlterPartner: String? { UserDefaults.standard.string(forKey: partnerSchluessel) }

    /// Der Trainingspartner: die gewählte Person, solange sie aktiv und nicht pausiert ist; ohne Wahl (oder wenn sie nicht mehr da ist) die Lovea-Person;
    /// mit `keinPartner` niemand. Sein Stand liegt im bisherigen Partner-Platz (Heute, Training, Essen, Schlaf).
    nonisolated static func partner(_ eintraege: [VerbindungEintrag], gewaehlt: String?) -> VerbindungEintrag? {
        guard gewaehlt != keinPartner else { return nil }
        let aktiv = eintraege.filter { $0.aktiv && !$0.ich.pause }
        if let gewaehlt, let p = aktiv.first(where: { $0.id == gewaehlt }) { return p }
        return aktiv.first(where: \.lovea)
    }

    /// Die Freigaben für die Lovea-Datei und die Vorschau: was die Lovea-Verbindung zeigt; leer bei Pause oder ohne aktive Verbindung.
    nonisolated static func freigaben(fuer eintrag: VerbindungEintrag?) -> Set<FreigabeArt> {
        guard let eintrag, eintrag.aktiv, !eintrag.ich.pause else { return [] }
        return Set(eintrag.ich.zeigtBereiche.compactMap(\.freigabe))
    }

    /// Die Bereiche, die diese App hochladen darf, als Freigaben. Unbekannte Namen vom Server fallen weg.
    /// Ein ausgeschalteter Bereich (`Einstellungen`) wird auch dann nicht hochgeladen, wenn eine Verbindung ihn zeigen darf.
    nonisolated static func hochladen(_ antwort: VerbindungenAntwort?, einstellungen: Einstellungen = Einstellungen()) -> Set<FreigabeArt> {
        guard let antwort else { return [] }
        return erlaubt(Set(antwort.teilenBereiche.compactMap(\.freigabe)), einstellungen: einstellungen)
    }

    /// Streicht die Freigaben, deren Bereich in der App ausgeschaltet ist (Gym: auch Plan und Training; Essen: auch Tagebuch). Auch für die Vorschau.
    nonisolated static func erlaubt(_ frei: Set<FreigabeArt>, einstellungen: Einstellungen) -> Set<FreigabeArt> {
        frei.filter { art in
            let bereich: AppBereich?
            switch art {
            case .gym, .plan, .verlauf: bereich = AppBereich.gym
            case .essen, .tagebuch: bereich = AppBereich.essen
            case .schlaf: bereich = AppBereich.schlaf
            case .schritte, .koerper, .stimmung, .gewohnheiten: bereich = nil
            }
            return bereich.map { einstellungen.zeigt($0) } ?? true
        }
    }

    /// Wo steht meine Anfrage? `gesehen`: sie stand schon einmal in der Liste. Fehlt sie erst dann, hat die andere Person sie abgelehnt;
    /// vorher kann die Liste nur noch alt sein (Funkloch), dann wird weiter gewartet.
    enum AnfrageStand: Equatable, Sendable { case wartet, verbunden, abgelehnt }

    nonisolated static func anfrageStand(id: String, gesehen: Bool, in eintraege: [VerbindungEintrag]) -> AnfrageStand {
        guard let e = eintraege.first(where: { $0.id == id }) else { return gesehen ? .abgelehnt : .wartet }
        return e.aktiv ? .verbunden : .wartet
    }

    /// Die erste Person, die über meine Einladung dazugekommen ist und beim Öffnen des Blatts noch nicht in der Liste stand.
    nonisolated static func neuePerson(_ eintraege: [VerbindungEintrag], bekannt: Set<String>) -> VerbindungEintrag? {
        eintraege.first { $0.aktiv && $0.eingeladen && !bekannt.contains($0.id) }
    }

    /// Über meine Einladung neu verbunden, nach `seit` und höchstens sieben Tage her, die neueste zuerst ("Für dich" und die Zahl am Tab).
    nonisolated static func neuVerbunden(_ eintraege: [VerbindungEintrag], seit: Date?, jetzt: Date) -> [VerbindungEintrag] {
        let ab = max(seit ?? .distantPast, jetzt.addingTimeInterval(-7 * 86_400))
        return eintraege
            .filter { e in e.aktiv && e.eingeladen && (e.erstellt.map { $0 > ab } ?? false) }
            .sorted { ($0.erstellt ?? .distantPast) > ($1.erstellt ?? .distantPast) }
    }

    /// Bereiche, die die Person dir erlaubt, die aber in ihren Daten fehlen (bei ihr ausgeschaltet): "wird nicht geteilt". Ohne Daten nichts behaupten.
    nonisolated static func nichtGeteilt(_ eintrag: VerbindungEintrag) -> [VerbindungBereich] {
        guard let daten = eintrag.daten else { return [] }
        let da = Set(daten.freigaben)
        return VerbindungBereich.allCases.filter { b in eintrag.sichtbareBereiche.contains(b) && (b.freigabe.map { !da.contains($0) } ?? false) }
    }

    /// Die Zeile unter dem Namen in der Liste: Schritte und Gym von heute, wenn die Person sie teilt und der Stand von heute ist; sonst nil.
    nonisolated static func kurzInfo(_ eintrag: VerbindungEintrag, jetzt: Date) -> String? {
        guard eintrag.aktiv, !eintrag.ich.pause, case .verbunden(let d) = eintrag.stand(jetzt: jetzt), d.heute.tag == Datum.text(jetzt) else { return nil }
        var teile: [String] = []
        if d.freigaben.contains(.schritte), let s = d.heute.schritte {
            teile.append("\(s.formatted(.number.locale(Locale(identifier: "de_DE")))) Schritte")
        }
        if d.freigaben.contains(.gym), let g = d.heute.gymTageWoche {
            if let z = d.heute.gymZiel, z > 0 { teile.append("Gym \(g) von \(z)") } else { teile.append(g == 1 ? "Gym 1 Tag" : "Gym \(g) Tage") }
        }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    /// Schneidet eine Zusammenfassung auf die erlaubten Freigaben zu: Felder der anderen Bereiche fallen weg, nicht nur die Liste.
    /// Für Daten, die nicht vom Server kommen (die Datei von Lovea): der Server filtert seine Daten selbst.
    nonisolated static func begrenze(_ datei: ZusammenfassungDatei, auf erlaubt: Set<FreigabeArt>) -> ZusammenfassungDatei {
        var d = datei
        d.freigaben = datei.freigaben.filter { erlaubt.contains($0) }
        var h = TagesZusammenfassung(tag: datei.heute.tag)
        let alt = datei.heute
        if d.freigaben.contains(.schritte) { h.schritte = alt.schritte; h.schritteZiel = alt.schritteZiel; h.schritteWoche = alt.schritteWoche }
        if d.freigaben.contains(.gym) { h.gymTageWoche = alt.gymTageWoche; h.gymTage = alt.gymTage; h.gymZiel = alt.gymZiel }
        if d.freigaben.contains(.schlaf) {
            h.schlafMinuten = alt.schlafMinuten; h.schlafWoche = alt.schlafWoche; h.schlafZiel = alt.schlafZiel; h.energieStufe = alt.energieStufe
            if d.freigaben.contains(.gym) { h.energieGym = alt.energieGym }
        }
        if d.freigaben.contains(.essen) { h.kcal = alt.kcal; h.wasserGlaeser = alt.wasserGlaeser }
        let habits = (alt.habitsFertig ?? []).filter { ($0 == "gym" && d.freigaben.contains(.gym)) || ($0 == "wasser" && d.freigaben.contains(.essen)) }
        h.habitsFertig = habits.isEmpty ? nil : habits
        if d.freigaben.contains(.plan) { h.plan = alt.plan }
        if d.freigaben.contains(.verlauf) { h.verlauf = alt.verlauf }
        if d.freigaben.contains(.tagebuch) { h.tagebuch = alt.tagebuch; h.tagebuchZiele = alt.tagebuchZiele }
        if d.freigaben.contains(.koerper) { h.koerper = alt.koerper }
        if d.freigaben.contains(.stimmung) { h.stimmung = alt.stimmung; h.stimmungWoche = alt.stimmungWoche }
        if d.freigaben.contains(.gewohnheiten) { h.gewohnheiten = alt.gewohnheiten }
        d.heute = h
        d.ereignisse = datei.ereignisse.filter { d.freigaben.contains(ereignisFreigabe($0.art)) }
        return d
    }

    nonisolated static func ereignisFreigabe(_ art: PartnerEreignisArt) -> FreigabeArt {
        switch art {
        case .gymStart, .gymEnde, .rekord: .gym
        case .ziel: .schritte
        case .schlafGut: .schlaf
        }
    }

    /// "Gerade eben", "vor 5 Minuten", "vor 3 Stunden", "gestern" (sonst Datum): wann die Person zuletzt Daten geschickt hat.
    nonisolated static func zuletztText(_ zeit: Date?, jetzt: Date) -> String {
        guard let zeit else { return "Noch keine Daten" }
        let s = jetzt.timeIntervalSince(zeit)
        if s < 90 { return "Gerade eben aktualisiert" }
        if s < 3600 { let m = Int(s / 60); return m == 1 ? "Vor 1 Minute aktualisiert" : "Vor \(m) Minuten aktualisiert" }
        if s < 86_400 { let h = Int(s / 3600); return h == 1 ? "Vor 1 Stunde aktualisiert" : "Vor \(h) Stunden aktualisiert" }
        let t = Int(s / 86_400)
        return t == 1 ? "Gestern aktualisiert" : "Vor \(t) Tagen aktualisiert"
    }
}
