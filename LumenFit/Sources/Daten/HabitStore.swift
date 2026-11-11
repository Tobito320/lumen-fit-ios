// Quelle: Lovea Health/HealthModell.swift (Habit-Teil, ohne Person, Punkte, Widget-Warteschlange)
import Foundation
import Observation

/// Gewohnheiten des Profils (`HabitFaltung`): Werte je Tag, Definitionen, Ausblenden, Löschen. Gym, Wasser, Koffein, Protein und Gewicht sind eingebaut.
@MainActor @Observable
final class HabitStore {
    @ObservationIgnored private let raum: LokalerRaum
    @ObservationIgnored private let ziele: ZieleStore?
    @ObservationIgnored private let ereignisse: EreignisKanal?
    @ObservationIgnored private let uhr: Uhr
    private var faltung = HabitFaltung()

    static let arten: Set<String> = ["habit.setzen", "habit.anlegen", "habit.aendern", "habit.ausblenden", "habit.loeschen"]

    init(raum: LokalerRaum, ziele: ZieleStore? = nil, ereignisse: EreignisKanal? = nil, uhr: @escaping Uhr = { Date() }) {
        self.raum = raum
        self.ziele = ziele
        self.ereignisse = ereignisse
        self.uhr = uhr
        faltung = raum.falten(Self.arten, HabitFaltung(), live: { [weak self] op in self?.faltung.anwenden(op) }) { $0.anwenden($1) }
    }

    var ich: ProfilID { raum.profil }

    // MARK: - Lesen

    /// Jede Gewohnheit samt Gym und Wasser; `ausgeblendet` wie vom Profil gesetzt.
    var habits: [String: Habit] { faltung.habits(ich: ich) }
    /// Ohne ausgeblendete; Gym, Wasser, dann in der Reihenfolge des Anlegens.
    var sichtbar: [Habit] { faltung.sichtbar(fuer: ich) }
    func wert(_ id: String, _ tag: String) -> Int { faltung.werte[id]?[ich]?[tag]?.wert ?? 0 }
    func werte(_ id: String) -> [String: Int] { (faltung.werte[id]?[ich] ?? [:]).mapValues(\.wert) }
    func gymAbgehakt(_ tag: String) -> Bool { wert(Habit.gym.id, tag) > 0 }

    /// Das Ziel für `HabitLogik`: Gyms Wochenziel und Wassers Tagesziel, nil für eigene Gewohnheiten.
    func habitZiel(_ id: String) -> Int? {
        switch id {
        case Habit.gym.id: return ziele?.ziele.gymTageProWoche ?? 3
        case Habit.wasser.id: return Habit.wasser.tagesziel
        default: return nil
        }
    }

    // MARK: - Schreiben

    func setze(_ id: String, datum: String, wert: Int, storniert: String? = nil) {
        raum.senden("habit.setzen", HabitSetzenD(art: id, datum: datum, wert: max(0, wert), storniert: storniert))
        ereignisse?.senden(.habitGeaendert(tag: datum))
    }

    func anlegen(_ habit: Habit) { raum.senden("habit.anlegen", habit) }
    func aendern(_ habit: Habit) { raum.senden("habit.aendern", habit) }
    func loeschen(_ id: String) { raum.senden("habit.loeschen", HabitLoeschenD(id: id)) }
    func ausblenden(_ id: String, _ aus: Bool) { raum.senden("habit.ausblenden", HabitAusblendenD(id: id, aus: aus)) }
    func setzeGym(datum: String, an: Bool) { setze(Habit.gym.id, datum: datum, wert: an ? 1 : 0) }
    func setzeWasser(datum: String, anzahl: Int) { setze(Habit.wasser.id, datum: datum, wert: anzahl) }
}
