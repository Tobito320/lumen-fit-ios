import SwiftUI

/// Was über dem Essen-Tab als Blatt liegt.
enum EssenBlatt: Identifiable {
    case hinzufuegen(Mahlzeit, EssenHinzuBereich)
    case scan(Mahlzeit)
    case eintrag(EssenEintrag)

    var id: String {
        switch self {
        case .hinzufuegen(let m, let b): "hinzu-\(m.rawValue)-\(b.rawValue)"
        case .scan(let m): "scan-\(m.rawValue)"
        case .eintrag(let e): "eintrag-\(e.id)"
        }
    }
}

/// Der Essen-Tab: Tagebuch ohne Konto mit Kalorien, Makro-Donut, Protein der Woche, Fasten-Fenster, Favoriten, Mahlzeiten und den Zielen aus den Körperdaten.
/// Der Scan-Knopf schwebt als Glas rechts unten. `bereich` kommt aus dem Link (`lumenfit://essen?bereich=scan|favoriten`).
struct EssenTabView: View {
    var bereich: EssenBereich = .heute
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var gewaehlt: String?
    @State private var blatt: EssenBlatt?
    @State private var toast: ToastInhalt?
    @State private var bereichGeoeffnet = false
    @State private var gerichtQuelle: Mahlzeit?
    @State private var gerichtName = ""
    @State private var gerichtAlert = false

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
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() } }
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
            VStack(spacing: Abstand.l) {
                tagesWahl
                kalorienKarte(summe, ziele)
                if essen.eintraege(tag).isEmpty {
                    LeerZustand(stimmung: .bereit, satz: "Noch nichts gegessen. Scanne eine Packung oder tippe auf das Plus.",
                                handlung: "Etwas eintragen") { blatt = .hinzufuegen(Mahlzeit.zurZeit(stunde: Datum.kalender.component(.hour, from: jetzt)), .suche) }
                } else {
                    donutKarte(summe)
                }
                proteinKarte(woche)
                EssenFastenKarte(essen: essen, jetzt: jetzt)
                favoritenAbschnitt(essen)
                ForEach(Mahlzeit.allCases) { m in mahlzeitKarte(m, essen) }
                EssenZielKarte(daten: daten, jetzt: jetzt) {
                    toast = ToastInhalt(titel: "Ziele übernommen", zeile: "Gilt ab sofort für dein Tagebuch", stimmung: .stolz)
                }
                analyseLink
            }
            .padding(.horizontal, Abstand.l)
            .padding(.top, Abstand.s)
            .padding(.bottom, 96)
        }
        .overlay(alignment: .bottomTrailing) { scanKnopf }
    }

    private var tagesWahl: some View {
        HStack {
            Button { gewaehlt = Datum.addTage(tag, -1) } label: {
                Image(systemName: "chevron.left").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel("Vorheriger Tag")
            Spacer()
            VStack(spacing: 0) {
                Text(tag == heute ? "Heute" : Datum.anzeige(tag)).font(.headline).foregroundStyle(palette.text)
                if tag != heute {
                    Button("Zurück zu heute") { gewaehlt = nil }.font(.footnote).frame(minHeight: Abstand.tippflaeche)
                }
            }
            Spacer()
            Button { gewaehlt = Datum.addTage(tag, 1) } label: {
                Image(systemName: "chevron.right").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .disabled(tag >= heute)
            .accessibilityLabel("Nächster Tag")
        }
    }

    // MARK: - Karten

    private func kalorienKarte(_ summe: Naehrwerte, _ ziele: ErnaehrungsZiele) -> some View {
        let rest = ziele.kcal - Int(summe.kcal.rounded())
        return HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Gegessen").font(.subheadline.weight(.semibold))
                HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                    RollZahl(wert: summe.kcal, format: .number.precision(.fractionLength(0)))
                        .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    Text("von \(ziele.kcal) kcal").font(.subheadline)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.aufAkzent.opacity(0.25))
                        Capsule().fill(palette.aufAkzent).frame(width: geo.size.width * min(max(ziele.kcal > 0 ? summe.kcal / Double(ziele.kcal) : 0, 0), 1))
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)
                Text(rest >= 0 ? "Noch \(rest) kcal übrig" : "\(-rest) kcal über dem Ziel").font(.subheadline.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func donutKarte(_ summe: Naehrwerte) -> some View {
        let d = MakroDonutDaten.aus(summe)
        return VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Makros heute").font(.headline).foregroundStyle(palette.text)
            MakroDonut(daten: d, kcal: summe.kcal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
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

    private func mahlzeitKarte(_ m: Mahlzeit, _ essen: EssenStore) -> some View {
        let eintraege = essen.eintraege(tag, m)
        let kcal = Int(ErnaehrungLogik.summe(eintraege).kcal.rounded())
        return ListenKarte {
            HStack(spacing: Abstand.m) {
                Image(systemName: m.symbol).foregroundStyle(palette.text2).accessibilityHidden(true)
                Text(essen.mahlzeitName(m)).font(.headline).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.s)
                Text("\(kcal) kcal").font(.subheadline).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text2)
                if !eintraege.isEmpty {
                    Menu {
                        Button("Als Gericht speichern", systemImage: "star") { gerichtName = ""; gerichtQuelle = m; gerichtAlert = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                    }
                    .accessibilityLabel("Mehr zu \(essen.mahlzeitName(m))")
                }
                Button { blatt = .hinzufuegen(m, .suche) } label: {
                    Image(systemName: "plus.circle.fill").font(.title3).frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .accessibilityLabel("\(essen.mahlzeitName(m)) hinzufügen")
            }
            .padding(.leading, Abstand.l)
            .padding(.trailing, Abstand.xs)
            ForEach(eintraege) { e in
                Haarlinie()
                EssenEintragZeile(eintrag: e) { blatt = .eintrag(e) }
            }
        }
    }

    private var analyseLink: some View {
        NavigationLink {
            WochenanalyseView()
        } label: {
            HStack {
                Label("Wochenanalyse", systemImage: "chart.bar.fill").font(.headline).foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(palette.text2).accessibilityHidden(true)
            }
            .padding(Abstand.l)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        }
        .buttonStyle(.plain)
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
        case .eintrag(let e):
            NavigationStack {
                EssenDetailView(lebensmittel: e.lebensmittel, mahlzeit: e.mahlzeit, tag: e.datum, bearbeiten: e) { blattSchliessen(gespeichert: $0) }
            }
            .lumenHintergrund()
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
