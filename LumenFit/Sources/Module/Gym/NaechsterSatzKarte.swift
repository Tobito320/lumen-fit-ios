// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Die eine mutige Karte im Training (schwarze Platte mit Streifen): läuft eine Pause, zeigt sie den Countdown mit Plus, Minus und
/// "Satz starten" (Idee 23, ein Tipp beendet die Pause); sonst steht da, welcher Satz dran ist, mit "Letztes Mal" (Idee 21). Die Zahl tickt das System (`Text(timerInterval:)`).
struct NaechsterSatzKarte: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @State private var mehr = 0
    @State private var weniger = 0
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeit = false
    @ScaledMetric(relativeTo: .largeTitle) private var heldenGroesse: CGFloat = 56

    var body: some View {
        let _ = sitzung.pauseEndeZaehler // sonst bleibt die Karte nach dem Pausenende auf 0:00 stehen
        HeroKarte(platte: true) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                if let pause = sitzung.pause {
                    pauseInhalt(pause)
                } else {
                    satzInhalt
                }
            }
        }
        .accessibilityElement(children: .contain)
        .haptik(.mehr, bei: mehr)
        .haptik(.weniger, bei: weniger)
    }

    // MARK: Pause

    @ViewBuilder
    private func pauseInhalt(_ pause: GymPauseStand) -> some View {
        let jetzt = umgebung.uhr()
        Label("Pause", systemImage: "timer").font(.footnote.weight(.semibold)).textCase(.uppercase)
        if pause.ziel > 0 {
            if let zeitraum = PauseLogik.zeitraum(pause, jetzt: jetzt) {
                Text(timerInterval: zeitraum, countsDown: true, showsHours: false)
                    .font(.system(size: heldenGroesse, weight: .bold, design: .rounded)).monospacedDigit()
                    .accessibilityLabel("Pause, noch \(GymFormat.zeit(PauseLogik.rest(pause, jetzt: jetzt) ?? 0))")
            } else {
                // Ziel überschritten: die Uhr zählt rot hoch (Lovea: roter Überlauf); bei "Satz-Zeit" ist es zugleich die Uhr des Satzes.
                VStack(alignment: .leading, spacing: 0) {
                    Text(satzzeit ? "Satz läuft" : "Pause vorbei").font(.footnote.weight(.semibold))
                    Text(pause.ende ?? pause.seit, style: .timer)
                        .font(.system(size: heldenGroesse, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.4))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(satzzeit ? "Satz läuft seit Pausenende" : "Pause vorbei, Überzeit")
            }
        } else {
            Text(pause.seit, style: .timer)
                .font(.system(size: heldenGroesse, weight: .bold, design: .rounded)).monospacedDigit()
        }
        if let letztes = naechsterSatzText { Text(letztes).font(.subheadline) }
        if let dran = sitzung.dran { SatzVorschlagAnzeige(sitzung: sitzung, uebung: dran.uebung, satz: dran.satz, aufPlatte: true) }
        HStack(spacing: Abstand.s) {
            Button("−15 s") { weniger += 1; sitzung.pauseAendern(sekunden: -PauseLogik.schritt) }
                .accessibilityLabel("15 Sekunden weniger")
            Button("+15 s") { mehr += 1; sitzung.pauseAendern(sekunden: PauseLogik.schritt) }
                .accessibilityLabel("15 Sekunden mehr")
            Spacer(minLength: 0)
            Button("Satz starten") { sitzung.naechsterSatzStarten() }
                .accessibilityHint("Beendet die Pause und startet den nächsten Satz")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.white)
    }

    // MARK: Satz

    @ViewBuilder
    private var satzInhalt: some View {
        if let dran = sitzung.dran, sitzung.liste.indices.contains(dran.uebung) {
            let u = sitzung.liste[dran.uebung]
            Text("Als Nächstes").font(.footnote.weight(.semibold)).textCase(.uppercase)
            Text(u.planUebung.anzeigeName).font(.title2.weight(.bold)).fontDesign(.rounded).lineLimit(3)
            if u.planUebung.istCardio {
                Text("\(u.planUebung.minuten ?? 20) min Cardio").font(.subheadline)
            } else {
                Text("Satz \(dran.satz + 1) von \(u.saetze.count)\(u.planUebung.supersatz == true ? " · Supersatz" : "")").font(.subheadline)
                if let letztes = naechsterSatzText { Text(letztes).font(.subheadline) }
                SatzVorschlagAnzeige(sitzung: sitzung, uebung: dran.uebung, satz: dran.satz, aufPlatte: true)
            }
        } else {
            LumiView(stimmung: .ziel, groesse: 56)
            Text("Alles geschafft").font(.title2.weight(.bold)).fontDesign(.rounded)
            Text("Beende das Training, wenn du fertig bist.").font(.subheadline)
        }
    }

    /// "Letztes Mal: 60 kg × 8" für den Satz, der dran ist.
    private var naechsterSatzText: String? {
        guard let dran = sitzung.dran, sitzung.liste.indices.contains(dran.uebung) else { return nil }
        let u = sitzung.liste[dran.uebung]
        return LetztesMal.text(zeile: dran.satz, in: u.saetze, vorher: u.vorher).map { "Letztes Mal: \($0)" }
    }
}
