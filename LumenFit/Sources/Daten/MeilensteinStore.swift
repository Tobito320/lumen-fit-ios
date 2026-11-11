import Foundation
import Observation

/// Erreichte Meilensteine (Op `fit.lumi.meilenstein`, Rumpf `MeilensteinStand`) und daraus Lumis Stufe.
@MainActor @Observable
final class MeilensteinStore {
    @ObservationIgnored private let raum: LokalerRaum
    @ObservationIgnored private let ereignisse: EreignisKanal?
    @ObservationIgnored private let uhr: Uhr
    private var stand: [String: MeilensteinStand] = [:]

    static let art = "fit.lumi.meilenstein"

    init(raum: LokalerRaum, ereignisse: EreignisKanal? = nil, uhr: @escaping Uhr = { Date() }) {
        self.raum = raum
        self.ereignisse = ereignisse
        self.uhr = uhr
        stand = raum.falten([Self.art], [:], live: { [weak self] op in
            if let m = op.daten(MeilensteinStand.self) { self?.stand[m.id] = m }
        }) { stand, op in
            if let m = op.daten(MeilensteinStand.self) { stand[m.id] = m }
        }
    }

    /// Nach Zeit sortiert, älteste zuerst.
    var erreicht: [MeilensteinStand] { stand.values.sorted { ($0.erreicht, $0.id) < ($1.erreicht, $1.id) } }

    func istErreicht(_ id: String) -> Bool { stand[id] != nil }

    /// Markiert einen Meilenstein, einmal je `id` (ein zweiter Aufruf schreibt nichts).
    func markiere(_ id: String) {
        guard stand[id] == nil else { return }
        raum.senden(Self.art, MeilensteinStand(id: id, erreicht: uhr()))
        ereignisse?.senden(.meilensteinErreicht(id: id))
    }

    /// Lumis Stufe 1 bis 9; die Ziel-Medaillen zählen nicht mit (`MeilensteinKatalog.neueIds`).
    var stufe: Int { LumiStufe.stufe(erreicht: MeilensteinKatalog.stufenZahl(stand.keys)) }
}
