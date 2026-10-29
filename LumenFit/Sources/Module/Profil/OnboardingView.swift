import SwiftUI

/// Stub des Grundgerüsts: Name und Passwort, dann ist das Profil da (es gibt nie einen Anmeldebildschirm). Das Modul profil baut das richtige Onboarding.
struct OnboardingView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var name = ""
    @State private var passwort = ""
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Dein Name", text: $name)
                    SecureField("Passwort (mindestens 4 Zeichen)", text: $passwort)
                }
                if let fehler { Text(fehler).foregroundStyle(.secondary) }
                Button("Profil anlegen") { anlegen() }
            }
            .navigationTitle("Willkommen")
            .lumenHintergrund()
        }
    }

    private func anlegen() {
        do {
            try umgebung.profil.anlegen(name: name, passwort: passwort)
            fehler = nil
        } catch ProfilFehler.nameLeer {
            fehler = "Wie soll Lumi dich nennen?"
        } catch ProfilFehler.passwortZuKurz {
            fehler = "Das Passwort braucht mindestens 4 Zeichen."
        } catch {
            fehler = "Das Profil konnte nicht gespeichert werden. Versuch es nochmal."
        }
    }
}
