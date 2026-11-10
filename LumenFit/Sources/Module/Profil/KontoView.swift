import SwiftUI

/// Die Unterseite "Konto" (Profil, oben): Name ändern (nach der Namensregel, höchstens alle `nameAendernTage` Tage), Passwort ändern,
/// Profil wechseln und, nur wenn der Server es erlaubt, ein weiteres Profil anlegen. Passwort gefragt wird nur bei Handlungen, nie beim Start.
/// Ganz unten "Konto löschen" (App Store 5.1.1(v)): Server, dann alles auf diesem iPhone.
struct KontoView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var name = ""
    @State private var meldung: String?
    @State private var blatt: Blatt?
    @State private var profilWahl = false
    @State private var toast: ToastInhalt?
    @State private var loeschMeldung: String?
    @FocusState private var fokus: Bool

    private enum Blatt: Identifiable {
        case passwortAendern, anlegen, kontoLoeschen
        case wechseln(Profil)

        var id: String {
            switch self {
            case .passwortAendern: "passwort"
            case .anlegen: "anlegen"
            case .kontoLoeschen: "konto-loeschen"
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
            loeschGruppe
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
                let festlegen = aktiv?.ohnePasswort ?? false
                ProfilPasswortBlatt(titel: festlegen ? "Passwort festlegen" : "Passwort ändern",
                                    erklaerung: festlegen ? "Mit einem Passwort fragt die App beim Wechseln und bei Alles löschen danach. Beim Start nie."
                                                          : "Gib dein aktuelles und dein neues Passwort ein.",
                                    knopf: festlegen ? "Passwort festlegen" : "Passwort ändern",
                                    neuTitel: festlegen ? "Passwort" : "Neues Passwort", ohneAlt: festlegen) { alt, neu in
                    let ok = await umgebung.profil.aenderePasswortImHintergrund(alt: alt, neu: neu)
                    if ok { toast = ToastInhalt(titel: festlegen ? "Passwort festgelegt" : "Passwort geändert", zeile: nil, stimmung: .ziel) }
                    return ok
                }
            case .wechseln(let ziel):
                ProfilPasswortBlatt(titel: "Zu \(ziel.name) wechseln",
                                    erklaerung: ziel.ohnePasswort ? "\(ziel.name) hat kein Passwort. Wechseln?" : "Gib das Passwort von \(ziel.name) ein.", knopf: "Wechseln",
                                    ohneAlt: ziel.ohnePasswort, zuruecksetzen: ziel) { passwort, _ in
                    await umgebung.profil.wechsleImHintergrund(zu: ziel.id, passwort: passwort)
                }
            case .anlegen:
                ProfilAnlegenBlatt()
            case .kontoLoeschen:
                KontoLoeschenBlatt { loeschMeldung = $0 }
            }
        }
        .lumenToast($toast)
        .alert("Konto löschen", isPresented: Binding(get: { loeschMeldung != nil }, set: { if !$0 { loeschMeldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loeschMeldung ?? "")
        }
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
            Button { blatt = .passwortAendern } label: {
                ProfilListenZeile(aktiv?.ohnePasswort == true ? "Passwort festlegen" : "Passwort ändern", symbol: "key.fill",
                                  wert: aktiv?.ohnePasswort == true ? "freiwillig" : nil)
            }
            if !andere.isEmpty {
                Button { profilWahl = true } label: { ProfilListenZeile("Profil wechseln", symbol: "person.2.fill", wert: "\(andere.count + 1) Profile") }
            }
            if darfAnlegen {
                Button { blatt = .anlegen } label: { ProfilListenZeile("Neues Profil anlegen", symbol: "person.badge.plus") }
            }
        }
    }

    private var loeschGruppe: some View {
        Section {
            Button(role: .destructive) { blatt = .kontoLoeschen } label: {
                Label("Konto löschen", systemImage: "trash.fill").foregroundStyle(.red)
            }
            .frame(minHeight: Abstand.tippflaeche)
        } footer: {
            Text("Löscht alles auf dem Lumen-Server und danach alles von Lumen Fit auf diesem iPhone. Daten in Health bleiben.")
                .foregroundStyle(palette.text2)
        }
        .listRowBackground(palette.flaeche)
    }

    private func speichern() {
        guard kannSpeichern else { return }
        switch umgebung.profil.aendereName(name, sperreTage: tage) {
        case .geaendert:
            fokus = false
            name = aktiv?.name ?? name
            toast = ToastInhalt(titel: "Name geändert", zeile: nil, stimmung: .ziel)
        case .ungueltig(let f): meldung = NamenRegel.text(f)
        case .gesperrt: meldung = "Dein Name ist gerade gesperrt."
        case .unveraendert: break
        case .nichtGespeichert: meldung = "Der Name konnte nicht gespeichert werden. Versuch es nochmal."
        }
    }
}

/// "Konto löschen": erst die Liste, was verschwindet, dann das Passwort (wie "Alles löschen"). Nach dem Passwort fragt `KontoLoeschen` den Server
/// und löscht erst danach alle Profile auf diesem iPhone. Ohne Netz bleibt alles; die Meldung zeigt die Konto-Seite.
private struct KontoLoeschenBlatt: View {
    let meldung: @MainActor (String) -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var weiter = false

    private var mehrereProfile: Bool { umgebung.profil.profile.count > 1 }

    var body: some View {
        if weiter {
            let ohne = umgebung.profil.aktiv?.ohnePasswort ?? false
            ProfilPasswortBlatt(titel: String(localized: "Konto löschen"),
                                erklaerung: ohne ? String(localized: "Zur Bestätigung tippe auf Konto löschen. Das lässt sich nicht rückgängig machen.")
                                                 : String(localized: "Zur Bestätigung dein Passwort. Das lässt sich nicht rückgängig machen."),
                                knopf: String(localized: "Konto löschen"), zerstoererisch: true, ohneAlt: ohne) { passwort, _ in
                await loeschen(passwort: passwort)
            }
        } else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Abstand.l) {
                        Text("Das wird gelöscht").font(.title3.bold()).foregroundStyle(palette.text)
                        ListenKarte {
                            VStack(alignment: .leading, spacing: Abstand.m) {
                                Text("Auf dem Lumen-Server: dein Konto, Einstellungen, Verbindungen und Freigaben, Freunde, Herausforderungen, Reaktionen, Stats, Nutzungszähler und Foto-Zähler.")
                                Text(mehrereProfile ? "Auf diesem iPhone: alle Profile mit Trainings, Essen, Gewicht, Zielen, Meilensteinen und Einstellungen."
                                                    : "Auf diesem iPhone: dein Profil mit Trainings, Essen, Gewicht, Zielen, Meilensteinen und Einstellungen.")
                            }
                            .font(.body).foregroundStyle(palette.text).padding(Abstand.l)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("Daten in Health bleiben. Eine Datensicherung, die du schon gemacht hast, bleibt dort, wo du sie abgelegt hast. Ohne Netz wird nichts gelöscht.")
                            .font(.footnote).foregroundStyle(palette.text2)
                        Button(role: .destructive) { weiter = true } label: { Text("Weiter").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(Abstand.l)
                }
                .lumenHintergrund()
                .navigationTitle("Konto löschen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            }
            .presentationDetents([.large])
        }
    }

    /// false nur bei falschem Passwort (das Blatt wackelt dann). Jedes andere Ergebnis schließt das Blatt; Fehler zeigt die Konto-Seite.
    private func loeschen(passwort: String) async -> Bool {
        guard let aktiv = umgebung.profil.aktiv else { return false }
        let ergebnis = await KontoLoeschen.fuehreAus(
            passwortStimmt: { await umgebung.profil.pruefeImHintergrund(passwort: passwort, fuer: aktiv.id) },
            server: { await umgebung.konto.kontoLoeschen() },
            lokal: {
                // Das aktive zuletzt: so sendet erst das letzte Profil `profilGeloescht`, kein Zwischenwechsel.
                let ids = umgebung.profil.profile.map(\.id).filter { $0 != aktiv.id } + [aktiv.id]
                return ids.allSatisfy { ProfilLoeschen.setzeZurueck(umgebung, profil: $0) }
            })
        if ergebnis == .falschesPasswort { return false }
        if let text = KontoLoeschen.meldung(ergebnis) { meldung(text) }
        return true
    }
}
