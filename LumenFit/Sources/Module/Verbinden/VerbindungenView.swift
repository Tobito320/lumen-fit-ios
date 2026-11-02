import SwiftUI

/// Die Seite "Verbindungen" (Profil): deine Personen (QR-Code oder Lovea), offene Anfragen, Mein Code, Code scannen, Mitteilungen bei Partner-Ereignissen (83)
/// und die Freunde (89). Pro Person: was du zeigst (mit Vorschau), was du sehen willst, Pause, Mitteilungen, Favorit, Name, Entfernen (`VerbindungPersonView`).
/// Das Band wohnt unter Profil > Geräte (`GeraeteView`).
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
    @State private var codeOffen = false
    @State private var scanOffen = false
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
            hinzufuegenAbschnitt
            if !speicher.wartend.isEmpty { wartendAbschnitt }
            if !personen.isEmpty { mitteilungenAbschnitt }
            freundeAbschnitt
        }
        .verbindenFormular()
        .refreshable { await umgebung.konto.verbindungenNeuLaden() }
        .task { await umgebung.konto.verbindungenNeuLaden() }
        .sheet(isPresented: $codeOffen) { VerbindungCodeBlatt() }
        .sheet(isPresented: $scanOffen) { VerbindungScanBlatt() }
        .alert("Das hat nicht geklappt", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(fehler ?? "") }
    }

    // MARK: Anfragen

    private var anfragenAbschnitt: some View {
        VerbindenAbschnitt(titel: "Anfragen", fuss: "Erst nach Annehmen sieht die Person etwas, zuerst nur Schritte und Gym.") {
            ForEach(speicher.anfragen) { a in
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text("\(a.name) möchte sich mit dir verbinden").foregroundStyle(palette.text)
                    HStack(spacing: Abstand.m) {
                        Button("Annehmen") { Task { if !(await umgebung.konto.anfrageAnnehmen(a.id)) { fehler = "Das ließ sich nicht annehmen. Versuche es nochmal." } } }
                            .buttonStyle(.lumenHauptknopf)
                        Button("Ablehnen", role: .destructive) { Task { if !(await umgebung.konto.anfrageAblehnen(a.id)) { fehler = "Das ließ sich nicht ablehnen. Versuche es nochmal." } } }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, Abstand.xs)
            }
        }
    }

    // MARK: Personen

    private var personenAbschnitt: some View {
        VerbindenAbschnitt(titel: "Personen", fuss: personenFuss) {
            if personen.isEmpty {
                Text(speicher.antwort == nil ? "Verbindungen werden geladen." : "Noch niemand verbunden.").foregroundStyle(palette.text2)
            }
            ForEach(personen) { p in
                NavigationLink { VerbindungPersonView(id: p.id) } label: { VerbindungZeile(eintrag: p) }
            }
        }
    }

    private var personenFuss: String {
        "Jede Person sieht nur, was du für sie einschaltest."
    }

    private var hinzufuegenAbschnitt: some View {
        VerbindenAbschnitt(titel: "Person hinzufügen", fuss: "Der Code gilt einmal für 10 Minuten und enthält keine Gesundheitsdaten.") {
            Button { codeOffen = true } label: { Label("Mein Code zeigen", systemImage: "qrcode") }.frame(minHeight: Abstand.tippflaeche)
            Button { scanOffen = true } label: { Label("Code scannen", systemImage: "qrcode.viewfinder") }.frame(minHeight: Abstand.tippflaeche)
        }
    }

    private var wartendAbschnitt: some View {
        VerbindenAbschnitt(titel: "Wartet auf Antwort") {
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
                ProfilListenZeile("Mitteilungen", symbol: "bell.badge", wert: mitteilungenWert)
            }
        }
    }

    private var mitteilungenWert: String {
        let an = Self.ereignisArten.filter { PartnerEreignisRegeln.an($0, einstellungen.werte) }.count
        return "\(an) von \(Self.ereignisArten.count) an"
    }

    // MARK: Freunde

    private var freundeAbschnitt: some View {
        VerbindenAbschnitt(titel: "Freunde", fuss: "Wochenkarten per Bild, Link oder QR-Code tauschen, ganz ohne Server.") {
            NavigationLink { FreundeView() } label: { Label("Freunde und Rangliste", systemImage: "person.2") }
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
