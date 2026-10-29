import SwiftUI

/// Das Onboarding in vier Karten (Idee 71): Willkommen mit Lumi, Name und Passwort, ein Ziel, Health. Danach nie wieder ein Passwort beim Start.
/// Das Profil entsteht erst auf der letzten Karte (`ProfilOnboardingFluss.abschliessen`).
struct OnboardingView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion
    @State private var fluss = ProfilOnboardingFluss()
    @State private var arbeitet = false
    @FocusState private var fokus: Feld?

    private enum Feld { case name, passwort }

    var body: some View {
        VStack(spacing: Abstand.l) {
            kopf
            ScrollView {
                VStack(spacing: Abstand.xl) {
                    switch fluss.karte {
                    case .willkommen: willkommen
                    case .profil: profil(name: Bindable(fluss).name, passwort: Bindable(fluss).passwort)
                    case .ziel: ziel
                    case .health: health
                    }
                    if let fehler = fluss.fehler { FehlerKarte(titel: "Das hat nicht geklappt", hilfe: fehler) }
                }
                .padding(.horizontal, Abstand.l)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .id(fluss.karte)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            fuss
        }
        .padding(.vertical, Abstand.l)
        .animation(reduceMotion ? nil : Feder.weich, value: fluss.karte)
        .lumenHintergrund()
        .haptik(.auswahl, bei: fluss.karte)
    }

    // MARK: - Kopf und Fuß

    private var kopf: some View {
        HStack {
            if fluss.karte != .willkommen {
                Button { fluss.zurueck() } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .accessibilityLabel("Zurück")
            } else {
                Color.clear.frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            Spacer()
            HStack(spacing: Abstand.s) {
                ForEach(ProfilOnboardingFluss.Karte.allCases, id: \.rawValue) { karte in
                    Capsule()
                        .fill(karte.rawValue <= fluss.karte.rawValue ? palette.text : palette.haar)
                        .frame(width: karte == fluss.karte ? 24 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(fluss.stand)
            Spacer()
            Color.clear.frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .padding(.horizontal, Abstand.s)
        .foregroundStyle(palette.text)
    }

    @ViewBuilder private var fuss: some View {
        VStack(spacing: Abstand.s) {
            switch fluss.karte {
            case .willkommen:
                knopf("Los geht's") { fluss.weiter() }
            case .profil, .ziel:
                knopf("Weiter") { fokus = nil; fluss.weiter() }.disabled(!fluss.kannWeiter)
            case .health:
                knopf("Health erlauben") { fertig(mitHealth: true) }.disabled(arbeitet)
                Button("Später") { fertig(mitHealth: false) }
                    .frame(minHeight: Abstand.tippflaeche)
                    .disabled(arbeitet)
            }
        }
        .padding(.horizontal, Abstand.l)
    }

    private func knopf(_ titel: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) { Text(titel).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(palette.aufAkzent)
    }

    // MARK: - Karten

    private var willkommen: some View {
        VStack(spacing: Abstand.l) {
            LumiView(stimmung: .bereit, groesse: 160).padding(.top, Abstand.l)
            Text("Hallo, ich bin Lumi.").font(.largeTitle.bold()).foregroundStyle(palette.text).multilineTextAlignment(.center)
            Text("Ich zähle mit, wenn du dich bewegst, trainierst und dich erholst. Das Einrichten dauert eine Minute.")
                .font(.body).foregroundStyle(palette.text2).multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private func profil(name: Binding<String>, passwort: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            karteTitel("Wie soll ich dich nennen?", "Name und Passwort bleiben auf deinem iPhone.")
            VStack(spacing: Abstand.m) {
                TextField("Dein Name", text: name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($fokus, equals: .name)
                    .onSubmit { fokus = .passwort }
                    .eingabeFeld(palette)
                SecureField("Passwort (mindestens \(Passwort.mindestLaenge) Zeichen)", text: passwort)
                    .textContentType(.newPassword)
                    .submitLabel(.done)
                    .focused($fokus, equals: .passwort)
                    .onSubmit { fokus = nil }
                    .eingabeFeld(palette)
                if let hinweis = fluss.passwortHinweis {
                    Text(hinweis).font(.footnote).foregroundStyle(palette.text2).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Label {
                Text("Du meldest dich nie wieder an. Das Passwort fragt nur nach, wenn du etwas Wichtiges tust: Profil wechseln, Passwort ändern oder alles löschen.")
                    .font(.subheadline).foregroundStyle(palette.text2)
            } icon: {
                Image(systemName: "lock.open.fill").foregroundStyle(palette.text)
            }
        }
    }

    private var ziel: some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            karteTitel("Was ist dein Ziel?", "Daraus schlage ich dir Schritte, Kalorien und Protein vor. Ändern geht jederzeit.")
            ListenKarte {
                ProfilAuswahlZeile(titel: "Abnehmen", hinweis: "Etwas weniger essen, viel bewegen", an: fluss.art == .abnehmen) { fluss.art = .abnehmen }
                Haarlinie()
                ProfilAuswahlZeile(titel: "Fit bleiben", hinweis: "Gewicht halten, gesund und stark", an: fluss.art == .halten) { fluss.art = .halten }
                Haarlinie()
                ProfilAuswahlZeile(titel: "Muskeln aufbauen", hinweis: "Mehr essen, mehr Protein, stärker werden", an: fluss.art == .aufbauen) { fluss.art = .aufbauen }
            }
            ListenKarte {
                Stepper(value: Bindable(fluss).gymTage, in: 1...7) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gym-Tage pro Woche").font(.body).foregroundStyle(palette.text)
                        Text(fluss.gymTage == 1 ? "1 Tag" : "\(fluss.gymTage) Tage").font(.footnote.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                }
                .padding(Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
            }
        }
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            karteTitel("Health dazunehmen?", "Lumen Fit liest Schritte, Schlaf, Training und mehr aus Health. So ist dein erster Tag schon voll. Alles bleibt auf deinem iPhone.")
            ListenKarte {
                ProfilZeile(symbol: "figure.walk", titel: "Schritte und Bewegung", zeile: "Für deinen Tagesbogen", pfeil: false)
                Haarlinie()
                ProfilZeile(symbol: "bed.double.fill", titel: "Schlaf und Erholung", zeile: "Für deine Nächte und die Bereitschaft", pfeil: false)
                Haarlinie()
                ProfilZeile(symbol: "scalemass.fill", titel: "Gewicht", zeile: "Für Verlauf und Ziel", pfeil: false)
            }
            Text("Du kannst das auch später ändern: Einstellungen, Health, Datenzugriff und Geräte, Lumen Fit.")
                .font(.footnote).foregroundStyle(palette.text2)
        }
    }

    private func karteTitel(_ titel: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text(titel).font(.title.bold()).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Text(text).font(.body).foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Abschluss

    private func fertig(mitHealth: Bool) {
        arbeitet = true
        Task {
            if mitHealth { await fluss.healthFragen(leser: umgebung.healthLeser) }
            await fluss.abschliessenImHintergrund(in: umgebung)
            arbeitet = false
        }
    }
}

private extension View {
    func eingabeFeld(_ palette: Palette) -> some View {
        padding(Abstand.m)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
    }
}
