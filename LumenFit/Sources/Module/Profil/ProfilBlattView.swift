import SwiftUI

/// Das Profil-Blatt (Idee 72), geöffnet von der Avatar-Kapsel auf jedem Tab: Name und Passwort ändern, Profil wechseln und anlegen, die Seiten
/// Aussehen, Ziele, Health, Datensicherung, Export, Datenschutz und Quellen, und "Alles löschen". Passwort gefragt wird nur bei Handlungen, nie beim Start.
struct ProfilBlattView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var blatt: Blatt?
    @State private var nameAendern = false
    @State private var neuerName = ""
    @State private var profilWahl = false
    @State private var toast: ToastInhalt?

    private enum Blatt: Identifiable {
        case passwortAendern, anlegen, loeschen
        case wechseln(Profil)

        var id: String {
            switch self {
            case .passwortAendern: "passwort"
            case .anlegen: "anlegen"
            case .loeschen: "loeschen"
            case .wechseln(let p): "wechseln-\(p.id.rawValue)"
            }
        }
    }

    var body: some View {
        let aktiv = umgebung.profil.aktiv
        let andere = umgebung.profil.profile.filter { $0.id != aktiv?.id }
        ScrollView {
            VStack(spacing: Abstand.xl) {
                kopf(aktiv)

                gruppe("Profil") {
                    Button { neuerName = aktiv?.name ?? ""; nameAendern = true } label: {
                        ProfilZeile(symbol: "person.fill", titel: "Name ändern", wert: aktiv?.name)
                    }
                    Haarlinie()
                    Button { blatt = .passwortAendern } label: { ProfilZeile(symbol: "key.fill", titel: "Passwort ändern") }
                    if !andere.isEmpty {
                        Haarlinie()
                        Button { profilWahl = true } label: { ProfilZeile(symbol: "person.2.fill", titel: "Profil wechseln", wert: "\(andere.count + 1) Profile") }
                    }
                    Haarlinie()
                    Button { blatt = .anlegen } label: { ProfilZeile(symbol: "person.badge.plus", titel: "Neues Profil anlegen") }
                }

                gruppe("Lumen Fit") {
                    link(symbol: "paintpalette.fill", titel: "Aussehen", wert: umgebung.daten?.einstellungen.werte.thema.anzeigeName) { AussehenView() }
                    Haarlinie()
                    link(symbol: "target", titel: "Ziele und Körper") { ZieleView() }
                    Haarlinie()
                    link(symbol: "heart.text.square.fill", titel: "Health-Zugriff") { ProfilHealthZugriffView() }
                    Haarlinie()
                    link(symbol: "link", titel: "Verbindungen") { VerbindungenView() }
                    Haarlinie()
                    link(symbol: "star.fill", titel: "Meilensteine") { MeilensteineView() }
                    Haarlinie()
                    Toggle(isOn: Binding(get: { umgebung.daten?.einstellungen.werte.haptik ?? true },
                                         set: { an in umgebung.daten?.einstellungen.aendere { $0.haptik = an } })) {
                        HStack(spacing: Abstand.m) {
                            Image(systemName: "hand.tap.fill").font(.body.weight(.semibold)).frame(width: 28).accessibilityHidden(true)
                            Text("Haptik").font(.body).foregroundStyle(palette.text)
                        }
                    }
                    .padding(.horizontal, Abstand.l).frame(minHeight: Abstand.tippflaeche)
                }

                gruppe("Deine Daten") {
                    link(symbol: "externaldrive.fill", titel: "Datensicherung", zeile: sicherungZeile) { DatensicherungView() }
                    Haarlinie()
                    link(symbol: "tablecells", titel: "Als Tabelle teilen") { ProfilExportView() }
                    Haarlinie()
                    link(symbol: "hand.raised.fill", titel: "Datenschutz") { ProfilDatenschutzView() }
                    Haarlinie()
                    link(symbol: "doc.text.fill", titel: "Quellen und Lizenzen") { QuellenView() }
                }

                gruppe(nil) {
                    Button(role: .destructive) { blatt = .loeschen } label: {
                        ProfilZeile(symbol: "trash.fill", titel: "Alles löschen", zeile: "Profil und alle Daten auf diesem iPhone", pfeil: false)
                    }
                }

                Text("Lumen Fit \(version)").font(.footnote).foregroundStyle(palette.text2)
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .alert("Name ändern", isPresented: $nameAendern) {
            TextField("Dein Name", text: $neuerName)
            Button("Speichern") { umgebung.profil.benenne(um: neuerName) }
            Button("Abbrechen", role: .cancel) {}
        }
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
            case .loeschen:
                ProfilLoeschenBlatt()
            }
        }
        .lumenToast($toast)
    }

    // MARK: - Teile

    private func kopf(_ aktiv: Profil?) -> some View {
        VStack(spacing: Abstand.s) {
            LumiView(stimmung: .bereit, groesse: 88, stufe: umgebung.daten?.meilensteine.stufe ?? 1)
            Text(aktiv?.name ?? "Profil").font(.title2.bold()).foregroundStyle(palette.text)
            Text(sicherungZeile).font(.footnote).foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var sicherungZeile: String {
        ProfilSicherungStand.zeile(zuletzt: umgebung.daten.flatMap { ProfilSicherungStand.lade($0.ordner) }, jetzt: umgebung.uhr())
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func gruppe<Inhalt: View>(_ titel: String?, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            if let titel { ProfilGruppenKopf(text: titel) }
            ListenKarte { inhalt() }.buttonStyle(.plain)
        }
    }

    private func link<Ziel: View>(symbol: String, titel: String, zeile: String? = nil, wert: String? = nil, @ViewBuilder ziel: @escaping () -> Ziel) -> some View {
        NavigationLink { ziel() } label: { ProfilZeile(symbol: symbol, titel: titel, zeile: zeile, wert: wert) }
            .buttonStyle(.plain)
    }
}

/// Neues Profil anlegen (ohne Passwort-Abfrage des aktuellen: das Anlegen ändert nichts am bestehenden Profil, es wird nur das aktive).
struct ProfilAnlegenBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var name = ""
    @State private var passwort = ""
    @State private var fehler: String?
    @State private var rechnet = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Abstand.l) {
                Text("Ein zweites Profil hat eigene Trainings, eigenes Essen und eigene Ziele. Du wechselst später mit dem Passwort des Profils.")
                    .font(.body).foregroundStyle(palette.text2)
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(Abstand.m).frame(minHeight: Abstand.tippflaeche)
                    .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                SecureField("Passwort (mindestens \(Passwort.mindestLaenge) Zeichen)", text: $passwort)
                    .textContentType(.newPassword)
                    .padding(Abstand.m).frame(minHeight: Abstand.tippflaeche)
                    .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                if let fehler { Text(fehler).font(.subheadline).foregroundStyle(palette.text) }
                Button(action: anlegen) { Text("Profil anlegen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(palette.aufAkzent)
                    .disabled(rechnet)
                Spacer()
            }
            .padding(Abstand.l)
            .lumenHintergrund()
            .navigationTitle("Neues Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }

    private func anlegen() {
        guard !rechnet else { return }
        rechnet = true
        Task {
            defer { rechnet = false }
            do {
                try await umgebung.profil.anlegenImHintergrund(name: name, passwort: passwort)
                dismiss()
            } catch ProfilFehler.nameLeer {
                fehler = "Wie soll das Profil heißen?"
            } catch ProfilFehler.passwortZuKurz {
                fehler = "Das Passwort braucht mindestens \(Passwort.mindestLaenge) Zeichen."
            } catch {
                fehler = "Das Profil konnte nicht gespeichert werden. Versuch es nochmal."
            }
        }
    }
}

/// Alles löschen: erst die Liste, was gespeichert war, dann das Passwort. Danach ist das Profil samt Daten weg (Health bleibt).
struct ProfilLoeschenBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var weiter = false

    var body: some View {
        if weiter {
            ProfilPasswortBlatt(titel: "Alles löschen", erklaerung: "Zur Bestätigung dein Passwort. Das lässt sich nicht rückgängig machen.",
                                knopf: "Alles löschen", zerstoererisch: true, zuruecksetzen: umgebung.profil.aktiv) { passwort, _ in
                await ProfilLoeschen.fuehreAusImHintergrund(umgebung, passwort: passwort)
            }
        } else {
            NavigationStack {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    Text("Das wird gelöscht").font(.title3.bold()).foregroundStyle(palette.text)
                    if let daten = umgebung.daten {
                        ListenKarte {
                            let zeilen = ProfilLoeschen.liste(daten)
                            ForEach(zeilen) { zeile in
                                Text(zeile.text).font(.body).foregroundStyle(palette.text).padding(Abstand.l)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if zeile.id != zeilen.last?.id { Haarlinie() }
                            }
                        }
                    }
                    Text("Daten in Health bleiben. Eine Datensicherung, die du schon gemacht hast, bleibt dort, wo du sie abgelegt hast.")
                        .font(.footnote).foregroundStyle(palette.text2)
                    Button(role: .destructive) { weiter = true } label: { Text("Weiter").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(Abstand.l)
                .lumenHintergrund()
                .navigationTitle("Alles löschen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            }
            .presentationDetents([.large])
        }
    }
}

/// "Passwort vergessen" (SPEC 5.4): löscht das Profil samt Daten ohne Passwort. Zwei Schritte: erst der Text mit der Liste, was verschwindet
/// (und für das aktive Profil der Weg zur Datensicherung), dann die Rückfrage. Es gibt keinen Rückweg per Mail, weil es keinen Server gibt.
struct ProfilZuruecksetzenBlatt: View {
    let profil: Profil
    let fertig: () -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var frage = false
    @State private var misslungen = false

    private var istAktiv: Bool { umgebung.profil.aktiv?.id == profil.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    Text(ProfilTexte.zuruecksetzenTitel(name: profil.name)).font(.title3.bold()).foregroundStyle(palette.text)
                    Text(ProfilTexte.zuruecksetzenText).font(.body).foregroundStyle(palette.text2)
                    if istAktiv, let daten = umgebung.daten {
                        ListenKarte {
                            let zeilen = ProfilLoeschen.liste(daten)
                            ForEach(zeilen) { zeile in
                                Text(zeile.text).font(.body).foregroundStyle(palette.text).padding(Abstand.l)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if zeile.id != zeilen.last?.id { Haarlinie() }
                            }
                        }
                        NavigationLink { DatensicherungView() } label: {
                            Label("Erst eine Datensicherung machen", systemImage: "externaldrive.fill")
                                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
                        }
                    }
                    if misslungen {
                        FehlerKarte(titel: "Das hat nicht geklappt", hilfe: "Das Profil konnte nicht gelöscht werden. Versuch es nochmal.")
                    }
                    Button(role: .destructive) { frage = true } label: { Text("Profil zurücksetzen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                        .buttonStyle(.borderedProminent)
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle("Zurücksetzen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .confirmationDialog(ProfilTexte.zuruecksetzenFrage(name: profil.name), isPresented: $frage, titleVisibility: .visible) {
                Button("Endgültig löschen", role: .destructive, action: ausfuehren)
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text(ProfilTexte.zuruecksetzenWarnung)
            }
        }
        .presentationDetents([.large])
    }

    private func ausfuehren() {
        if ProfilLoeschen.setzeZurueck(umgebung, profil: profil.id) {
            fertig()
            dismiss()
        } else {
            misslungen = true
        }
    }
}
