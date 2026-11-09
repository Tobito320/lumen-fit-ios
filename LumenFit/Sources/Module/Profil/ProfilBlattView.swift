import SwiftUI

/// Das Profil-Blatt (Idee 72), geöffnet von der Avatar-Kapsel auf jedem Tab. Kompakte Einstellungsliste: eine Zeile je Eintrag, Wert rechts.
/// Alles liegt höchstens eine Ebene tief, ohne "Mehr"-Zwischenstufe; "Freunde und Partner" enthält den Code zum Zeigen und Scannen.
/// Lovea hat hier keinen Eintrag: der Import läuft einmal von selbst (`LoveaEinmalImport`), die Partner-Verbindung braucht keinen Schalter.
struct ProfilBlattView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var trainingSitzung: GymSitzung?
    @State private var trainingBlatt = false

    var body: some View {
        List {
            ProfilAbschnitt {
                link("Freunde und Partner", .profilFreunde, symbol: "person.2.fill") { VerbindungenView() }
            }
            ProfilBereicheAbschnitt()
            ProfilAbschnitt {
                link("Konto", .profilKonto, symbol: "person.crop.circle.fill", wert: umgebung.profil.aktiv?.name) { KontoView() }
            }
            ProfilAbschnitt {
                link("Aussehen", .profilAussehen, symbol: "paintpalette.fill", wert: themaName) { AussehenView() }
                link("Ziele und Körper", .profilZiele, symbol: "target") { ZieleView() }
                // Trainings-Einstellungen auch hier erreichbar (Wunsch vom 09.11.2026), das Zahnrad im Training bleibt.
                if umgebung.bereicheWirksam.gymAn {
                    Button { trainingBlatt = true } label: { ProfilListenZeile("Training", symbol: "dumbbell.fill") }
                }
                link("Health-Zugriff", .profilHealth, symbol: "heart.text.square.fill") { ProfilHealthZugriffView() }
                link("Meilensteine", .profilMeilensteine, symbol: "star.fill") { MeilensteineView() }
                // Band und AirPods gehören zum Schlaf-Schalter des Servers (`ServerConfig.schlafSichtbar`).
                if umgebung.konto.schlafSichtbar { link("Geräte", .profilGeraete, symbol: "applewatch") { GeraeteView() } }
            }
            ProfilAbschnitt {
                link("Deine Daten", .profilDaten, symbol: "externaldrive.fill", wert: sicherungKurz) { ProfilDatenView() }
                link("Über Lumen Fit", .profilUeber, symbol: "info.circle.fill", wert: ProfilAppInfo.version) { ProfilUeberView() }
            }
        }
        .profilListe()
        .defaultScrollAnchor(startAnker)
        .navigationTitle("Profil")
        .sheet(isPresented: $trainingBlatt) { if let trainingSitzung { GymEinstellungenBlatt(sitzung: trainingSitzung) } }
        // Die Sitzung entsteht hier, nicht im Körper: `GymSitzung.von` setzt den Port, das darf nicht beim Zeichnen passieren.
        .task { trainingSitzung = GymSitzung.von(umgebung) }
    }

    /// Oben; nur das Debug-Bild der CI startet unten (Start-Argument `-lumenFitScroll unten`), damit die untere Hälfte im Bild zu sehen ist.
    private var startAnker: UnitPoint {
        #if DEBUG
        return StartArgumente.lies().scrollUnten ? .bottom : .top
        #else
        return .top
        #endif
    }

    private var sicherungKurz: String {
        ProfilSicherungStand.kurz(zuletzt: umgebung.daten.flatMap { ProfilSicherungStand.lade($0.ordner) }, jetzt: umgebung.uhr())
    }

    private var themaName: String? {
        umgebung.daten.map { $0.einstellungen.werte.erscheinung.anzeigeName }
    }

    private func link<Ziel: View>(_ titel: String, _ eintrag: NutzungEintrag, symbol: String, wert: String? = nil, @ViewBuilder ziel: @escaping () -> Ziel) -> some View {
        NavigationLink { ziel() } label: { ProfilListenZeile(titel, symbol: symbol, wert: wert) }
            .nutzungEintrag(eintrag)
    }
}

/// "Deine Daten": Datensicherung, Tabellenexport und ganz unten "Alles löschen".
struct ProfilDatenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var loeschen = false

    var body: some View {
        List {
            ProfilAbschnitt {
                NavigationLink { DatensicherungView() } label: {
                    ProfilListenZeile("Datensicherung", symbol: "externaldrive.fill", wert: sicherungKurz)
                }
                NavigationLink { ProfilExportView() } label: { ProfilListenZeile("Als Tabelle teilen", symbol: "tablecells") }
            }
            ProfilAbschnitt(fuss: "Löscht Profil und alle Daten auf diesem iPhone.") {
                Button(role: .destructive) { loeschen = true } label: { Label("Alles löschen", systemImage: "trash.fill") }
            }
        }
        .profilListe()
        .navigationTitle("Deine Daten")
        .sheet(isPresented: $loeschen) { ProfilLoeschenBlatt() }
    }

    private var sicherungKurz: String {
        ProfilSicherungStand.kurz(zuletzt: umgebung.daten.flatMap { ProfilSicherungStand.lade($0.ordner) }, jetzt: umgebung.uhr())
    }
}

/// "Über Lumen Fit": Datenschutz, Quellen und Lizenzen, Version.
struct ProfilUeberView: View {
    var body: some View {
        List {
            ProfilAbschnitt {
                NavigationLink { ProfilDatenschutzView() } label: { ProfilListenZeile("Datenschutz", symbol: "hand.raised.fill") }
                NavigationLink { QuellenView() } label: { ProfilListenZeile("Quellen und Lizenzen", symbol: "doc.text.fill") }
                ProfilListenZeile("Version", symbol: "info.circle", wert: ProfilAppInfo.version)
            }
        }
        .profilListe()
        .navigationTitle("Über Lumen Fit")
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
                Text("Ein zweites Profil hat eigene Trainings, eigenes Essen und eigene Ziele. Ein Passwort ist freiwillig: mit einem fragt die App beim Wechseln danach.")
                    .font(.body).foregroundStyle(palette.text2)
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(Abstand.m).frame(minHeight: Abstand.tippflaeche)
                    .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                if let hinweis = ProfilOnboardingFluss.nameHinweis(name) {
                    Text(hinweis).font(.footnote).foregroundStyle(palette.text2)
                }
                SecureField("Passwort (freiwillig, mindestens \(Passwort.mindestLaenge) Zeichen)", text: $passwort)
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
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.disabled(rechnet) } }
            .interactiveDismissDisabled(rechnet)
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
            } catch ProfilFehler.nameUngueltig(let grund) {
                fehler = NamenRegel.text(grund)
            } catch ProfilFehler.nichtErlaubt {
                fehler = "Weitere Profile sind auf diesem iPhone nicht möglich."
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
            let ohne = umgebung.profil.aktiv?.ohnePasswort ?? false
            ProfilPasswortBlatt(titel: "Alles löschen",
                                erklaerung: ohne ? "Zur Bestätigung tippe auf Alles löschen. Das lässt sich nicht rückgängig machen."
                                                 : "Zur Bestätigung dein Passwort. Das lässt sich nicht rückgängig machen.",
                                knopf: "Alles löschen", zerstoererisch: true, ohneAlt: ohne, zuruecksetzen: umgebung.profil.aktiv) { passwort, _ in
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
