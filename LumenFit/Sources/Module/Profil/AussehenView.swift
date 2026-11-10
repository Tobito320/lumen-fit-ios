import SwiftUI

/// Aussehen (unter Mehr Einstellungen): Erscheinung System, Hell oder Dunkel zum Antippen (Standard System) und Haptik. Es gibt nur ein Theme (Auftrag 09.11.); die Wahl wirkt sofort über `EinstellungenStore`,
/// `AppRootView` setzt die Erscheinung aus den Einstellungen.
struct AussehenView: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let gespeichert = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        List {
            ProfilAbschnitt {
                Picker("Erscheinung", selection: Binding(
                    get: { gespeichert.erscheinung },
                    set: { neu in umgebung.daten?.einstellungen.aendere { $0.erscheinung = neu } })) {
                    ForEach(Erscheinung.allCases, id: \.self) { Text($0.anzeigeName).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            ProfilAbschnitt {
                Toggle(isOn: Binding(get: { gespeichert.haptik },
                                     set: { an in umgebung.daten?.einstellungen.aendere { $0.haptik = an } })) {
                    ProfilListenZeile("Haptik", symbol: "hand.tap.fill")
                }
            }
        }
        .profilListe()
        .navigationTitle("Aussehen")
        .haptik(.auswahl, bei: gespeichert.erscheinung)
    }
}
