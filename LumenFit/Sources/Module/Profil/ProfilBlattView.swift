import SwiftUI

/// Die Wurzel des Profil-Tabs (Entwurf 10.11.2026): Konto-Karte, "Freunde einladen", Kacheln Übungen und Splits, Präferenzen und Training,
/// die Übergangs-Zeilen Essen und Schlaf ("Bis zum Umzug") und "Mehr Einstellungen". Keine Lumi-Zeile (die Lumi-Seite bleibt über Erfolge erreichbar).
/// Lovea hat hier keinen Eintrag: der Import läuft einmal von selbst (`LoveaEinmalImport`), die Partner-Verbindung braucht keinen Schalter.
struct ProfilBlattView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var trainingSitzung: GymSitzung?
    @State private var trainingBlatt = false
    @State private var einladenOffen = false
    @State private var uebungenOffen = false
    @State private var splitsOffen = false
    @State private var teilenLaedt = false
    @State private var teilenFehler = false
    @State private var statsOffen = false

    var body: some View {
        let gymAn = umgebung.bereicheWirksam.gymAn
        List {
            Section { kontoKarte }.listRowBackground(palette.flaeche)
            Section { einladenKarte }.listRowBackground(palette.flaeche)
            if gymAn {
                Section { kacheln }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            ProfilAbschnitt {
                link(String(localized: "Präferenzen"), .profilZiele, symbol: "slider.horizontal.3", farbe: Bereichsfarbe.gewicht, wert: praeferenzenWert) {
                    ProfilPraeferenzenView()
                }
                // Stats: wer mich sieht (Privat, Freunde, Öffentlich), Baustein aus Verbinden/Stats.
                Button { statsOffen = true } label: {
                    ProfilListenZeile(String(localized: "Stats"), symbol: "chart.bar.fill", wert: StatsLogik.sichtbarkeitText(umgebung.daten?.einstellungen.werte ?? Einstellungen()), farbe: Bereichsfarbe.freunde)
                }
                // Trainings-Einstellungen auch hier erreichbar (Wunsch vom 09.11.2026), das Zahnrad im Training bleibt.
                if gymAn {
                    Button { trainingBlatt = true } label: { ProfilListenZeile(String(localized: "Training"), symbol: "dumbbell.fill", farbe: .orange) }
                }
            }
            ProfilUmzugZeilen()
            ProfilAbschnitt {
                link(String(localized: "Mehr Einstellungen"), .profilMehr, symbol: "list.bullet", farbe: Bereichsfarbe.einstellungen) { ProfilMehrEinstellungenView() }
            }
        }
        // Wie `profilListe()`, aber mit großem Titel (Wurzel des Tabs).
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .lumenHintergrund()
        .defaultScrollAnchor(startAnker)
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $uebungenOffen) { UebungsSucheView(titel: String(localized: "Übungen")) }
        .sheet(isPresented: $trainingBlatt) { if let trainingSitzung { GymEinstellungenBlatt(sitzung: trainingSitzung) } }
        .sheet(isPresented: $splitsOffen) { if let trainingSitzung { SplitBibliothekView(sitzung: trainingSitzung) } }
        .sheet(isPresented: $einladenOffen) { VerbindungCodeBlatt() }
        .sheet(isPresented: $statsOffen) { StatsEinstellungBlatt() }
        .alert("Kein Code möglich", isPresented: $teilenFehler) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Die App konnte dein Konto nicht erreichen. Prüfe das Netz und versuche es nochmal.")
        }
        // Die Sitzung entsteht hier, nicht im Körper: `GymSitzung.von` setzt den Port, das darf nicht beim Zeichnen passieren.
        .task { trainingSitzung = GymSitzung.von(umgebung) }
    }

    // MARK: - Karten oben

    private var kontoKarte: some View {
        let name = umgebung.profil.aktiv?.name ?? ""
        return NavigationLink { KontoView().onAppear { umgebung.konto.nutzung.getippt(.profilKonto) } } label: {
            HStack(spacing: Abstand.m) {
                Text(ProfilInitialen.aus(name))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.aufAkzentFlaeche)
                    .frame(width: 52, height: 52)
                    .background(palette.akzentFlaeche, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.title3.weight(.semibold)).foregroundStyle(palette.text).lineLimit(1)
                    Text("Konto, Freunde und mehr").font(.subheadline).foregroundStyle(palette.text2)
                }
            }
            .padding(.vertical, Abstand.xs)
        }
        .onAppear { umgebung.konto.nutzung.gesehen(.profilKonto) }
    }

    /// Ein Tipp zeigt den QR-Code (`VerbindungCodeBlatt`); "Teilen" holt einen Code (24 Stunden) und öffnet das Teilen-Menü von iOS.
    private var einladenKarte: some View {
        HStack(spacing: Abstand.m) {
            Button {
                umgebung.konto.nutzung.getippt(.profilEinladen)
                einladenOffen = true
            } label: {
                HStack(spacing: Abstand.m) {
                    Image(systemName: "qrcode")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Rundung.klein, style: .continuous).strokeBorder(palette.haar, lineWidth: 1))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Freunde einladen").font(.body.weight(.semibold)).foregroundStyle(palette.text)
                        Text("QR-Code zeigen, dein Freund scannt ihn mit der Kamera").font(.footnote).foregroundStyle(palette.text2)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            Button(action: teilen) {
                Group {
                    if teilenLaedt { ProgressView() } else { Image(systemName: "square.and.arrow.up").font(.body.weight(.semibold)) }
                }
                .foregroundStyle(palette.akzent)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .buttonStyle(.borderless)
            .disabled(teilenLaedt)
            .accessibilityLabel("Einladung teilen")
        }
        .padding(.vertical, Abstand.xs)
        .onAppear { umgebung.konto.nutzung.gesehen(.profilEinladen) }
    }

    /// Übungen und Splits nebeneinander; sie öffnen die vorhandenen Seiten aus Gym.
    private var kacheln: some View {
        HStack(spacing: Abstand.m) {
            kachel(String(localized: "Übungen"), symbol: "dumbbell.fill", farbe: palette.akzent, eintrag: .profilUebungen) { uebungenOffen = true }
            kachel(String(localized: "Splits"), symbol: "list.clipboard.fill", farbe: Bereichsfarbe.splits, eintrag: .profilSplits) { splitsOffen = true }
        }
    }

    private func kachel(_ titel: String, symbol: String, farbe: Color, eintrag: NutzungEintrag, aktion: @escaping () -> Void) -> some View {
        Button {
            umgebung.konto.nutzung.getippt(eintrag)
            aktion()
        } label: {
            HStack(spacing: Abstand.m) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(farbe)
                    .frame(width: 32, height: 32)
                    .background(farbe.opacity(0.2), in: .rect(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                Text(titel).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .onAppear { umgebung.konto.nutzung.gesehen(eintrag) }
    }

    private func teilen() {
        teilenLaedt = true
        Task {
            let code = await umgebung.konto.codeErzeugen()
            teilenLaedt = false
            guard let code else { teilenFehler = true; return }
            ProfilTeilen.zeige(ProfilTeilen.einladungText(code: code.code))
        }
    }

    // MARK: - Werte

    /// Oben; nur das Debug-Bild der CI startet unten (Start-Argument `-lumenFitScroll unten`), damit die untere Hälfte im Bild zu sehen ist.
    private var startAnker: UnitPoint {
        #if DEBUG
        return StartArgumente.lies().scrollUnten ? .bottom : .top
        #else
        return .top
        #endif
    }

    private var praeferenzenWert: String? {
        umgebung.daten.map { ProfilPraeferenzLogik.zieleText($0.einstellungen.werte.trainingsZiele) }
    }

    private func link<Ziel: View>(_ titel: String, _ eintrag: NutzungEintrag, symbol: String, farbe: Color? = nil, wert: String? = nil,
                                  @ViewBuilder ziel: @escaping () -> Ziel) -> some View {
        ProfilLink(titel: titel, eintrag: eintrag, symbol: symbol, farbe: farbe, wert: wert, ziel: ziel)
    }
}

/// Eine Zeile, die eine Seite öffnet und für die Nutzung zählt: gesehen, sobald sie erscheint; getippt, wenn die Zielseite erscheint
/// (eine Tipp-Geste an der Zeile schluckt in der Liste den Tipp auf Text und Symbol, Fund 10.11.2026).
struct ProfilLink<Ziel: View>: View {
    let titel: String
    let eintrag: NutzungEintrag
    let symbol: String
    var farbe: Color?
    var wert: String?
    @ViewBuilder let ziel: () -> Ziel
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        NavigationLink { ziel().onAppear { umgebung.konto.nutzung.getippt(eintrag) } } label: {
            ProfilListenZeile(titel, symbol: symbol, wert: wert, farbe: farbe)
        }
        .onAppear { umgebung.konto.nutzung.gesehen(eintrag) }
    }
}

/// Initialen für die Konto-Karte: erste Buchstaben der ersten zwei Wörter, groß.
enum ProfilInitialen {
    static func aus(_ name: String) -> String {
        let woerter = name.split(whereSeparator: \.isWhitespace).prefix(2)
        let zeichen = woerter.compactMap(\.first).map { String($0).uppercased() }.joined()
        return zeichen.isEmpty ? "?" : zeichen
    }
}

/// Teilen über das iOS-Teilen-Menü, ohne vorher eine Datei oder einen Link zu kennen (der Code kommt erst nach dem Tipp vom Server).
@MainActor
enum ProfilTeilen {
    static func einladungText(code: String) -> String {
        String(localized: "Trainier mit mir in Lumen Fit. Mein Code: \(code). Er gilt 24 Stunden. Tipp ihn beim Einrichten bei \"Hat dich jemand eingeladen?\" ein oder später unter Stats bei \"Code eingeben\".")
    }

    static func zeige(_ text: String) {
        let szene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        guard let fenster = szene?.keyWindow, var oben = fenster.rootViewController else { return }
        while let weiter = oben.presentedViewController { oben = weiter }
        let blatt = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        blatt.popoverPresentationController?.sourceView = fenster
        oben.present(blatt, animated: true)
    }
}

/// "Daten" (unter Mehr Einstellungen): Sicherung, Tabellenexport und ganz unten "Alles löschen".
struct ProfilDatenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var loeschen = false

    var body: some View {
        List {
            ProfilAbschnitt(String(localized: "Sicherung")) {
                NavigationLink { DatensicherungView() } label: {
                    ProfilListenZeile(String(localized: "Datensicherung"), symbol: "externaldrive.fill", wert: sicherungKurz, farbe: .teal)
                }
            }
            ProfilAbschnitt(String(localized: "Export")) {
                NavigationLink { ProfilExportView() } label: {
                    ProfilListenZeile(String(localized: "Als Tabelle teilen"), symbol: "tablecells", farbe: Bereichsfarbe.einstellungen)
                }
            }
            ProfilAbschnitt(fuss: "Löscht Profil und alle Daten auf diesem iPhone.") {
                Button(role: .destructive) { loeschen = true } label: { Label("Alles löschen", systemImage: "trash.fill") }
            }
        }
        .profilListe()
        .navigationTitle("Daten")
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
