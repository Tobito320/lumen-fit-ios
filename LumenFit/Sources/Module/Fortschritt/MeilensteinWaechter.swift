import Observation
import SwiftUI

/// Hört auf die Ereignisse der App, prüft die Medaillen, schreibt neue über `MeilensteinStore.markiere` (einmal je Kennung, überlebt den Neustart über
/// den Op `fit.lumi.meilenstein`) und zeigt einmal den Toast. Der Store sendet `Ereignis.meilensteinErreicht`. Mehrere Medaillen auf einmal sind ein Toast.
@MainActor @Observable
final class MeilensteinWaechter {
    /// Der Toast für `.lumenToast`; die Ansicht setzt ihn nach 3 Sekunden zurück.
    var toast: ToastInhalt?
    /// Zählt neue Lumi-Stufen, damit die Haptik `.stufe` genau einmal auslöst.
    private(set) var stufenZaehler = 0

    @ObservationIgnored private var umgebung: AppUmgebung?
    @ObservationIgnored private var laeuft = false

    /// Idempotent und synchron: meldet die Prüfung bei den Ereignissen an und prüft einmal nach (Altdaten, Datensicherung).
    func start(_ umgebung: AppUmgebung) {
        guard !laeuft else { return }
        laeuft = true
        self.umgebung = umgebung
        let strom = umgebung.ereignisse.strom()
        Task { [weak self] in
            for await ereignis in strom { self?.verarbeite(ereignis) }
        }
        umgebung.beiAbruf { [weak self] in self?.pruefeAlles() }
        pruefeAlles()
    }

    private func verarbeite(_ ereignis: Ereignis) {
        switch ereignis {
        case .trainingBeendet, .satzFertig, .gewichtGespeichert, .habitGeaendert, .mahlzeitGespeichert, .healthAktualisiert, .profilGewechselt:
            pruefeAlles()
        case .vordergrund:
            pruefeAlles()
            // Health liefert Schlaf und Gewicht erst nach dem Wechsel in den Vordergrund: einmal später nachsehen.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                self?.pruefeAlles()
            }
        case .meilensteinErreicht, .trainingGestartet, .einstellungenGeaendert, .partnerAktualisiert:
            break
        }
    }

    /// Prüft das aktive Profil; ohne Profil nichts. Auch die Meilensteine-Seite ruft es beim Öffnen.
    func pruefeAlles() {
        guard let umgebung, let daten = umgebung.daten else { return }
        pruefe(daten, naechte: umgebung.gesundheit.naechte, heute: Datum.text(umgebung.uhr()))
    }

    /// Prüft und vergibt. Gibt die neu vergebenen Kennungen zurück.
    @discardableResult
    func pruefe(_ daten: DatenSatz, naechte: [String: SchlafNacht], heute: String) -> [String] {
        let vorher = daten.meilensteine.erreicht.map(\.id)
        let schon = Set(vorher)
        guard schon.count < MeilensteinKatalog.anzahl else { return [] }
        let ziele = daten.ziele.ziele
        let eingabe = MeilensteinDaten(
            sessions: daten.training.sessions, gymTage: daten.habits.werte(Habit.gym.id), gymTageProWoche: ziele.gymTageProWoche, heute: heute,
            schlafMinuten: naechte.mapValues(\.schlafMinuten), schlafZiel: ziele.schlafMinuten,
            gewicht: daten.habits.werte(Habit.gewicht.id), gewichtZielKg: ziele.gewichtKg,
            essenTage: daten.essen.tage, fruehstueckTage: schon.contains("fruehstueck") ? 0 : fruehstueckTage(daten))
        let neu = MeilensteinPruefung.faellig(eingabe, schon: schon)
        guard !neu.isEmpty else { return [] }
        let stufeVorher = daten.meilensteine.stufe
        for id in neu { daten.meilensteine.markiere(id) }
        let stufeNachher = daten.meilensteine.stufe
        zeige(neu, neueStufe: stufeNachher > stufeVorher ? stufeNachher : nil)
        return neu
    }

    private func fruehstueckTage(_ daten: DatenSatz) -> Int {
        daten.essen.tage.filter { !daten.essen.eintraege($0, .fruehstueck).isEmpty }.count
    }

    private func zeige(_ ids: [String], neueStufe: Int?) {
        guard let inhalt = Self.toastInhalt(ids, neueStufe: neueStufe) else { return }
        toast = inhalt
        if neueStufe != nil { stufenZaehler += 1 }
    }

    /// Der Text des Toasts: bei neuer Lumi-Stufe die Stufe, sonst die eine Medaille, sonst die Zahl. Ohne bekannte Kennung nil.
    static func toastInhalt(_ ids: [String], neueStufe: Int?) -> ToastInhalt? {
        let medaillen = ids.compactMap { MeilensteinKatalog.nachId[$0] }
        if let stufe = neueStufe {
            return ToastInhalt(titel: "Lumi ist jetzt Stufe \(stufe)", zeile: medaillen.first.map { "Neue Medaille: \($0.titel)" }, stimmung: .stolz)
        }
        if medaillen.count == 1, let m = medaillen.first {
            return ToastInhalt(titel: "Neue Medaille: \(m.titel)", zeile: m.bedingung, stimmung: .stolz)
        }
        guard !medaillen.isEmpty else { return nil }
        return ToastInhalt(titel: "\(medaillen.count) neue Medaillen", zeile: medaillen.prefix(3).map(\.titel).joined(separator: ", "), stimmung: .stolz)
    }
}

extension EnvironmentValues {
    /// Gesetzt, sobald eine Ansicht darüber den Toast der Meilensteine schon zeigt (verhindert doppelte Toasts).
    @Entry var fortschrittToastAktiv: Bool = false
}

private struct FortschrittToastModifier: ViewModifier {
    @Environment(\.fortschrittToastAktiv) private var aktiv

    func body(content: Content) -> some View {
        if aktiv {
            content
        } else {
            let waechter = FortschrittModul.waechter
            content
                .lumenToast(Binding(get: { waechter.toast }, set: { waechter.toast = $0 }))
                .haptik(.stufe, bei: waechter.stufenZaehler)
                .environment(\.fortschrittToastAktiv, true)
        }
    }
}

extension View {
    /// Zeigt den Toast "Neue Medaille" mit Lumi `stolz` und Haptik `.erfolg` (neue Lumi-Stufe zusätzlich `.stufe`). Zeigt ihn nur einmal, auch wenn mehrere Ansichten ihn anhängen.
    func fortschrittToast() -> some View { modifier(FortschrittToastModifier()) }
}
