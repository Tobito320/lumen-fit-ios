// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Die eine mutige Karte im Training (schwarze Platte mit Streifen): läuft eine Pause, zeigt sie den Countdown mit Plus, Minus und
/// Überspringen (Idee 23); sonst steht da, welcher Satz dran ist, mit "Letztes Mal" (Idee 21). Die Zahl tickt das System (`Text(timerInterval:)`).
struct NaechsterSatzKarte: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @ScaledMetric(relativeTo: .largeTitle) private var heldenGroesse: CGFloat = 56

    var body: some View {
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
                Text("Pause vorbei").font(.system(size: heldenGroesse * 0.6, weight: .bold, design: .rounded))
            }
        } else {
            Text(pause.seit, style: .timer)
                .font(.system(size: heldenGroesse, weight: .bold, design: .rounded)).monospacedDigit()
        }
        if let letztes = naechsterSatzText { Text(letztes).font(.subheadline) }
        HStack(spacing: Abstand.s) {
            Button("−15 s") { sitzung.pauseAendern(sekunden: -PauseLogik.schritt) }
                .accessibilityLabel("15 Sekunden weniger")
            Button("+15 s") { sitzung.pauseAendern(sekunden: PauseLogik.schritt) }
                .accessibilityLabel("15 Sekunden mehr")
            Spacer(minLength: 0)
            Button("Überspringen") { sitzung.pauseUeberspringen() }
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
            }
        } else {
            LumiView(stimmung: .stolz, groesse: 56)
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
