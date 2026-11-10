import SwiftUI

/// Stats > Mit Freunden > Trainingspartner: eure Woche (`CrewPartnerAbschnitt`) und, mit Lovea verbunden, das Heute des Partners (vorher im Tab Freunde).
struct StatsTrainingspartnerSeite: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                CrewPartnerAbschnitt()
                if umgebung.daten?.einstellungen.werte.loveaVerbunden == true { PartnerKarte(bereich: .heute) }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle("Trainingspartner")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Stats > Mit Freunden > Herausforderungen: laufende Herausforderungen und "Herausfordern" (vorher im Tab Freunde).
struct StatsHerausforderungenSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var herausfordern = false

    var body: some View {
        let jetzt = umgebung.uhr()
        let liste = (CrewDienst.von(umgebung).antwort?.herausforderungen ?? []).filter(\.dabei)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                ListenKarte {
                    if liste.isEmpty {
                        GymZeile(titel: String(localized: "Noch keine Herausforderung"), untertitel: String(localized: "Duell, Gruppe oder ein gemeinsames Ziel mit deinen Freunden."))
                    } else {
                        ForEach(Array(liste.enumerated()), id: \.element.id) { i, h in
                            if i > 0 { Haarlinie() }
                            NavigationLink { CrewHerausforderungSeite(id: h.id) } label: {
                                GymZeile(titel: CrewLogik.titel(h), untertitel: "\(CrewLogik.text(CrewLogik.stand(h, jetzt: jetzt))) · \(CrewLogik.restText(h, jetzt: jetzt))") {
                                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button { herausfordern = true } label: {
                    Label("Herausfordern", systemImage: "flag.checkered").frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.lumenHauptknopf)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle("Herausforderungen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await CrewDienst.von(umgebung).laden() }
        .sheet(isPresented: $herausfordern) { CrewHerausforderungBlatt() }
    }
}

/// Stats > Mit Freunden > Rekorde der Freunde (Pinnwand, vorher im Tab Freunde).
struct StatsRekordeFreundeSeite: View {
    var body: some View {
        ScrollView {
            GymRekordPinnwandView()
                .padding(.horizontal, Abstand.l)
                .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle("Rekorde der Freunde")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Stats > Mit Freunden > Freunde verwalten: wer gerade trainiert (antippbar), Einladen, Code eingeben und was jede Person sieht (vorher im Tab Freunde).
struct StatsFreundeSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var einladenOffen = false
    @State private var codeOffen = false

    var body: some View {
        let zeilen = GymCrewQuelle.zeilen(umgebung)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                if !zeilen.isEmpty { GymCrewZeilen(zeilen: zeilen, grenze: .max) }
                ListenKarte {
                    Button { einladenOffen = true } label: {
                        GymZeile(titel: String(localized: "Freund einladen"), untertitel: String(localized: "QR-Code zeigen, dein Freund scannt ihn")) {
                            Image(systemName: "qrcode").foregroundStyle(palette.akzent).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    Haarlinie()
                    Button { codeOffen = true } label: {
                        GymZeile(titel: String(localized: "Code eingeben"), untertitel: String(localized: "Den Code eines Freundes eintippen")) {
                            Image(systemName: "keyboard").foregroundStyle(palette.akzent).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    Haarlinie()
                    NavigationLink { VerbindungenView() } label: {
                        GymZeile(titel: String(localized: "Was jede Person sieht"), untertitel: String(localized: "Freigaben ändern, entfernen")) {
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle("Freunde")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $einladenOffen) { VerbindungCodeBlatt() }
        .sheet(isPresented: $codeOffen) { VerbindungScanBlatt() }
    }
}
