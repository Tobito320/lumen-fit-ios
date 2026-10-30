import SwiftUI

/// Profil > Geräte (Wunsch vom 30.10.2026: Geräte im Profil, dann AirPods, Fitness-Tracker und alles, was Lovea am Band hatte):
/// das Band (Fitness-Tracker, aus Lovea hierher gezogen), Kopfhörer und AirPods, Apple Watch und Health. Die Zeilen lesen nur den Stand; Bluetooth fragt erst die Band-Seite,
/// und nur mit dem Schalter "Band in Lumen Fit nutzen".
struct GeraeteView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    private var dienst: BandDienstImpl? { umgebung.band as? BandDienstImpl }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                gruppe("Fitness-Tracker") {
                    NavigationLink { BandSeite() } label: {
                        ProfilZeile(symbol: "applewatch", titel: "Fitness-Tracker", zeile: "Das Band: Schritte, Puls, Schlaf, Vibration", wert: bandKurz)
                    }
                }
                gruppe("Audio") {
                    NavigationLink { KopfhoererSeite() } label: {
                        ProfilZeile(symbol: "airpods", titel: "Kopfhörer und AirPods", zeile: "Ansagen im Training", wert: nil)
                    }
                }
                gruppe("Apple Watch und Health") {
                    NavigationLink { ProfilHealthZugriffView() } label: {
                        ProfilZeile(symbol: "heart.text.square.fill", titel: "Apple Health", zeile: "Puls, Schritte und Schlaf von Watch und iPhone", wert: nil)
                    }
                }
                Text("Den Akku der AirPods gibt iOS Apps nicht frei. Was die Apple Watch misst, kommt über Apple Health.")
                    .font(.footnote)
                    .foregroundStyle(palette.text2)
                    .padding(.horizontal, Abstand.xs)
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Geräte")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }

    /// Kurzer Stand für die Zeile: aus, nicht verbunden oder Status mit Akku.
    private var bandKurz: String {
        guard umgebung.daten?.einstellungen.werte.bandAktiv == true else { return "Aus" }
        guard let modell = dienst?.modell else { return "Nicht verbunden" }
        guard let akku = modell.akku, modell.zustand == .verbunden else { return modell.statusText }
        return "\(modell.statusText), \(akku.prozent) %"
    }

    private func gruppe<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ProfilGruppenKopf(text: titel)
            ListenKarte { inhalt() }.buttonStyle(.plain)
        }
    }
}
