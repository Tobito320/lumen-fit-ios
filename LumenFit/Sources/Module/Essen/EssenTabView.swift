import SwiftUI

/// Was über dem Essen-Tab als Blatt liegt.
enum EssenBlatt: Identifiable {
    case hinzufuegen(Mahlzeit, EssenHinzuBereich)
    case scan(Mahlzeit)

    var id: String {
        switch self {
        case .hinzufuegen(let m, let b): "hinzu-\(m.rawValue)-\(b.rawValue)"
        case .scan(let m): "scan-\(m.rawValue)"
        }
    }
}

/// Der Essen-Tab: Tagebuch ohne Konto mit Kalorien, Makro-Donut, Protein der Woche, Fasten-Fenster, Favoriten, Mahlzeiten und den Zielen aus den Körperdaten.
/// Der Scan-Knopf schwebt als Glas rechts unten. `bereich` kommt aus dem Link (`lumenfit://essen?bereich=scan|favoriten`).
struct EssenTabView: View {
    var bereich: EssenBereich = .heute
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @State private var gewaehlt: String?
    @State private var blatt: EssenBlatt?
    @State private var toast: ToastInhalt?
    @State private var bereichGeoeffnet = false
    @State private var gerichtQuelle: Mahlzeit?
    @State private var gerichtName = ""
    @State private var gerichtAlert = false
    @State private var vorwaerts = true
    @State private var wechsel = 0
    @State private var verbrannt: Int?
    @State private var offeneMahlzeit: Mahlzeit?
    @State private var uebersichtOffen = false
    @State private var naehrwerteOffen = false
    @State private var auswertungOffen = false
    @State private var fastenOffen = false
    @State private var zieleOffen = false
    @State private var wochenOffen = false
    @State private var kalenderOffen = false
    @State private var anpassenOffen = false
    @State private var koerperOffen = false
    @Environment(\.bewegungAus) private var bewegungAus

    private var heute: String { Datum.text(umgebung.uhr()) }
    private var tag: String { gewaehlt ?? heute }

    var body: some View {
        Group {
            if let daten = umgebung.daten {
                inhalt(daten)
            } else {
                LeerZustand(stimmung: .bereit, satz: "Lege zuerst ein Profil an, dann führe ich dein Essen.")
            }
        }
        .navigationTitle("Essen")
        .lumenHintergrund()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { mehrMenue }
            ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() }
        }
        .navigationDestination(item: $offeneMahlzeit) { EssenMahlzeitSeite(mahlzeit: $0, tag: tag) }
        .navigationDestination(isPresented: $uebersichtOffen) { EssenMahlzeitenUebersicht(tag: tag) }
        .navigationDestination(isPresented: $naehrwerteOffen) { EssenTagesNaehrwerteView(tag: tag) }
        .navigationDestination(isPresented: $auswertungOffen) { EssenAuswertungView() }
        .navigationDestination(isPresented: $fastenOffen) { EssenFastenView() }
        .navigationDestination(isPresented: $zieleOffen) { EssenZielDetailView() }
        .navigationDestination(isPresented: $wochenOffen) { WochenanalyseView() }
        .sheet(isPresented: $kalenderOffen) { EssenDatumBlatt(tag: tagBinding, heute: heute) }
        .sheet(isPresented: $anpassenOffen) { EssenTagebuchAnpassenBlatt() }
        .sheet(isPresented: $koerperOffen) { EssenKoerperwerteBlatt(tag: tag) }
        .task(id: tag) { await verbranntLaden() }
        .haptik(.auswahl, bei: wechsel)
        .lumenToast($toast)
        .task {
            LebensmittelIndex.shared.laden()
            guard !bereichGeoeffnet else { return }
            bereichGeoeffnet = true
            let jetzt = Mahlzeit.zurZeit(stunde: Datum.kalender.component(.hour, from: umgebung.uhr()))
            switch bereich {
            case .heute: break
            case .scan: blatt = .scan(jetzt)
            case .favoriten: blatt = .hinzufuegen(jetzt, .favoriten)
            }
        }
        .onDisappear { LebensmittelIndex.shared.freigeben() }
        .sheet(item: $blatt) { b in
            blattInhalt(b)
        }
        .alert("Als Gericht speichern", isPresented: $gerichtAlert) {
            TextField("Name", text: $gerichtName)
            Button("Speichern") { gerichtSpeichern() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Du findest das Gericht danach bei den Favoriten und kannst es mit einem Tipp noch einmal eintragen.")
        }
    }

    // MARK: - Inhalt

    private func inhalt(_ daten: DatenSatz) -> some View {
        let essen = daten.essen
        let jetzt = umgebung.uhr()
        let summe = essen.summe(tag)
        let ziele = essen.ernaehrungsZiele(tag: tag)
        let woche = WochenanalyseLogik.berechne(bis: heute, eintraege: { essen.eintraege($0) }, ziele: { essen.ernaehrungsZiele(tag: $0) })
        return ScrollView {
            VStack(spacing: Abstand.xl) {
                if aufbau == .lovea {
                    // Lovea `ErnaehrungView.swift:81-83`: KI-Aufträge stehen über dem Tageskopf.
                    EssenKiAnalysenAbschnitt { name in toast = ToastInhalt(titel: "Eingetragen", zeile: name, stimmung: .stolz) }
                }
                EssenTagesKopf(tag: tag, heute: heute, vorher: { wechseln(-1) }, nachher: { wechseln(1) }, datumOeffnen: { kalenderOffen = true })
                VStack(spacing: Abstand.xl) {
                    if aufbau != .lovea {
                        EssenKiAnalysenAbschnitt { name in toast = ToastInhalt(titel: "Eingetragen", zeile: name, stimmung: .stolz) }
                    }
                    ForEach(essen.anpassung.sichtbar, id: \.self) { abschnitt($0, daten, summe, ziele) }
                    if essen.eintraege(tag).isEmpty {
                        LeerZustand(stimmung: .bereit, satz: "Noch nichts gegessen. Scanne eine Packung oder tippe auf das Plus.",
                                    handlung: "Etwas eintragen") { blatt = .hinzufuegen(Mahlzeit.zurZeit(stunde: Datum.kalender.component(.hour, from: jetzt)), .suche) }
                    } else {
                        donutKarte(summe)
                    }
                    proteinKarte(woche)
                    EssenFastenKarte(essen: essen)
                    favoritenAbschnitt(essen)
                    EssenZielKarte(daten: daten, jetzt: jetzt) {
                        toast = ToastInhalt(titel: "Ziele übernommen", zeile: "Gilt ab sofort für dein Tagebuch", stimmung: .stolz)
                    }
                }
                .id(tag)
                .transition(bewegungAus ? .opacity : .push(from: vorwaerts ? .trailing : .leading))
                PartnerKarte(bereich: .essen)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.top, Abstand.s)
            .padding(.bottom, 96)
        }
        .overlay(alignment: .bottomTrailing) { scanKnopf }
    }

    @ViewBuilder
    private func abschnitt(_ id: String, _ daten: DatenSatz, _ summe: Naehrwerte, _ ziele: ErnaehrungsZiele) -> some View {
        let essen = daten.essen
        switch id {
        case "uebersicht":
            VStack(alignment: .leading, spacing: Abstand.m) {
                ueberschrift("Übersicht")
                EssenUebersichtKarte(summe: summe, ziele: ziele, verbrannt: verbrannt) { naehrwerteOffen = true }
                if !essen.ernaehrungsZiele.eingerichtet {
                    Button { zieleOffen = true } label: {
                        HStack(spacing: Abstand.s) {
                            Text("Ziel \(ziele.kcal) kcal geschätzt.").foregroundStyle(palette.text2)
                            Text("Anpassen").fontWeight(.semibold).foregroundStyle(palette.text)
                        }
                        .font(.footnote)
                        .frame(minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.plain)
                }
            }
        case "ernaehrung":
            VStack(alignment: .leading, spacing: Abstand.m) {
                abschnittKopf("Ernährung") { uebersichtOffen = true }
                EssenMahlzeitenAbschnitt(essen: essen, tag: tag, zielKcal: ziele.kcal, bearbeitbar: true,
                                         oeffnen: { offeneMahlzeit = $0 },
                                         hinzufuegen: { blatt = .hinzufuegen($0, .suche) },
                                         alsGericht: { gerichtName = ""; gerichtQuelle = $0; gerichtAlert = true })
            }
        case "wasser":
            VStack(alignment: .leading, spacing: Abstand.m) {
                ueberschrift("Wasserzähler")
                EssenWasserKarte(glaeser: daten.habits.wert(Habit.wasser.id, tag),
                                 zielGlaeser: daten.habits.habitZiel(Habit.wasser.id) ?? 8,
                                 ausLebensmittelnMl: Int(ErnaehrungLogik.wasserAusLebensmitteln(essen.eintraege(tag)).rounded()),
                                 bearbeitbar: true) { daten.habits.setzeWasser(datum: tag, anzahl: $0) }
            }
        case "koerper":
            VStack(alignment: .leading, spacing: Abstand.m) {
                abschnittKopf("Körperwerte") { koerperOffen = true }
                EssenKoerperKarte(tag: tag, gewicht: essen.gewicht(bis: tag),
                                  werte: KoerperArt.allCases.compactMap { essen.koerperwert($0, bis: tag) },
                                  aendern: { gewichtAendern($0, essen) })
            }
        default:
            EmptyView()
        }
    }

    private func ueberschrift(_ text: String) -> some View {
        Text(text).font(.title2.weight(.heavy)).fontDesign(.rounded).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
    }

    private func abschnittKopf(_ text: String, mehr: @escaping @MainActor () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            ueberschrift(text)
            Spacer()
            Button("Mehr") { mehr() }
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.text)
                .frame(minHeight: Abstand.tippflaeche)
        }
    }

    private var mehrMenue: some View {
        Menu {
            Button("Ziele", systemImage: "target") { zieleOffen = true }
            Button("Auswertung", systemImage: "chart.bar") { auswertungOffen = true }
            Button("Nährwerte des Tages", systemImage: "list.bullet.rectangle") { naehrwerteOffen = true }
            Button("Wochenanalyse", systemImage: "chart.bar.fill") { wochenOffen = true }
            Button("Intervallfasten", systemImage: "timer") { fastenOffen = true }
            Button("Tagebuch anpassen", systemImage: "slider.horizontal.3") { anpassenOffen = true }
        } label: {
            Image(systemName: "ellipsis").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .accessibilityLabel("Mehr")
    }

    // MARK: - Tag, Gewicht, Health

    private var tagBinding: Binding<String> {
        Binding(get: { tag }, set: { neu in
            vorwaerts = neu > tag
            withAnimation(bewegungAus ? nil : Feder.weich) { gewaehlt = neu == heute ? nil : neu }
        })
    }

    /// Eine Richtung wechseln: Push-Übergang in dieser Richtung, leises Auswahl-Signal. Morgen und später sind erlaubt (Planen).
    private func wechseln(_ richtung: Int) {
        vorwaerts = richtung > 0
        let neu = Datum.addTage(tag, richtung)
        withAnimation(bewegungAus ? nil : Feder.weich) { gewaehlt = neu == heute ? nil : neu }
        wechsel += 1
    }

    /// ±0,1 kg vom Gewicht dieses Tages oder vom letzten davor. Nie eingetragen: Körperwerte-Blatt öffnen.
    private func gewichtAendern(_ schritt: Int, _ essen: EssenStore) {
        guard let letztes = essen.gewicht(bis: tag) else { koerperOffen = true; return }
        essen.gewichtSetzen(zehntel: EssenTagebuchLogik.gewichtNach(zehntel: letztes.zehntel, schritt: schritt), datum: tag)
    }

    /// Aktive Kalorien des Tages aus Apple Health (nur Anzeige). Ohne Freigabe oder Daten bleibt es leer.
    private func verbranntLaden() async {
        let tagJetzt = tag
        let werte = await umgebung.healthLeser.tagesWerte(von: tagJetzt, bis: tagJetzt)
        verbrannt = werte.first { $0.tag == tagJetzt }.map { Int($0.aktiveKcal.rounded()) }
    }

    private func donutKarte(_ summe: Naehrwerte) -> some View {
        let d = MakroDonutDaten.aus(summe)
        return VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Makros heute").font(.headline).foregroundStyle(palette.text)
            MakroDonut(daten: d, kcal: summe.kcal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }

    @ViewBuilder
    private func proteinKarte(_ woche: Wochenanalyse) -> some View {
        if !woche.istLeer {
            DiagrammKarte(aussage: "Protein je Tag gegen das Ziel", kernzeile: woche.klartext.first ?? "") {
                EssenProteinDiagramm(analyse: woche)
            }
        }
    }

    @ViewBuilder
    private func favoritenAbschnitt(_ essen: EssenStore) -> some View {
        let favoriten = essen.favoriten
        let haeufig = essen.haeufig
        let liste = Array((favoriten + haeufig.filter { h in !favoriten.contains { $0.id == h.id } }).prefix(12))
        let mahlzeit = Mahlzeit.zurZeit(stunde: Datum.kalender.component(.hour, from: umgebung.uhr()))
        if !liste.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(favoriten.isEmpty ? "Häufig gegessen" : "Favoriten und häufig").font(.headline).foregroundStyle(palette.text)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Abstand.s) {
                        ForEach(liste) { l in
                            Button { vorgewaehlt = l; blatt = .hinzufuegen(mahlzeit, .favoriten) } label: {
                                Pille(text: l.name, symbolName: essen.istFavorit(l) ? "star.fill" : "clock")
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: Abstand.tippflaeche)
                            .accessibilityHint("Öffnet die Favoriten")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scanKnopf: some View {
        GlassEffectContainer(spacing: Abstand.m) {
            Button {
                blatt = .scan(Mahlzeit.zurZeit(stunde: Datum.kalender.component(.hour, from: umgebung.uhr())))
            } label: {
                Image(systemName: "camera.viewfinder").font(.title2).frame(width: 56, height: 56)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Essen scannen")
            .accessibilityHint("Öffnet die Kamera für den Barcode")
        }
        .padding(Abstand.l)
    }

    // MARK: - Blätter

    @State private var vorgewaehlt: Lebensmittel?

    @ViewBuilder
    private func blattInhalt(_ b: EssenBlatt) -> some View {
        switch b {
        case .hinzufuegen(let m, let bereich):
            EssenHinzufuegenView(mahlzeit: m, tag: tag, start: bereich, vorgewaehlt: vorgewaehlt) { blattSchliessen(gespeichert: $0) }
        case .scan(let m):
            ScanView(mahlzeit: m, tag: tag) { blattSchliessen(gespeichert: $0) }
        }
    }

    /// Eine ganze Mahlzeit als Gericht (Rezept der Art `mahlzeit`) und als Favorit speichern; die Vorlage ändert sich später nicht mit dem Tagebuch.
    private func gerichtSpeichern() {
        guard let m = gerichtQuelle, let essen = umgebung.daten?.essen else { return }
        let eintraege = essen.eintraege(tag, m)
        guard !eintraege.isEmpty else { return }
        let name = gerichtName.trimmingCharacters(in: .whitespacesAndNewlines)
        let zutaten = eintraege.map { Zutat(id: UUID().uuidString, lebensmittel: $0.lebensmittel, menge: $0.menge, einheit: $0.einheit) }
        let rezept = Rezept(id: UUID().uuidString, name: name.isEmpty ? essen.mahlzeitName(m) : name, portionen: 1, zutaten: zutaten, art: .mahlzeit)
        essen.rezeptSichern(rezept)
        essen.favoritSetzen(ErnaehrungLogik.alsLebensmittel(rezept), an: true)
        gerichtQuelle = nil
        toast = ToastInhalt(titel: "Gericht gespeichert", zeile: "Bei den Favoriten", stimmung: .stolz)
    }

    private func blattSchliessen(gespeichert: Bool) {
        blatt = nil
        vorgewaehlt = nil
        if gespeichert { toast = ToastInhalt(titel: "Eingetragen", zeile: nil, stimmung: .stolz) }
    }
}
