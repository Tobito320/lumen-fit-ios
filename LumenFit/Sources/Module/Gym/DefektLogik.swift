// Quelle: Lovea Health/Defekt/DefektNotizen.swift (Datei im Profilordner statt UserDefaults)
import Foundation
import Observation

/// "Gerät kaputt oder wackelig": eine Notiz je Studio und Übung. Tage als `yyyy-MM-dd`.
struct DefektNotiz: Codable, Equatable, Sendable {
    var text: String? = nil
    var gemeldetAm: String
    /// "Wieder in Ordnung": gesetzt = erledigt, die Notiz zeigt sich nicht mehr.
    var erledigtAm: String? = nil

    var istOffen: Bool { erledigtAm == nil }

    init(text: String? = nil, gemeldetAm: String, erledigtAm: String? = nil) {
        self.text = text
        self.gemeldetAm = gemeldetAm
        self.erledigtAm = erledigtAm
    }

    /// Alle Felder tolerant: neue Felder machen alte Dateien nie unlesbar.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        gemeldetAm = try c.decodeIfPresent(String.self, forKey: .gemeldetAm) ?? ""
        erledigtAm = try c.decodeIfPresent(String.self, forKey: .erledigtAm)
    }

    private enum CodingKeys: String, CodingKey { case text, gemeldetAm, erledigtAm }
}

enum DefektLogik {
    /// Ab so vielen Tagen fragt die Karte "Noch defekt?".
    static let veraltetNachTagen = 30

    static func alter(_ notiz: DefektNotiz, heute: String) -> Int {
        guard !notiz.gemeldetAm.isEmpty else { return 0 }
        return max(0, Datum.tageZwischen(notiz.gemeldetAm, heute))
    }

    static func veraltet(_ notiz: DefektNotiz, heute: String) -> Bool { alter(notiz, heute: heute) > veraltetNachTagen }

    /// "heute", "gestern", "vor 3 Tagen".
    static func alterText(_ notiz: DefektNotiz, heute: String) -> String {
        switch alter(notiz, heute: heute) {
        case 0: "heute"
        case 1: "gestern"
        case let n: "vor \(n) Tagen"
        }
    }

    /// Die Ausweich-Übung, die als Erste vorgeschlagen wird. Nach einem Tausch rechnet die Logik von der ursprünglichen Übung aus.
    static func vorschlag(fuer u: WorkoutUebung) -> Uebung? {
        guard let aktuell = u.planUebung.katalog else { return nil }
        let vorlage = u.ersatzFuer.flatMap { UebungsKatalog.nachId[$0] } ?? aktuell
        return AusweichLogik.alternativen(fuer: vorlage).first { $0.id != aktuell.id }
    }

    /// Der Schlüssel einer Notiz: Studio (frei getippt, klein geschrieben) und Übung. Ohne Studio-Namen gilt "ohne-studio".
    static func schluessel(studio: String, uebung: String) -> String {
        let s = studio.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(s.isEmpty ? "ohne-studio" : s)|\(uebung)"
    }
}

/// Die Defekt-Notizen des Profils. Liegen im Profilordner (`defekte.json`), werden nicht synchronisiert: die Notiz hängt am Studio.
@MainActor @Observable
final class DefektStore {
    @ObservationIgnored private let datei: JSONDatei<[String: DefektNotiz]>?
    private var tabelle: [String: DefektNotiz] = [:]

    init(ordner: URL? = nil) {
        datei = ordner.map { JSONDatei<[String: DefektNotiz]>($0.appendingPathComponent("defekte.json")) }
        if let alt = datei?.lade() { tabelle = alt }
    }

    /// Nur die offene Notiz; erledigte zählen nicht.
    func offen(studio: String, uebung: String) -> DefektNotiz? {
        tabelle[DefektLogik.schluessel(studio: studio, uebung: uebung)].flatMap { $0.istOffen ? $0 : nil }
    }

    /// Meldet neu; eine frühere Notiz (auch eine erledigte) wird überschrieben. Leerer Text = ohne Text.
    func melden(text: String, studio: String, uebung: String, am tag: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        sichern(DefektNotiz(text: t.isEmpty ? nil : t, gemeldetAm: tag), studio, uebung)
    }

    func erledigen(studio: String, uebung: String, am tag: String) {
        guard var n = tabelle[DefektLogik.schluessel(studio: studio, uebung: uebung)] else { return }
        n.erledigtAm = tag
        sichern(n, studio, uebung)
    }

    /// "Noch defekt?" mit Ja: das Datum rückt auf heute.
    func bestaetigen(studio: String, uebung: String, am tag: String) {
        guard var n = tabelle[DefektLogik.schluessel(studio: studio, uebung: uebung)], n.istOffen else { return }
        n.gemeldetAm = tag
        sichern(n, studio, uebung)
    }

    private func sichern(_ n: DefektNotiz, _ studio: String, _ uebung: String) {
        tabelle[DefektLogik.schluessel(studio: studio, uebung: uebung)] = n
        datei?.speichere(tabelle)
    }
}
