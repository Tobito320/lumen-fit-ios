import SwiftUI

/// Aussehen (Idee 73): Erscheinung (System, Hell, Dunkel) und Farbwelt (fünf Themes, mit Freigabe sechs) als je eine Zeile mit Menü. Wirkt sofort: die Wahl
/// geht über `EinstellungenStore` und `AppRootView` setzt Thema und Erscheinung aus den Einstellungen.
struct AussehenView: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let loveaErlaubt = umgebung.konto.loveaErlaubt
        let gespeichert = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        // Mit dem Theme, das wirklich gilt (ein gespeichertes Lovea ohne Freigabe zählt als Monochrom).
        let thema = ProfilThemaWahl.wirksam(gespeichert.thema, loveaErlaubt: loveaErlaubt)
        List {
            ProfilAbschnitt(fuss: ProfilThemaWahl.beschreibung(thema)) {
                Picker("Erscheinung", selection: Binding(
                    get: { gespeichert.erscheinung },
                    set: { neu in umgebung.daten?.einstellungen.aendere { $0.erscheinung = neu } })) {
                    ForEach(Erscheinung.allCases, id: \.self) { Text($0.anzeigeName).tag($0) }
                }
                .pickerStyle(.menu)
                Picker("Farbwelt", selection: Binding(
                    get: { thema },
                    set: { neu in
                        guard let store = umgebung.daten?.einstellungen else { return }
                        store.werte = ProfilThemaWahl.waehle(neu, aktuell: store.werte)
                    })) {
                    ForEach(ProfilThemaWahl.verfuegbar(loveaErlaubt: loveaErlaubt), id: \.self) { Text($0.anzeigeName).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
        .profilListe()
        .navigationTitle("Aussehen")
        .haptik(.auswahl, bei: thema)
    }
}
