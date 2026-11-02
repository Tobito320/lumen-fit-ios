// Quelle: Lovea Health/Ernaehrung/EssenLive.swift
import Foundation

/// Hängt die Essen-Live-Activity an die Ereignisse der App: Mahlzeit gespeichert, App im Vordergrund, Profil gewechselt, Einstellung geändert, Training an und aus.
/// Kein Timer, kein Push: gerechnet und aktualisiert wird nur bei einem Ereignis. `start` ist idempotent und synchron.
enum EssenLiveModul {
    @MainActor private static var laufzeiten: [ObjectIdentifier: EssenLiveLaufzeit] = [:]

    @MainActor
    static func start(_ umgebung: AppUmgebung, fabrik: any EssenLiveFabrik = EssenActivityKitFabrik(), speicher: UserDefaults = .standard) {
        let kennung = ObjectIdentifier(umgebung)
        guard laufzeiten[kennung] == nil else { return }
        laufzeiten[kennung] = EssenLiveLaufzeit(umgebung, fabrik: fabrik, speicher: speicher)
    }

    /// Die Laufzeit einer Umgebung (für Tests); nil, solange `start` nicht lief.
    @MainActor static func laufzeit(_ umgebung: AppUmgebung) -> EssenLiveLaufzeit? { laufzeiten[ObjectIdentifier(umgebung)] }
}

@MainActor
final class EssenLiveLaufzeit {
    let dienst: EssenLiveDienst
    private let umgebung: AppUmgebung
    private let speicher: UserDefaults
    private var ereignisse: Task<Void, Never>?

    init(_ umgebung: AppUmgebung, fabrik: any EssenLiveFabrik, speicher: UserDefaults) {
        self.umgebung = umgebung
        self.speicher = speicher
        self.dienst = EssenLiveDienst(fabrik: fabrik, uhr: umgebung.uhr, ablage: EssenLiveAblage(werte: speicher))
        // Erst abonnieren (synchron), dann zuhören: der Kanal liefert nur, was nach dem Abonnieren gesendet wird.
        let strom = umgebung.ereignisse.strom()
        ereignisse = Task { @MainActor [weak self] in
            for await ereignis in strom { await self?.verarbeite(ereignis) }
        }
    }

    func verarbeite(_ ereignis: Ereignis) async {
        switch ereignis {
        case .profilGeloescht:
            await dienst.beenden()
        case .mahlzeitGespeichert, .vordergrund, .profilGewechselt, .einstellungenGeaendert, .trainingGestartet, .trainingBeendet:
            await abgleichen()
        default:
            return
        }
    }

    /// Stand von heute aus dem Tagebuch des aktiven Profils, dann an den Dienst. Ohne Profil läuft nichts.
    func abgleichen() async {
        guard let essen = umgebung.daten?.essen else {
            await dienst.beenden()
            return
        }
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let stunde = Datum.kalender.component(.hour, from: jetzt)
        let stand = EssenLiveLogik.stand(eintraege: essen.eintraege(heute), ziele: essen.ernaehrungsZiele(tag: heute), tag: heute, stunde: stunde)
        await dienst.abgleichen(stand, an: EssenLiveEinstellung.an(speicher))
    }
}
