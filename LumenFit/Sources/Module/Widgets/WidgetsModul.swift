import Foundation
import WidgetKit

/// Modul widgets, App-Seite: Snapshot für die Widgets, Live Activity fürs Training, Haken der Intents (Satz fertig, Kurzbefehle), Gewohnheiten aus dem Widget
/// übernehmen, Spotlight. `start` ist idempotent und läuft synchron in `ModulStart.starteAlle`; die Ports werden dort gesetzt (SPEC 5.9 Vertrag 2).
enum WidgetsModul {
    @MainActor private static var laufzeiten: [ObjectIdentifier: WidgetsLaufzeit] = [:]

    @MainActor
    static func start(_ umgebung: AppUmgebung, senke: any SpotlightSenke = CoreSpotlightSenke(),
                      fabrik: any LiveAktivitaetFabrik = ActivityKitFabrik(),
                      neuladen: @escaping @MainActor () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        let kennung = ObjectIdentifier(umgebung)
        guard laufzeiten[kennung] == nil else { return }
        laufzeiten[kennung] = WidgetsLaufzeit(umgebung, senke: senke, fabrik: fabrik, neuladen: neuladen)
    }

    /// Die laufenden Teile einer Umgebung (für Tests); nil, solange `start` nicht lief.
    @MainActor static func laufzeit(_ umgebung: AppUmgebung) -> WidgetsLaufzeit? { laufzeiten[ObjectIdentifier(umgebung)] }

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild: ein Snapshot mit erfundenen Werten im Theme des Profils.
    @MainActor
    static func demoSaat(_ umgebung: AppUmgebung) {
        var snapshot = WidgetSnapshot.beispiel(jetzt: umgebung.uhr(), thema: umgebung.daten?.einstellungen.werte.thema ?? .monochrom)
        snapshot.profilKennung = umgebung.profil.aktiv?.id.rawValue
        WidgetSnapshotDatei.schreibe(snapshot, ordner: umgebung.ordner)
    }
}

/// Alles, was `WidgetsModul.start` in Gang setzt, an einem Ort: die Haken, das Abo auf die Ereignisse, der Darwin-Anstoß vom Widget.
@MainActor
final class WidgetsLaufzeit {
    let schreiber: WidgetSnapshotSchreiber
    let spotlight: SpotlightPflege
    let live: LiveActivityDienst
    private let umgebung: AppUmgebung
    private var hoerer: WidgetAnstossHoerer?
    private var ereignisse: Task<Void, Never>?

    init(_ umgebung: AppUmgebung, senke: any SpotlightSenke, fabrik: any LiveAktivitaetFabrik, neuladen: @escaping @MainActor () -> Void) {
        self.umgebung = umgebung
        self.schreiber = WidgetSnapshotSchreiber(umgebung: umgebung, neuladen: neuladen)
        self.spotlight = SpotlightPflege(umgebung: umgebung, senke: senke)
        self.live = LiveActivityDienst(fabrik: fabrik)

        // Haken der Intents: `trainingSteuerung` wird erst beim Tippen gelesen (das Modul gym setzt sie in seinem eigenen `start`).
        SatzFertigIntent.ausfuehren = { umgebung.trainingSteuerung.satzFertig() }
        KurzbefehlHaken.trainingStarten = {
            umgebung.trainingSteuerung.starte(planTag: nil)
            umgebung.router.oeffne(.gym(.training))
        }
        KurzbefehlHaken.oeffne = { umgebung.router.oeffne($0) }
        umgebung.liveAnzeige = live

        umgebung.beiAbruf { [weak self] in await self?.abruf() }
        hoerer = WidgetAnstossHoerer { [weak self] in Task { @MainActor in self?.uebernimmTipps() } }
        schreiber.beobachteGesundheit()
        // Erst abonnieren (synchron), dann zuhören: der Kanal liefert nur, was nach dem Abonnieren gesendet wird.
        let strom = umgebung.ereignisse.strom()
        ereignisse = Task { @MainActor [weak self] in
            for await ereignis in strom { await self?.verarbeite(ereignis) }
        }
        // Der erste Lauf nach dem App-Start, nicht mittendrin (das Profil lädt seine Daten erst jetzt).
        Task { @MainActor [weak self] in
            self?.uebernimmTipps()
            self?.schreiber.anfordern(sofort: true)
            self?.spotlight.aktualisiere()
        }
    }

    func verarbeite(_ ereignis: Ereignis) async {
        switch ereignis {
        case .vordergrund:
            uebernimmTipps()
            spotlight.aktualisiere()
            schreiber.anfordern()
        case .profilGewechselt:
            uebernimmTipps()
            spotlight.aktualisiere()
            schreiber.anfordern(sofort: true)
        case .trainingBeendet:
            await live.training(nil)
            spotlight.aktualisiere()
            schreiber.anfordern()
        default:
            schreiber.anfordern()
        }
    }

    /// Tipps aus dem Widget in den Raum des aktiven Profils (idempotent über die Op-Id).
    func uebernimmTipps() {
        guard let daten = umgebung.daten else { return }
        let tage = WidgetOpsImport.uebernimm(ordner: umgebung.ordner, profil: daten.profil, raum: daten.raum, jetzt: umgebung.uhr())
        for tag in tage { umgebung.ereignisse.senden(.habitGeaendert(tag: tag)) }
    }

    /// Hintergrund-Abruf (`umgebung.beiAbruf`): Health nachladen, aber nie die Abfrage der Rechte auslösen (nur wenn die Person schon gefragt wurde), dann sofort schreiben.
    func abruf() async {
        uebernimmTipps()
        if umgebung.daten?.einstellungen.werte.healthGefragt == true { await umgebung.gesundheit.aktualisiere() }
        schreiber.anfordern(sofort: true)
    }
}
