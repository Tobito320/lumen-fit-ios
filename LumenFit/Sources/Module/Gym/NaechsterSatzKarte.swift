// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Die Pause-Karte im Training (Idee 23, nur einbinden, solange `sitzung.pause` läuft): Countdown in Lime mit −15 s, +15 s und "Set starten" (ein Tipp beendet die Pause), Überzeit rot,
/// darunter "Letztes Mal" und das Ziel des nächsten Sets. Steht nur, solange eine Pause läuft; welches Set dran ist, zeigt sonst die Tabelle
/// (Nummer in Lime), "Alles geschafft" die Lumi-Zeile. Die Zahl tickt das System (`Text(timerInterval:)`).
struct NaechsterSatzKarte: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @State private var mehr = 0
    @State private var weniger = 0
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeit = false
    @ScaledMetric(relativeTo: .largeTitle) private var heldenGroesse: CGFloat = 56
    @Environment(\.palette) private var palette

    var body: some View {
        let _ = sitzung.pauseEndeZaehler // sonst bleibt die Karte nach dem Pausenende auf 0:00 stehen
        VStack(alignment: .leading, spacing: Abstand.s) {
            if let pause = sitzung.pause { pauseInhalt(pause) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .contain)
        .haptik(.mehr, bei: mehr)
        .haptik(.weniger, bei: weniger)
    }

    // MARK: Pause

    @ViewBuilder
    private func pauseInhalt(_ pause: GymPauseStand) -> some View {
        let jetzt = umgebung.uhr()
        Label("Pause", systemImage: "timer").font(.footnote.weight(.semibold)).textCase(.uppercase).foregroundStyle(palette.text2)
        if pause.ziel > 0 {
            if let zeitraum = PauseLogik.zeitraum(pause, jetzt: jetzt) {
                Text(timerInterval: zeitraum, countsDown: true, showsHours: false)
                    .font(.system(size: heldenGroesse, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(palette.akzent)
                    .accessibilityLabel("Pause, noch \(GymFormat.zeit(PauseLogik.rest(pause, jetzt: jetzt) ?? 0))")
            } else {
                // Ziel überschritten: die Uhr zählt rot hoch (Lovea: roter Überlauf); bei "Satz-Zeit" ist es zugleich die Uhr des Satzes.
                VStack(alignment: .leading, spacing: 0) {
                    Text(satzzeit ? "Set läuft" : "Pause vorbei").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
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
                .foregroundStyle(palette.akzent)
        }
        if let letztes = naechsterSatzText { Text(letztes).font(.subheadline).foregroundStyle(palette.text2) }
        if let dran = sitzung.dran { SatzVorschlagAnzeige(sitzung: sitzung, uebung: dran.uebung, satz: dran.satz) }
        HStack(spacing: Abstand.s) {
            Button("−15 s") { weniger += 1; sitzung.pauseAendern(sekunden: -PauseLogik.schritt) }
                .accessibilityLabel("15 Sekunden weniger")
            Button("+15 s") { mehr += 1; sitzung.pauseAendern(sekunden: PauseLogik.schritt) }
                .accessibilityLabel("15 Sekunden mehr")
            Spacer(minLength: 0)
            Button("Set starten") { sitzung.naechsterSatzStarten() }
                .buttonStyle(.lumenHauptknopf)
                .accessibilityHint("Beendet die Pause und startet das nächste Set")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(palette.text)
    }

    /// "Letztes Mal: 60 kg × 8" für den Satz, der dran ist.
    private var naechsterSatzText: String? {
        guard let dran = sitzung.dran, sitzung.liste.indices.contains(dran.uebung) else { return nil }
        let u = sitzung.liste[dran.uebung]
        return LetztesMal.text(zeile: dran.satz, in: u.saetze, vorher: u.vorher).map { String(localized: "Letztes Mal: \($0)") }
    }
}
