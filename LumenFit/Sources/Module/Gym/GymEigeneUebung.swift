// Quelle: Lovea Health/UebungsSuche.swift (`eigeneHinzufuegen`: dort nur ein Name, hier mit Muskel, Gerät und Notiz)
import Foundation
import Observation

/// Inhalt der Op `fit.gym.uebung`: eine selbst angelegte Übung. Die letzte Op einer `id` gilt; `geloescht` ist der Grabstein (die Übung
/// verschwindet aus Suche und Auswahl, bestehende Trainings behalten ihren Namen, weil der im Plan und im Lauf steht).
/// Cardio ist ein Körperteil ("Cardio", Muskel "Herz-Kreislauf"): so zählt die Übung Minuten statt Sätze, wie im Katalog.
struct GymEigeneUebungD: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var muskel: String
    var koerper: String
    var geraet: String
    var neben: [String]? = nil
    var notiz: String? = nil
    /// Tag des Anlegens (`yyyy-MM-dd`).
    var angelegt: String? = nil
    var geloescht: Bool? = nil
}

/// Warum das Formular nicht speichert; `text` steht unter dem Feld.
enum GymEigeneFehler: Error, Equatable, Sendable {
    case nameLeer, nameZuLang, muskelFehlt, geraetFehlt
    case dubletteKatalog, dubletteEigene

    var text: String {
        switch self {
        case .nameLeer: "Gib der Übung einen Namen."
        case .nameZuLang: "Der Name ist zu lang (höchstens \(GymEigeneLogik.maxName) Zeichen)."
        case .muskelFehlt: "Wähle Körperteil und Muskel."
        case .geraetFehlt: "Wähle ein Gerät."
        case .dubletteKatalog: "Diese Übung gibt es schon im Katalog."
        case .dubletteEigene: "Diese Übung hast du schon angelegt."
        }
    }
}

/// Reine Regeln für eigene Übungen: prüfen, aus den Ops falten, mit dem Katalog zusammenführen.
enum GymEigeneLogik {
    nonisolated static let art = "fit.gym.uebung"
    /// Beginnt mit `lv-`: `UebungsKatalog.hatVideo` ist falsch, es gibt nie ein Bild aus dem Netz, nur das Symbol.
    nonisolated static let idVorsilbe = "lv-eigen-"
    nonisolated static let maxName = 60
    nonisolated static let maxNotiz = 300

    static func istEigene(_ id: String) -> Bool { id.hasPrefix(idVorsilbe) }

    static func neueId() -> String { idVorsilbe + UUID().uuidString.lowercased() }

    /// Getrimmt, mehrfache Leerzeichen und Zeilenumbrüche zu einem Leerzeichen.
    static func bereinigt(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Cardio zählt Minuten statt Sätze.
    static func einheitText(koerper: String) -> String {
        koerper == "Cardio" ? "Minuten" : "Gewicht und Wiederholungen"
    }

    /// Die Muskeln zur Auswahl für ein Körperteil; Cardio hat nur den einen.
    static func muskeln(koerper: String, katalog: [Uebung] = UebungsKatalog.alle) -> [String] {
        koerper == "Cardio" ? ["Herz-Kreislauf"] : UebungsKatalog.muskeln(koerper, in: katalog)
    }

    /// Beim Wechsel des Körperteils: der Muskel bleibt, wenn er dazugehört, sonst der häufigste des neuen Körperteils.
    static func muskel(koerper: String, aktuell: String, katalog: [Uebung] = UebungsKatalog.alle) -> String {
        let moegliche = muskeln(koerper: koerper, katalog: katalog)
        return moegliche.contains(aktuell) ? aktuell : (moegliche.first ?? "")
    }

    /// nil = darf gespeichert werden. `bekannt` sind Katalog und eigene Übungen zusammen; die Übung mit `id` (beim Bearbeiten) zählt nicht als Dublette.
    static func pruefe(name: String, koerper: String, muskel: String, geraet: String, id: String? = nil, bekannt: [Uebung]) -> GymEigeneFehler? {
        let n = bereinigt(name)
        if n.isEmpty { return .nameLeer }
        if n.count > maxName { return .nameZuLang }
        if koerper.isEmpty || muskel.isEmpty { return .muskelFehlt }
        if geraet.isEmpty { return .geraetFehlt }
        let gesucht = UebungsKatalog.normal(n)
        for u in bekannt where u.id != id && (UebungsKatalog.normal(u.name) == gesucht || UebungsKatalog.normal(u.en) == gesucht) {
            return istEigene(u.id) ? .dubletteEigene : .dubletteKatalog
        }
        return nil
    }

    /// Der Stand aus den Ops (älteste zuerst): je `id` gewinnt die letzte, gelöschte fehlen; Reihenfolge des ersten Auftretens.
    static func falten(ops: [Op]) -> [GymEigeneUebungD] {
        var reihenfolge: [String] = []
        var stand: [String: GymEigeneUebungD] = [:]
        for op in ops {
            guard op.art == art, let d = op.daten(GymEigeneUebungD.self), istEigene(d.id) else { continue }
            if stand[d.id] == nil { reihenfolge.append(d.id) }
            stand[d.id] = d
        }
        return reihenfolge.compactMap { id in stand[id].flatMap { $0.geloescht == true ? nil : $0 } }
    }

    /// Die Übung, wie Suche und Plan sie sehen. `en` ist der Name selbst, damit die Suche ihn auch dort findet.
    static func uebung(_ d: GymEigeneUebungD) -> Uebung {
        Uebung(id: d.id, name: d.name, en: d.name, muskel: d.muskel, koerper: d.koerper, geraet: d.geraet, neben: d.neben ?? [])
    }

    /// Eigene zuerst (nach Name), dann der Katalog; eine Katalog-`id` wird nie von einer eigenen überdeckt.
    static func zusammen(katalog: [Uebung], eigene: [GymEigeneUebungD]) -> [Uebung] {
        let ids = Set(katalog.map(\.id))
        let eigeneUebungen = eigene.filter { !ids.contains($0.id) }.map(uebung).sorted { $0.name < $1.name }
        return eigeneUebungen + katalog
    }

    /// Ein neuer Planeintrag. Eigene Übungen tragen ihren Namen im Eintrag: der Katalog kennt sie nicht, und der Name bleibt auch nach dem Löschen.
    static func planUebung(_ u: Uebung) -> PlanUebung {
        var p = PlanUebung.neu(u)
        if istEigene(u.id) { p.name = u.name }
        return p
    }
}

/// Die eigenen Übungen des Profils, gefaltet aus den Ops `fit.gym.uebung`. Wird beim Start des Moduls geladen (`GymModul.start`).
@MainActor @Observable
final class GymEigeneStore {
    @ObservationIgnored private let raum: LokalerRaum?
    @ObservationIgnored private let uhr: Uhr
    private(set) var liste: [GymEigeneUebungD] = []

    init(raum: LokalerRaum?, uhr: @escaping Uhr = { Date() }) {
        self.raum = raum
        self.uhr = uhr
        laden()
    }

    func laden() {
        liste = GymEigeneLogik.falten(ops: raum?.ops(arten: [GymEigeneLogik.art]) ?? [])
    }

    /// Die eigenen Übungen als `Uebung`, nach Name.
    var uebungen: [Uebung] { GymEigeneLogik.zusammen(katalog: [], eigene: liste) }

    /// Katalog und eigene Übungen.
    var alle: [Uebung] { GymEigeneLogik.zusammen(katalog: UebungsKatalog.alle, eigene: liste) }

    /// Katalog und eigene nach `id` (für "Zuletzt benutzt").
    var nachId: [String: Uebung] {
        UebungsKatalog.nachId.merging(Dictionary(uebungen.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })) { katalog, _ in katalog }
    }

    /// Katalog-Übung oder eigene.
    func finde(_ id: String) -> Uebung? {
        UebungsKatalog.nachId[id] ?? liste.first { $0.id == id }.map(GymEigeneLogik.uebung)
    }

    func daten(_ id: String) -> GymEigeneUebungD? { liste.first { $0.id == id } }

    func istEigene(_ id: String) -> Bool { liste.contains { $0.id == id } }

    /// Legt an (`id` nil) oder ändert (`id` einer eigenen Übung). Bei Fehler wird nichts geschrieben.
    @discardableResult
    func sichern(id: String? = nil, name: String, koerper: String, muskel: String, geraet: String, notiz: String) -> Result<Uebung, GymEigeneFehler> {
        if let fehler = GymEigeneLogik.pruefe(name: name, koerper: koerper, muskel: muskel, geraet: geraet, id: id, bekannt: alle) {
            return .failure(fehler)
        }
        let alt = id.flatMap(daten)
        let text = GymEigeneLogik.bereinigt(notiz)
        let d = GymEigeneUebungD(
            id: alt?.id ?? GymEigeneLogik.neueId(), name: GymEigeneLogik.bereinigt(name), muskel: muskel, koerper: koerper, geraet: geraet,
            neben: alt?.neben, notiz: text.isEmpty ? nil : String(text.prefix(GymEigeneLogik.maxNotiz)),
            angelegt: alt?.angelegt ?? Datum.text(uhr()))
        raum?.senden(GymEigeneLogik.art, d)
        laden()
        return .success(GymEigeneLogik.uebung(d))
    }

    /// Grabstein: die Übung verschwindet aus Suche und Auswahl, Pläne und Trainings behalten ihren Eintrag samt Namen.
    func loeschen(_ id: String) {
        guard var d = daten(id) else { return }
        d.geloescht = true
        raum?.senden(GymEigeneLogik.art, d)
        laden()
    }
}
