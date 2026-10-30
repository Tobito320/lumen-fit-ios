import SwiftUI

/// Aussehen (Idee 73): Theme-Karten (fünf, mit Freigabe sechs) mit Mini-Vorschau (Farbe, Muster) und die Erscheinung System, Hell, Dunkel. Wirkt sofort: die Wahl
/// geht über `EinstellungenStore` und `AppRootView` setzt Thema und Erscheinung aus den Einstellungen.
struct AussehenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    private let spalten = [GridItem(.flexible(), spacing: Abstand.m), GridItem(.flexible(), spacing: Abstand.m)]

    var body: some View {
        let loveaErlaubt = umgebung.konto.loveaErlaubt
        let gespeichert = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        // Mit dem Theme, das wirklich gilt (ein gespeichertes Lovea ohne Freigabe zählt als Monochrom).
        let einstellungen: Einstellungen = {
            var e = gespeichert
            e.thema = ProfilThemaWahl.wirksam(e.thema, loveaErlaubt: loveaErlaubt)
            return e
        }()
        // Steht die Erscheinung auf System, ist `schema` das des Systems; bei Hell und Dunkel zählt die Wahl.
        let dunkel = ProfilThemaWahl.istDunkel(einstellungen.erscheinung, systemDunkel: schema == .dark)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    ProfilGruppenKopf(text: "Erscheinung")
                    Picker("Erscheinung", selection: Binding(
                        get: { einstellungen.erscheinung },
                        set: { neu in umgebung.daten?.einstellungen.aendere { $0.erscheinung = neu } })) {
                        ForEach(Erscheinung.allCases, id: \.self) { Text($0.anzeigeName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: Abstand.s) {
                    ProfilGruppenKopf(text: "Farbwelt")
                    LazyVGrid(columns: spalten, spacing: Abstand.m) {
                        ForEach(ProfilThemaWahl.verfuegbar(loveaErlaubt: loveaErlaubt), id: \.self) { thema in karte(thema, aktiv: einstellungen.thema == thema, dunkel: dunkel) }
                    }
                    Text(ProfilThemaWahl.beschreibung(einstellungen.thema))
                        .font(.footnote).foregroundStyle(palette.text2)
                        .padding(.horizontal, Abstand.xs)
                    Text("Bei erhöhtem Kontrast schaltet iOS die Muster von selbst aus.")
                        .font(.footnote).foregroundStyle(palette.text2)
                        .padding(.horizontal, Abstand.xs)
                }
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Aussehen")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .haptik(.auswahl, bei: einstellungen.thema)
    }

    private func karte(_ thema: ThemaID, aktiv: Bool, dunkel: Bool) -> some View {
        Button {
            guard let store = umgebung.daten?.einstellungen else { return }
            store.werte = ProfilThemaWahl.waehle(thema, aktuell: store.werte)
        } label: {
            VStack(alignment: .leading, spacing: Abstand.s) {
                ProfilThemaVorschau(thema: thema, dunkel: dunkel)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(thema.anzeigeName).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                        Text(ProfilThemaWahl.muster(thema)).font(.footnote).foregroundStyle(palette.text2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: aktiv ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(aktiv ? palette.text : palette.rand)
                        .accessibilityHidden(true)
                }
            }
            .padding(Abstand.s)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(aktiv ? palette.text : palette.haar, lineWidth: aktiv ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.federnd)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(thema.anzeigeName), Muster \(ProfilThemaWahl.muster(thema))")
        .accessibilityValue(aktiv ? "ausgewählt" : "")
        .accessibilityAddTraits(aktiv ? [.isButton, .isSelected] : .isButton)
    }
}
