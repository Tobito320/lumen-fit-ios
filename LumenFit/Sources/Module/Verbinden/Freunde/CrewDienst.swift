import Foundation
import Observation

/// Eine neue Herausforderung für `POST /freunde/herausforderungen`. Genau eins von `tage` oder `ende`; `ziel` nur bei gemeinsam (der Server lehnt sonst ab).
struct CrewNeueHerausforderung: Encodable, Equatable, Sendable {
    var art: CrewMass
    var modus: CrewModus
    var tage: Int?
    var ende: String?
    var ziel: Int?
    var uebung: String?
    var einladen: [String]

    /// `tage` nil heißt "bis Sonntag".
    init(art: CrewMass, modus: CrewModus, tage: Int?, ziel: Int?, uebung: String?, einladen: [String], jetzt: Date) {
        self.art = art
        self.modus = modus
        if let tage { self.tage = min(max(tage, 1), 28) } else { ende = LoveaVertrag.isoText(CrewLogik.endeBisSonntag(jetzt: jetzt)) }
        self.ziel = modus == .gemeinsam ? min(max(ziel ?? 1, 1), 10_000_000) : nil
        self.uebung = art == .uebung ? uebung.map { String($0.prefix(40)) } : nil
        self.einladen = Array(einladen.prefix(9))
    }
}

/// Ein Weg zum Server, der ohne Netz liegen blieb (Annehmen, Ablehnen, Verlassen; aus Build 18 auch Respekt). Geht beim nächsten Abgleich in derselben
/// Reihenfolge raus; was der Server dann ablehnt (etwa die Verbindung ist weg), ist erledigt.
struct CrewAuftrag: Codable, Equatable, Sendable {
    var pfad: String
    var methode: String
    var koerper: Data?
}

/// Die Crew beim Server (`GET /freunde` und die Aktionen dazu). Eine Instanz je Konto (`von`). Der letzte Stand liegt als `crew-server.json` neben dem Konto,
/// damit die Seite auch ohne Netz etwas zeigt. In der Demo (`-lumenFitDemo`, nur DEBUG) eine feste Beispiel-Antwort ohne Netz.
@MainActor @Observable
final class CrewDienst {
    nonisolated static let dateiName = "crew-server.json"
    /// Die Warteschlange ohne Netz (`CrewAuftrag`), neben dem Cache.
    nonisolated static let ausstehendName = "crew-ausstehend.json"
    nonisolated static let ausstehendMax = 50
    /// Bis wann die Reaktionen gesehen sind (Sekunden seit 1970), für "neu" am Einstieg.
    nonisolated static let gesehenSchluessel = "fit.crew.gesehen"
    /// So oft holt das Öffnen einer Ansicht höchstens neu.
    nonisolated static let pause: TimeInterval = 60
    nonisolated static let keinNetz = "Das hat nicht geklappt. Prüfe die Verbindung und versuche es nochmal."

    private(set) var antwort: CrewAntwort?
    private(set) var laedt = false
    /// Was ohne Netz gemacht wurde und noch zum Server muss (offline zuerst: die Ansicht zeigt es schon).
    private(set) var ausstehend: [CrewAuftrag] = []
    /// Der Text zum letzten Fehlschlag einer Aktion; die Ansicht zeigt ihn und setzt ihn zurück.
    var fehler: String?

    @ObservationIgnored private let umgebung: AppUmgebung
    @ObservationIgnored private let datei: URL
    @ObservationIgnored private let ausstehendDatei: URL
    @ObservationIgnored private let demo: Bool
    @ObservationIgnored private var zuletzt: Date?

    private static var instanzen: [ObjectIdentifier: CrewDienst] = [:]

    static func von(_ umgebung: AppUmgebung) -> CrewDienst {
        let schluessel = ObjectIdentifier(umgebung.konto)
        if let da = instanzen[schluessel] { return da }
        let neu = CrewDienst(umgebung: umgebung, demo: LoveaFreigabe.demoAktiv)
        instanzen[schluessel] = neu
        return neu
    }

    init(umgebung: AppUmgebung, demo: Bool = false) {
        #if DEBUG
        let istDemo = demo
        #else
        let istDemo = false
        #endif
        let pfad = umgebung.konto.ordner.appendingPathComponent(Self.dateiName)
        self.umgebung = umgebung
        self.demo = istDemo
        datei = pfad
        let warte = umgebung.konto.ordner.appendingPathComponent(Self.ausstehendName)
        ausstehendDatei = warte
        ausstehend = istDemo ? [] : (try? Data(contentsOf: warte)).flatMap { try? JSONDecoder().decode([CrewAuftrag].self, from: $0) } ?? []
        antwort = istDemo ? Self.demoAntwort(jetzt: umgebung.uhr())
            : (try? Data(contentsOf: pfad)).flatMap { try? LoveaVertrag.decoder().decode(CrewAntwort.self, from: $0) }
    }

    private static func demoAntwort(jetzt: Date) -> CrewAntwort? {
        #if DEBUG
        return CrewDemo.antwort(jetzt: jetzt)
        #else
        return nil
        #endif
    }

    private var sessions: [GymSession] { umgebung.daten?.training.sessions ?? [] }

    // MARK: Lesen

    /// Neu über meine Einladung verbunden (seit dem letzten Blick, höchstens sieben Tage): "Für dich" und die Zahl am Tab. Likes gibt es seit Build 19
    /// nicht mehr (W-034); Reaktionen im Cache bleiben nur lesbar.
    func neue(seit: Date?) -> [VerbindungEintrag] { VerbindungenLogik.neuVerbunden(umgebung.konto.verbindungen.eintraege, seit: seit, jetzt: umgebung.uhr()) }
    var einladungen: [CrewHerausforderung] { (antwort?.herausforderungen ?? []).filter { $0.eingeladen && !$0.abgebrochen } }
    func herausforderung(_ id: String) -> CrewHerausforderung? { antwort?.herausforderungen.first { $0.id == id } }

    // MARK: Abgleich

    /// Holt `GET /freunde` (höchstens einmal je Minute, außer `erzwingen`) und meldet danach die eigenen Werte, die sich geändert haben.
    func laden(erzwingen: Bool = false) async {
        guard !demo, !laedt else { return }
        let jetzt = umgebung.uhr()
        if !erzwingen, let z = zuletzt, jetzt >= z, jetzt.timeIntervalSince(z) < Self.pause { return }
        guard let k = umgebung.konto.registrierteKennung() else { return }
        laedt = true
        defer { laedt = false }
        zuletzt = jetzt
        await ausstehendSenden(k)
        // Blieb etwas liegen, gilt weiter der eigene Stand (sonst verschwände kurz, was schon gezeigt ist).
        guard ausstehend.isEmpty, let r = await umgebung.konto.sendeMitKonto("/freunde", methode: "GET", kennung: k), r.status == 200,
              let neu = try? LoveaVertrag.decoder().decode(CrewAntwort.self, from: r.daten) else { return }
        setze(neu)
        await werteMelden(k)
    }

    private func werteMelden(_ k: KontoKennung) async {
        // Die Crew gehört dem Konto: nur die Einheiten seines Profils zählen, nicht die eines zweiten Profils auf demselben Gerät.
        guard let a = antwort, let profil = umgebung.daten?.profil, umgebung.konto.gehoertZuProfil(profil) else { return }
        let werte = CrewLogik.zuMelden(a, sessions: sessions, jetzt: umgebung.uhr())
        guard !werte.isEmpty, let body = try? JSONEncoder().encode(["werte": werte]),
              let r = await umgebung.konto.sendeMitKonto("/freunde/werte", methode: "PUT", body: body, kennung: k), r.status == 200 else { return }
        aendere { neu in
            for w in werte {
                guard let i = neu.herausforderungen.firstIndex(where: { $0.id == w.id }),
                      let j = neu.herausforderungen[i].teilnehmer.firstIndex(where: \.ich) else { continue }
                neu.herausforderungen[i].teilnehmer[j].wert = w.wert
            }
        }
    }

    /// Die Warteschlange der Reihe nach senden; ohne Netz bleibt der Rest liegen. Eine Ablehnung (4xx) erledigt den Auftrag; bei 429 und 5xx bleibt er liegen
    /// (sonst ginge ein Annehmen oder eine Reaktion bei einem Serverfehler verloren), und nichts dahinter überholt ihn.
    private func ausstehendSenden(_ k: KontoKennung) async {
        while let a = ausstehend.first {
            guard let r = await umgebung.konto.sendeMitKonto(a.pfad, methode: a.methode, body: a.koerper, kennung: k), r.status != 429, r.status < 500 else { return }
            ausstehend.removeFirst()
            speichereAusstehend()
        }
    }

    private func merke(_ a: CrewAuftrag) {
        ausstehend.append(a)
        if ausstehend.count > Self.ausstehendMax { ausstehend.removeFirst(ausstehend.count - Self.ausstehendMax) }
        speichereAusstehend()
    }

    private func speichereAusstehend() {
        guard !demo else { return }
        if ausstehend.isEmpty {
            try? FileManager.default.removeItem(at: ausstehendDatei)
        } else if let daten = try? JSONEncoder().encode(ausstehend) {
            try? FileManager.default.createDirectory(at: ausstehendDatei.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? daten.write(to: ausstehendDatei, options: .atomic)
        }
    }

    private func setze(_ neu: CrewAntwort) {
        antwort = neu
        guard !demo, let daten = try? LoveaVertrag.encoder().encode(neu) else { return }
        try? FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: datei, options: .atomic)
    }

    private func aendere(_ f: (inout CrewAntwort) -> Void) {
        var a = antwort ?? CrewAntwort()
        f(&a)
        setze(a)
    }

    private func sende(_ pfad: String, _ methode: String, _ body: Data? = nil) async -> (status: Int, daten: Data)? {
        if demo { return (methode == "POST" ? 201 : 200, Data()) }
        guard let k = await umgebung.konto.kennungBereit() else { return nil }
        return await umgebung.konto.sendeMitKonto(pfad, methode: methode, body: body, kennung: k)
    }

    // MARK: Herausforderungen

    /// nil = angelegt; sonst der Satz für die Person.
    func erstellen(_ neu: CrewNeueHerausforderung) async -> String? {
        guard let body = try? JSONEncoder().encode(neu) else { return Self.keinNetz }
        let r = await sende("/freunde/herausforderungen", "POST", body)
        switch r?.status {
        case 201?, 200?:
            await laden(erzwingen: true)
            return nil
        case 400?: return "Eine Person ist nicht mehr verbunden oder hat pausiert."
        case 429?: return "Du bist schon in zehn laufenden Herausforderungen, oder es waren zu viele Versuche. Warte eine Minute."
        default: return Self.keinNetz
        }
    }

    func annehmen(_ id: String) async -> String? { await aktion(id, "annehmen") }
    func ablehnen(_ id: String) async -> String? { await aktion(id, "ablehnen") }
    func verlassen(_ id: String) async -> String? { await aktion(id, "verlassen") }

    private func aktion(_ id: String, _ was: String) async -> String? {
        guard CrewLogik.istId(id) else { return Self.keinNetz }
        let pfad = "/freunde/herausforderungen/\(id)/\(was)"
        let r = await sende(pfad, "POST")
        // Ohne Netz: gleich so zeigen und später senden (offline zuerst).
        if r == nil { merke(CrewAuftrag(pfad: pfad, methode: "POST", koerper: nil)) }
        switch r?.status {
        case 200?, 201?, nil:
            aendere { a in
                guard let i = a.herausforderungen.firstIndex(where: { $0.id == id }) else { return }
                if was == "annehmen" {
                    a.herausforderungen[i].ich = "dabei"
                    if let j = a.herausforderungen[i].teilnehmer.firstIndex(where: \.ich) { a.herausforderungen[i].teilnehmer[j].status = "dabei" }
                } else {
                    a.herausforderungen.remove(at: i)
                }
            }
            if r != nil { await laden(erzwingen: true) }
            return nil
        case 409?: return "Diese Herausforderung läuft nicht mehr."
        case 404?: return "Diese Herausforderung gibt es nicht mehr."
        case 429?: return "Du bist schon in zehn laufenden Herausforderungen."
        default: return Self.keinNetz
        }
    }
}
