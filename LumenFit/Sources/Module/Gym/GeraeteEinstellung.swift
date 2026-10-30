// Quelle: Lovea Health/Einstellung/EinstellGedaechtnis.swift (Datei im Profilordner statt UserDefaults)
import Foundation
import Observation

/// Was jemand an einem Gerät eingestellt hat: Bankstufe, Sitzhöhe, Polster und eine freie Notiz. Leere Felder = nicht gesetzt.
struct GeraeteWerte: Codable, Equatable, Sendable {
    var stufe: String? = nil
    var sitz: String? = nil
    var polster: String? = nil
    var notiz: String? = nil

    init(stufe: String? = nil, sitz: String? = nil, polster: String? = nil, notiz: String? = nil) {
        self.stufe = stufe
        self.sitz = sitz
        self.polster = polster
        self.notiz = notiz
    }

    /// Alle Felder `decodeIfPresent`: neue Felder machen alte Dateien nie unlesbar.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stufe = try c.decodeIfPresent(String.self, forKey: .stufe)
        sitz = try c.decodeIfPresent(String.self, forKey: .sitz)
        polster = try c.decodeIfPresent(String.self, forKey: .polster)
        notiz = try c.decodeIfPresent(String.self, forKey: .notiz)
    }

    private enum CodingKeys: String, CodingKey { case stufe, sitz, polster, notiz }

    /// Ränder weg, leere Felder werden nil.
    var bereinigt: GeraeteWerte {
        func s(_ t: String?) -> String? {
            let r = t?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (r?.isEmpty ?? true) ? nil : r
        }
        return GeraeteWerte(stufe: s(stufe), sitz: s(sitz), polster: s(polster), notiz: s(notiz))
    }

    var istLeer: Bool { bereinigt == GeraeteWerte() }
}

/// Die Datei `geraete.json` im Profilordner: Einstellungen je Gerät (Schlüssel: Studio und Übung, `DefektLogik.schluessel`).
struct GeraeteEinstellungDatei: Codable, Equatable, Sendable {
    var eintraege: [String: GeraeteWerte] = [:]

    init(eintraege: [String: GeraeteWerte] = [:]) { self.eintraege = eintraege }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eintraege = try c.decodeIfPresent([String: GeraeteWerte].self, forKey: .eintraege) ?? [:]
    }

    private enum CodingKeys: String, CodingKey { case eintraege }

    static func datei(_ ordner: URL) -> JSONDatei<GeraeteEinstellungDatei> {
        JSONDatei<GeraeteEinstellungDatei>(ordner.appendingPathComponent("geraete.json"))
    }

    static func lesen(_ ordner: URL?) -> GeraeteEinstellungDatei {
        ordner.flatMap { datei($0).lade() } ?? GeraeteEinstellungDatei()
    }

    /// Katalog-Id, bei eigenen Übungen der Name.
    static func uebungsSchluessel(_ u: PlanUebung) -> String { u.uebung == PlanUebung.eigen ? u.anzeigeName : u.uebung }
}

@MainActor @Observable
final class GeraeteStore {
    @ObservationIgnored private let ordner: URL?
    private var stand: GeraeteEinstellungDatei

    init(ordner: URL? = nil) {
        self.ordner = ordner
        stand = GeraeteEinstellungDatei.lesen(ordner)
    }

    func werte(studio: String, uebung: String) -> GeraeteWerte? {
        stand.eintraege[DefektLogik.schluessel(studio: studio, uebung: uebung)]
    }

    /// Überschreibt; leere Werte löschen den Eintrag.
    func setzen(_ werte: GeraeteWerte, studio: String, uebung: String) {
        let k = DefektLogik.schluessel(studio: studio, uebung: uebung)
        let sauber = werte.bereinigt
        if sauber.istLeer { stand.eintraege[k] = nil } else { stand.eintraege[k] = sauber }
        if let ordner { GeraeteEinstellungDatei.datei(ordner).speichere(stand) }
    }
}
