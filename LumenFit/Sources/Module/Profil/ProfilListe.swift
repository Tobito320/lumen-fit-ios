import SwiftUI

/// Kompakte Einstellungsseiten (Wunsch 02.11.2026): eine Zeile je Einstellung, Titel links, Wert rechts, wenige Abschnitte, kurze Fußtexte.
/// Systemliste `.insetGrouped` mit `.listSectionSpacing(.compact)`; Zeilen auf der flachen `flaeche` des Themes, Seite auf dem Theme-Grund.
private struct ProfilListenStil: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    func profilListe() -> some View { modifier(ProfilListenStil()) }
}

/// Ein Abschnitt einer Einstellungsliste: optionaler Kopf, Zeilen auf `flaeche`, optionaler Fußtext (höchstens ein kurzer Satz).
struct ProfilAbschnitt<Inhalt: View>: View {
    let titel: String?
    let fuss: String?
    let inhalt: Inhalt
    @Environment(\.palette) private var palette

    init(_ titel: String? = nil, fuss: String? = nil, @ViewBuilder inhalt: () -> Inhalt) {
        self.titel = titel
        self.fuss = fuss
        self.inhalt = inhalt()
    }

    var body: some View {
        Section {
            inhalt.listRowBackground(palette.flaeche)
        } header: {
            if let titel { Text(titel).foregroundStyle(palette.text2) }
        } footer: {
            if let fuss { Text(fuss).foregroundStyle(palette.text2) }
        }
    }
}

/// Eine Einstellungszeile: Symbol und Titel links, Wert rechts, eine Zeile, lieber kleiner als abgeschnitten.
/// Mit `farbe` steht das Symbol weiß im farbigen Quadrat (`SymbolQuadrat`, neues Design).
struct ProfilListenZeile: View {
    let titel: String
    var symbol: String?
    var wert: String?
    var farbe: Color?
    @Environment(\.palette) private var palette

    init(_ titel: String, symbol: String? = nil, wert: String? = nil, farbe: Color? = nil) {
        self.titel = titel
        self.symbol = symbol
        self.wert = wert
        self.farbe = farbe
    }

    var body: some View {
        LabeledContent {
            if let wert {
                Text(wert).foregroundStyle(palette.text2).lineLimit(1).minimumScaleFactor(0.8)
            }
        } label: {
            Group {
                if let symbol, let farbe {
                    Label { Text(titel) } icon: { SymbolQuadrat(symbol: symbol, farbe: farbe) }
                } else if let symbol {
                    Label(titel, systemImage: symbol)
                } else {
                    Text(titel)
                }
            }
            .foregroundStyle(palette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}

/// Versionsnummer der App für "Über Lumen Fit".
enum ProfilAppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
