import SwiftUI

/// Die Unterseite "Konto" (Profil, oben): Name ändern (nach der Namensregel, höchstens alle `nameAendernTage` Tage), Passwort ändern,
/// Profil wechseln und, nur wenn der Server es erlaubt, ein weiteres Profil anlegen. Passwort gefragt wird nur bei Handlungen, nie beim Start.
struct KontoView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var name = ""
    @State private var meldung: String?
    @State private var blatt: Blatt?
    @State private var profilWahl = false
    @State private var toast: ToastInhalt?
    @FocusState private var fokus: Bool

    private enum Blatt: Identifiable {
        case passwortAendern, anlegen
        case wechseln(Profil)

        var id: String {
            switch self {
            case .passwortAendern: "passwort"
            case .anlegen: "anlegen"
            case .wechseln(let p): "wechseln-\(p.id.rawValue)"
            }
        }
    }

    private var aktiv: Profil? { umgebung.profil.aktiv }
    private var andere: [Profil] { umgebung.profil.profile.filter { $0.id != aktiv?.id } }
    private var tage: Int { umgebung.konto.config.nameAendernTage }
    private var darfAnlegen: Bool { umgebung.konto.config.profilAnlegenErlaubt }

    /// Ab wann der Name wieder änderbar ist; nil, wenn jetzt.
    private var freiAb: Date? { NamenRegel.freiAb(letzteAenderung: aktiv?.nameGeaendert, tage: tage, jetzt: umgebung.uhr()) }

    /// Fehlertext zur Eingabe (leer, solange sie dem gespeicherten Namen gleicht).
    private var eingabeFehler: String? {
        guard name != (aktiv?.name ?? "") else { return nil }
        if case .failure(let f) = NamenRegel.pruefe(name) { return NamenRegel.text(f) }
        return nil
    }

    private var kannSpeichern: Bool {
        guard freiAb == nil, name != (aktiv?.name ?? ""), case .success(let sauber) = NamenRegel.pruefe(name) else { return false }
        return sauber != aktiv?.name
    }

    var body: some View {
        List {
            namensGruppe
            kontoGruppe
        }
        .profilListe()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Konto")
        .onAppear { name = aktiv?.name ?? "" }
        .confirmationDialog("Profil wechseln", isPresented: $profilWahl, titleVisibility: .visible) {
            ForEach(andere) { p in Button(p.name) { blatt = .wechseln(p) } }
            Button("Abbrechen", role: .cancel) {}
        }
        .sheet(item: $blatt) { art in
            switch art {
            case .passwortAendern:
                ProfilPasswortBlatt(titel: "Passwort ändern", erklaerung: "Gib dein aktuelles und dein neues Passwort ein.", knopf: "Passwort ändern",
                                    neuTitel: "Neues Passwort") { alt, neu in
                    let ok = await umgebung.profil.aenderePasswortImHintergrund(alt: alt, neu: neu)
                    if ok { toast = ToastInhalt(titel: "Passwort geändert", zeile: nil, stimmung: .stolz) }
                    return ok
                }
            case .wechseln(let ziel):
                ProfilPasswortBlatt(titel: "Zu \(ziel.name) wechseln", erklaerung: "Gib das Passwort von \(ziel.name) ein.", knopf: "Wechseln",
                                    zuruecksetzen: ziel) { passwort, _ in
                    await umgebung.profil.wechsleImHintergrund(zu: ziel.id, passwort: passwort)
                }
            case .anlegen:
                ProfilAnlegenBlatt()
            }
        }
        .lumenToast($toast)
    }

    // MARK: - Teile

    private var namensGruppe: some View {
        ProfilAbschnitt("Name", fuss: regelText) {
            TextField("Dein Name", text: $name)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($fokus)
                .onSubmit(speichern)
                .onChange(of: name) { meldung = nil }
                .disabled(freiAb != nil)
                .foregroundStyle(palette.text)
            if let text = eingabeFehler ?? meldung {
                Label(text, systemImage: "exclamationmark.circle").foregroundStyle(palette.text)
            }
            if name != (aktiv?.name ?? "") {
                Button("Name speichern", action: speichern).disabled(!kannSpeichern)
            }
        }
    }

    /// Die Regel in einem Satz; gesperrt: mit dem Tag, ab dem es wieder geht.
    private var regelText: String {
        if let frei = freiAb {
            return "Gesperrt bis \(frei.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "de_DE"))))."
        }
        let wann = tage == 0 ? "" : tage == 1 ? ", einmal am Tag änderbar" : ", alle \(tage) Tage änderbar"
        return "\(NamenRegel.minLaenge) bis \(NamenRegel.maxLaenge) Zeichen aus Buchstaben, Leerzeichen, - und '\(wann)."
    }

    private var kontoGruppe: some View {
        ProfilAbschnitt {
            Button { blatt = .passwortAendern } label: { ProfilListenZeile("Passwort ändern", symbol: "key.fill") }
            if !andere.isEmpty {
                Button { profilWahl = true } label: { ProfilListenZeile("Profil wechseln", symbol: "person.2.fill", wert: "\(andere.count + 1) Profile") }
            }
            if darfAnlegen {
                Button { blatt = .anlegen } label: { ProfilListenZeile("Neues Profil anlegen", symbol: "person.badge.plus") }
            }
        }
    }

    private func speichern() {
        guard kannSpeichern else { return }
        switch umgebung.profil.aendereName(name, sperreTage: tage) {
        case .geaendert:
            fokus = false
            name = aktiv?.name ?? name
            toast = ToastInhalt(titel: "Name geändert", zeile: nil, stimmung: .stolz)
        case .ungueltig(let f): meldung = NamenRegel.text(f)
        case .gesperrt: meldung = "Dein Name ist gerade gesperrt."
        case .unveraendert: break
        case .nichtGespeichert: meldung = "Der Name konnte nicht gespeichert werden. Versuch es nochmal."
        }
    }
}
