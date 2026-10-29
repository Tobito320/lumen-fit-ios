import Foundation
import Observation

/// Eine kleine, wegwischbare Karte des Tages (Idee 19). `id` ist je Anlass und Tag (oder Woche) eindeutig, damit eine weggewischte Karte nicht zurückkommt.
struct TagesHinweis: Identifiable, Equatable, Sendable {
    /// Wohin ein Tipp auf die Karte führt; nil = die Karte ist nur zum Lesen.
    enum Ziel: Equatable, Sendable { case rueckblick }

    var id: String
    var symbol: String
    var titel: String
    var text: String
    var ziel: Ziel? = nil
}

/// Die Regeln der Hinweise des Tages. Reine Logik; jede Regel nennt ihre echte Zahl. Höchstens `hoechstens` Karten, wichtigste zuerst.
enum TagesHinweisLogik {
    static let hoechstens = 3

    struct Eingabe: Sendable {
        var heute: String
        var stunde = 12
        /// Schlafminuten je Aufwachtag.
        var schlafMinuten: [String: Int] = [:]
        var schritte: [String: Int] = [:]
        var schritteZiel = 10_000
        var gymTage: Set<String> = []
        var gymZielWoche = 3
        var gymInFolge = 0
        var wasserHeute = 0
        var wasserZiel = 8
        /// Tage mit Gewichtseintrag.
        var gewichtTage: [String] = []
    }

    static let kurzeNachtBis = 360

    /// Alle Anlässe von heute in der Reihenfolge ihrer Wichtigkeit.
    static func regeln(_ e: Eingabe) -> [TagesHinweis] {
        var liste: [TagesHinweis] = []
        let gestern = Datum.addTage(e.heute, -1)
        liste += rueckblickKarten(e)
        if let heute = e.schlafMinuten[e.heute], let davor = e.schlafMinuten[gestern], heute < kurzeNachtBis, davor < kurzeNachtBis {
            liste.append(TagesHinweis(id: "schlaf-kurz-\(e.heute)", symbol: "bed.double.fill", titel: "Zweimal unter 6 Stunden",
                                      text: "\(BereitScore.stunden(davor)) und \(BereitScore.stunden(heute)). Heute locker, früh ins Bett."))
        }
        if e.gymInFolge >= 3 {
            liste.append(TagesHinweis(id: "gym-folge-\(e.heute)", symbol: "dumbbell.fill", titel: "\(e.gymInFolge) Tage Gym am Stück",
                                      text: "Plane einen Ruhetag ein, dann bleibt die Kraft."))
        }
        let woche = HabitLogik.wochenTage(heute: e.heute)
        let gym = e.gymTage.intersection(Set(woche)).count
        let uebrig = 7 - Datum.wochentag(e.heute) + (e.gymTage.contains(e.heute) ? 0 : 1)
        if e.gymZielWoche > 0, gym < e.gymZielWoche, Datum.wochentag(e.heute) >= 5 {
            let fehlt = e.gymZielWoche - gym
            liste.append(TagesHinweis(id: "gym-woche-\(woche[0])", symbol: "calendar", titel: "Noch \(fehlt) \(fehlt == 1 ? "Gym-Tag" : "Gym-Tage") bis zum Wochenziel",
                                      text: "\(gym) von \(e.gymZielWoche) Tagen, noch \(uebrig) \(uebrig == 1 ? "Tag" : "Tage") in der Woche."))
        }
        if e.wasserZiel > 0, e.stunde >= 16, e.wasserHeute * 2 < e.wasserZiel {
            liste.append(TagesHinweis(id: "wasser-\(e.heute)", symbol: "drop.fill", titel: "Wenig Wasser bisher",
                                      text: "\(e.wasserHeute) von \(e.wasserZiel) Gläsern. Ein Glas jetzt hilft."))
        }
        if let letzter = e.gewichtTage.max(), Datum.tageZwischen(letzter, e.heute) >= 7 {
            liste.append(TagesHinweis(id: "gewicht-\(e.heute)", symbol: "scalemass.fill", titel: "Länger nicht gewogen",
                                      text: "Dein letzter Eintrag ist \(Datum.tageZwischen(letzter, e.heute)) Tage her. Drei Sekunden reichen."))
        }
        let serie = (0..<3).allSatisfy { (e.schritte[Datum.addTage(e.heute, -$0)] ?? 0) >= e.schritteZiel && e.schritteZiel > 0 }
        if serie {
            liste.append(TagesHinweis(id: "schritte-serie-\(e.heute)", symbol: "figure.walk", titel: "Drei Tage über dem Schrittziel",
                                      text: "Das hält dein Herz fit. Weiter so."))
        }
        return liste
    }

    /// Die Sonntagskarte (Idee 39): sonntags der Wochenrückblick, am letzten Tag des Monats der Monatsrückblick. Ein Tipp öffnet den Rückblick.
    /// Nur eine Karte beim Öffnen der App, keine Mitteilung und keine Erinnerung (Lumen Fit ist nur Health).
    static func rueckblickKarten(_ e: Eingabe) -> [TagesHinweis] {
        var karten: [TagesHinweis] = []
        let woche = HabitLogik.wochenTage(heute: e.heute)
        if Datum.wochentag(e.heute) == 7 {
            let gym = e.gymTage.intersection(Set(woche)).count
            karten.append(TagesHinweis(id: "rueckblick-woche-\(woche[0])", symbol: "calendar", titel: "Dein Wochenrückblick ist da",
                                       text: "\(gym) \(gym == 1 ? "Gym-Tag" : "Gym-Tage") diese Woche. Tippe, um ihn anzusehen und zu teilen.", ziel: .rueckblick))
        }
        if Datum.addTage(e.heute, 1).prefix(7) != e.heute.prefix(7) {
            karten.append(TagesHinweis(id: "rueckblick-monat-\(e.heute.prefix(7))", symbol: "calendar.badge.clock", titel: "Dein Monatsrückblick ist da",
                                       text: "Der Monat ist rum. Tippe, um ihn anzusehen und zu teilen.", ziel: .rueckblick))
        }
        return karten
    }

    /// Die Insights aus dem Training (`HeuteHinweisLogik`, "Das fällt mir auf") als Karten. Gesperrte (noch ohne Daten) fehlen.
    static func ausEinsichten(_ einsichten: [HeuteHinweis], heute: String) -> [TagesHinweis] {
        einsichten.filter { $0.art != .gesperrt }.map {
            TagesHinweis(id: "einsicht-\($0.id)-\(Datum.montagDerWoche(heute))", symbol: "lightbulb.fill", titel: $0.titel, text: "\($0.text) \($0.tipp)")
        }
    }

    /// Was auf dem Bildschirm steht: ohne die weggewischten, höchstens drei.
    static func zeige(_ alle: [TagesHinweis], weggewischt: Set<String>) -> [TagesHinweis] {
        Array(alle.filter { !weggewischt.contains($0.id) }.prefix(hoechstens))
    }
}

/// Merkt sich weggewischte Karten im Profilordner (`heute-hinweise.json`). Es bleiben die letzten 90 Ids.
@MainActor @Observable
final class TagesHinweisSpeicher {
    nonisolated static let dateiname = "heute-hinweise.json"
    nonisolated static let behalten = 90

    private(set) var weggewischt: [String]
    @ObservationIgnored private let datei: JSONDatei<[String]>?

    /// Ohne Ordner nur im Speicher.
    init(ordner: URL? = nil) {
        let d = ordner.map { JSONDatei<[String]>($0.appendingPathComponent(Self.dateiname)) }
        datei = d
        weggewischt = d?.lade() ?? []
    }

    var ids: Set<String> { Set(weggewischt) }

    func wische(_ id: String) {
        guard !weggewischt.contains(id) else { return }
        weggewischt = Array((weggewischt + [id]).suffix(Self.behalten))
        datei?.speichere(weggewischt)
    }
}
