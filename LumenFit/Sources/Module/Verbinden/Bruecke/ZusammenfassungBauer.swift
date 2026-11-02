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
        /// Wassergläser heute; nur mit Freigabe essen in der Datei.
        var wasserGlaeser: Int? = nil
        // Ansichten des Partners (Plan, Verlauf, Tagebuch, Körper): nil oder leer heißt "nichts zu sagen". Jedes Feld hat genau seine Freigabe.
        var plan: PartnerPlan? = nil
        var verlauf: PartnerVerlauf? = nil
        var tagebuch: [PartnerTagebuchTag] = []
        var tagebuchZiele: PartnerMakros? = nil
        var koerper: [String: [PartnerMesspunkt]] = [:]
        // Stimmung (Morgen-Check) und alle Gewohnheiten mit Serie und Quote: je mit ihrer Freigabe.
        var stimmung: Int? = nil
        var gewohnheiten: [GewohnheitStand] = []
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
        if e.freigaben.contains(.essen) { heute.wasserGlaeser = e.wasserGlaeser }
        ansichten(&heute, e)
    }

    /// Plan, Verlauf, Tagebuch und Körperwerte: je nur mit der eigenen Freigabe (Standard aus), leere Listen werden zu "nicht da".
    private static func ansichten(_ heute: inout TagesZusammenfassung, _ e: Eingabe) {
        if e.freigaben.contains(.plan) { heute.plan = e.plan }
        if e.freigaben.contains(.verlauf) {
            var v = e.verlauf
            // Sätze und Trainingstage nur mit der zusätzlichen Freigabe gym (der Server prüft es noch einmal).
            if !e.freigaben.contains(.gym) { v?.tage = nil; v?.einheiten = nil }
            heute.verlauf = v
        }
        if e.freigaben.contains(.tagebuch) {
            heute.tagebuch = e.tagebuch.isEmpty ? nil : e.tagebuch
            heute.tagebuchZiele = e.tagebuch.isEmpty ? nil : e.tagebuchZiele
        }
        if e.freigaben.contains(.koerper) { heute.koerper = e.koerper.isEmpty ? nil : e.koerper }
        if e.freigaben.contains(.stimmung) {
            heute.stimmung = e.stimmung
        }
        if e.freigaben.contains(.gewohnheiten) { heute.gewohnheiten = e.gewohnheiten.isEmpty ? nil : e.gewohnheiten }
    }

    static func baue(_ e: Eingabe) -> ZusammenfassungDatei {
        var heute = TagesZusammenfassung(tag: Datum.text(e.jetzt))
        if e.freigaben.contains(.schritte) { heute.schritte = e.schritte }
        if e.freigaben.contains(.gym) { heute.gymTageWoche = e.gymTageWoche }
        if e.freigaben.contains(.schlaf) { heute.schlafMinuten = e.schlafMinuten }
        if e.freigaben.contains(.essen) { heute.kcal = e.kcal }
        erweitere(&heute, e)
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
