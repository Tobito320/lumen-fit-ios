import SwiftUI

/// Karte "Übersicht" oben im Tab Fortschritt (Entwurf, Besitzer 10.11.2026): Monat | Woche, drei Kacheln (Workouts insgesamt, dieser Zeitraum,
/// Gewicht in 30 Tagen), Balken der letzten 4 Monate bzw. 8 Wochen und Lumi mit einem Satz.
struct FortUebersichtKarte: View {
    let daten: FortUebersichtDaten
    @Binding var zeitraum: FortZeitraum
    let mehr: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            HStack {
                Text("Übersicht").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                Spacer(minLength: Abstand.s)
                Picker("Zeitraum", selection: $zeitraum) {
                    Text("Monat").tag(FortZeitraum.monat)
                    Text("Woche").tag(FortZeitraum.woche)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 170)
            }
            HStack(spacing: Abstand.s) {
                kachel("Workouts", wert: "\(daten.insgesamt)", unten: String(localized: "insgesamt"))
                kachel(zeitraum == .monat ? "Diesen Monat" : "Diese Woche", wert: "\(daten.imZeitraum)",
                       unten: zeitraum == .monat ? String(localized: "Trainings") : daten.geplant.map { String(localized: "von \($0) geplant") } ?? String(localized: "Trainings"))
                kachel("Gewicht", wert: daten.gewicht30.map(FortUebersicht.gewichtText) ?? "–", unten: String(localized: "kg in 30 Tagen"))
            }
            FortSaeulen(saeulen: daten.balken.map { b in
                .init(id: b.id, beschriftung: b.beschriftung, wert: Double(b.anzahl),
                      sprechtext: String(localized: "\(b.beschriftung): \(b.anzahl) Trainings"))
            }, hervorgehoben: daten.balken.last?.id, hoehe: 72)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(zeitraum == .monat ? Text("Trainings je Monat") : Text("Trainings je Woche"))
            Haarlinie()
            FortLumiZeile(stimmung: mehr ? .serie : .bereit, satz: FortUebersicht.lumiSatz(mehr: mehr))
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
        .haptik(.auswahl, bei: zeitraum)
    }

    private func kachel(_ titel: LocalizedStringKey, wert: String, unten: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption).foregroundStyle(palette.text2).lineLimit(1).minimumScaleFactor(0.8)
            Text(wert).font(.title2.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text).lineLimit(1).minimumScaleFactor(0.6)
            Text(unten).font(.caption).foregroundStyle(palette.text2).lineLimit(2).minimumScaleFactor(0.8)
        }
        .padding(Abstand.m)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(palette.haar, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
