// Quelle: Lovea Health/Tracker/BandPuls.swift
import Foundation
import UIKit

/// Einstellungen der Band-Vibration, die nicht zu einer Quelle gehören (Quellen: `BandQuelle`). Liegen in `UserDefaults`: das Band gehört dem Gerät,
/// nicht dem Profil.
enum BandEinstellung {
    static let akkuSchwelle = "fit.band.akku.schwelle"
    static let standardAkkuSchwelle = 15
    static let akkuSchwellen = [0, 10, 15, 20, 30]
    static let nachtAn = "fit.band.ruhe.nacht"
    static let fenster = "fit.band.ruhe.fenster"
    static let ausnahme = "fit.band.ruhe.ausnahme"
    static let maxFenster = 3
    static let zielPuls = "fit.band.gymPuls.ziel"
    static let standardZielPuls = 150
    static let zielPulse = [120, 130, 140, 150, 160, 170, 180]
    static let sitzVon = "fit.band.sitzen.von"
    static let sitzBis = "fit.band.sitzen.bis"
    static let standardSitzVon = 9 * 60
    static let standardSitzBis = 20 * 60

    static func fensterListe(_ d: UserDefaults = .standard) -> [BandRegeln.Zeitfenster] {
        d.data(forKey: fenster).flatMap { try? JSONDecoder().decode([BandRegeln.Zeitfenster].self, from: $0) } ?? []
    }

    static func fensterSpeichern(_ liste: [BandRegeln.Zeitfenster], _ d: UserDefaults = .standard) {
        d.set(try? JSONEncoder().encode(liste), forKey: fenster)
    }
}

/// Gibt Pulse am Armband aus. Ereignisgetrieben, kein Timer: Partner-Ereignisse (`PartnerEreignisRegeln`), Wünsche von Lovea
/// (`BandWunschSchlange`), das Pausen-Ende (`BandDienstImpl.vibriere`) und das Ende einer Tracker-Runde (`rundeEnde`) rufen hierher.
/// Alles Äußere (Verbindung, Umfeld, Warten) kommt als Rückruf, damit die Regeln ohne Band testbar sind.
@MainActor
final class BandPuls {
    private let finden: @MainActor () -> Void
    private let verbunden: @MainActor () -> Bool
    private let umfeldLeser: @MainActor (Date) -> BandRegeln.Umfeld
    private let defaults: UserDefaults
    private let warte: @Sendable (TimeInterval) async -> Void
    /// Hält die App für die Folge von Pulsen wach, wenn der Abruf sie im Hintergrund geweckt hat (nur bei mehr als einem Puls).
    private var hintergrund = UIBackgroundTaskIdentifier.invalid
    /// Eine Folge läuft: eine zweite würde mitten in einen Puls fallen (ob das Band das als eigenen Puls nimmt, ist ungeprüft).
    private(set) var laeuft = false

    init(finden: @escaping @MainActor () -> Void, verbunden: @escaping @MainActor () -> Bool,
         umfeld: @escaping @MainActor (Date) -> BandRegeln.Umfeld, defaults: UserDefaults = .standard,
         warte: @escaping @Sendable (TimeInterval) async -> Void = { _ = try? await Task.sleep(for: .seconds($0)) }) {
        self.finden = finden
        self.verbunden = verbunden
        self.umfeldLeser = umfeld
        self.defaults = defaults
        self.warte = warte
    }

    // MARK: Ausgabe

    /// Schickt die Pulse der Regel, ohne weitere Prüfung; merkt sich den Zeitpunkt für die Mindestpause. Eine laufende Folge geht vor.
    /// Liefert die Aufgabe, die endet, wenn die Folge durch ist (für Tests).
    @discardableResult
    func ausgeben(_ quelle: BandQuelle, _ staerke: BandNachrichtRegel.Staerke, _ jetzt: Date, merken: Bool = true) -> Task<Void, Never>? {
        guard !laeuft else { return nil }
        laeuft = true
        if merken { defaults.set(jetzt.timeIntervalSince1970, forKey: quelle.letzteSchluessel) }
        let zeiten = BandNachrichtRegel.zeiten(staerke)
        if zeiten.count > 1, hintergrund == .invalid {
            hintergrund = UIApplication.shared.beginBackgroundTask(withName: "LumenFit-Band-Puls") { [weak self] in
                // Zeit um: Fenster sofort zurückgeben (der Handler läuft auf dem Hauptthread), sonst beendet iOS die App. Die übrigen Pulse fehlen dann.
                MainActor.assumeIsolated { self?.hintergrundEnde() }
            }
        }
        return Task { @MainActor [weak self] in
            var davor: TimeInterval = 0
            for bei in zeiten {
                if bei > davor { await self?.warte(bei - davor) }
                davor = bei
                self?.finden()
            }
            self?.laeuft = false
            self?.hintergrundEnde()
        }
    }

    private func hintergrundEnde() {
        guard hintergrund != .invalid else { return }
        UIApplication.shared.endBackgroundTask(hintergrund)
        hintergrund = .invalid
    }

    /// Prüft die Regeln der Quelle und vibriert. `staerke` überschreibt die eingestellte (Wünsche mit eigenem Muster).
    /// Liefert den Grund, warum nicht vibriert wurde, oder `nil`, wenn die Folge gestartet wurde.
    @discardableResult
    func ausloesen(_ quelle: BandQuelle, staerke: BandNachrichtRegel.Staerke? = nil, jetzt: Date = Date()) -> BandRegeln.Grund? {
        guard verbunden() else { return .nichtAmArm }
        let regel = quelle.regel(defaults)
        if let grund = BandRegeln.pruefen(quelle, regel: regel, letzte: quelle.letzte(defaults), jetzt: jetzt,
                                          minute: BandRegeln.minuteAmTag(jetzt), umfeld: umfeldLeser(jetzt)) { return grund }
        ausgeben(quelle, staerke ?? regel.staerke, jetzt)
        return nil
    }

    /// Ein Wunsch von Lovea oder das Pausen-Ende: das Muster bestimmt die Pulse, die Regeln der Quelle bleiben.
    @discardableResult
    func muster(_ muster: BandMuster, jetzt: Date = Date()) -> BandRegeln.Grund? {
        let quelle = BandMusterRegel.quelle(muster)
        let eingestellt = BandQuelle.gymPause.regel(defaults).staerke
        return ausloesen(quelle, staerke: BandMusterRegel.staerke(muster, pauseEnde: eingestellt), jetzt: jetzt)
    }

    /// Ein Weck-Wunsch von Lumen Alarm: ohne Schalter der Quelle, Ruhezeit, Akku-Wächter und Mindestpause (ein Wecker soll auch nachts und dicht hintereinander
    /// summen) und ohne die Pause der Quelle zu stempeln. Nur das Band muss verbunden sein. `lang` ist genau ein Puls und läuft auch, während eine Folge läuft
    /// (die Wellen von Lumen Alarm liegen im 2-Sekunden-Takt); die anderen Muster geben ihre Pulse als Folge. `false`: Band nicht verbunden, später noch einmal.
    @discardableResult
    func wecker(_ muster: BandMuster, jetzt: Date = Date()) -> Bool {
        guard verbunden() else { return false }
        if muster == .lang { finden(); return true }
        ausgeben(.wunsch, BandMusterRegel.staerke(muster, pauseEnde: .normal), jetzt, merken: false)
        return true
    }

    // MARK: Ziel-Puls und Sitzen

    /// Ende einer Tracker-Runde (`TrackerModell.abschliessen`): hier kommen frische Zahlen vom Band. Ziel-Puls im Training, Sitz-Erinnerung.
    /// Läuft nur, wenn iOS die App für Band-Daten weckt: ein Takt ist nicht garantiert. `heute` und `stand`: Schritte von heute und Ende der letzten vollen Abfrage.
    func rundeEnde(training: Bool, puls: Int?, zeit: Date?, heute: BandTag? = nil, stand: Date? = nil, jetzt: Date = Date()) {
        let ziel = defaults.object(forKey: BandEinstellung.zielPuls) as? Int ?? BandEinstellung.standardZielPuls
        if BandRegeln.zielPulsErreicht(training: training, puls: puls, zeit: zeit, jetzt: jetzt, ziel: ziel) { ausloesen(.gymPuls, jetzt: jetzt) }
        sitzen(heute: heute, stand: stand, jetzt: jetzt)
    }

    /// Sitz-Erinnerung: nur mit Schalter, nur mit Schritten von heute und Daten, die nicht älter als 20 Minuten sind. Die Pause der Quelle ist hier die Zeit ohne Schritte.
    private func sitzen(heute: BandTag?, stand: Date?, jetzt: Date) {
        let quelle = BandQuelle.sitzen
        let regel = quelle.regel(defaults)
        guard regel.an, let heute else { return }
        let tagAnfang = Datum.datum(Datum.text(jetzt))
        let fenster = BandRegeln.Zeitfenster(von: defaults.object(forKey: BandEinstellung.sitzVon) as? Int ?? BandEinstellung.standardSitzVon,
                                             bis: defaults.object(forKey: BandEinstellung.sitzBis) as? Int ?? BandEinstellung.standardSitzBis)
        let frisch = stand.map { jetzt.timeIntervalSince($0) < 20 * 60 } ?? false
        guard BandRegeln.sitzFaellig(letzteBewegung: BandRegeln.bewegungsEnde(letzteMinute: heute.letzteMinute, tagAnfang: tagAnfang),
                                     fensterAnfang: tagAnfang.addingTimeInterval(TimeInterval(fenster.von * 60)),
                                     letzterPuls: quelle.letzte(defaults), jetzt: jetzt, schwelleMinuten: regel.pauseMinuten,
                                     fenster: fenster, minute: BandRegeln.minuteAmTag(jetzt), schrittdatenFrisch: frisch) else { return }
        ausloesen(quelle, jetzt: jetzt)
    }

    // MARK: Umfeld

    /// Band am Arm, Akku, Ruhefenster aus den Einstellungen. Der Akku zählt nur, wenn er in den letzten 12 Stunden gelesen wurde.
    static func umfeld(_ jetzt: Date, defaults d: UserDefaults = .standard, bandAmArm: Bool?, akku: Int?, akkuGelesen: Date?) -> BandRegeln.Umfeld {
        var ruhe = BandEinstellung.fensterListe(d)
        if d.object(forKey: BandEinstellung.nachtAn) as? Bool ?? true { ruhe.append(BandRegeln.standardNacht) }
        let frisch = akkuGelesen.map { jetzt.timeIntervalSince($0) < 12 * 3600 } ?? false
        return BandRegeln.Umfeld(bandAmArm: bandAmArm, akku: frisch ? akku : nil,
                                 akkuSchwelle: d.object(forKey: BandEinstellung.akkuSchwelle) as? Int ?? BandEinstellung.standardAkkuSchwelle,
                                 ruhe: ruhe, ruheAusnahme: d.object(forKey: BandEinstellung.ausnahme) as? Bool ?? true)
    }
}
