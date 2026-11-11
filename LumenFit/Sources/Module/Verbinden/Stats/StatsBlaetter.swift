import SwiftUI

/// "Mitmachen" bei Stats > Alle (DSGVO Art. 9: ausdrückliches Ja): wie es Punkte gibt, was andere sehen, Spitzname, Haken "Ich akzeptiere die Regeln",
/// "Akzeptieren und mitmachen". Erst wenn der Server den Spitznamen nimmt, ist man öffentlich. Auch für "Spitzname ändern".
struct StatsMitmachenBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var name = ""
    @State private var akzeptiert = false
    @State private var fehler: String?
    @State private var sendet = false

    var body: some View {
        let lokal = StatsLogik.spitznameGrund(name)
        NavigationStack {
            Form {
                Section("So gibt es Punkte") {
                    LabeledContent("Training", value: "+10")
                    LabeledContent("Set", value: "+1")
                    LabeledContent("Rekord", value: "+5")
                    Text("Ein Training je Tag zählt. Aufwärmsätze zählen nicht. Ein Rekord ist ein neues schwerstes Gewicht in einer Übung.")
                        .font(.footnote).foregroundStyle(palette.text2)
                }
                Section("Was andere sehen") {
                    Text("Deinen Spitznamen, deine Punkte, Trainings, Sets, Serie, wie lange du schon trainierst und deine Schritte (heute und im Monat), wenn du Schritte mitzählst.")
                    Text("Nie deinen Namen, dein Gewicht, deinen Körper oder andere Gesundheitsdaten. Deine Rekorde zählen nur ohne Namen in „Stärker als … %“.")
                        .foregroundStyle(palette.text2)
                }
                Section {
                    TextField("Spitzname", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: name) { fehler = nil }
                } header: {
                    Text("Dein Spitzname")
                } footer: {
                    if let fehler { Text(fehler).foregroundStyle(.red) } else if !name.isEmpty, let lokal { Text(StatsLogik.spitznameText(lokal)) }
                    else { Text("3 bis 20 Zeichen, nicht dein echter Name.") }
                }
                Section {
                    Toggle("Ich akzeptiere die Regeln", isOn: $akzeptiert)
                } footer: {
                    Text("Keine Beleidigungen. Wer oft gemeldet wird, ist ausgeblendet, bis wir es geprüft haben. Aufhören geht jederzeit in Profil > Stats, dann ist alles sofort gelöscht.")
                }
                Section {
                    Button {
                        Task {
                            sendet = true
                            fehler = await StatsDienst.von(umgebung).mitmachen(spitzname: name)
                            sendet = false
                            if fehler == nil { dismiss() }
                        }
                    } label: {
                        HStack {
                            Text("Akzeptieren und mitmachen")
                            if sendet { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(!akzeptiert || lokal != nil || sendet)
                }
            }
            .navigationTitle("Bei Alle mitmachen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .onAppear { if name.isEmpty { name = umgebung.daten?.einstellungen.werte.statsSpitzname ?? "" } }
    }
}

/// Profil > Stats (Baustein für finalizer): "Freunde sehen mich" und "Öffentlich in Alle". Einschalten von Öffentlich geht nur über das Blatt
/// "Mitmachen"; Ausschalten löscht auf dem Server sofort. Der Wert rechts in der Profil-Zeile: `StatsLogik.sichtbarkeitText(_:)`.
struct StatsEinstellungBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @State private var mitmachenOffen = false

    var body: some View {
        let e = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        let oeffentlich = e.statsOeffentlich && e.statsSpitzname != nil
        NavigationStack {
            Form {
                Section {
                    Toggle("Freunde sehen mich", isOn: Binding(get: { e.statsFreunde }, set: { an in umgebung.daten?.einstellungen.aendere { $0.statsFreunde = an } }))
                } footer: {
                    Text("Deine Freunde sehen deinen Platz, deine Punkte, Trainings, Sets, Serie, dein schwerstes Gewicht je Übung und deine Schritte, wenn du Schritte mitzählst.")
                }
                Section {
                    Toggle("Öffentlich in Alle", isOn: Binding(get: { oeffentlich }, set: { an in
                        if an { mitmachenOffen = true } else { umgebung.daten?.einstellungen.aendere { $0.statsOeffentlich = false } }
                    }))
                    if oeffentlich, let name = e.statsSpitzname {
                        Button("Spitzname ändern") { mitmachenOffen = true }
                        LabeledContent("Spitzname", value: name)
                    }
                } footer: {
                    Text("Alle sehen deinen Spitznamen, deine Zahlen und Schritte, nie deinen Namen, dein Gewicht oder andere Gesundheitsdaten.")
                }
                Section {
                    Text("Privat heißt: Deine Zahlen bleiben auf dem iPhone. Deinen Platz rechnet die App selbst aus. Ausschalten löscht deine Zahlen sofort vom Server.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .sheet(isPresented: $mitmachenOffen) { StatsMitmachenBlatt() }
    }
}

/// Übung > Rekorde, Karte "Im Vergleich" (Baustein für finalizer): Platz unter den Freunden und "Stärker als P %" unter allen, mit dem eigenen
/// schwersten Gewicht. Ohne Gewicht in dieser Übung nichts.
struct StatsVergleichKarte: View {
    let uebungID: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var kg: Double?

    var body: some View {
        let stats = StatsDienst.von(umgebung)
        Group {
            if let kg {
                let freunde = StatsLogik.platzFreunde(kg: kg, uebung: uebungID, freunde: stats.antwort?.freunde ?? [])
                let alle = StatsLogik.prozentAlle(kg: kg, uebung: uebungID, rekorde: stats.antwort?.rekorde ?? [:], jahr: stats.eigene.jahr)
                VStack(alignment: .leading, spacing: Abstand.s) {
                    StatsKopf(titel: String(localized: "Im Vergleich"), zusatz: RekordLogik.text(kg))
                    ListenKarte {
                        GymZeile(titel: String(localized: "Freunde"),
                                 untertitel: freunde.von > 1 ? String(localized: "Platz \(freunde.rang) von \(freunde.von)") : String(localized: "Noch kein Freund mit dieser Übung"))
                        Haarlinie()
                        GymZeile(titel: alle.flatMap { $0.jahr }.map { String(localized: "Alle \(StatsLogik.jahrText($0))") } ?? String(localized: "Alle"),
                                 untertitel: alle.map { String(localized: "Stärker als \($0.prozent) %") } ?? String(localized: "Noch zu wenige zum Vergleich"))
                    }
                }
            }
        }
        .task(id: uebungID) {
            let sessions = umgebung.daten?.training.sessions ?? []
            kg = RekordLogik.rekord(RekordLogik.tage(katalogId: uebungID, in: sessions), .gewicht)
            await stats.laden()
        }
    }
}
