import SwiftUI

/// Statt des Onboardings, wenn der Schlüsselbund-Eintrag der Profile da war, sich aber nicht lesen ließ (SPEC 5.4). Es wird nichts überschrieben:
/// "Erneut versuchen" liest noch einmal, bei einem beschädigten Eintrag kann die Person ihn verwerfen (eine Kopie bleibt als `konto.profile.alt`).
struct ProfilLadeProblemView: View {
    let problem: ProfilLadeProblem
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var frage = false

    var body: some View {
        VStack(spacing: Abstand.xl) {
            Spacer()
            LumiView(stimmung: .denkt, groesse: 120)
            VStack(spacing: Abstand.s) {
                Text("Ich finde deine Profile gerade nicht").font(.title2.bold()).foregroundStyle(palette.text).multilineTextAlignment(.center)
                Text(problem == .lesefehler ? ProfilTexte.ladeProblemLesefehler : ProfilTexte.ladeProblemKaputt)
                    .font(.body).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            }
            Button { umgebung.ladeProfileNeu() } label: { Text("Erneut versuchen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(palette.aufAkzent)
            if problem == .kaputt {
                Button(role: .destructive) { frage = true } label: { Text("Verwerfen und neu anfangen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
            }
            Spacer()
        }
        .padding(Abstand.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lumenHintergrund()
        .confirmationDialog("Beschädigten Eintrag verwerfen?", isPresented: $frage, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) { umgebung.profil.verwerfeKaputtes() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Eine Kopie bleibt auf diesem iPhone. Daten in Health bleiben.")
        }
    }
}
