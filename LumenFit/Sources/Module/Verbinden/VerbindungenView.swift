import SwiftUI

/// Die Seite "Verbindungen" (Profil): Lovea verbinden (Idee 81), Freigaben je Datenart mit Vorschau (84), Mitteilungen bei Partner-Ereignissen (83),
/// das Band (85) und die Freunde (89). Nicht verbunden zeigt sie nur die Schalter, nie etwas vom Partner und keine Fehlermeldung.
struct VerbindungenView: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        Group {
            if let daten = umgebung.daten {
                VerbindungenInhalt(daten: daten)
            } else {
                LeerZustand(stimmung: .bereit, satz: "Lege zuerst ein Profil an.")
            }
        }
        .navigationTitle("Verbindungen")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}

private struct VerbindungenInhalt: View {
    let daten: DatenSatz
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    private static let ereignisArten: [PartnerEreignisArt] = [.gymStart, .gymEnde, .ziel, .rekord, .schlafGut]

    private var einstellungen: EinstellungenStore { daten.einstellungen }
    private var verbindung: VerbindungStore { daten.verbindung }
    private var loveaAn: Bool { einstellungen.werte.loveaVerbunden }

    var body: some View {
        Form {
            loveaAbschnitt
            if loveaAn {
                freigabenAbschnitt
                vorschauAbschnitt
                mitteilungenAbschnitt
            }
            bandAbschnitt
            freundeAbschnitt
        }
        .verbindenFormular()
    }

    // MARK: Lovea

    private var loveaAbschnitt: some View {
        VerbindenAbschnitt(titel: "Lovea", fuss: loveaStatus) {
            Toggle("Mit Lovea verbinden", isOn: Binding(
                get: { loveaAn },
                set: { neu in
                    einstellungen.aendere { $0.loveaVerbunden = neu }
                    if neu { Task { _ = await umgebung.mitteiler.erlaubnisHolen() } }
                }))
        }
    }

    private var loveaStatus: String {
        guard loveaAn else { return "Aus. Lumen Fit läuft wie gewohnt." }
        if case .verbunden(let datei) = verbindung.partner { return "Verbunden mit \(datei.profilName)." }
        return "Noch keine Verbindung. Sie entsteht, sobald Lovea seine Datei geschrieben hat."
    }

    // MARK: Freigaben und Vorschau

    private var freigabenAbschnitt: some View {
        VerbindenAbschnitt(titel: "Das teilst du", fuss: VerbindenTexte.freigabenFuss()) {
            ForEach(FreigabeArt.allCases, id: \.self) { art in
                Toggle(isOn: freigabe(art)) {
                    HStack(spacing: Abstand.m) {
                        Image(systemName: FreigabenVorschau.symbol(art))
                            .frame(width: 28)
                            .foregroundStyle(palette.text2)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(FreigabenVorschau.name(art))
                            Text(FreigabenVorschau.erklaerung(art)).font(.footnote).foregroundStyle(palette.text2)
                        }
                    }
                }
                .frame(minHeight: Abstand.tippflaeche)
            }
        }
    }

    private func freigabe(_ art: FreigabeArt) -> Binding<Bool> {
        Binding(get: { verbindung.freigaben.contains(art) },
                set: { neu in
                    if neu { verbindung.freigaben.insert(art) } else { verbindung.freigaben.remove(art) }
                    VerbindenDienste.geteilt?.bruecke.schreibe()
                })
    }

    private var vorschauAbschnitt: some View {
        let zeilen = VerbindenDienste.geteilt?.bruecke.vorschau().map(FreigabenVorschau.zeilen) ?? []
        return VerbindenAbschnitt(titel: "Das sieht dein Partner",
                                  fuss: VerbindenTexte.vorschauFuss()) {
            if verbindung.freigaben.isEmpty {
                Text("Nichts. Du teilst noch keine Daten.").foregroundStyle(palette.text2)
            } else if zeilen.isEmpty {
                Text("Heute gibt es noch keine Werte.").foregroundStyle(palette.text2)
            }
            ForEach(zeilen) { zeile in
                LabeledContent {
                    Text(zeile.wert).monospacedDigit()
                } label: {
                    Label(zeile.titel, systemImage: zeile.symbol)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Mitteilungen

    private var mitteilungenAbschnitt: some View {
        VerbindenAbschnitt(titel: "Mitteilungen", fuss: VerbindenTexte.mitteilungenFuss) {
            ForEach(Self.ereignisArten, id: \.self) { art in
                Toggle(PartnerEreignisRegeln.name(art), isOn: Binding(
                    get: { PartnerEreignisRegeln.an(art, einstellungen.werte) },
                    set: { neu in einstellungen.aendere { $0.mitteilungen[PartnerEreignisRegeln.schluessel(art)] = neu } }))
            }
        }
    }

    // MARK: Band

    private var bandAbschnitt: some View {
        VerbindenAbschnitt(titel: "Band", fuss: "Standard aus. Solange Lovea das Band selbst hält, lass es aus: nur eine App kann das Band halten. Erst mit dem Schalter fragt Lumen Fit nach Bluetooth.") {
            Toggle("Band in Lumen Fit nutzen", isOn: Binding(
                get: { einstellungen.werte.bandAktiv },
                set: { neu in einstellungen.aendere { $0.bandAktiv = neu } }))
            if einstellungen.werte.bandAktiv {
                NavigationLink { BandSeite() } label: { LabeledContent("Band", value: bandKurz) }
            }
        }
    }

    private var bandKurz: String {
        guard let modell = (umgebung.band as? BandDienstImpl)?.modell else { return "Nicht verbunden" }
        guard let akku = modell.akku else { return modell.statusText }
        return "\(modell.statusText), \(akku.prozent) %"
    }

    // MARK: Freunde

    private var freundeAbschnitt: some View {
        VerbindenAbschnitt(titel: "Freunde", fuss: "Wochenkarten per Bild, Link oder QR-Code tauschen, ganz ohne Server.") {
            NavigationLink { FreundeView() } label: { Label("Freunde und Rangliste", systemImage: "person.2") }
        }
    }
}
