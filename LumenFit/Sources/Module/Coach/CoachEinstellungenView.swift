import SwiftUI

/// Einstellungen des Coachs: eigener Name, wer antwortet (Apple Intelligence oder Regeln) und was mit den Daten passiert (nichts verlässt das iPhone).
struct CoachEinstellungenView: View {
    let modell: CoachModell
    @Environment(\.palette) private var palette
    @State private var name = ""
    @State private var motorText = "Wird geprüft ..."
    @FocusState private var fokus: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                ListenKarte {
                    VStack(alignment: .leading, spacing: Abstand.xs) {
                        Text("Name des Coachs").font(.footnote).foregroundStyle(palette.text2)
                        TextField(CoachLokal.standardName, text: $name)
                            .font(.body)
                            .focused($fokus)
                            .submitLabel(.done)
                            .onSubmit { sichern() }
                            .frame(minHeight: Abstand.tippflaeche)
                            .onChange(of: name) {
                                if name.count > CoachLokal.maxNameZeichen { name = String(name.prefix(CoachLokal.maxNameZeichen)) }
                            }
                    }
                    .padding(Abstand.l)
                    Haarlinie()
                    VStack(alignment: .leading, spacing: Abstand.xs) {
                        Text("Wer antwortet").font(.footnote).foregroundStyle(palette.text2)
                        Text(motorText).font(.body).foregroundStyle(palette.text)
                    }
                    .padding(Abstand.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
                ListenKarte {
                    Toggle(isOn: Binding(get: { modell.disziplin }, set: { modell.setzeDisziplin($0) })) {
                        VStack(alignment: .leading, spacing: Abstand.xs) {
                            Text("Coach hält mich an den Plan").font(.body).foregroundStyle(palette.text)
                            Text("Der Coach erinnert dich im Chat an deinen Trainingsplan, wenn du davon abweichst.")
                                .font(.footnote).foregroundStyle(palette.text2)
                        }
                    }
                    .padding(Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                    Haarlinie()
                    HStack {
                        Text("Gemerkt im Gedächtnis").font(.body).foregroundStyle(palette.text)
                        Spacer(minLength: Abstand.s)
                        Text("\(modell.gedaechtnis?.eintraege.count ?? 0) von \(CoachGedaechtnis.maxEintraege)")
                            .font(.body.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                    .padding(Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                    .accessibilityElement(children: .combine)
                }
                Text("Alle Antworten entstehen auf deinem iPhone. Deine Fragen, dein Schlaf, dein Training und dein Essen werden nie gesendet. "
                     + "Gemerkt wird nur, was du im Gedächtnis siehst, und du kannst es jederzeit löschen.")
                    .font(.subheadline).foregroundStyle(palette.text2)
                Text("Der Coach ist kein Arzt und stellt keine Diagnosen. Bei Beschwerden sprich bitte mit deiner Ärztin oder deinem Arzt.")
                    .font(.subheadline).foregroundStyle(palette.text2)
            }
            .padding(Abstand.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .onAppear { name = modell.einstellungen?.stand.name ?? "" }
        .onDisappear { sichern() }
        .task {
            let bereit = await ModellCoachMotor().verfuegbar()
            motorText = bereit ? "Apple Intelligence auf deinem iPhone" : "Textbausteine und Regeln auf deinem iPhone (Apple Intelligence ist hier nicht verfügbar)"
        }
    }

    private func sichern() { modell.einstellungen?.setzeName(name) }
}
