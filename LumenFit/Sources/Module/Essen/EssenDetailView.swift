import SwiftUI

/// Ein Lebensmittel ansehen und eintragen: Nährwerte, Portion-Schieber (Gramm, Stück, Portion) mit rollenden Zahlen, Halal- und Zucker-Ampel,
/// Schilder, Quelle ("Quelle: BLS" oder "Quelle: Open Food Facts"), Nutri-Score, Portionsbeispiele und Favorit. Mit `bearbeiten` ändert oder löscht es einen Tagebuch-Eintrag.
/// Unten die Mengen-Leiste mit Zahlenfeld, Einheit und Dreier-Rad (Lovea `LebensmittelDetailView`). Fehlen die Zutaten, holt die Ampel sie einmal bei Open Food Facts nach.
struct EssenDetailView: View {
    let lebensmittel: Lebensmittel
    let bearbeiten: EssenEintrag?
    let tag: String
    let fertig: @MainActor (Bool) -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var mahlzeit: Mahlzeit
    @State private var auswahl: MengenOption
    @State private var zahl: Double
    @State private var loeschenFragen = false
    @State private var portionsbeispieleOffen = false
    /// Zutaten und Siegel von Open Food Facts, einmal nachgeladen (nur für die Ampel, nie gespeichert).
    @State private var nachgeladen: Lebensmittel?
    /// Zählt das Sichern: löst die Haptik aus und sperrt den Knopf gegen doppelte Einträge.
    @State private var gesichert = 0

    init(lebensmittel: Lebensmittel, mahlzeit: Mahlzeit, tag: String, bearbeiten: EssenEintrag? = nil, fertig: @escaping @MainActor (Bool) -> Void) {
        self.lebensmittel = lebensmittel
        self.bearbeiten = bearbeiten
        self.tag = bearbeiten?.datum ?? tag
        self.fertig = fertig
        _mahlzeit = State(initialValue: bearbeiten?.mahlzeit ?? mahlzeit)
        let start: (option: MengenOption, zahl: Double)
        if let e = bearbeiten {
            start = (MengenOption.auswahl(einheit: e.einheit, portionName: e.lebensmittel.portionName, l: lebensmittel), e.menge)
        } else {
            start = EssenMenge.start(lebensmittel, letzte: nil)
        }
        _auswahl = State(initialValue: start.option)
        _zahl = State(initialValue: start.zahl)
    }

    private var essen: EssenStore? { umgebung.daten?.essen }

    /// Das Lebensmittel mit der gewählten Portion, wie es gespeichert wird.
    private var fuerMenge: Lebensmittel {
        if case .portion(let p) = auswahl { return ErnaehrungLogik.mitPortion(lebensmittel, p) }
        return lebensmittel
    }

    private var werte: Naehrwerte { ErnaehrungLogik.naehrwerte(fuerMenge, menge: zahl, einheit: auswahl.einheit) }

    /// Für Ampel und Zutatenzeile: mit den nachgeladenen Zutaten, sonst unverändert.
    private var angezeigt: Lebensmittel { EssenAmpelNachladen.zusammen(lebensmittel, geladen: nachgeladen) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                kopf
                werteKarte
                mahlzeitWahl
                EssenAmpelKarte(lebensmittel: angezeigt)
                let schilder = FoodRating.schilder(lebensmittel)
                if !schilder.isEmpty { EssenSchilderZeile(schilder: schilder) }
                naehrwerteKarte
                portionsbeispieleZeile
                herkunft
            }
            .padding(Abstand.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Lebensmittel")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .toolbar { werkzeugleiste }
        .safeAreaInset(edge: .bottom) {
            EssenMengenLeiste(lebensmittel: lebensmittel, auswahl: auswahl, zahl: $zahl, knopf: bearbeiten == nil ? "Eintragen" : "Speichern",
                              deaktiviert: gesichert > 0, einheitWechseln: { einheitWechseln($0) }, aktion: { speichern() })
        }
        .haptik(.erfolg, bei: gesichert)
        .sheet(isPresented: $portionsbeispieleOffen) { EssenPortionsBeispieleBlatt() }
        .task {
            guard bearbeiten == nil, let letzte = essen?.letzteMenge(lebensmittel) else { return }
            let start = EssenMenge.start(lebensmittel, letzte: letzte)
            auswahl = start.option
            zahl = start.zahl
        }
        .task(id: lebensmittel.id) {
            // Einmal pro Barcode und Sitzung, leise bei Fehlern; nie beim Bearbeiten eines Eintrags.
            guard EssenAmpelNachladen.braucht(lebensmittel, bearbeiten: bearbeiten != nil), let code = lebensmittel.barcode else { return }
            nachgeladen = await EssenModul.suche(umgebung).zutatenNachladen(code)
        }
        .confirmationDialog("Eintrag löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let e = bearbeiten { essen?.loeschen(e) }
                fertig(false)
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: - Teile

    private var kopf: some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text(lebensmittel.name).font(.title2.weight(.bold)).foregroundStyle(palette.text)
            if let marke = lebensmittel.marke { Text(marke).font(.subheadline).foregroundStyle(palette.text2) }
            Text(EssenQuelle.zeile(lebensmittel)).font(.footnote).foregroundStyle(palette.text2)
            if let note = EssenNutriScoreLogik.note(lebensmittel.nutriscore) {
                EssenNutriScoreAbzeichen(note: note).padding(.top, Abstand.xs)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var werteKarte: some View {
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                    RollZahl(wert: werte.kcal, format: .number.precision(.fractionLength(0)))
                        .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    Text("kcal").font(.subheadline)
                }
                HStack(spacing: Abstand.xl) {
                    makro("Protein", werte.protein)
                    makro("Kohlenhydrate", werte.kohlenhydrate)
                    makro("Fett", werte.fett)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func makro(_ name: String, _ gramm: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                RollZahl(wert: gramm, format: .number.precision(.fractionLength(0))).font(.title3.weight(.bold)).fontDesign(.rounded)
                Text("g").font(.footnote)
            }
            Text(name).font(.footnote)
        }
    }

    private var mahlzeitWahl: some View {
        Picker("Mahlzeit", selection: $mahlzeit) {
            ForEach(Mahlzeit.allCases) { m in Text(essen?.mahlzeitName(m) ?? m.name).tag(m) }
        }
        .pickerStyle(.menu)
        .frame(minHeight: Abstand.tippflaeche)
    }

    private var naehrwerteKarte: some View {
        let n = lebensmittel.pro100
        let einheit = lebensmittel.basisEinheit.rawValue
        var zeilen: [(String, String)] = [("Energie", "\(Int(n.kcal.rounded())) kcal"), ("Fett", gramm(n.fett))]
        if let g = n.gesFett { zeilen.append(("davon gesättigt", gramm(g))) }
        zeilen.append(("Kohlenhydrate", gramm(n.kohlenhydrate)))
        if let z = n.zucker { zeilen.append(("davon Zucker", gramm(z))) }
        if let b = n.ballaststoffe { zeilen.append(("Ballaststoffe", gramm(b))) }
        zeilen.append(("Eiweiß", gramm(n.protein)))
        if let s = n.salz { zeilen.append(("Salz", gramm(s))) }
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Nährwerte pro 100 \(einheit)").font(.headline).foregroundStyle(palette.text)
            ForEach(Array(zeilen.enumerated()), id: \.offset) { _, z in
                HStack {
                    Text(z.0).font(.subheadline).foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.s)
                    Text(z.1).font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                }
                .accessibilityElement(children: .combine)
            }
            mikroZeilen
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
    }

    private func gramm(_ x: Double) -> String { "\(ErnaehrungLogik.zahl(x)) g" }

    @ViewBuilder
    private var mikroZeilen: some View {
        let jetzt = werte
        let vorhanden = Mikro.allCases.filter { jetzt.wert($0) != nil && $0.gruppe != .weitere }
        if !vorhanden.isEmpty {
            Haarlinie()
            Text("Vitamine und Mineralstoffe für deine Menge").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            ForEach(vorhanden) { m in
                let wert = jetzt.wert(m) ?? 0
                HStack {
                    Text(m.name).font(.subheadline).foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.s)
                    Text("\(ErnaehrungLogik.zahl(wert)) \(m.einheit)").font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                    if let p = AnalyseLogik.prozentReferenz(wert, m) {
                        Text("\(Int(p.rounded())) %").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var herkunft: some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            if let zutaten = angezeigt.zutaten, !zutaten.isEmpty {
                Text("Zutaten").font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
                Text(zutaten).font(.footnote).foregroundStyle(palette.text2)
            }
            Text(EssenQuelle.zeile(lebensmittel)).font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
            if EssenQuelle.name(lebensmittel) == "BLS" {
                Text("Nährwerte: Max Rubner-Institut, Bundeslebensmittelschlüssel 4.0 (CC BY 4.0)").font(.footnote).foregroundStyle(palette.text2)
            } else if EssenQuelle.name(lebensmittel) == "Open Food Facts" {
                Text("Daten: Open Food Facts, Lizenz ODbL. Sie stammen von Nutzern und können Fehler enthalten.").font(.footnote).foregroundStyle(palette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ToolbarContentBuilder
    private var werkzeugleiste: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let essen {
                let favorit = essen.istFavorit(lebensmittel)
                Button { essen.favoritSetzen(lebensmittel, an: !favorit) } label: {
                    Image(systemName: favorit ? "star.fill" : "star")
                }
                .haptik(.auswahl, bei: favorit)
                .accessibilityLabel(favorit ? "Aus den Favoriten nehmen" : "Zu den Favoriten")
            }
            if bearbeiten != nil {
                Button(role: .destructive) { loeschenFragen = true } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Eintrag löschen")
            }
        }
    }

    private var portionsbeispieleZeile: some View {
        Button { portionsbeispieleOffen = true } label: {
            HStack {
                Text("Portionsbeispiele").foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
            .frame(minHeight: Abstand.tippflaeche)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Zeigt, wie groß eine Portion ungefähr ist")
    }

    // MARK: - Aktionen

    private func einheitWechseln(_ neu: MengenOption) {
        guard neu != auswahl else { return }
        zahl = EssenMenge.umrechnen(zahl, von: auswahl, nach: neu)
        auswahl = neu
    }

    private func speichern() {
        guard let essen, zahl > 0, gesichert == 0 else { return }
        if var e = bearbeiten {
            e.menge = zahl
            e.einheit = auswahl.einheit
            e.lebensmittel = fuerMenge
            e.mahlzeit = mahlzeit
            essen.aendern(e)
        } else {
            essen.eintragen(fuerMenge, menge: zahl, einheit: auswahl.einheit, mahlzeit: mahlzeit, datum: tag)
        }
        gesichert += 1
        // Kurz warten, damit die Haptik noch auf der sichtbaren Seite ausgelöst wird, bevor das Blatt schließt.
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            fertig(true)
        }
    }
}
