// Quelle: Lovea Health/GymSession.swift (WorkoutRueckblick :406, nur lesen, für die Einheit des Partners)
import SwiftUI

/// Eine Einheit des Partners zum Nachlesen: Zeit, Volumen, Sätze, dann je Übung die Sätze. Nur lesen. Die Daten sind die Zusammenfassung, die die Person mit
/// den Freigaben verlauf und gym schickt (`PartnerEinheit`); ohne Puls, RPE und Satzzeiten.
struct GymPartnerEinheitView: View {
    let name: String
    let einheit: PartnerEinheit

    var body: some View {
        List {
            Section {
                LabeledContent("Zeit", value: einheit.minuten.map { TrainingLogik.dauerText(TimeInterval($0 * 60)) } ?? "läuft oder ohne Ende")
                LabeledContent("Volumen") {
                    HStack(spacing: 2) {
                        RollZahl(wert: GymPartnerLogik.volumen(einheit).rounded(), format: .number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))
                        Text("kg")
                    }
                    .foregroundStyle(.secondary)
                }
                LabeledContent("Sätze") {
                    RollZahl(wert: Double(GymPartnerLogik.saetzeZahl(einheit)), format: .number.precision(.fractionLength(0))).foregroundStyle(.secondary)
                }
                if let kcal = einheit.kcal { LabeledContent("Aktive Kalorien", value: "\(kcal) kcal") }
            }
            ForEach(Array(einheit.uebungen.enumerated()), id: \.offset) { _, u in
                Section(u.name) {
                    let saetze = u.saetze.map(GymPartnerLogik.satz)
                    ForEach(saetze.indices, id: \.self) { i in
                        HStack(spacing: 12) {
                            Text(WorkoutLogik.nummer(saetze, i))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(saetze[i].kuerzel == nil ? Color.secondary : Color.orange)
                                .frame(width: 24)
                            Text(WorkoutLogik.satzText(saetze[i])).monospacedDigit()
                            Spacer(minLength: 8)
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .navigationTitle(einheit.name ?? Datum.anzeige(einheit.tag))
        .navigationBarTitleDisplayMode(.inline)
    }
}
