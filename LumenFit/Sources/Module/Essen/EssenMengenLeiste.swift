// Quelle: Lovea Health/Ernaehrung/ErnaehrungPortionen.swift (MengenLeiste); neu im Lumen-Design
import SwiftUI

/// Feste Leiste unten auf der Lebensmittel-Seite: Zahlenfeld und Einheit oben, Hauptknopf, darunter das Dreier-Rad (Ganzzahl, Bruch, Einheit).
/// Tippt jemand ins Feld, verschwindet das Rad für die Tastatur. Die Einheit läuft über `einheitWechseln`, damit die Menge mit umgerechnet wird
/// (150 g werden bei "ganze, 50 g" zu 3 Stück).
struct EssenMengenLeiste: View {
    let lebensmittel: Lebensmittel
    let auswahl: MengenOption
    @Binding var zahl: Double
    let knopf: String
    var deaktiviert = false
    let einheitWechseln: @MainActor (MengenOption) -> Void
    let aktion: @MainActor () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var feld = ""
    @State private var ganz = 1
    @State private var bruch = 0
    @FocusState private var tippt: Bool

    /// Alle Optionen des Lebensmittels; eine gespeicherte Portion, die nicht dazugehört, kommt dazu (sonst wäre die Rad-Auswahl ungültig).
    private var optionen: [MengenOption] {
        let alle = MengenOption.optionen(lebensmittel)
        return alle.contains(auswahl) ? alle : alle + [auswahl]
    }

    private var einheitBindung: Binding<MengenOption> {
        Binding(get: { auswahl }, set: { einheitWechseln($0) })
    }

    var body: some View {
        VStack(spacing: Abstand.m) {
            HStack(spacing: Abstand.s) {
                TextField("0", text: $feld)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($tippt)
                    .font(.title3.weight(.semibold)).fontDesign(.rounded).monospacedDigit()
                    .frame(width: 96, height: Abstand.tippflaeche)
                    .padding(.horizontal, Abstand.m)
                    .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                    .accessibilityLabel("Menge")
                Menu {
                    Picker("Einheit", selection: einheitBindung) {
                        ForEach(optionen, id: \.self) { Text($0.anzeige(lebensmittel)).tag($0) }
                    }
                } label: {
                    HStack {
                        Text(auswahl.anzeige(lebensmittel)).lineLimit(1).minimumScaleFactor(0.75)
                        Spacer(minLength: Abstand.xs)
                        Image(systemName: "chevron.up.chevron.down").accessibilityHidden(true)
                    }
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, Abstand.m)
                    .frame(minHeight: Abstand.tippflaeche)
                    .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                }
                .accessibilityLabel("Einheit: \(auswahl.anzeige(lebensmittel))")
            }
            Button(action: aktion) {
                Text(knopf).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.lumenHauptknopf)
            .controlSize(.large)
            .disabled(zahl <= 0 || deaktiviert)
            if !tippt { rad }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .lumenLeiste()
        .animation(bewegungAus ? nil : Feder.schnell, value: tippt)
        .onAppear { vonZahl() }
        .onChange(of: zahl) { _, _ in if !tippt { vonZahl() } }
        .onChange(of: feld) { _, neu in if tippt { zahl = ErnaehrungLogik.eingabe(neu) ?? 0 } }
        .onChange(of: tippt) { _, an in if !an { vonZahl() } }
        .onChange(of: ganz) { _, _ in radGedreht() }
        .onChange(of: bruch) { _, _ in radGedreht() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { tippt = false }
            }
        }
    }

    // Das Rad tickt selbst haptisch; keine zusätzliche Haptik darauflegen.
    private var rad: some View {
        HStack(spacing: 0) {
            Picker("Ganzzahl", selection: $ganz) { ForEach(0...MengenRad.maxGanz, id: \.self) { Text("\($0)").tag($0) } }
                .frame(width: 80)
            Picker("Bruch", selection: $bruch) { ForEach(MengenRad.brueche.indices, id: \.self) { Text(MengenRad.brueche[$0].text).tag($0) } }
                .frame(width: 60)
            Picker("Einheit", selection: einheitBindung) { ForEach(optionen, id: \.self) { Text($0.anzeige(lebensmittel)).tag($0) } }
                .frame(maxWidth: .infinity)
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(height: 168)
    }

    private func radGedreht() {
        guard !tippt, let neu = MengenRad.radZahl(ganz: ganz, bruch: bruch, aktuell: zahl) else { return }
        zahl = neu
        feld = MengenRad.feldText(neu)
    }

    private func vonZahl() {
        feld = MengenRad.feldText(zahl)
        let z = MengenRad.zerlegen(zahl)
        ganz = z.ganz
        bruch = z.bruch
    }
}
