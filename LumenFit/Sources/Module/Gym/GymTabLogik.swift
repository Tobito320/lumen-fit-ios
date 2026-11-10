import Foundation

/// Reine Rechnungen des Training-Tabs im neuen Design (10.11.2026): Kurzversion, Lumi-Zeile, Plan-Woche, Katalog-Chips,
/// Split-Filter nach Tagen, Muskel einer Übung. Keine Ansicht, kein Zustand.
enum GymTabLogik {
    /// Auf 5 min gerundet, mindestens 5 (wie `ZeitSchaetzung.umfang`).
    static func rund(_ minuten: Int) -> Int { max(5, Int((Double(minuten) / 5).rounded()) * 5) }

    /// Kurzversion des Tages ("Kurz · 30 min"): die ersten Übungen des Plans, solange der Tag auf 5 min gerundet in `grenze` passt;
    /// immer mindestens eine. Ein Supersatz-Paar bleibt zusammen (beide oder keine). `minuten` ist die Schätzung (Standard `ZeitSchaetzung`),
    /// damit die Regel deren Formel folgt.
    static func kurzversion(_ tag: TrainingsTag, grenze: Int = 30,
                            minuten: (TrainingsTag) -> Int = { ZeitSchaetzung.minuten($0) }) -> TrainingsTag {
        var kurz = tag
        kurz.uebungen = []
        for block in ZeitSchaetzung.bloecke(tag.uebungen) {
            var probe = kurz
            probe.uebungen += block
            if !kurz.uebungen.isEmpty, rund(minuten(probe)) > grenze { break }
            kurz = probe
        }
        return kurz
    }

    /// Lohnt die Kurzversion: nur, wenn sie wirklich Übungen weglässt.
    static func kurzLohnt(_ tag: TrainingsTag, minuten: (TrainingsTag) -> Int = { ZeitSchaetzung.minuten($0) }) -> Bool {
        kurzversion(tag, minuten: minuten).uebungen.count < tag.uebungen.count
    }

    /// Plan-Ids der Übungen, die die Kurzversion weglässt (sie werden beim Start ausgelassen, nicht gelöscht).
    static func kurzWeg(_ tag: TrainingsTag, minuten: (TrainingsTag) -> Int = { ZeitSchaetzung.minuten($0) }) -> Set<String> {
        Set(tag.uebungen.map(\.id)).subtracting(kurzversion(tag, minuten: minuten).uebungen.map(\.id))
    }

    /// Lumi über dem Startknopf: läuft, heute schon trainiert, Plantag, Ruhetag.
    struct LumiZeile: Equatable, Sendable {
        var stimmung: LumiStimmung
        var satz: String
    }

    static func lumi(laeuft: Bool, heuteGemacht: Bool, tagName: String?) -> LumiZeile {
        if laeuft { return LumiZeile(stimmung: .anfeuern, satz: String(localized: "Läuft. Ich zähle deine Sets mit.")) }
        if heuteGemacht { return LumiZeile(stimmung: .ziel, satz: String(localized: "Heute schon trainiert. Stark.")) }
        if let tagName { return LumiZeile(stimmung: .bereit, satz: String(localized: "Heute \(tagName). Ich zähle deine Sets mit.")) }
        return LumiZeile(stimmung: .ruhetag, satz: String(localized: "Ruhetag. Muskeln wachsen jetzt."))
    }

    /// Die wievielte Woche mit dem jetzigen Plan: ab der Woche der ersten Einheit mit einem seiner Tage (1 = diese Woche).
    /// nil ohne Plan oder ohne solche Einheit. Ein Enddatum des Plans gibt es nicht, darum kein "von M".
    static func planWoche(_ plan: TrainingsPlan, sessions: [GymSession], heute: String) -> Int? {
        let ids = Set(plan.tage.map(\.id))
        guard let erste = sessions.filter({ s in s.tag.map { ids.contains($0) } == true }).map(\.start).min() else { return nil }
        let tage = Datum.tageZwischen(Datum.montagDerWoche(Datum.text(erste)), Datum.montagDerWoche(heute))
        return max(1, tage / 7 + 1)
    }

    /// Die Hauptgruppe einer Übung (direkter Teil), nil bei Cardio und Übungen ohne bekannten Muskel.
    static func gruppe(_ u: Uebung) -> MuskelGruppe? { MuskelLogik.teile(u).first?.teil.gruppe }

    /// Split-Bibliothek: Tage-Chips "2–3 Tage", "4 Tage", "5+ Tage".
    enum TageChip: CaseIterable, Sendable {
        case zweiDrei, vier, fuenfPlus

        var titel: String {
            switch self {
            case .zweiDrei: String(localized: "2–3 Tage")
            case .vier: String(localized: "4 Tage")
            case .fuenfPlus: String(localized: "5+ Tage")
            }
        }

        func passt(_ tage: Int) -> Bool {
            switch self {
            case .zweiDrei: tage <= 3
            case .vier: tage == 4
            case .fuenfPlus: tage >= 5
            }
        }
    }

    /// Längster Tag eines Splits in Minuten (über die Schätzung des Plans, den er ergäbe).
    static func splitMinuten(_ v: SplitVorlage, minuten: (TrainingsTag) -> Int = { ZeitSchaetzung.minuten($0) }) -> Int {
        rund(SplitLogik.alsPlan(v, neueId: { "x" }).tage.map(minuten).max() ?? 0)
    }
}

/// Chips über dem Übungskatalog. Waden, Unterarme und Nacken gehen in Beine, Arme und Rücken auf; Muskel und Körperteil genau bleiben im Filter-Blatt.
enum GymKatalogChip: String, CaseIterable, Identifiable, Sendable {
    case brust, ruecken, beine, schultern, arme, bauch, cardio, ganzkoerper

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .brust: String(localized: "Brust")
        case .ruecken: String(localized: "Rücken")
        case .beine: String(localized: "Beine")
        case .schultern: String(localized: "Schultern")
        case .arme: String(localized: "Arme")
        case .bauch: String(localized: "Bauch")
        case .cardio: String(localized: "Cardio")
        case .ganzkoerper: String(localized: "Ganzkörper")
        }
    }

    // shortcut: "Ganzkörper" = Beine und Oberkörper zugleich mit Zusatzlast (Kreuzheben, Thruster, Clean), aus Muskel und Mitarbeit;
    // ohne Körpergewicht, Ball, Band und Rolle (sonst kommen Dehnungen mit). Eine gepflegte Liste der Grundübungen wäre genauer.
    private static let oben: Set<String> = ["Schultern", "hintere Schulter", "Trapez", "oberer Rücken", "Rautenmuskel", "Rücken", "Latissimus", "Brust", "obere Brust", "Rückenstrecker", "unterer Rücken"]
    private static let unten: Set<String> = ["Quadrizeps", "Adduktoren", "Po", "Abduktoren", "Beinbeuger", "Waden"]
    private static let ohneLast: Set<String> = ["Körpergewicht", "Gymnastikball", "Band", "Widerstandsband", "Rolle", "Bosu-Ball", "Assistiert"]

    func passt(_ u: Uebung) -> Bool {
        switch self {
        case .brust: return u.koerper == "Brust"
        case .ruecken: return u.koerper == "Rücken" || u.koerper == "Nacken"
        case .beine: return u.koerper == "Beine" || u.koerper == "Waden"
        case .schultern: return u.koerper == "Schultern"
        case .arme: return u.koerper == "Arme" || u.koerper == "Unterarme"
        case .bauch: return u.koerper == "Bauch"
        case .cardio: return u.istCardio
        case .ganzkoerper:
            guard !u.istCardio, !Self.ohneLast.contains(u.geraet) else { return false }
            let alle = Set([u.muskel] + u.neben)
            return !alle.isDisjoint(with: Self.oben) && !alle.isDisjoint(with: Self.unten)
        }
    }

    /// Cardio-Geräte sind keine "Hanteln & Maschinen": mit Cardio-Chip gilt der Gerätefilter erst, wenn ihn jemand gewählt hat.
    func geraetWahl(_ geraet: String?) -> String? {
        self == .cardio && geraet == nil ? UebungsKatalog.alleGeraete : geraet
    }
}

/// "Was mache ich für …?" (Hilfe-Blatt) und die Muskel-Seite: welche Gruppen, ein Satz je Gruppe.
enum GymMuskelHilfe {
    static let gruppen: [MuskelGruppe] = [.brust, .ruecken, .schulter, .bizeps, .trizeps, .beine, .bauch]

    static func satz(_ g: MuskelGruppe) -> String {
        switch g {
        case .brust: String(localized: "Die Brust drückt: alles, was Arme vom Körper wegschiebt.")
        case .ruecken: String(localized: "Der Rücken zieht: Rudern und Latzug, dazu hält er dich aufrecht.")
        case .schulter: String(localized: "Die Schulter hebt den Arm nach vorn, zur Seite und nach hinten.")
        case .bizeps: String(localized: "Der Bizeps beugt den Ellbogen, er hilft bei jedem Zug.")
        case .trizeps: String(localized: "Der Trizeps streckt den Ellbogen, er hilft bei jedem Drücken.")
        case .beine: String(localized: "Beine und Po tragen dich: Beugen, Strecken, Heben.")
        case .bauch: String(localized: "Der Bauch hält den Rumpf fest, bei schweren Übungen und im Alltag.")
        case .unterarme: String(localized: "Die Unterarme halten fest: Griff und Handgelenk.")
        case .nacken: String(localized: "Der Nacken hält den Kopf, Training meist über Trapez und Shrugs.")
        }
    }

    /// Gruppe je Katalog-Übung, einmal gerechnet ("Nach Muskel" im Katalog, Muskel-Seite); eigene Übungen werden direkt gerechnet.
    private static let gruppeJeId: [String: MuskelGruppe] = Dictionary(
        UebungsKatalog.alle.compactMap { u in GymTabLogik.gruppe(u).map { (u.id, $0) } }, uniquingKeysWith: { a, _ in a })

    static func gruppe(von u: Uebung) -> MuskelGruppe? { UebungsKatalog.nachId[u.id] != nil ? gruppeJeId[u.id] : GymTabLogik.gruppe(u) }

    /// Hinten liegende Gruppen zeigt die Figur von hinten.
    static func vonHinten(_ g: MuskelGruppe) -> Bool { [.ruecken, .trizeps, .nacken].contains(g) }

    /// Alle Katalog-Übungen dieser Gruppe, gängige zuerst, dann nach Name.
    static func uebungen(_ g: MuskelGruppe, in liste: [Uebung] = UebungsKatalog.alle) -> [Uebung] {
        liste.filter { gruppe(von: $0) == g }.sorted { a, b in
            let ra = UebungsKatalog.beliebtRang[a.id] ?? Int.max, rb = UebungsKatalog.beliebtRang[b.id] ?? Int.max
            return ra != rb ? ra < rb : a.name < b.name
        }
    }
}
