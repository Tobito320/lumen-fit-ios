import Foundation
import Observation
import WidgetKit

/// Schreibt `widget-stand.json` ins Gruppenverzeichnis (`umgebung.ordner`: in der App die App Group, in Tests ein Temp-Ordner) und lädt die Widgets neu.
/// Läuft bei jedem `Ereignis` (auch `.vordergrund` und `.healthAktualisiert`) und wenn sich der Gesundheitsstand ändert, höchstens alle 30 Sekunden
/// (die letzte Änderung wird nachgeholt). Geschrieben und neu geladen wird nur, wenn sich der Inhalt geändert hat (Akku).
@MainActor
final class WidgetSnapshotSchreiber {
    private let umgebung: AppUmgebung
    private let neuladen: @MainActor () -> Void
    private var drossel: WidgetsDrossel?
    private var beobachtet = false

    /// `verzoegere` und `neuladen` kommen in Tests von außen; sonst gilt `Task.sleep` und `WidgetCenter.reloadAllTimelines`.
    init(umgebung: AppUmgebung, neuladen: @escaping @MainActor () -> Void = { WidgetCenter.shared.reloadAllTimelines() },
         verzoegere: (@MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void)? = nil) {
        self.umgebung = umgebung
        self.neuladen = neuladen
        let warte: @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void = verzoegere ?? { sekunden, aktion in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(sekunden))
                aktion()
            }
        }
        self.drossel = WidgetsDrossel(uhr: umgebung.uhr, aktion: { [weak self] in _ = self?.schreibeJetzt() }, verzoegere: warte)
    }

    /// Ein Ereignis oder eine Änderung ist da: schreiben, gedrosselt. `sofort` für Profilwechsel und den Hintergrund-Abruf.
    func anfordern(sofort: Bool = false) {
        drossel?.anfordern(sofort: sofort)
    }

    /// Wer `gesundheit` ändert (die Heute-Ansicht holt Health, ohne ein `Ereignis` zu senden), stößt hier den Schnappschuss an.
    /// Idempotent; die Beobachtung erneuert sich nach jeder Änderung selbst.
    func beobachteGesundheit() {
        guard !beobachtet else { return }
        beobachtet = true
        verfolge()
    }

    private func verfolge() {
        let gesundheit = umgebung.gesundheit
        withObservationTracking {
            _ = gesundheit.tage
            _ = gesundheit.naechte
            _ = gesundheit.vitale
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.anfordern()
                self.verfolge()
            }
        }
    }

    /// Baut und schreibt den Snapshot jetzt, wenn sich etwas geändert hat. Gibt zurück, ob geschrieben wurde.
    @discardableResult
    func schreibeJetzt() -> Bool {
        let neu = Self.snapshot(umgebung)
        let bestehend = WidgetSnapshotDatei.lade(ordner: umgebung.ordner)
        var vergleich = neu
        vergleich.geschrieben = bestehend?.geschrieben
        // Vergleich ohne Zeitstempel und gegen die Datei selbst: ein Vorab-Haken aus dem Widget, den die App nicht bestätigt hat, wird so überschrieben.
        guard bestehend != vergleich else { return false }
        guard WidgetSnapshotDatei.schreibe(neu, ordner: umgebung.ordner) else { return false }
        neuladen()
        return true
    }

    // MARK: - Aus den Stores

    /// Der Snapshot des aktiven Profils; ohne Profil ein leerer (die Widgets zeigen dann ihren Leerzustand).
    static func snapshot(_ umgebung: AppUmgebung) -> WidgetSnapshot {
        guard let eingabe = eingabe(umgebung) else { return WidgetSnapshot(geschrieben: umgebung.uhr()) }
        return WidgetSnapshotBauer.baue(eingabe)
    }

    static func eingabe(_ umgebung: AppUmgebung) -> WidgetEingabe? {
        guard let profil = umgebung.profil.aktiv, let daten = umgebung.daten else { return nil }
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let gesundheit = umgebung.gesundheit
        let essenZiele = daten.essen.ernaehrungsZiele(tag: heute)
        let summe = daten.essen.summe(heute)
        let habits = daten.habits.sichtbar.map { habit in
            WidgetHabitEingabe(habit: habit, werte: daten.habits.werte(habit.id), ziel: daten.habits.habitZiel(habit.id))
        }
        let stimmungen = daten.raum.ops(arten: ["fit.lumi.stimmung"]).compactMap { $0.daten(StimmungsEintrag.self) }
        return WidgetEingabe(
            jetzt: jetzt, profilName: profil.name, profilKennung: profil.id.rawValue,
            thema: ProfilThemaWahl.wirksam(daten.einstellungen.werte.thema, loveaErlaubt: umgebung.konto.loveaErlaubt), erscheinung: daten.einstellungen.werte.erscheinung, ziele: daten.ziele.ziele,
            schritte: gesundheit.tage[heute]?.schritte, schlafMinuten: gesundheit.naechte[heute]?.schlafMinuten,
            hrv: gesundheit.vitale[.hrv]?.last.map { Int($0.wert.rounded()) },
            sessions: daten.training.sessions, plan: daten.training.plan,
            kcal: Int(summe.kcal.rounded()), kcalZiel: essenZiele.kcal, protein: Int(summe.protein.rounded()), proteinZiel: essenZiele.protein,
            habits: habits, lumi: stimmungen.last { $0.tag == heute }?.stimmung ?? .bereit, lumiStufe: daten.meilensteine.stufe,
            gymTage: WochenStreifenLogik.gymTage(sessions: daten.training.sessions, haken: daten.habits.werte(Habit.gym.id)),
            partner: PartnerAnzeige.zusammenfassung(daten.verbindung.partner))
    }
}
