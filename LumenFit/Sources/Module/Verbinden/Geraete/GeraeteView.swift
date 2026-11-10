import SwiftUI

/// Profil > Geräte (Wunsch vom 30.10.2026: Geräte im Profil, dann AirPods, Fitness-Tracker und alles, was Lovea am Band hatte):
/// das Band (Fitness-Tracker, aus Lovea hierher gezogen), Kopfhörer und AirPods, Apple Watch und Health. Die Zeilen lesen nur den Stand; Bluetooth fragt erst die Band-Seite,
/// und nur mit dem Schalter "Band in Lumen Fit nutzen".
struct GeraeteView: View {
    @Environment(AppUmgebung.self) private var umgebung

    private var dienst: BandDienstImpl? { umgebung.band as? BandDienstImpl }

    var body: some View {
        Form {
            VerbindenAbschnitt(fuss: VerbindenDienste.geteilt?.uebernahmeZeile ?? String(localized: "Was die Apple Watch misst, kommt über Apple Health.")) {
                NavigationLink { BandSeite() } label: {
                    if umgebung.daten?.einstellungen.werte.bandEingerichtet == true {
                        ProfilListenZeile(String(localized: "Fitness-Tracker"), symbol: "applewatch", wert: bandKurz)
                    } else {
                        ProfilListenZeile(String(localized: "Band einrichten"), symbol: "applewatch")
                    }
                }
                NavigationLink { KopfhoererSeite() } label: {
                    ProfilListenZeile(String(localized: "Kopfhörer und AirPods"), symbol: "airpods")
                }
                NavigationLink { ProfilHealthZugriffView() } label: {
                    ProfilListenZeile(String(localized: "Apple Watch und Health"), symbol: "heart.text.square.fill")
                }
            }
        }
        .verbindenFormular()
        .navigationTitle("Geräte")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Kurzer Stand für die Zeile: aus, nicht verbunden oder Status mit Akku.
    private var bandKurz: String {
        guard umgebung.daten?.einstellungen.werte.bandAktiv == true else { return String(localized: "Aus") }
        guard let modell = dienst?.modell else { return String(localized: "Nicht verbunden") }
        guard let akku = modell.akku, modell.zustand == .verbunden else { return modell.statusText }
        return "\(modell.statusText), \(akku.prozent) %"
    }
}
