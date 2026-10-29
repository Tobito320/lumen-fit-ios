// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Scheiben- und Aufwärmrechner als Sheet (Idee 25). Das Arbeitsgewicht startet beim schwersten Satz der Übung, Plus und Minus ändern es in 2,5-kg-Schritten.
struct RechnerBlatt: View {
    let sitzung: GymSitzung
    let index: Int
    @State private var arbeit: Double = 60
    @State private var reiter = Reiter.scheiben
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette

    private enum Reiter: String, CaseIterable, Identifiable {
        case scheiben = "Scheiben", aufwaermen = "Aufwärmen"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    HeroKarte(platte: true) {
                        VStack(alignment: .leading, spacing: Abstand.s) {
                            Text("Arbeitsgewicht").font(.footnote.weight(.semibold)).textCase(.uppercase)
                            HStack {
                                Button { arbeit = max(2.5, arbeit - 2.5) } label: { Image(systemName: "minus.circle.fill").font(.largeTitle).frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche) }
                                    .accessibilityLabel("Weniger")
                                Spacer()
                                Text("\(TrainingLogik.kgText(arbeit)) kg")
                                    .font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                                    .contentTransition(.numericText())
                                Spacer()
                                Button { arbeit = min(500, arbeit + 2.5) } label: { Image(systemName: "plus.circle.fill").font(.largeTitle).frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche) }
                                    .accessibilityLabel("Mehr")
                            }
                            .buttonStyle(.federnd)
                        }
                    }
                    Picker("Rechner", selection: $reiter) {
                        ForEach(Reiter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch reiter {
                    case .scheiben: scheibenInhalt
                    case .aufwaermen: aufwaermInhalt
                    }
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle("Rechner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
            .onAppear { arbeit = startwert }
        }
        .presentationDetents([.medium, .large])
    }

    private var startwert: Double {
        guard sitzung.liste.indices.contains(index) else { return 60 }
        let kg = sitzung.liste[index].saetze.filter { $0.typ != "w" }.compactMap(\.kg).max()
        return kg ?? 60
    }

    private var scheibenInhalt: some View {
        let e = ScheibenRechner.berechne(kg: arbeit)
        return ListenKarte {
            GymZeile(titel: "Pro Seite", untertitel: "Stange \(TrainingLogik.kgText(ScheibenRechner.stange)) kg") {
                Text(ScheibenRechner.text(e)).font(.headline).multilineTextAlignment(.trailing)
            }
            if e.unterStange {
                Haarlinie()
                GymZeile(titel: "Das ist weniger als die Stange", untertitel: "Nimm Kurzhanteln oder eine leichtere Stange")
            } else if e.rest > 0 {
                Haarlinie()
                GymZeile(titel: "Genau geht es nicht", untertitel: "Mit diesen Scheiben sind es \(ScheibenRechner.zahl(e.erreicht)) kg, \(ScheibenRechner.zahl(e.rest)) kg weniger")
            }
            if !e.proSeite.isEmpty {
                Haarlinie()
                HStack(spacing: Abstand.xs) {
                    ForEach(Array(e.proSeite.enumerated()), id: \.offset) { _, kg in
                        Text(ScheibenRechner.zahl(kg))
                            .font(.footnote.weight(.bold)).monospacedDigit()
                            .frame(minWidth: 36, minHeight: 36)
                            .background(palette.grund, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Rundung.klein, style: .continuous).stroke(palette.rand, lineWidth: 1))
                    }
                }
                .padding(Abstand.m)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Scheiben pro Seite: \(ScheibenRechner.text(e))")
            }
        }
    }

    private var aufwaermInhalt: some View {
        let saetze = AufwaermRechner.saetze(arbeit: arbeit)
        return VStack(alignment: .leading, spacing: Abstand.m) {
            ListenKarte {
                ForEach(Array(zip(AufwaermRechner.standard, saetze).enumerated()), id: \.offset) { i, paar in
                    GymZeile(titel: AufwaermRechner.zeile(paar.1, prozent: paar.0.prozent))
                    if i < saetze.count - 1 { Haarlinie() }
                }
            }
            Button {
                sitzung.aufwaermen(index, arbeit: arbeit)
                schliessen()
            } label: {
                Label("Als Aufwärmsätze einfügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.borderedProminent)
            Text("Aufwärmsätze zählen nicht für Volumen und Rekorde.").font(.footnote).foregroundStyle(palette.text2)
        }
    }
}
