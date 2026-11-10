import SwiftUI

/// Die Seite "Verbindungen" (Profil, im Tab Freunde "Freunde verwalten"): deine Personen (QR-Code, Code oder Lovea), offene Anfragen alter Links,
/// Mitteilungen bei Partner-Ereignissen (83)
/// und die Freunde (89). Pro Person: was du zeigst (mit Vorschau), was du sehen willst, Pause, Mitteilungen, Favorit, Name, Entfernen (`VerbindungPersonView`).
/// Das Band wohnt unter Profil > Geräte (`GeraeteView`).
struct VerbindungenView: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        Group {
            if let daten = umgebung.daten {
                VerbindungenInhalt(daten: daten)
            } else {
                LeerZustand(stimmung: .bereit, satz: String(localized: "Lege zuerst ein Profil an."))
            }
        }
        .navigationTitle("Freunde und Partner")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}

private struct VerbindungenInhalt: View {
    let daten: DatenSatz
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var fehler: String?

    private static let ereignisArten: [PartnerEreignisArt] = [.gymStart, .gymEnde, .ziel, .rekord, .schlafGut]

    private var einstellungen: EinstellungenStore { daten.einstellungen }
    private var speicher: VerbindungenSpeicher { umgebung.konto.verbindungen }
    private var personen: [VerbindungEintrag] {
        speicher.personen.sorted { ($0.ich.favorit ? 0 : 1, $0.anzeigeName.lowercased()) < ($1.ich.favorit ? 0 : 1, $1.anzeigeName.lowercased()) }
    }

    var body: some View {
        Form {
            if !speicher.anfragen.isEmpty { anfragenAbschnitt }
            personenAbschnitt
            if !speicher.wartend.isEmpty { wartendAbschnitt }
            if !personen.isEmpty { mitteilungenAbschnitt }
            freundeAbschnitt
        }
        .verbindenFormular()
        .refreshable { await umgebung.konto.verbindungenNeuLaden() }
        .task { await umgebung.konto.verbindungenNeuLaden() }
        .alert("Das hat nicht geklappt", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
            Button("Verstanden", role: .cancel) {}
        } message: { Text(fehler ?? "") }
    }

    // MARK: Anfragen

    private var anfragenAbschnitt: some View {
        VerbindenAbschnitt(titel: String(localized: "Anfragen"), fuss: String(localized: "Erst nach Annehmen sieht die Person etwas, zuerst nur Schritte und Gym.")) {
            ForEach(speicher.anfragen) { a in
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text("\(a.name) möchte sich mit dir verbinden").foregroundStyle(palette.text)
                    HStack(spacing: Abstand.m) {
                        Button("Annehmen") { Task { if !(await umgebung.konto.anfrageAnnehmen(a.id)) { fehler = String(localized: "Das ließ sich nicht annehmen. Versuche es nochmal.") } } }
                            .buttonStyle(.lumenHauptknopf)
                        Button("Ablehnen", role: .destructive) { Task { if !(await umgebung.konto.anfrageAblehnen(a.id)) { fehler = String(localized: "Das ließ sich nicht ablehnen. Versuche es nochmal.") } } }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, Abstand.xs)
            }
        }
    }

    // MARK: Personen

    private var personenAbschnitt: some View {
        VerbindenAbschnitt(titel: String(localized: "Personen"), fuss: personenFuss) {
            if personen.isEmpty {
                Text(speicher.antwort == nil ? "Verbindungen werden geladen." : "Noch niemand verbunden.").foregroundStyle(palette.text2)
            }
            ForEach(personen) { p in
                NavigationLink { VerbindungPersonView(id: p.id) } label: { VerbindungZeile(eintrag: p) }
            }
        }
    }

    private var personenFuss: String {
        String(localized: "Jede Person sieht nur, was du für sie einschaltest. Neue Freunde lädst du im Tab Freunde ein.")
    }

    private var wartendAbschnitt: some View {
        VerbindenAbschnitt(titel: String(localized: "Wartet auf Antwort")) {
            ForEach(speicher.wartend) { w in
                HStack {
                    Label(w.name, systemImage: "hourglass")
                    Spacer()
                    Button("Zurückziehen", role: .destructive) { Task { _ = await umgebung.konto.verbindungEntfernen(w.id) } }
                        .buttonStyle(.borderless)
                }
                .frame(minHeight: Abstand.tippflaeche)
            }
        }
    }

    // MARK: Mitteilungen

    /// Die fünf Schalter liegen eine Ebene tiefer; die Zeile zeigt, wie viele an sind.
    private var mitteilungenAbschnitt: some View {
        VerbindenAbschnitt {
            NavigationLink { VerbindungMitteilungenSeite(einstellungen: einstellungen, arten: Self.ereignisArten) } label: {
                ProfilListenZeile(String(localized: "Mitteilungen"), symbol: "bell.badge", wert: mitteilungenWert)
            }
        }
    }

    private var mitteilungenWert: String {
        let an = Self.ereignisArten.filter { PartnerEreignisRegeln.an($0, einstellungen.werte) }.count
        return String(localized: "\(an) von \(Self.ereignisArten.count) an")
    }

    // MARK: Freunde

    private var freundeAbschnitt: some View {
        VerbindenAbschnitt(titel: String(localized: "Freunde"), fuss: String(localized: "Wochenkarten per Bild, Link oder QR-Code tauschen, ganz ohne Server.")) {
            NavigationLink { FreundeView() } label: { Label("Wochenkarten tauschen", systemImage: "person.2") }
        }
    }
}

/// Mitteilungen bei Partner-Ereignissen: je Ereignis ein Schalter.
private struct VerbindungMitteilungenSeite: View {
    let einstellungen: EinstellungenStore
    let arten: [PartnerEreignisArt]

    var body: some View {
        Form {
            VerbindenAbschnitt(fuss: VerbindenTexte.mitteilungenFuss) {
                ForEach(arten, id: \.self) { art in
                    Toggle(PartnerEreignisRegeln.name(art), isOn: Binding(
                        get: { PartnerEreignisRegeln.an(art, einstellungen.werte) },
                        set: { neu in einstellungen.aendere { $0.mitteilungen[PartnerEreignisRegeln.schluessel(art)] = neu } }))
                }
            }
        }
        .verbindenFormular()
        .navigationTitle("Mitteilungen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
