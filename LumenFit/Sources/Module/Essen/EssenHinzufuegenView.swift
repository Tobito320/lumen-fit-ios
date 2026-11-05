import SwiftUI

/// Die vier Listen im Hinzufügen-Blatt.
enum EssenHinzuBereich: String, CaseIterable, Identifiable, Sendable {
    case suche, favoriten, zuletzt, eigene

    var id: String { rawValue }

    var name: String {
        switch self {
        case .suche: "Suche"
        case .favoriten: "Favoriten"
        case .zuletzt: "Zuletzt"
        case .eigene: "Eigene"
        }
    }
}

/// Wo das Blatt gerade einen Editor zeigt (eigenes Lebensmittel, Rezept, Mahlzeit).
private enum EssenEditorBlatt: Identifiable {
    case neuesRezept(RezeptArt)
    case rezept(Rezept)
    case eigenes(Lebensmittel)

    var id: String {
        switch self {
        case .neuesRezept(let art): "neu-\(art.rawValue)"
        case .rezept(let r): "rezept-\(r.id)"
        case .eigenes(let l): "eigen-\(l.id)"
        }
    }
}

/// Lebensmittel finden und eintragen: Suche in BLS (ohne Netz) und beim Tippen auf dem Lumen-Server, Favoriten, Zuletzt, Eigene, Scan, Etikett-Foto
/// und Eingabe von Hand. Das Netz wird nur auf "Suchen" gefragt, nie beim Tippen.
/// Wie in Lovea bleibt das Blatt nach dem Eintragen offen: das Plus in der Zeile trägt sofort ein (letzte Menge, sonst Portion oder 100 g),
/// ein Banner meldet es. "Fertig" schließt mit `fertig(true)`, "Abbrechen" (ohne Eintrag) mit `fertig(false)`.
struct EssenHinzufuegenView: View {
    let mahlzeit: Mahlzeit
    let tag: String
    let start: EssenHinzuBereich
    let vorgewaehlt: Lebensmittel?
    let fertig: @MainActor (Bool) -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var bereich: EssenHinzuBereich
    @State private var text = ""
    @State private var pfad: [EssenZiel] = []
    @State private var scanOffen = false
    @State private var fotoOffen = false
    @State private var fotoVorlage: Naehrwerte?
    @State private var typ: EssenHinzuTyp = .lebensmittel
    @State private var sortierung: EssenHinzuSortierung = .haeufig
    @State private var chip: EssenSuchChip?
    @State private var zaehler = 0
    @State private var toast: ToastInhalt?
    @State private var geradeEingetragen: Set<String> = []
    @State private var schnellOffen = false
    @State private var editor: EssenEditorBlatt?
    @State private var loeschenZiel: Lebensmittel?
    @State private var vorschlaege: (name: String, liste: [Lebensmittel], code: String)?
    @State private var vorschlagsZiel: EssenZiel?
    @State private var barcodeFehler: String?

    init(mahlzeit: Mahlzeit, tag: String, start: EssenHinzuBereich, vorgewaehlt: Lebensmittel? = nil, fertig: @escaping @MainActor (Bool) -> Void) {
        self.mahlzeit = mahlzeit
        self.tag = tag
        self.start = start
        self.vorgewaehlt = vorgewaehlt
        self.fertig = fertig
        _bereich = State(initialValue: start)
        _pfad = State(initialValue: vorgewaehlt.map { [EssenZiel.detail($0)] } ?? [])
    }

    private var suche: LebensmittelSuche { EssenModul.suche(umgebung) }
    private var essen: EssenStore? { umgebung.daten?.essen }
    private var mahlzeitName: String { essen?.mahlzeitName(mahlzeit) ?? mahlzeit.name }

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    Picker("Liste", selection: $bereich) {
                        ForEach(EssenHinzuBereich.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if bereich == .suche { sucheBereich } else { listenBereich }
                }
                .padding(Abstand.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(mahlzeitName)
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(zaehler > 0 ? "Fertig" : "Abbrechen") { fertig(zaehler > 0) }
                }
                ToolbarItem(placement: .primaryAction) { erstellenMenue }
            }
            .navigationDestination(for: EssenZiel.self) { ziel in
                EssenZielAnsicht(ziel: ziel, mahlzeit: mahlzeit, tag: tag, vorlage: fotoVorlage, fertig: { zielFertig($0) }) { pfad = [$0] }
            }
            .sheet(isPresented: $scanOffen) {
                ScanView(mahlzeit: mahlzeit, tag: tag) { gespeichert in
                    scanOffen = false
                    if gespeichert { vermerken(name: nil) }
                }
            }
            .sheet(isPresented: $fotoOffen) {
                NaehrwertFotoView { werte in
                    fotoOffen = false
                    fotoVorlage = werte
                    pfad = [.eigenes(barcode: nil)]
                }
            }
            .sheet(isPresented: $schnellOffen) {
                EssenSchnellEintragenBlatt(mahlzeit: mahlzeit, tag: tag) { l in vermerken(name: l.name) }
            }
            .sheet(item: $editor, onDismiss: neuSuchen) { blatt in editorInhalt(blatt) }
            .sheet(isPresented: Binding(get: { vorschlaege != nil }, set: { if !$0 { vorschlaege = nil } }), onDismiss: {
                guard let ziel = vorschlagsZiel else { return }
                vorschlagsZiel = nil
                pfad = [ziel]
            }) {
                if let v = vorschlaege {
                    EssenMehrtrefferBlatt(name: v.name, treffer: v.liste,
                                          auswahl: { l in vorschlagWaehlen(l, code: v.code) },
                                          keinesDavon: { vorschlagsZiel = .eigenes(barcode: v.code) })
                }
            }
            .confirmationDialog("\(loeschenZiel?.name ?? "Eintrag") löschen?", isPresented: Binding(get: { loeschenZiel != nil }, set: { if !$0 { loeschenZiel = nil } }),
                                titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { loeschenAusfuehren() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Schon eingetragene Mahlzeiten bleiben im Tagebuch.")
            }
            .task(id: text) {
                // Kurz warten, bis das Tippen pausiert (die Suche über 7.140 Einträge läuft auf dem Hauptakteur), und auf den BLS-Index
                // warten, der im Hintergrund lädt (höchstens etwa drei Sekunden). BLS sofort, der Server danach (entprellt, bricht mit der Task ab).
                barcodeFehler = nil
                LebensmittelIndex.shared.laden()
                try? await Task.sleep(for: .milliseconds(text.isEmpty ? 0 : 200))
                for _ in 0..<20 where !Task.isCancelled && !LebensmittelIndex.shared.bereit { try? await Task.sleep(for: .milliseconds(150)) }
                guard !Task.isCancelled else { return }
                suche.eingabe(text, vorne: vorne)
                await suche.serverSuchen()
            }
        }
        .lumenToast($toast)
        .nutzungAblauf(.essen, stufe: "offen")
        .onChange(of: scanOffen) { _, offen in if offen { umgebung.konto.nutzung.ablauf(.essen, stufe: "scan") } }
        .onChange(of: fotoOffen) { _, offen in if offen { umgebung.konto.nutzung.ablauf(.essen, stufe: "foto") } }
    }

    /// Favoriten, Zuletzt, Eigene und eigene Rezepte stehen in den Treffern vor dem BLS.
    private var vorne: [Lebensmittel] {
        guard let essen else { return [] }
        return essen.favoriten + essen.zuletzt + essen.eigene + essen.rezepte.map(ErnaehrungLogik.alsLebensmittel)
    }

    /// Nach Bearbeiten, Löschen oder Kopieren (und nach dem Editor, der die geteilte Suche mitbenutzt): die Trefferliste neu aufbauen.
    private func neuSuchen() {
        suche.eingabe(text, vorne: vorne)
    }

    // MARK: - Erstellen

    private var erstellenMenue: some View {
        Menu {
            Button { schnellOffen = true } label: { Label("Schnell eintragen", systemImage: "bolt.fill") }
            Button { pfad = [.eigenes(barcode: nil)] } label: { Label("Neues Lebensmittel", systemImage: "carrot.fill") }
            Button { editor = .neuesRezept(.mahlzeit) } label: { Label("Neue Mahlzeit", systemImage: "takeoutbag.and.cup.and.straw.fill") }
            Button { editor = .neuesRezept(.rezept) } label: { Label("Neues Rezept", systemImage: "book.pages.fill") }
        } label: {
            Image(systemName: "plus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .accessibilityLabel("Erstellen")
        .accessibilityHint("Schnell eintragen, neues Lebensmittel, neue Mahlzeit oder neues Rezept")
    }

    @ViewBuilder
    private func editorInhalt(_ blatt: EssenEditorBlatt) -> some View {
        switch blatt {
        case .neuesRezept(let art): EssenRezeptEditor(art: art)
        case .rezept(let r): EssenRezeptEditor(start: r)
        case .eigenes(let l):
            NavigationStack {
                EssenEigenesView(barcode: nil, start: l, fertig: { _ in editor = nil }, geloescht: { editor = nil })
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { editor = nil } } }
            }
        }
    }

    // MARK: - Suche

    private var sucheBereich: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            HStack(spacing: Abstand.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(palette.text2).accessibilityHidden(true)
                TextField("Lebensmittel oder Barcode", text: $text)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Suchen")
                if !text.isEmpty {
                    Button { text = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                        .accessibilityLabel("Suchfeld leeren")
                }
            }
            .padding(.leading, Abstand.m)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))

            werkzeuge

            if BarcodeLogik.istBarcodeEingabe(text) { barcodeZeile }

            if text.trimmingCharacters(in: .whitespaces).count < 2 {
                grundliste
            } else {
                chipReihe
                ergebnisse
                EssenOnlineHinweis(zustand: suche.online)
            }
        }
    }

    private var werkzeuge: some View {
        HStack(spacing: Abstand.s) {
            kachel("Scannen", symbol: "barcode.viewfinder") { scanOffen = true }
            kachel("Etikett", symbol: "camera.fill") { fotoOffen = true }
            kachel("Von Hand", symbol: "square.and.pencil") { pfad = [.eigenes(barcode: nil)] }
            kachel("Schnell", symbol: "bolt.fill") { schnellOffen = true }
            EssenKiFotoKnopf(mahlzeit: mahlzeit, tag: tag, vonHand: { pfad = [.eigenes(barcode: nil)] }) { vermerken(name: $0) }
        }
    }

    private func kachel(_ titel: String, symbol: String, aktion: @escaping @MainActor () -> Void) -> some View {
        Button { aktion() } label: {
            VStack(spacing: Abstand.xs) {
                Image(systemName: symbol).font(.title3).accessibilityHidden(true)
                Text(titel).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, minHeight: 64)
            .lumenKartenFlaeche()
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(titel == "Schnell" ? "Schnell eintragen, nur Kalorien" : titel)
    }

    private var barcodeZeile: some View {
        Button {
            Task { await barcodeSuchen(text) }
        } label: {
            Label("Barcode \(text) nachschlagen", systemImage: "barcode.viewfinder")
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.lumenHauptknopf)
    }

    private func barcodeSuchen(_ code: String) async {
        let ergebnis = await suche.barcode(code)
        switch ergebnis {
        case .gefunden(let l): pfad = [.detail(l)]
        case .vorschlaege(let n, let liste, let c): vorschlaege = (n, liste, c)
        case .unbekannt(let c): pfad = [.eigenes(barcode: c)]
        case .offline: barcodeFehler = "Kein Netz. Versuche es mit Netz noch einmal."
        case .limit(_, let s): barcodeFehler = "Open Food Facts erlaubt 15 Abfragen in der Minute. In etwa \(s) Sekunden geht es wieder."
        case .fehler: barcodeFehler = "Open Food Facts antwortet gerade nicht. Versuche es gleich noch einmal."
        }
    }

    /// Der gewählte Vorschlag wird als eigenes Lebensmittel mit dem gescannten Code gespeichert.
    private func vorschlagWaehlen(_ l: Lebensmittel, code: String) {
        let eigenes = EssenMehrtrefferLogik.alsEigenes(l, code: code)
        essen?.eigenesSichern(eigenes)
        vorschlagsZiel = .detail(eigenes)
    }

    // MARK: - Listen

    /// Leere Suche: Typ und Sortierung wie in Lovea, darunter die Liste.
    @ViewBuilder
    private var grundliste: some View {
        HStack(spacing: Abstand.s) {
            menue($typ, EssenHinzuTyp.allCases).haptik(.auswahl, bei: typ)
            menue($sortierung, EssenHinzuSortierung.allCases).haptik(.auswahl, bei: sortierung)
            Spacer(minLength: 0)
        }
        let liste = EssenHinzuLogik.liste(typ: typ, sortierung: sortierung, haeufig: essen?.haeufig ?? [], zuletzt: essen?.zuletzt ?? [],
                                          favoriten: essen?.favoriten ?? [], rezepte: essen?.rezepte ?? [])
        if liste.isEmpty {
            LeerZustand(stimmung: .bereit, satz: grundlisteLeer)
        } else {
            zeilenKarte(liste)
        }
    }

    private var grundlisteLeer: String {
        switch typ {
        case .lebensmittel: "Tippe einen Namen, scanne eine Packung oder fotografiere das Etikett."
        case .mahlzeiten: "Speichere zum Beispiel Haferflocken, Milch und Honig als eine Mahlzeit und trag sie mit einem Plus ein."
        case .rezepte: "Noch kein Rezept. Lege mit dem Plus oben eines an."
        }
    }

    private func menue<T: Hashable & RawRepresentable>(_ wert: Binding<T>, _ faelle: [T]) -> some View where T.RawValue == String {
        Menu {
            Picker("Auswahl", selection: wert) {
                ForEach(faelle, id: \.self) { Text($0.rawValue).tag($0) }
            }
        } label: {
            HStack(spacing: Abstand.xs) {
                Text(wert.wrappedValue.rawValue).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(palette.text)
            .padding(.horizontal, Abstand.m)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.flaeche, in: .capsule)
        }
        .accessibilityLabel("\(wert.wrappedValue.rawValue), ändern")
    }

    private var chipReihe: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Abstand.s) {
                ForEach([EssenSuchChip.favoriten, .vonMir, .vonAnderen], id: \.self) { c in
                    let aktiv = chip == c
                    Button { chip = aktiv ? nil : c } label: {
                        Label(c.titel, systemImage: c.symbol)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(aktiv ? palette.aufAkzent : palette.text)
                            .padding(.horizontal, Abstand.m)
                            .frame(minHeight: Abstand.tippflaeche)
                            .background(aktiv ? palette.akzent : palette.flaeche, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(aktiv ? .isSelected : [])
                }
            }
        }
        .haptik(.auswahl, bei: chip)
    }

    /// Treffer, nach Chip gefiltert.
    private var treffer: [Lebensmittel] {
        let alle = suche.stand.sichtbar
        guard chip != nil, let essen else { return alle }
        let eigeneUndRezepte = essen.eigene + essen.rezepte.map(ErnaehrungLogik.alsLebensmittel)
        func von(_ h: EssenHerkunft) -> [Lebensmittel] {
            eigeneUndRezepte.filter { EssenHinzuLogik.herkunft(ersteller: essen.ersteller($0), ich: essen.ich) == h }
        }
        // Eigenes ohne bekannten Ersteller zählt als meins.
        let vonMir = von(.ich) + von(.keine)
        return EssenHinzuLogik.suchKarten(chip: chip, treffer: alle, favoriten: essen.favoriten, vonMir: vonMir, vonAnderen: von(.andere))
    }

    @ViewBuilder
    private var ergebnisse: some View {
        let liste = treffer
        if let barcodeFehler { FehlerKarte(titel: "Barcode nicht geprüft", hilfe: barcodeFehler) }
        if liste.isEmpty {
            Text("Nichts gefunden. Du kannst das Lebensmittel von Hand eintragen.")
                .font(.subheadline).foregroundStyle(palette.text2)
        } else {
            zeilenKarte(liste)
        }
    }

    private func zeilenKarte(_ liste: [Lebensmittel]) -> some View {
        ListenKarte {
            ForEach(Array(liste.enumerated()), id: \.element.id) { i, l in
                if i > 0 { Haarlinie() }
                zeile(l)
            }
        }
    }

    private func zeile(_ l: Lebensmittel) -> some View {
        let herkunft = essen.map { EssenHinzuLogik.herkunft(ersteller: $0.ersteller(l), ich: $0.ich) } ?? .keine
        return EssenHinzuZeile(lebensmittel: l, eingetragen: geradeEingetragen.contains(l.id), herkunft: herkunft,
                               istFavorit: essen?.istFavorit(l) ?? false,
                               tippen: { suche.merke(l); pfad = [.detail(l)] },
                               plus: { direktEintragen(l) },
                               bearbeiten: { bearbeitenOeffnen(l) },
                               loeschen: { loeschenZiel = l },
                               kopieren: { kopieren(l) },
                               favoritUmschalten: { essen?.favoritSetzen(l, an: !(essen?.istFavorit(l) ?? false)); neuSuchen() })
    }

    // MARK: - Favoriten, Zuletzt, Eigene

    @ViewBuilder
    private var listenBereich: some View {
        let liste: [Lebensmittel] = switch bereich {
        case .favoriten: essen?.favoriten ?? []
        case .zuletzt: essen?.zuletzt ?? []
        case .eigene: essen?.eigene ?? []
        case .suche: []
        }
        if liste.isEmpty {
            LeerZustand(stimmung: .bereit, satz: leerSatz)
        } else {
            zeilenKarte(liste)
        }
    }

    private var leerSatz: String {
        switch bereich {
        case .favoriten: "Noch keine Favoriten. Tippe in einem Lebensmittel auf den Stern, oder speichere eine ganze Mahlzeit als Gericht."
        case .zuletzt: "Hier erscheint, was du zuletzt gegessen hast."
        case .eigene: "Noch nichts Eigenes. Lebensmittel von Hand oder vom Etikett landen hier."
        case .suche: ""
        }
    }

    // MARK: - Aktionen

    /// Ergebnis des Detail-Blatts: nach dem Eintragen zurück zur Liste (das Blatt bleibt offen), sonst nur zurück.
    private func zielFertig(_ gespeichert: Bool) {
        var name: String?
        if case .detail(let l)? = pfad.last { name = l.name }
        pfad = []
        if gespeichert { vermerken(name: name) }
    }

    /// Zähler hoch und Banner. Das Banner löst die Erfolgs-Haptik aus; die Zeile mit dem Zähler macht jedes Banner verschieden, auch bei gleichem Namen.
    private func vermerken(name: String?) {
        zaehler += 1
        let n = zaehler
        toast = ToastInhalt(titel: name.map { "\($0) eingetragen" } ?? "Eingetragen",
                            zeile: "\(n) \(n == 1 ? "Eintrag" : "Einträge") in \(mahlzeitName)", stimmung: .bereit)
    }

    /// Plus-Tipp: Mahlzeit-Vorlage als ganze Mahlzeit, sonst letzte Menge oder Standard. Das Plus wird eine Sekunde lang zum Häkchen.
    private func direktEintragen(_ l: Lebensmittel) {
        guard let essen else { return }
        if let vorlage = essen.mahlzeitVorlage(l.id) {
            essen.mahlzeitEintragen(vorlage, mahlzeit: mahlzeit, datum: tag)
        } else {
            let menge = EssenHinzuLogik.plusMenge(l, letzte: essen.letzteMenge(l))
            essen.eintragen(l, menge: menge.menge, einheit: menge.einheit, mahlzeit: mahlzeit, datum: tag)
        }
        vermerken(name: l.name)
        geradeEingetragen.insert(l.id)
        Task {
            try? await Task.sleep(for: .seconds(1))
            geradeEingetragen.remove(l.id)
        }
    }

    private func bearbeitenOeffnen(_ l: Lebensmittel) {
        if let r = EssenHinzuLogik.rezept(zu: l, in: essen?.rezepte ?? []) { editor = .rezept(r) } else { editor = .eigenes(l) }
    }

    private func loeschenAusfuehren() {
        guard let l = loeschenZiel else { return }
        loeschenZiel = nil
        if let r = EssenHinzuLogik.rezept(zu: l, in: essen?.rezepte ?? []) { essen?.rezeptLoeschen(r) } else { essen?.eigenesLoeschen(l) }
        neuSuchen()
    }

    private func kopieren(_ l: Lebensmittel) {
        if let r = EssenHinzuLogik.rezept(zu: l, in: essen?.rezepte ?? []) { essen?.kopieren(r) } else { essen?.kopieren(l) }
        toast = ToastInhalt(titel: "\(l.name) kopiert", zeile: "Jetzt bei deinen eigenen", stimmung: .bereit)
        neuSuchen()
    }
}

/// Eine Zeile mit Plus zum Direkt-Eintragen: Tipp auf den Namen öffnet das Lebensmittel, Tipp auf das Plus trägt ein (Lovea `HinzuZeile`).
/// Langes Drücken: eigene Einträge bearbeiten oder löschen, fremde kopieren; Favorit für alle.
struct EssenHinzuZeile: View {
    let lebensmittel: Lebensmittel
    var eingetragen = false
    var herkunft: EssenHerkunft = .keine
    var istFavorit = false
    let tippen: @MainActor () -> Void
    let plus: @MainActor () -> Void
    var bearbeiten: @MainActor () -> Void = {}
    var loeschen: @MainActor () -> Void = {}
    var kopieren: @MainActor () -> Void = {}
    var favoritUmschalten: @MainActor () -> Void = {}

    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus

    var body: some View {
        HStack(spacing: Abstand.s) {
            Button(action: tippen) {
                HStack(spacing: Abstand.m) {
                    VStack(alignment: .leading, spacing: Abstand.xs) {
                        Text(lebensmittel.name).font(.body).foregroundStyle(palette.text).multilineTextAlignment(.leading)
                        Text([lebensmittel.marke, EssenHinzuLogik.portionText(lebensmittel)].compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote).foregroundStyle(palette.text2)
                    }
                    Spacer(minLength: Abstand.s)
                    if let note = EssenNutriScoreLogik.note(lebensmittel.nutriscore) { EssenNutriScoreAbzeichen(note: note, kompakt: true) }
                    Text("\(EssenHinzuLogik.portionKcal(lebensmittel)) kcal")
                        .font(.subheadline).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text2)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(lebensmittel.anzeigeName), \(EssenHinzuLogik.portionKcal(lebensmittel)) Kilokalorien, \(EssenHinzuLogik.portionText(lebensmittel))")
            .accessibilityHint("Öffnet das Lebensmittel")
            Button(action: plus) {
                Image(systemName: eingetragen ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundStyle(palette.text)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                    .contentShape(.rect)
            }
            .buttonStyle(.federnd)
            .accessibilityLabel(eingetragen ? "\(lebensmittel.name) eingetragen" : "\(lebensmittel.name) eintragen")
            .accessibilityHint("Trägt mit der letzten Menge ein")
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.xs)
        .animation(bewegungAus ? nil : Feder.schnell, value: eingetragen)
        .contextMenu {
            switch herkunft {
            case .ich:
                Button("Bearbeiten", systemImage: "pencil", action: bearbeiten)
                Button("Löschen", systemImage: "trash", role: .destructive, action: loeschen)
            case .andere:
                Button("Zu mir kopieren", systemImage: "doc.on.doc", action: kopieren)
            case .keine:
                EmptyView()
            }
            Button(istFavorit ? "Favorit entfernen" : "Favorit", systemImage: istFavorit ? "star.slash" : "star", action: favoritUmschalten)
        }
    }
}
