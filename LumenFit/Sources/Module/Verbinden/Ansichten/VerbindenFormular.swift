import SwiftUI

/// Abschnitt eines Einstellungsformulars im Lumen-Look: Zeilen auf `flaeche`, Kopf und Fuß als Text.
struct VerbindenAbschnitt<Inhalt: View>: View {
    var titel: String?
    var fuss: String?
    let inhalt: Inhalt
    @Environment(\.palette) private var palette

    init(titel: String? = nil, fuss: String? = nil, @ViewBuilder inhalt: () -> Inhalt) {
        self.titel = titel
        self.fuss = fuss
        self.inhalt = inhalt()
    }

    var body: some View {
        Section {
            inhalt
        } header: {
            if let titel { Text(titel) }
        } footer: {
            if let fuss { Text(fuss) }
        }
        .listRowBackground(palette.flaeche)
    }
}

private struct VerbindenFormularStil: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .tint(palette.akzent)
    }
}

extension View {
    /// Das Formular der Verbinden-Seiten: Hintergrund des Themes, enge Abschnitte, Schalter in der Akzentfarbe.
    func verbindenFormular() -> some View { modifier(VerbindenFormularStil()) }
}
