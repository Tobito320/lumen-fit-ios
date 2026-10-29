import SwiftUI

/// Ein Lebensmittel ansehen und eintragen: Nährwerte, Portion-Schieber (Gramm, Stück, Portion) mit rollenden Zahlen, Halal- und Zucker-Ampel,
/// Schilder, Quelle ("Quelle: BLS" oder "Quelle: Open Food Facts") und Favorit. Mit `bearbeiten` ändert oder löscht es einen Tagebuch-Eintrag.
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
    @State private var feld = ""
    @State private var loeschenFragen = false
    @FocusState private var tippt: Bool

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                kopf
                werteKarte
                mengenKarte
                mahlzeitWahl
                EssenAmpelKarte(lebensmittel: lebensmittel)
                let schilder = FoodRating.schilder(lebensmittel)
                if !schilder.isEmpty { EssenSchilderZeile(schilder: schilder) }
                naehrwerteKarte
                herkunft
            }
            .padding(Abstand.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Lebensmittel")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .toolbar { werkzeugleiste }
        .safeAreaInset(edge: .bottom) { speichernLeiste }
        .task {
            feld = MengenRad.feldText(zahl)
            guard bearbeiten == nil, let letzte = essen?.letzteMenge(lebensmittel) else { return }
            let start = EssenMenge.start(lebensmittel, letzte: letzte)
            auswahl = start.option
            zahl = start.zahl
            feld = MengenRad.feldText(zahl)
        }
        .onChange(of: zahl) { _, neu in if !tippt { feld = MengenRad.feldText(neu) } }
        .onChange(of: feld) { _, neu in
            guard tippt else { return }
            zahl = ErnaehrungLogik.eingabe(neu) ?? 0
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

    private var mengenKarte: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Menge").font(.headline).foregroundStyle(palette.text)
            HStack(spacing: Abstand.s) {
                TextField("0", text: $feld)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($tippt)
                    .font(.title3.weight(.semibold)).fontDesign(.rounded).monospacedDigit()
                    .frame(width: 96, height: Abstand.tippflaeche)
                    .padding(.horizontal, Abstand.m)
                    .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                    .accessibilityLabel("Menge")
                Menu {
                    Picker("Einheit", selection: Binding(get: { auswahl }, set: { einheitWechseln($0) })) {
                        ForEach(MengenOption.optionen(lebensmittel), id: \.self) { Text($0.anzeige(lebensmittel)).tag($0) }
                    }
                } label: {
                    HStack {
                        Text(auswahl.anzeige(lebensmittel)).lineLimit(1).minimumScaleFactor(0.75)
                        Spacer(minLength: Abstand.xs)
                        Image(systemName: "chevron.up.chevron.down").accessibilityHidden(true)
                    }
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, Abstand.m)
                    .frame(minHeight: Abstand.tippflaeche)
                    .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                }
                .accessibilityLabel("Einheit: \(auswahl.anzeige(lebensmittel))")
            }
            HStack(spacing: Abstand.s) {
                Button { schieben(-1) } label: { Image(systemName: "minus.circle.fill").font(.title2).frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                    .accessibilityLabel("Weniger")
                Slider(value: Binding(get: { min(zahl, EssenMenge.bereich(auswahl).upperBound) }, set: { zahl = $0 }),
                       in: EssenMenge.bereich(auswahl), step: EssenMenge.schritt(auswahl))
                    .accessibilityLabel("Menge")
                    .accessibilityValue(ErnaehrungLogik.mengeText(zahl, auswahl.einheit, fuerMenge))
                Button { schieben(1) } label: { Image(systemName: "plus.circle.fill").font(.title2).frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                    .accessibilityLabel("Mehr")
            }
            .haptik(.auswahl, bei: zahl)
            Text(ErnaehrungLogik.mengeText(zahl, auswahl.einheit, fuerMenge)).font(.footnote).foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
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
            if let zutaten = lebensmittel.zutaten, !zutaten.isEmpty {
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
                .accessibilityLabel(favorit ? "Aus den Favoriten nehmen" : "Zu den Favoriten")
            }
            if bearbeiten != nil {
                Button(role: .destructive) { loeschenFragen = true } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Eintrag löschen")
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Fertig") { tippt = false }
        }
    }

    private var speichernLeiste: some View {
        Button { speichern() } label: {
            Text(bearbeiten == nil ? "Eintragen" : "Speichern").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(zahl <= 0)
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .background(.bar)
    }

    // MARK: - Aktionen

    private func schieben(_ richtung: Double) {
        let schritt = EssenMenge.schritt(auswahl)
        zahl = max(0, zahl + richtung * schritt)
    }

    private func einheitWechseln(_ neu: MengenOption) {
        guard neu != auswahl else { return }
        zahl = EssenMenge.umrechnen(zahl, von: auswahl, nach: neu)
        auswahl = neu
    }

    private func speichern() {
        guard let essen, zahl > 0 else { return }
        if var e = bearbeiten {
            e.menge = zahl
            e.einheit = auswahl.einheit
            e.lebensmittel = fuerMenge
            e.mahlzeit = mahlzeit
            essen.aendern(e)
        } else {
            essen.eintragen(fuerMenge, menge: zahl, einheit: auswahl.einheit, mahlzeit: mahlzeit, datum: tag)
        }
        fertig(true)
    }
}
