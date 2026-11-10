// Quelle: Lovea Health/Tracker/BandRegeln.swift
import Foundation

/// Woher ein Puls am Armband kommen kann. Der Tracker kennt nur den einen Finden-Befehl (`TrackerProtokoll.findenAnfrage`): ein Puls von
/// fester Stärke und Länge (rund 5 bis 10 s). Was sich je Quelle einstellen lässt, ist darum nur: an/aus, Zahl der Pulse (1 bis 3) und
/// die Mindestpause bis zum nächsten Mal. Quellen aus Lovea, die es hier nicht gibt: Chat, Anruf, Termine (Chat und Anruf des Partners kommen als
/// Wunsch von Lovea, Termine gehören zu Lumen Alarm).
enum BandQuelle: String, CaseIterable, Identifiable, Sendable {
    case partner, wunsch, gymPause, gymPuls, sitzen

    var id: String { rawValue }

    var name: String {
        switch self {
        case .partner: String(localized: "Partner: Gym, Ziel, Schlaf")
        case .wunsch: String(localized: "Vibrationswünsche von Lovea")
        case .gymPause: String(localized: "Gym: Pause vorbei")
        case .gymPuls: String(localized: "Gym: Ziel-Puls erreicht")
        case .sitzen: String(localized: "Sitz-Erinnerung")
        }
    }

    var symbol: String {
        switch self {
        case .partner: "person.2.fill"
        case .wunsch: "bell.badge.fill"
        case .gymPause: "timer"
        case .gymPuls: "heart.fill"
        case .sitzen: "figure.stand"
        }
    }

    /// Nur diese dürfen durch die Ruhezeit, wenn die Ausnahme an ist: der Partner wollte es so.
    var kommtVomPartner: Bool { self == .partner || self == .wunsch }

    var standardAn: Bool {
        switch self {
        case .wunsch, .gymPause: true
        case .partner, .gymPuls, .sitzen: false
        }
    }

    var standardStaerke: BandNachrichtRegel.Staerke { self == .wunsch ? .normal : .sanft }

    /// Mindestpause in Minuten.
    var standardPause: Int {
        switch self {
        case .partner: BandNachrichtRegel.standardPause
        case .wunsch, .gymPause: 0
        case .gymPuls: 10
        case .sitzen: 60
        }
    }

    var pausen: [Int] {
        switch self {
        case .gymPuls: [5, 10, 15, 30]
        case .sitzen: [30, 45, 60, 90, 120]
        case .partner: BandNachrichtRegel.pausen
        default: [0, 1, 2, 5, 10, 15, 30]
        }
    }

    var pauseName: String { self == .sitzen ? String(localized: "Nach Minuten ohne Schritte") : String(localized: "Mindestpause") }

    private func schluessel(_ teil: String) -> String { "fit.band.\(rawValue).\(teil)" }
    var anSchluessel: String { schluessel("an") }
    var staerkeSchluessel: String { schluessel("staerke") }
    var pauseSchluessel: String { schluessel("pause") }
    var letzteSchluessel: String { schluessel("letzte") }

    func regel(_ d: UserDefaults) -> BandRegeln.Regel {
        BandRegeln.Regel(an: d.object(forKey: anSchluessel) as? Bool ?? standardAn,
                         staerke: d.string(forKey: staerkeSchluessel).flatMap(BandNachrichtRegel.Staerke.init(rawValue:)) ?? standardStaerke,
                         pauseMinuten: d.object(forKey: pauseSchluessel) as? Int ?? standardPause)
    }

    func letzte(_ d: UserDefaults) -> Date? {
        (d.object(forKey: letzteSchluessel) as? Double).map(Date.init(timeIntervalSince1970:))
    }
}

/// Reine Regeln für alle Pulse am Armband: Gate (Schalter, Arm, Akku, Ruhezeit, Pause), Ruhefenster, Ziel-Puls.
/// Ohne Gerät und Uhr testbar: Zeiten kommen als Parameter, Minuten sind Minuten seit Mitternacht (Berliner Zeit, `BandRegeln.minuteAmTag`).
enum BandRegeln {
    /// Zwischen zwei Pulsen derselben Quelle mindestens so lange, auch bei Mindestpause 0: dieselbe Meldung kann zweimal ankommen
    /// (Datei und Abruf), und eine Folge von drei Pulsen dauert rund 24 s.
    static let untergrenze: TimeInterval = 30

    struct Regel: Equatable, Sendable {
        var an: Bool
        var staerke: BandNachrichtRegel.Staerke
        var pauseMinuten: Int
    }

    /// Ein Zeitfenster am Tag. `bis` kleiner als `von` läuft über Mitternacht; gleich heißt leer (nie).
    struct Zeitfenster: Codable, Equatable, Sendable {
        var von: Int
        var bis: Int

        func enthaelt(_ minute: Int) -> Bool {
            if von == bis { return false }
            return von < bis ? (minute >= von && minute < bis) : (minute >= von || minute < bis)
        }
    }

    struct Umfeld: Equatable, Sendable {
        /// `nil` = unbekannt, dann trotzdem vibrieren.
        var bandAmArm: Bool?
        /// Band-Akku in Prozent; `nil` = unbekannt, dann nicht sperren.
        var akku: Int?
        /// Unter diesem Wert keine Pulse mehr; 0 = Wächter aus.
        var akkuSchwelle: Int
        var ruhe: [Zeitfenster]
        /// Der Partner (Ereignis, Wunsch) darf durch die Ruhezeit.
        var ruheAusnahme: Bool
    }

    enum Grund: Equatable, Sendable {
        case aus, nichtAmArm, akkuNiedrig, ruhezeit, pause
    }

    /// Die Nacht, wenn nichts anderes eingestellt ist: 22:00 bis 07:00 (Lumen Fit kennt keinen Wecker, an dem sie enden könnte).
    static let standardNacht = Zeitfenster(von: 22 * 60, bis: 7 * 60)

    /// Minuten seit Mitternacht in Berliner Zeit.
    static func minuteAmTag(_ datum: Date) -> Int {
        let teile = Datum.kalender.dateComponents([.hour, .minute], from: datum)
        return (teile.hour ?? 0) * 60 + (teile.minute ?? 0)
    }

    /// Akku und Ruhezeit. `nil` = frei. Gilt für alle Quellen; die Pause und der Schalter der Quelle prüft `pruefen`.
    static func umfeldGrund(_ quelle: BandQuelle, minute: Int, umfeld: Umfeld) -> Grund? {
        if umfeld.bandAmArm == false { return .nichtAmArm }
        if umfeld.akkuSchwelle > 0, let akku = umfeld.akku, akku < umfeld.akkuSchwelle { return .akkuNiedrig }
        if umfeld.ruhe.contains(where: { $0.enthaelt(minute) }), !(quelle.kommtVomPartner && umfeld.ruheAusnahme) { return .ruhezeit }
        return nil
    }

    /// Springt die Uhr zurück, ist die Pause vorbei. Die Pause läuft ab dem letzten Puls dieser Quelle.
    static func pauseVorbei(letzte: Date?, jetzt: Date, minuten: Int) -> Bool {
        guard let letzte else { return true }
        let seitdem = jetzt.timeIntervalSince(letzte)
        return seitdem < 0 || seitdem >= max(untergrenze, TimeInterval(minuten * 60))
    }

    /// Warum nicht vibriert wird; `nil` = vibrieren. Reihenfolge: Schalter, Band am Arm, Akku, Ruhezeit, Pause.
    static func pruefen(_ quelle: BandQuelle, regel: Regel, letzte: Date?, jetzt: Date, minute: Int, umfeld: Umfeld) -> Grund? {
        guard regel.an else { return .aus }
        if let grund = umfeldGrund(quelle, minute: minute, umfeld: umfeld) { return grund }
        return pauseVorbei(letzte: letzte, jetzt: jetzt, minuten: regel.pauseMinuten) ? nil : .pause
    }

    // MARK: Sitzen

    /// Ein Puls fürs Aufstehen: Schrittdaten sind frisch, es ist im Tageszeitfenster, und seit der letzten Bewegung (oder dem
    /// Fensterbeginn heute, wenn die später war) sind `schwelleMinuten` vergangen. Danach höchstens alle `schwelleMinuten` wieder.
    static func sitzFaellig(letzteBewegung: Date?, fensterAnfang: Date, letzterPuls: Date?, jetzt: Date, schwelleMinuten: Int,
                            fenster: Zeitfenster, minute: Int, schrittdatenFrisch: Bool) -> Bool {
        guard schrittdatenFrisch, fenster.enthaelt(minute) else { return false }
        let bezug = max(letzteBewegung ?? fensterAnfang, fensterAnfang)
        let schwelle = TimeInterval(schwelleMinuten * 60)
        guard jetzt.timeIntervalSince(bezug) >= schwelle else { return false }
        guard let letzterPuls else { return true }
        let seitdem = jetzt.timeIntervalSince(letzterPuls)
        return seitdem < 0 || seitdem >= schwelle
    }

    /// Ende der letzten Viertelstunde mit Schritten (`BandTag.letzteMinute` ist ihr Anfang).
    static func bewegungsEnde(letzteMinute: Int?, tagAnfang: Date) -> Date? {
        letzteMinute.map { tagAnfang.addingTimeInterval(TimeInterval(($0 + 15) * 60)) }
    }

    // MARK: Gym

    /// Ziel-Puls erreicht: ein Training läuft und der jüngste Pulswert vom Band ist nicht älter als `alter` und mindestens `ziel`.
    static func zielPulsErreicht(training: Bool, puls: Int?, zeit: Date?, jetzt: Date, ziel: Int, alter: TimeInterval = 10 * 60) -> Bool {
        guard training, let puls, let zeit else { return false }
        let seitdem = jetzt.timeIntervalSince(zeit)
        return seitdem >= -60 && seitdem <= alter && puls >= ziel
    }
}

/// Wie ein Wunsch von Lovea (`BandMuster`) am Band ankommt. Das Band kann nur Pulse gleicher Länge: kurz ist ein Puls, lang und doppelt sind
/// zwei, ruf sind drei. `pauseEnde` nimmt die Stärke, die für "Gym: Pause vorbei" eingestellt ist.
enum BandMusterRegel {
    static func staerke(_ muster: BandMuster, pauseEnde: BandNachrichtRegel.Staerke) -> BandNachrichtRegel.Staerke {
        switch muster {
        case .kurz: .sanft
        case .lang, .doppelt: .normal
        case .ruf: .stark
        case .pauseEnde: pauseEnde
        }
    }

    static func quelle(_ muster: BandMuster) -> BandQuelle { muster == .pauseEnde ? .gymPause : .wunsch }
}
