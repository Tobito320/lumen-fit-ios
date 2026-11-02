// Quelle: Lovea Health/Ernaehrung/EssenLive.swift
import ActivityKit
import Foundation

/// Die Stelle, die ActivityKit anfasst. Im Test ein Fake. `Activity` ist nicht Sendable: die echte Fabrik hält kein Objekt, sie fragt `Activity.activities` jedes Mal neu.
protocol EssenLiveFabrik: Sendable {
    /// Der Tag der laufenden Essen-Activity (auch einer, die ein früherer App-Prozess gestartet hat); nil, wenn keine läuft.
    func laufenderTag() async -> String?
    /// Läuft gerade die Training-Activity? Dann zeigt Lumen Fit nur sie, wie Lovea.
    func trainingLaeuft() async -> Bool
    /// Legt sie an (eine alte vom Vortag wird vorher beendet). Geht nur im Vordergrund und mit erlaubten Live Activities; false heißt: nicht gestartet.
    func starte(_ stand: EssenLiveStand, veraltetAb: Date) async -> Bool
    func aktualisiere(_ stand: EssenLiveStand, veraltetAb: Date) async
    func beende() async
}

/// Hält die Essen-Live-Activity passend zum Tagebuch: startet sie, aktualisiert sie nur bei geändertem Stand, beendet sie bei Schalter aus, Training oder Tageswechsel.
/// Hat die Person sie weggewischt, startet sie heute nicht wieder von selbst, auch nicht nach einem App-Neustart (der Tag steht in `speicher`). Aufrufe laufen nacheinander (eine Kette), damit ein Ende nicht vor einem Start überholt.
actor EssenLiveDienst {
    private let fabrik: any EssenLiveFabrik
    private let uhr: Uhr
    private let speicher: UserDefaults?
    nonisolated static let gestartetSchluessel = "lumenfit.essenLive.gestartetTag"
    nonisolated static let beendetSchluessel = "lumenfit.essenLive.beendetTag"
    private var gestartetTag: String? { didSet { speicher?.set(gestartetTag, forKey: Self.gestartetSchluessel) } }
    private var beendetTag: String? { didSet { speicher?.set(beendetTag, forKey: Self.beendetSchluessel) } }
    private var letzter: EssenLiveStand?
    private var kette: Task<Void, Never>?

    init(fabrik: any EssenLiveFabrik, uhr: @escaping Uhr = { Date() }, speicher: UserDefaults? = nil) {
        self.fabrik = fabrik
        self.uhr = uhr
        self.speicher = speicher
        gestartetTag = speicher?.string(forKey: Self.gestartetSchluessel)
        beendetTag = speicher?.string(forKey: Self.beendetSchluessel)
    }

    func abgleichen(_ stand: EssenLiveStand, an: Bool) async {
        let vorher = kette
        let aufgabe = Task { [self] in
            await vorher?.value
            await verarbeite(stand, an: an)
        }
        kette = aufgabe
        await aufgabe.value
    }

    /// Ohne Profil oder bei gelöschten Daten: alles beenden.
    func beenden() async {
        let vorher = kette
        let aufgabe = Task { [self] in
            await vorher?.value
            await fabrik.beende()
            vergiss()
        }
        kette = aufgabe
        await aufgabe.value
    }

    private func vergiss() {
        gestartetTag = nil
        letzter = nil
    }

    private func verarbeite(_ stand: EssenLiveStand, an: Bool) async {
        let laufend = await fabrik.laufenderTag()
        // Lief sie heute und ist weg, hat die Person sie beendet (das gilt auch nach einem Neustart: der Tag steht im Speicher).
        if laufend == nil, gestartetTag == stand.tag { beendetTag = stand.tag }
        if !an { beendetTag = nil; gestartetTag = nil }
        let training = await fabrik.trainingLaeuft()
        let aktion = EssenLiveLogik.aktion(laufendTag: laufend, heute: stand.tag, an: an, trainingLaeuft: training, vomNutzerBeendet: beendetTag == stand.tag)
        let veraltetAb = WidgetAnzeige.naechsteMitternacht(uhr())
        switch aktion {
        case .nichts:
            return
        case .beenden:
            await fabrik.beende()
            vergiss()
        case .starten:
            if await fabrik.starte(stand, veraltetAb: veraltetAb) {
                gestartetTag = stand.tag
                letzter = stand
            }
        case .aktualisieren:
            gestartetTag = stand.tag
            guard letzter != stand else { return }
            letzter = stand
            await fabrik.aktualisiere(stand, veraltetAb: veraltetAb)
        }
    }
}

/// ActivityKit (ungeprüft ohne Gerät: Start nur im Vordergrund, Anzeige, Dynamic Island).
struct EssenActivityKitFabrik: EssenLiveFabrik {
    private static func lebt(_ activity: Activity<EssenLiveAktivitaet>) -> Bool {
        activity.activityState == .active || activity.activityState == .stale
    }

    func laufenderTag() async -> String? {
        Activity<EssenLiveAktivitaet>.activities.first { Self.lebt($0) }?.content.state.stand.tag
    }

    func trainingLaeuft() async -> Bool {
        Activity<TrainingAktivitaet>.activities.contains { $0.activityState == .active || $0.activityState == .stale }
    }

    func starte(_ stand: EssenLiveStand, veraltetAb: Date) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        for alt in Activity<EssenLiveAktivitaet>.activities { await alt.end(nil, dismissalPolicy: .immediate) }
        let inhalt = ActivityContent(state: EssenLiveAktivitaet.ContentState(stand: stand), staleDate: veraltetAb)
        return (try? Activity.request(attributes: EssenLiveAktivitaet(), content: inhalt)) != nil
    }

    func aktualisiere(_ stand: EssenLiveStand, veraltetAb: Date) async {
        let inhalt = ActivityContent(state: EssenLiveAktivitaet.ContentState(stand: stand), staleDate: veraltetAb)
        for activity in Activity<EssenLiveAktivitaet>.activities where Self.lebt(activity) { await activity.update(inhalt) }
    }

    func beende() async {
        for activity in Activity<EssenLiveAktivitaet>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
