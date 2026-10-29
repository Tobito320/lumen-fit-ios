import Foundation

/// Hält die Bilder der Plan-Übungen vorgeladen (Idee 26), damit sie im Studio ohne Netz da sind und nicht erst beim ersten Ansehen kommen.
/// Läuft beim Start, beim Zurückkehren in die App und nach einem Profilwechsel; holt nur, was im Cache fehlt (Datei da = nichts zu tun),
/// eine Übung nach der anderen und nicht im Datensparmodus. Offline ist ein Versuch billig und endet sofort.
@MainActor
enum PlanBilder {
    private static var laeuft = false

    /// Katalog-Ids der Plan-Übungen mit Bild, ohne Wiederholung, in Plan-Reihenfolge. Eigene Übungen haben keins.
    nonisolated static func ids(_ plan: TrainingsPlan) -> [String] {
        var gesehen = Set<String>()
        return plan.tage.flatMap(\.uebungen).map(\.uebung).filter { $0 != PlanUebung.eigen && UebungsKatalog.hatVideo($0) && gesehen.insert($0).inserted }
    }

    /// Was noch fehlt. `vorhanden` sagt, ob das Bild schon im Cache liegt.
    nonisolated static func fehlend(_ plan: TrainingsPlan, vorhanden: (String) -> Bool) -> [String] {
        ids(plan).filter { !vorhanden($0) }
    }

    /// Holt die fehlenden Bilder; gibt zurück, wie viele es versucht hat. Ein zweiter Aufruf, solange einer läuft, tut nichts.
    @discardableResult
    static func holeFehlende(_ plan: TrainingsPlan,
                             vorhanden: (String) -> Bool = { FileManager.default.fileExists(atPath: UebungsMedien.lokal($0).path) },
                             laden: @MainActor ([String]) async -> Void = { await UebungsMedien.vorladen($0, sparsam: true) }) async -> Int {
        guard !laeuft else { return 0 }
        let liste = fehlend(plan, vorhanden: vorhanden)
        guard !liste.isEmpty else { return 0 }
        laeuft = true
        defer { laeuft = false }
        await laden(liste)
        return liste.count
    }

    /// Einmal beim Modulstart, danach bei jedem Vordergrund und Profilwechsel (der Plan kann sich geändert haben).
    static func beobachte(_ umgebung: AppUmgebung) {
        let strom = umgebung.ereignisse.strom()
        Task { @MainActor in
            await auffrischen(umgebung)
            for await ereignis in strom {
                switch ereignis {
                case .vordergrund, .profilGewechselt: await auffrischen(umgebung)
                default: break
                }
            }
        }
    }

    private static func auffrischen(_ umgebung: AppUmgebung) async {
        guard let plan = umgebung.daten?.training.plan else { return }
        await holeFehlende(plan)
    }
}
