import Foundation
import Observation

/// Alle Stores eines Profils. Wechselt das Profil, entsteht ein neuer `DatenSatz` (`AppUmgebung.daten`).
/// Der Ordner `<AppGruppe.ordner>/profile/<ProfilID>/` wird hier angelegt; `ops.jsonl` und die kleinen Dateien liegen darin.
@MainActor @Observable
final class DatenSatz {
    let profil: ProfilID
    let ordner: URL
    let raum: LokalerRaum
    let einstellungen: EinstellungenStore
    let ziele: ZieleStore
    let training: TrainingStore
    let essen: EssenStore
    let habits: HabitStore
    let meilensteine: MeilensteinStore
    let verbindung: VerbindungStore
    let importVerlauf: ImportVerlaufStore

    init(profil: ProfilID, ordner: URL, ereignisse: EreignisKanal, uhr: @escaping Uhr, bruecke: any PartnerAustausch = KeinePartnerBruecke()) {
        self.profil = profil
        self.ordner = ordner
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let raum = LokalerRaum(ordner: ordner, profil: profil, uhr: uhr)
        raum.beiSpeicherfehler = { ereignisse.senden(.speichernFehlgeschlagen) }
        let einstellungen = EinstellungenStore(ordner: ordner, ereignisse: ereignisse)
        let ziele = ZieleStore(ordner: ordner)
        let habits = HabitStore(raum: raum, ziele: ziele, ereignisse: ereignisse, uhr: uhr)
        let essen = EssenStore(raum: raum, ziele: ziele, ordner: ordner, ereignisse: ereignisse, uhr: uhr)
        essen.gewichtQuelle = { habits.werte(Habit.gewicht.id) }
        essen.massQuelle = { habits.werte($0) }
        essen.habitSetzer = { id, datum, wert in habits.setze(id, datum: datum, wert: wert) }
        essen.habitLeser = { id, datum in habits.wert(id, datum) }
        self.raum = raum
        self.einstellungen = einstellungen
        self.ziele = ziele
        self.habits = habits
        self.essen = essen
        self.training = TrainingStore(raum: raum, einstellungen: einstellungen, ereignisse: ereignisse, uhr: uhr)
        self.meilensteine = MeilensteinStore(raum: raum, ereignisse: ereignisse, uhr: uhr)
        self.importVerlauf = ImportVerlaufStore(raum: raum)
        self.verbindung = VerbindungStore(ordner: ordner, bruecke: bruecke, einstellungen: einstellungen, ereignisse: ereignisse)
    }
}
