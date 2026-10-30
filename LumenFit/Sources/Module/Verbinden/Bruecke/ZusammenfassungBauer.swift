import Foundation

/// Baut `zusammenfassung.json` (SPEC 5.5): nur Zusammenfassungen, nur die Datenarten, die der Nutzer freigegeben hat (Standard keine), nie Rohdaten.
/// Rein und ohne Stores testbar: die Werte kommen als Parameter, der Aufrufer (`LoveaBrueckeDienst`) liest sie aus den Stores.
enum ZusammenfassungBauer {
    struct Eingabe: Sendable {
        var name: String
        var jetzt: Date
        var freigaben: Set<FreigabeArt>
        var schritte: Int?
        var gymTageWoche: Int?
        var schlafMinuten: Int?
        var kcal: Int?
        var ereignisse: [PartnerEreignis]
        // Erweiterung (Gleichstand Health): leer oder nil heißt "nichts zu sagen", dann steht das Feld nicht in der Datei.
        var schritteZiel: Int? = nil
        var schritteWoche: [String: Int] = [:]
        var gymTage: Set<String> = []
        var gymZiel: Int? = nil
        var schlafWoche: [String: Int] = [:]
        var schlafZiel: Int? = nil
        var energieStufe: String? = nil
        var energieGym: String? = nil
        /// Eingebaute Gewohnheiten, die heute erledigt sind (`gym`, `wasser`); der Bauer gibt nur frei, was die Freigabe erlaubt.
        var habitsFertig: Set<String> = []
        /// Zyklus-Hinweise für den Partner; schon von der Quelle nur gesetzt, wenn die Person es erlaubt hat.
        var zyklus: ZyklusZusammenfassung? = nil
    }

    /// So lange bleiben eigene Ereignisse in der Datei; ältere sind erledigt.
    nonisolated static let ereignisFrist: TimeInterval = 48 * 3600
    nonisolated static let ereignisMaximal = 20

    /// Welche Freigabe ein Ereignis braucht: Gym, Rekord und Gym-Ende gehören zum Gym, das Ziel zu den Schritten, gut geschlafen zum Schlaf.
    static func freigabe(fuer art: PartnerEreignisArt) -> FreigabeArt {
        switch art {
        case .gymStart, .gymEnde, .rekord: .gym
        case .ziel: .schritte
        case .schlafGut: .schlaf
        }
    }

    /// Die Wochenwerte, den Energie-Rat und die Gewohnheiten, je nur mit der Freigabe ihrer Art (Energie hängt am Schlaf, ihr Gym-Satz zusätzlich am Gym).
    private static func erweitere(_ heute: inout TagesZusammenfassung, _ e: Eingabe) {
        if e.freigaben.contains(.schritte) {
            heute.schritteZiel = e.schritteZiel
            heute.schritteWoche = e.schritteWoche.isEmpty ? nil : e.schritteWoche
        }
        if e.freigaben.contains(.gym) {
            heute.gymTage = e.gymTage.isEmpty ? nil : e.gymTage.sorted()
            heute.gymZiel = e.gymZiel
        }
        if e.freigaben.contains(.schlaf) {
            heute.schlafWoche = e.schlafWoche.isEmpty ? nil : e.schlafWoche
            heute.schlafZiel = e.schlafZiel
            heute.energieStufe = e.energieStufe
            if e.freigaben.contains(.gym) { heute.energieGym = e.energieStufe == nil ? nil : e.energieGym }
        }
        var fertig: Set<String> = []
        if e.freigaben.contains(.gym), e.habitsFertig.contains("gym") { fertig.insert("gym") }
        if e.freigaben.contains(.essen), e.habitsFertig.contains("wasser") { fertig.insert("wasser") }
        heute.habitsFertig = fertig.isEmpty ? nil : fertig.sorted()
    }

    static func baue(_ e: Eingabe) -> ZusammenfassungDatei {
        var heute = TagesZusammenfassung(tag: Datum.text(e.jetzt))
        if e.freigaben.contains(.schritte) { heute.schritte = e.schritte }
        if e.freigaben.contains(.gym) { heute.gymTageWoche = e.gymTageWoche }
        if e.freigaben.contains(.schlaf) { heute.schlafMinuten = e.schlafMinuten }
        if e.freigaben.contains(.essen) { heute.kcal = e.kcal }
        erweitere(&heute, e)
        heute.zyklus = e.zyklus
        let erlaubt = e.ereignisse
            .filter { e.freigaben.contains(freigabe(fuer: $0.art)) && e.jetzt.timeIntervalSince($0.zeit) <= ereignisFrist }
            .sorted { $0.zeit < $1.zeit }
            .suffix(ereignisMaximal)
        return ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: e.jetzt, profilName: e.name,
                                    freigaben: FreigabeArt.allCases.filter { e.freigaben.contains($0) },
                                    heute: heute, ereignisse: Array(erlaubt))
    }
}

/// Die eigenen Ereignisse (Gym gestartet und beendet, Rekord, Ziel, Schlaf gut), die in `zusammenfassung.json` stehen, solange sie frisch sind.
/// Gleiche `id` zählt einmal. Liegen als Datei im Profilordner (`ereignisse-gesendet.json`), damit ein Neustart sie nicht vergisst.
@MainActor
final class EigeneEreignisse {
    private let datei: JSONDatei<[PartnerEreignis]>?
    private(set) var liste: [PartnerEreignis]

    /// Ohne Ordner nur im Speicher (Tests).
    init(ordner: URL?) {
        datei = ordner.map { JSONDatei<[PartnerEreignis]>($0.appendingPathComponent("ereignisse-gesendet.json")) }
        liste = datei?.lade() ?? []
    }

    /// `true`, wenn das Ereignis neu war.
    @discardableResult
    func fuegeHinzu(_ ereignis: PartnerEreignis, jetzt: Date) -> Bool {
        guard !liste.contains(where: { $0.id == ereignis.id }) else { return false }
        liste.append(ereignis)
        liste.removeAll { jetzt.timeIntervalSince($0.zeit) > ZusammenfassungBauer.ereignisFrist }
        datei?.speichere(liste)
        return true
    }
}
