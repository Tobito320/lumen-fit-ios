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

/// Lebensmittel finden und eintragen: Suche in BLS (ohne Netz) und auf Wunsch in Open Food Facts, Favoriten, Zuletzt, Eigene, Scan, Etikett-Foto
/// und Eingabe von Hand. Das Netz wird nur auf "Suchen" gefragt, nie beim Tippen.
struct EssenHinzufuegenView: View {
    let mahlzeit: Mahlzeit
    let tag: String
    let start: EssenHinzuBereich
    let vorgewaehlt: Lebensmittel?
    let fertig: @MainActor (Bool) -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var bereich: EssenHinzuBereich
    @State private var text = ""
    @State private var pfad: [EssenZiel] = []
    @State private var scanOffen = false
    @State private var fotoOffen = false
    @State private var fotoVorlage: Naehrwerte?

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
            .navigationTitle(essen?.mahlzeitName(mahlzeit) ?? mahlzeit.name)
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { fertig(false) } } }
            .navigationDestination(for: EssenZiel.self) { ziel in
                EssenZielAnsicht(ziel: ziel, mahlzeit: mahlzeit, tag: tag, vorlage: fotoVorlage, fertig: fertig) { pfad = [$0] }
            }
            .sheet(isPresented: $scanOffen) {
                ScanView(mahlzeit: mahlzeit, tag: tag) { gespeichert in
                    scanOffen = false
                    if gespeichert { fertig(true) }
                }
            }
            .sheet(isPresented: $fotoOffen) {
                NaehrwertFotoView { werte in
                    fotoOffen = false
                    fotoVorlage = werte
                    pfad = [.eigenes(barcode: nil)]
                }
            }
            .task(id: text) {
                // Kurz warten, bis das Tippen pausiert (die Suche über 7.140 Einträge läuft auf dem Hauptakteur), und auf den BLS-Index
                // warten, der im Hintergrund lädt (höchstens etwa drei Sekunden). Nur lokal, nie Netz.
                barcodeFehler = nil
                LebensmittelIndex.shared.laden()
                try? await Task.sleep(for: .milliseconds(text.isEmpty ? 0 : 200))
                for _ in 0..<20 where !Task.isCancelled && !LebensmittelIndex.shared.bereit { try? await Task.sleep(for: .milliseconds(150)) }
                guard !Task.isCancelled else { return }
                suche.eingabe(text, vorne: vorne)
            }
        }
    }

    /// Favoriten, Zuletzt und Eigene stehen in den Treffern vor dem BLS.
    private var vorne: [Lebensmittel] {
        guard let essen else { return [] }
        return essen.favoriten + essen.zuletzt + essen.eigene
    }

    // MARK: - Suche

    private var sucheBereich: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            HStack(spacing: Abstand.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(palette.text2).accessibilityHidden(true)
                TextField("Lebensmittel oder Barcode", text: $text)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await suche.onlineSuchen() } }
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
                LeerZustand(stimmung: .bereit, satz: "Tippe einen Namen, scanne eine Packung oder fotografiere das Etikett.")
            } else {
                ergebnisse
                onlineBereich
            }
        }
    }

    private var werkzeuge: some View {
        HStack(spacing: Abstand.s) {
            kachel("Scannen", symbol: "barcode.viewfinder") { scanOffen = true }
            kachel("Etikett", symbol: "camera.fill") { fotoOffen = true }
            kachel("Von Hand", symbol: "square.and.pencil") { pfad = [.eigenes(barcode: nil)] }
        }
    }

    private func kachel(_ titel: String, symbol: String, aktion: @escaping @MainActor () -> Void) -> some View {
        Button { aktion() } label: {
            VStack(spacing: Abstand.xs) {
                Image(systemName: symbol).font(.title3).accessibilityHidden(true)
                Text(titel).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var barcodeZeile: some View {
        Button {
            Task { await barcodeSuchen(text) }
        } label: {
            Label("Barcode \(text) nachschlagen", systemImage: "barcode.viewfinder")
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.borderedProminent)
    }

    private func barcodeSuchen(_ code: String) async {
        let ergebnis = await suche.barcode(code)
        switch ergebnis {
        case .gefunden(let l): pfad = [.detail(l)]
        case .unbekannt(let c): pfad = [.eigenes(barcode: c)]
        case .offline: barcodeFehler = "Kein Netz. Versuche es mit Netz noch einmal."
        case .limit(_, let s): barcodeFehler = "Open Food Facts erlaubt 15 Abfragen in der Minute. In etwa \(s) Sekunden geht es wieder."
        case .fehler: barcodeFehler = "Open Food Facts antwortet gerade nicht. Versuche es gleich noch einmal."
        }
    }

    @State private var barcodeFehler: String?

    @ViewBuilder
    private var ergebnisse: some View {
        let liste = suche.stand.sichtbar
        if let barcodeFehler { FehlerKarte(titel: "Barcode nicht geprüft", hilfe: barcodeFehler) }
        if liste.isEmpty {
            Text("Nichts gefunden. Du kannst bei Open Food Facts suchen oder das Lebensmittel von Hand eintragen.")
                .font(.subheadline).foregroundStyle(palette.text2)
        } else {
            ListenKarte {
                ForEach(Array(liste.enumerated()), id: \.element.id) { i, l in
                    if i > 0 { Haarlinie() }
                    Button { suche.merke(l); pfad = [.detail(l)] } label: {
                        EssenLebensmittelZeile(lebensmittel: l).padding(.horizontal, Abstand.l)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var onlineBereich: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Button { Task { await suche.onlineSuchen() } } label: {
                Label("Bei Open Food Facts suchen", systemImage: "magnifyingglass").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
            .disabled(suche.online == .laedt)
            switch suche.online {
            case .ruhig: Text("Die Suche im BLS läuft ohne Netz. Open Food Facts fragt erst, wenn du hier tippst.").font(.footnote).foregroundStyle(palette.text2)
            case .laedt: ProgressView("Ich suche …")
            case .fertig(let n): Text(n == 0 ? "Open Food Facts hat nichts Passendes." : "\(n) Treffer von Open Food Facts stehen unten in der Liste.").font(.footnote).foregroundStyle(palette.text2)
            case .limit(let s): FehlerKarte(titel: "Kurz warten", hilfe: "Open Food Facts erlaubt nur 10 Suchen in der Minute. In etwa \(s) Sekunden geht es wieder.")
            case .offline: FehlerKarte(titel: "Kein Netz", hilfe: "Die Treffer aus dem BLS bleiben stehen. Mit Netz kannst du es noch einmal versuchen.")
            case .fehler: FehlerKarte(titel: "Open Food Facts antwortet gerade nicht", hilfe: "Das liegt nicht an dir. Versuche es gleich noch einmal.")
            }
        }
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
            ListenKarte {
                ForEach(Array(liste.enumerated()), id: \.element.id) { i, l in
                    if i > 0 { Haarlinie() }
                    Button { pfad = [.detail(l)] } label: { EssenLebensmittelZeile(lebensmittel: l).padding(.horizontal, Abstand.l) }
                        .buttonStyle(.plain)
                }
            }
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
}
