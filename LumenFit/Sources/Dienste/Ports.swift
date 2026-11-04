import Foundation

/// Gesetzt vom Modul widgets (ActivityKit). Standard: tut nichts.
protocol LiveAnzeige: Sendable {
    func training(_ stand: TrainingLiveStand?) async
}

/// Gesetzt vom Modul gym. Die Live-Activity-Knöpfe und Siri-Kurzbefehle rufen sie auf.
@MainActor protocol TrainingSteuerung: AnyObject {
    func starte(planTag: String?)
    func satzFertig()
    func naechsterSatzStarten()
    func pauseAendern(sekunden: Int)
    func beende()
}

struct BandStatus: Equatable, Sendable {
    var verbunden: Bool
    var akkuProzent: Int?
    var name: String?
}

/// Gesetzt vom Modul verbinden. Standard: nicht verbunden, `vibriere` tut nichts.
protocol BandDienst: Sendable {
    func status() async -> BandStatus
    func verbinde() async
    func trenne() async
    func vibriere(_ muster: BandMuster) async
}

/// Gesetzt vom Modul coach (Auswahl `CoachWahl`). Standard: Rückfalltext "Der Coach ist gleich da".
protocol CoachMotor: Sendable {
    var name: String { get }
    func verfuegbar() async -> Bool
    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort
}

// MARK: - Standardwerte, bis ein Modul den Port setzt

struct KeineLiveAnzeige: LiveAnzeige {
    func training(_ stand: TrainingLiveStand?) async {}
}

@MainActor final class KeineTrainingSteuerung: TrainingSteuerung {
    func starte(planTag: String?) {}
    func satzFertig() {}
    func naechsterSatzStarten() {}
    func pauseAendern(sekunden: Int) {}
    func beende() {}
}

struct KeinBand: BandDienst {
    func status() async -> BandStatus { BandStatus(verbunden: false, akkuProzent: nil, name: nil) }
    func verbinde() async {}
    func trenne() async {}
    func vibriere(_ muster: BandMuster) async {}
}

struct RueckfallCoachMotor: CoachMotor {
    var name: String { "Rückfall" }
    func verfuegbar() async -> Bool { true }
    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
        CoachAntwort(text: "Der Coach ist gleich da.", chips: [])
    }
}

struct KeinePartnerBruecke: PartnerAustausch {
    func partner(jetzt: Date) -> PartnerStand { .nichtVerbunden }
    func schreibe(zusammenfassung: ZusammenfassungDatei) {}
    func wuensche() -> [BandWunsch] { [] }
    func melde(erledigt ids: [String]) {}
    func schreibe(status: BandStatusDatei) {}
}
