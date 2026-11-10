// Quelle: Lovea Health/LoveaWidgets/Sources/GymLiveWidget.swift
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Idee 94 und 95: die Training-Live-Activity. Sperrbildschirm mit Übung, "Satz 3 von 4", Pausen-Countdown, Fortschrittsbalken in Trainieren-Tief und dem Knopf
/// "Satz fertig" (`SatzFertigIntent`, ohne die App zu öffnen); Dynamic Island kompakt mit Lumi und Dauer, erweitert mit Übung, Satz und Pause.
/// Zähler laufen als `Text(timerInterval:)` und `Text(_, style: .timer)`: das System tickt, die App muss nichts aktualisieren. Ein Tipp öffnet das Gym.
struct TrainingLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingAktivitaet.self) { kontext in
            TrainingSperrbildschirm(planName: kontext.attributes.planName, stand: kontext.state.stand)
                .widgetURL(RouteURL.url(fuer: .gym(.training)))
        } dynamicIsland: { kontext in
            let stand = kontext.state.stand
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LumiView(stimmung: stand.lumi, groesse: 28)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(stand.start, style: .timer)
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 72, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(stand.uebung).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TrainingInselUnten(stand: stand)
                }
            } compactLeading: {
                LumiView(stimmung: stand.lumi, groesse: 22)
            } compactTrailing: {
                Text(stand.start, style: .timer)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 56, alignment: .trailing)   // wie Lovea; breiter wird die Insel nicht
            } minimal: {
                LumiView(stimmung: stand.lumi, groesse: 22)
            }
            .widgetURL(RouteURL.url(fuer: .gym(.training)))
        }
    }
}

/// Die Farben der Live Activity aus dem Theme der App (Snapshot der Gruppe); Dynamic Island ist immer schwarz und nimmt deshalb die dunklen Töne.
private func trainingFarben(systemDunkel: Bool, kontrastHoch: Bool) -> WidgetFarben {
    let snapshot = WidgetSnapshotDatei.lade()
    return WidgetFarben.bau(thema: snapshot?.thema ?? .monochrom, erscheinung: snapshot?.erscheinung, systemDunkel: systemDunkel,
                            kontrastHoch: kontrastHoch, modus: .fullColor)
}

/// Der Knopf: in der Pause "Satz starten" (Pause zu Ende, nächster Satz läuft), sonst "Satz fertig". Mindestens 44 pt, Schrift auf Trainieren-Tief mit Kontrast.
/// Nach dem Pausenende bleibt "Satz starten" stehen, bis die App neu meldet: genau das ist dann der nächste Schritt.
private struct SatzFertigKnopf: View {
    let stand: TrainingLiveStand
    let farben: WidgetFarben

    var body: some View {
        if stand.pauseEnde != nil {
            Button(intent: SatzStartenIntent()) { kreis("play.fill") }
                .buttonStyle(.plain)
                .accessibilityLabel("Satz starten")
        } else {
            Button(intent: SatzFertigIntent()) { kreis("checkmark") }
                .buttonStyle(.plain)
                .accessibilityLabel("Satz fertig")
        }
    }

    private func kreis(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title3.weight(.bold))
            .foregroundStyle(farben.aufTrainieren)
            .frame(width: 52, height: 52)
            .background(farben.trainieren, in: .circle)
    }
}

/// "Satz 3 von 4", darunter "60 kg × 8" und die Satz-Uhr (ab Pausenende, hochzählend). Ist alles fertig oder gibt es keinen Satz,
/// steht stattdessen "2 von 5 Übungen fertig".
private struct SatzZeilen: View {
    let stand: TrainingLiveStand
    let farben: WidgetFarben

    var body: some View {
        if stand.von > 0 {
            Text("Satz \(stand.satz) von \(stand.von)").font(.subheadline.weight(.semibold)).foregroundStyle(farben.text2)
            if let zeile = stand.satzZeile {
                HStack(spacing: 6) {
                    Text(zeile).font(.subheadline).foregroundStyle(farben.text)
                    if let seit = stand.satzSeit {
                        Text(seit, style: .timer)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(farben.text2)
                            .frame(maxWidth: 56, alignment: .leading)
                            .accessibilityLabel("Satz läuft seit")
                    }
                }
            }
        } else if let fertig = stand.uebungenFertig, let gesamt = stand.uebungenGesamt, gesamt > 0 {
            Text("\(fertig) von \(gesamt) Übungen fertig").font(.subheadline).foregroundStyle(farben.text2)
        }
    }
}

/// Die Pause als Zähler, solange sie läuft. Nach ihrem Ende bleibt der Zähler bei 0:00 stehen, bis die App den nächsten Satz meldet (kein Neuzeichnen ohne Aktualisierung).
private struct PausenZeile: View {
    let stand: TrainingLiveStand
    let farben: WidgetFarben

    var body: some View {
        let jetzt = Date.now   // einmal gelesen: die Spanne darf nie rückwärts laufen
        if let ende = stand.pauseEnde, ende > jetzt {
            HStack(spacing: 4) {
                Text("Pause").font(.subheadline.weight(.semibold))
                Text(timerInterval: jetzt...ende, countsDown: true)
                    .font(.subheadline.monospacedDigit())
                    .frame(maxWidth: 64, alignment: .leading)
            }
            .foregroundStyle(farben.text)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Sperrbildschirm: Plan und Dauer oben, Übung und Satz mit dem Knopf in der Mitte, unten der Fortschritt der Sätze dieser Übung.
private struct TrainingSperrbildschirm: View {
    let planName: String?
    let stand: TrainingLiveStand
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        let farben = trainingFarben(systemDunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LumiView(stimmung: stand.lumi, groesse: 24)
                Text(planName ?? stand.planName ?? String(localized: "Training"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(farben.text2)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(stand.start, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(farben.text2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80, alignment: .trailing)
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stand.uebung).font(.headline).foregroundStyle(farben.text).lineLimit(1)
                    SatzZeilen(stand: stand, farben: farben)
                    PausenZeile(stand: stand, farben: farben)
                }
                Spacer(minLength: 8)
                SatzFertigKnopf(stand: stand, farben: farben)
            }
            WidgetBalken(anteil: WidgetAnzeige.anteil(max(stand.satz - 1, 0), stand.von), farbe: farben.trainieren, spur: farben.trainieren.opacity(0.22))
        }
        .padding(16)
        .activityBackgroundTint(farben.grund)
        .accessibilityElement(children: .contain)
    }
}

/// Dynamic Island erweitert, unten: Satz, Pause und der Knopf. Immer dunkel, weil die Insel schwarz ist.
private struct TrainingInselUnten: View {
    let stand: TrainingLiveStand

    var body: some View {
        let farben = trainingFarben(systemDunkel: true, kontrastHoch: false)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                SatzZeilen(stand: stand, farben: farben)
                PausenZeile(stand: stand, farben: farben)
            }
            Spacer(minLength: 8)
            SatzFertigKnopf(stand: stand, farben: farben)
        }
    }
}
