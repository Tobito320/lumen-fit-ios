import SwiftUI

/// "Mehr Einstellungen" (Entwurf 10.11.2026): Aussehen, Sprache, Mitteilungen; Health-Zugriff, Daten, Über Lumen Fit; Geräte nur mit Freigabe des Servers.
struct ProfilMehrEinstellungenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            ProfilAbschnitt {
                ProfilLink(titel: String(localized: "Aussehen"), eintrag: .profilAussehen, symbol: "moon.fill", farbe: Bereichsfarbe.gewicht, wert: themaName) {
                    AussehenView()
                }
                // Die Sprache wählt iOS je App (Einstellungen, Lumen Fit, Sprache); rechts steht die aktive.
                Button {
                    umgebung.konto.nutzung.getippt(.profilSprache)
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    ProfilListenZeile(String(localized: "Sprache"), symbol: "globe", wert: ProfilSprache.aktiv(), farbe: .orange)
                }
                .onAppear { umgebung.konto.nutzung.gesehen(.profilSprache) }
                ProfilLink(titel: String(localized: "Mitteilungen"), eintrag: .profilMitteilungen, symbol: "bell.fill", farbe: .red,
                           wert: String(localized: "Freunde")) {
                    VerbindungenView()
                }
            }
            ProfilAbschnitt {
                ProfilLink(titel: String(localized: "Health-Zugriff"), eintrag: .profilHealth, symbol: "heart.fill", farbe: .pink) { ProfilHealthZugriffView() }
                ProfilLink(titel: String(localized: "Daten"), eintrag: .profilDaten, symbol: "icloud.fill", farbe: Bereichsfarbe.creatin, wert: sicherungKurz) {
                    ProfilDatenView()
                }
                ProfilLink(titel: String(localized: "Über Lumen Fit"), eintrag: .profilUeber, symbol: "info.circle.fill", farbe: Bereichsfarbe.einstellungen,
                           wert: ProfilAppInfo.version) {
                    ProfilUeberView()
                }
            }
            // Band und AirPods gehören zum Schlaf-Schalter des Servers (`ServerConfig.schlafSichtbar`).
            if umgebung.konto.schlafSichtbar {
                ProfilAbschnitt {
                    ProfilLink(titel: String(localized: "Geräte"), eintrag: .profilGeraete, symbol: "applewatch", farbe: .indigo) { GeraeteView() }
                }
            }
        }
        .profilListe()
        .navigationTitle("Mehr Einstellungen")
    }

    private var themaName: String? {
        umgebung.daten.map { $0.einstellungen.werte.erscheinung.anzeigeName }
    }

    private var sicherungKurz: String {
        ProfilSicherungStand.kurz(zuletzt: umgebung.daten.flatMap { ProfilSicherungStand.lade($0.ordner) }, jetzt: umgebung.uhr())
    }
}

/// Die Sprache, in der die App gerade läuft, in dieser Sprache geschrieben ("Deutsch", "English").
enum ProfilSprache {
    static func aktiv(_ codes: [String] = Bundle.main.preferredLocalizations) -> String {
        let code = codes.first ?? "de"
        let name = Locale(identifier: code).localizedString(forLanguageCode: code) ?? code
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}

/// Präferenzen (früher "Ziele und Körper"): wie in der Einführung Erfahrung, Ziele, Orte, Tage, Dauer und Fokus-Muskeln, dazu "Mitzählen" (Bereiche,
/// Gewicht, Schritte, Schlaf, Creatin, Gewohnheiten) und die bisherigen Ziele und Körperdaten eine Ebene tiefer. Ganz unten "Einführung nochmal ansehen".
struct ProfilPraeferenzenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var gewohnheiten = false
    @State private var einfuehrung: ProfilOnboardingFluss?

    var body: some View {
        let werte = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        List {
            ProfilAbschnitt(String(localized: "Training"), fuss: planText) {
                Picker(selection: binding(\.trainingsErfahrung)) {
                    Text("Nicht gewählt").tag(TrainingsErfahrung?.none)
                    ForEach(TrainingsErfahrung.allCases, id: \.self) { Text(ProfilPraeferenzLogik.titel($0)).tag(TrainingsErfahrung?.some($0)) }
                } label: {
                    Text("Erfahrung").foregroundStyle(palette.text)
                }
                .pickerStyle(.menu)
                NavigationLink {
                    ProfilMehrfachSeite(titel: String(localized: "Ziel"), werte: TrainingsZiel.allCases, gewaehlt: binding(\.trainingsZiele),
                                        name: ProfilPraeferenzLogik.titel, hinweis: ProfilPraeferenzLogik.hinweis)
                } label: {
                    ProfilListenZeile(String(localized: "Ziel"), wert: ProfilPraeferenzLogik.zieleText(werte.trainingsZiele))
                }
                NavigationLink {
                    ProfilMehrfachSeite(titel: String(localized: "Ort"), werte: TrainingsOrt.allCases, gewaehlt: binding(\.trainingsOrte),
                                        name: ProfilPraeferenzLogik.titel, hinweis: ProfilPraeferenzLogik.hinweis)
                } label: {
                    ProfilListenZeile(String(localized: "Ort"), wert: ProfilPraeferenzLogik.orteText(werte.trainingsOrte))
                }
                Stepper(value: tage, in: ProfilPraeferenzLogik.tageBereich) {
                    ProfilListenZeile(String(localized: "Tage pro Woche"), wert: ProfilPraeferenzLogik.tageText(tage.wrappedValue))
                }
                Stepper(value: minuten, in: ProfilPraeferenzLogik.minutenBereich, step: ProfilPraeferenzLogik.minutenSchritt) {
                    ProfilListenZeile(String(localized: "Dauer"), wert: ProfilPraeferenzLogik.minutenText(minuten.wrappedValue))
                }
                NavigationLink {
                    ScrollView { EinfuehrungFokusWahl(fokus: binding(\.fokusMuskeln)).padding(Abstand.l) }
                        .lumenHintergrund()
                        .navigationTitle("Fokus-Muskeln")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    ProfilListenZeile(String(localized: "Fokus-Muskeln"), wert: ProfilPraeferenzLogik.fokusText(werte.fokusMuskeln))
                }
            }
            ProfilAbschnitt(String(localized: "Mitzählen"), fuss: String(localized: "Nur was an ist, siehst du auf der Startseite. Ausblenden löscht nichts.")) {
                bereichSchalter(.gym, werte)
                schalter(String(localized: "Körpergewicht"), "scalemass.fill", Bereichsfarbe.gewicht, binding(\.gewichtMitzaehlen))
                schalter(String(localized: "Schritte"), "figure.walk", .orange, binding(\.schritteMitzaehlen))
                if umgebung.konto.schlafSichtbar { bereichSchalter(.schlaf, werte) }
                schalter(String(localized: "Creatin"), "pills.fill", Bereichsfarbe.creatin, binding(\.creatinMitzaehlen))
                bereichSchalter(.essen, werte)
                Button { gewohnheiten = true } label: {
                    ProfilListenZeile(String(localized: "Gewohnheiten verwalten"), symbol: "checklist", farbe: .green)
                }
            }
            ProfilAbschnitt(String(localized: "Ziele und Körper")) {
                NavigationLink { ZieleView() } label: {
                    ProfilListenZeile(String(localized: "Ziele und Körper"), symbol: "target", wert: zielWert, farbe: .red)
                }
            }
            Section {
                Button {
                    let gymTage = umgebung.daten?.ziele.ziele.gymTageProWoche ?? ProfilPraeferenzLogik.standardTage
                    einfuehrung = ProfilOnboardingFluss(nochmal: true, start: werte, gymTage: gymTage)
                } label: {
                    Text("Einführung nochmal ansehen").font(.body.weight(.semibold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.lumenHauptknopf)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .profilListe()
        .navigationTitle("Präferenzen")
        .sheet(isPresented: $gewohnheiten) { HabitVerwaltungView() }
        .fullScreenCover(item: $einfuehrung) { OnboardingView(fluss: $0) }
    }

    // MARK: - Werte

    private var planText: String? {
        guard let name = umgebung.daten?.training.plan.splitName, !name.isEmpty else { return nil }
        return String(localized: "Dein Plan: \(name)")
    }

    private var zielWert: String? {
        guard let art = umgebung.daten?.ziele.ziele.art else { return nil }
        switch art {
        case .abnehmen: return String(localized: "Abnehmen")
        case .halten: return String(localized: "Halten")
        case .aufbauen: return String(localized: "Aufbauen")
        }
    }

    private var tage: Binding<Int> {
        Binding(get: { umgebung.daten?.ziele.ziele.gymTageProWoche ?? ProfilPraeferenzLogik.standardTage },
                set: { neu in
                    guard let store = umgebung.daten?.ziele else { return }
                    var z = store.ziele
                    z.gymTageProWoche = neu
                    store.setze(z)
                })
    }

    private var minuten: Binding<Int> {
        Binding(get: { umgebung.daten?.einstellungen.werte.trainingsMinuten ?? ProfilPraeferenzLogik.standardMinuten },
                set: { neu in umgebung.daten?.einstellungen.aendere { $0.trainingsMinuten = ProfilPraeferenzLogik.minutenGerundet(neu) } })
    }

    private func binding<Wert>(_ pfad: WritableKeyPath<Einstellungen, Wert>) -> Binding<Wert> {
        Binding(get: { (umgebung.daten?.einstellungen.werte ?? Einstellungen())[keyPath: pfad] },
                set: { neu in umgebung.daten?.einstellungen.aendere { $0[keyPath: pfad] = neu } })
    }

    private func schalter(_ titel: String, _ symbol: String, _ farbe: Color, _ an: Binding<Bool>) -> some View {
        Toggle(isOn: an) { ProfilListenZeile(titel, symbol: symbol, farbe: farbe) }
            .tint(palette.akzentFlaeche)
    }

    /// Bereich an oder aus (Gym, Schlaf, Essen); der letzte eingeschaltete ist gesperrt.
    private func bereichSchalter(_ bereich: AppBereich, _ werte: Einstellungen) -> some View {
        let waehlbar = ProfilBereiche.waehlbar(schlafSichtbar: umgebung.konto.schlafSichtbar)
        let nurEiner = waehlbar.filter { werte.zeigt($0) }.count == 1
        return Toggle(isOn: Binding(get: { werte.zeigt(bereich) }, set: { ProfilBereiche.schalte(bereich, an: $0, in: umgebung) })) {
            ProfilListenZeile(ProfilBereiche.titel(bereich), symbol: ProfilBereiche.symbol(bereich), farbe: farbe(bereich))
        }
        .tint(palette.akzentFlaeche)
        .disabled(nurEiner && werte.zeigt(bereich))
    }

    private func farbe(_ bereich: AppBereich) -> Color {
        switch bereich {
        case .gym: palette.akzent
        case .essen: .pink
        case .schlaf: .indigo
        }
    }
}

/// Mehrfachwahl mit Haken (Ziele, Orte).
private struct ProfilMehrfachSeite<Wert: Hashable>: View {
    let titel: String
    let werte: [Wert]
    @Binding var gewaehlt: [Wert]
    let name: (Wert) -> String
    let hinweis: (Wert) -> String

    var body: some View {
        List {
            ProfilAbschnitt(fuss: String(localized: "Du kannst mehrere wählen.")) {
                ForEach(werte, id: \.self) { w in
                    ProfilAuswahlZeile(titel: name(w), hinweis: hinweis(w), an: gewaehlt.contains(w)) {
                        gewaehlt = ProfilPraeferenzLogik.umschalten(gewaehlt, w)
                    }
                }
            }
        }
        .profilListe()
        .navigationTitle(titel)
    }
}
