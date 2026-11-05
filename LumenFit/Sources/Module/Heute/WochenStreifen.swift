import SwiftUI

/// Montag bis Sonntag mit kleinen Bögen je Tag (Idee 20): außen Schritte, Mitte Gym, innen Schlaf (nur die gewählten Bereiche). Ein Tipp öffnet den Tag.
struct WochenStreifen: View {
    let woche: [HeuteWochenTag]
    var bereiche = Einstellungen()
    let oeffne: (String) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HeuteKartenKopf(symbol: "calendar", titel: "Diese Woche")
                HStack(spacing: 0) {
                    ForEach(woche) { tag in
                        Button { oeffne(tag.tag) } label: {
                            VStack(spacing: Abstand.xs) {
                                ZStack {
                                    HeuteMiniBogen(anteil: tag.schritte, bereich: .bewegen, strich: 3)
                                    if bereiche.gymAn { HeuteMiniBogen(anteil: tag.gym, bereich: .trainieren, strich: 3).padding(5) }
                                    if bereiche.schlafAn { HeuteMiniBogen(anteil: tag.schlaf, bereich: .erholen, strich: 3).padding(bereiche.gymAn ? 10 : 5) }
                                }
                                .frame(width: 38, height: 38)
                                Text(tag.kuerzel)
                                    .font(.caption.weight(tag.istHeute ? .bold : .medium))
                                    .foregroundStyle(tag.istHeute ? palette.text : palette.text2)
                                Capsule().fill(tag.istHeute ? palette.text : Color.clear).frame(width: 14, height: 2)
                                if bereiche.gymAn { WochenPersonenPunkte(tag: tag.tag, ichGym: tag.gym > 0) }
                            }
                            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                            .opacity(tag.zukunft ? 0.45 : 1)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(tag.zukunft)
                        .accessibilityLabel(WochenStreifenLogik.beschreibung(tag, bereiche: bereiche))
                        .accessibilityHint(tag.zukunft ? "" : "Öffnet den Tag")
                    }
                }
            }
            .padding(Abstand.l)
        }
    }
}

/// Ein Tag der Woche im Detail (Blatt): Schritte, Gym, Schlaf, Wasser und Gewicht dieses Tages.
struct HeuteTagView: View {
    let tag: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    if let daten = umgebung.daten {
                        HeuteTagZeilen(tag: tag, daten: daten)
                        StimmungTagKarte(tag: tag)
                    }
                }
                .padding(Abstand.l)
            }
            .navigationTitle(Datum.anzeige(tag))
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}

/// Schritte, Gym, Schlaf, Wasser und Gewicht eines Tages als Liste (Blatt der Woche und Tagwahl des Heute-Tabs). Ohne Wert steht "keine Daten".
struct HeuteTagZeilen: View {
    let tag: String
    let daten: DatenSatz
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View { zeilen(daten) }

    private func zeilen(_ daten: DatenSatz) -> some View {
        let werte = umgebung.gesundheit.tage[tag]
        let nacht = TagesformQuellen.nacht(tag, daten: daten, gesundheit: umgebung.gesundheit)
        let einheit = GymTageLogik.einheit(am: tag, in: daten.training.sessions)
        let gymHaken = daten.habits.wert(Habit.gym.id, tag) > 0
        let wasser = daten.habits.wert(Habit.wasser.id, tag)
        let gewicht = daten.habits.wert(Habit.gewicht.id, tag)
        let ziele = daten.ziele.ziele
        let bereiche = umgebung.bereicheWirksam
        return ListenKarte {
            zeile("figure.walk", "Schritte", (werte?.schritte).map { $0 > 0 ? "\(HeuteQuellen.zahl($0)) von \(HeuteQuellen.zahl(ziele.schritte))" : "keine Daten" } ?? "keine Daten")
            if bereiche.gymAn {
                Haarlinie()
                zeile("dumbbell.fill", "Gym", einheit != nil ? "Training gespeichert" : (gymHaken ? "abgehakt" : "kein Training"))
            }
            if bereiche.schlafAn {
                Haarlinie()
                zeile("bed.double.fill", "Schlaf", nacht.map { "\(BereitScore.stunden($0.minuten)) von \(BereitScore.stunden(ziele.schlafMinuten))" } ?? "keine Daten")
            }
            Haarlinie()
            zeile("drop.fill", "Wasser", wasser > 0 ? "\(wasser) Gläser" : "nichts eingetragen")
            if gewicht > 0 {
                Haarlinie()
                zeile("scalemass.fill", "Gewicht", GewichtText.anzeige(gewicht))
            }
            if let m = werte, m.distanzMeter > 0 || m.etagen > 0 {
                Haarlinie()
                zeile("figure.stair.stepper", "Distanz und Etagen", "\(String(format: "%.1f", m.distanzMeter / 1000).replacingOccurrences(of: ".", with: ",")) km, \(m.etagen) Etagen")
            }
        }
    }

    private func zeile(_ symbol: String, _ titel: String, _ wert: String) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: symbol).foregroundStyle(palette.text2).frame(width: 24).accessibilityHidden(true)
            Text(titel).font(.body).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            Text(wert).font(.body).foregroundStyle(palette.text2).multilineTextAlignment(.trailing)
        }
        .padding(Abstand.l)
        .accessibilityElement(children: .combine)
    }
}
