// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (Schalter "Live-Aktivität")
import SwiftUI

/// Der Abschnitt "Live-Aktivität" in "Tagebuch anpassen": zeigt den Essensstand des Tages auf dem Sperrbildschirm und in der Dynamic Island.
/// Standard aus; der Haken liegt in UserDefaults (`fit.essen.live`), die Änderung geht als Ereignis an die Live-Activity.
struct EssenLiveSchalter: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var an = EssenLiveEinstellung.an()

    var body: some View {
        Section {
            Toggle("Essen auf dem Sperrbildschirm", isOn: Binding(
                get: { an },
                set: { neu in
                    an = neu
                    EssenLiveEinstellung.setze(neu)
                    umgebung.ereignisse.senden(.einstellungenGeaendert)
                }))
                .frame(minHeight: Abstand.tippflaeche)
                .listRowBackground(palette.flaeche)
        } header: {
            Text("Live-Aktivität")
        } footer: {
            Text("Zeigt Kalorien, Protein und deine Mahlzeiten von heute auf dem Sperrbildschirm und in der Dynamic Island. Sie aktualisiert sich nur, wenn du etwas einträgst.")
        }
    }
}
