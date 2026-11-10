// Quelle: Lovea Health/Ernaehrung/KiFoto.swift (KiFotoBlatt; die Oberfläche ist neu im Lumen-Design)
import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

/// Kamera oder Fotoauswahl -> KI-Schätzung -> prüfen und anpassen -> ins Tagebuch. Die Kamera geht sofort auf. Die Schätzung läuft im
/// `EssenKiAuftragStore`, nicht in diesem Blatt: Schließt jemand es, läuft sie weiter, und das Ergebnis wartet in Essen.
/// Nichts wird eingetragen, bevor es bestätigt ist.
struct EssenKiFotoBlatt: View {
    let datum: String
    /// Name der Mahlzeit für die Bestätigung.
    let fertig: @MainActor (String) -> Void
    /// "Von Hand eintragen": das Blatt geht zu, der Aufrufer zeigt die Handeingabe.
    let vonHand: @MainActor () -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bewegungAus) private var bewegungAus

    private enum Phase: Equatable {
        case start, laedt, ergebnis
        case keinEssen(String)
        case fehler(EssenKiAnzeige)
    }

    @State private var kameraOffen = false
    /// Zustimmung ansehen oder zurücknehmen (Hand-Symbol oben rechts).
    @State private var zustimmungOffen = false
    /// Die erste Kamera geht von selbst auf; bricht man sie ab, ist man schon fertig.
    @State private var autoKamera: Bool
    @State private var gesperrt = EssenKiFotoBlatt.kameraGesperrt
    @State private var auswahl: PhotosPickerItem?
    /// Der Auftrag im Store; nil, solange noch kein Foto da ist.
    @State private var auftragId: UUID?
    /// Das Foto aus der Bibliothek wird gelesen (einen Auftrag gibt es erst danach).
    @State private var liest = false
    @State private var leseAufgabe: Task<Void, Never>?
    @State private var fotoFehler = false
    @State private var vorschau: UIImage?
    /// Die Schätzung, die in `komponenten` und Co. steht. Die Gramm gehören diesem Blatt, nicht dem Store.
    @State private var geladen: EssenKiAnalyse?
    @State private var komponenten: [EssenKiKomponente] = []
    @State private var urspruenglich: [UUID: Double] = [:]
    @State private var entfernt: Set<UUID> = []
    @State private var versteckt: [EssenKiVersteckt] = []
    @State private var versteckteZaehlen = true
    @State private var mahlzeitWahl: Mahlzeit
    @State private var antwort = ""
    @State private var verwerfenFrage = false
    @State private var speichert = false
    @State private var fehlerZaehler = 0
    @State private var geschaetzt = 0

    /// Neues Foto: Kamera und Auswahl.
    init(mahlzeit: Mahlzeit, datum: String, fertig: @escaping @MainActor (String) -> Void, vonHand: @escaping @MainActor () -> Void = {}) {
        self.datum = datum
        self.fertig = fertig
        self.vonHand = vonHand
        _mahlzeitWahl = State(initialValue: mahlzeit)
        _autoKamera = State(initialValue: Self.kameraVorhanden && !Self.kameraGesperrt)
    }

    /// Eine Analyse aus Essen öffnen: prüfen und übernehmen, nochmal oder von Hand. Alles steht schon da, damit beim Öffnen kein Ladebild aufblitzt.
    init(auftrag: EssenKiAuftrag, fertig: @escaping @MainActor (String) -> Void, vonHand: @escaping @MainActor () -> Void = {}) {
        self.datum = auftrag.datum
        self.fertig = fertig
        self.vonHand = vonHand
        _auftragId = State(initialValue: auftrag.id)
        _mahlzeitWahl = State(initialValue: auftrag.mahlzeit)
        _autoKamera = State(initialValue: false)
        _geladen = State(initialValue: auftrag.analyse)
        if let a = auftrag.analyse, !EssenKiFotoLogik.keinEssen(a) {
            let w = Self.werte(a)
            _komponenten = State(initialValue: w.komponenten)
            _urspruenglich = State(initialValue: w.urspruenglich)
            _versteckt = State(initialValue: w.versteckt)
        }
    }

    private static var kameraVorhanden: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private static var kameraGesperrt: Bool {
        let s = AVCaptureDevice.authorizationStatus(for: .video)
        return s == .denied || s == .restricted
    }

    private static func werte(_ a: EssenKiAnalyse) -> (komponenten: [EssenKiKomponente], urspruenglich: [UUID: Double], versteckt: [EssenKiVersteckt]) {
        let k = a.komponenten
        return (k, Dictionary(uniqueKeysWithValues: k.map { ($0.id, $0.gramm) }), a.versteckteListe)
    }

    private var store: EssenKiAuftragStore? { EssenKiModul.store(umgebung) }
    private var anim: Animation? { bewegungAus ? nil : Feder.weich }
    private func mahlzeitName(_ m: Mahlzeit) -> String { umgebung.daten?.essen.mahlzeitName(m) ?? m.name }

    private var auftrag: EssenKiAuftrag? { auftragId.flatMap { store?.auftrag($0) } }

    /// Was gezeigt wird, folgt dem Auftrag im Store. Die Schätzung erscheint erst, wenn ihre Zutaten geladen sind.
    private var phase: Phase {
        if speichert { return .ergebnis }
        guard let a = auftrag else {
            if fotoFehler { return .fehler(EssenKiFotoLogik.fotoUnlesbar) }
            return liest ? .laedt : .start
        }
        switch a.status {
        case .laeuft:
            return .laedt
        case .fertig:
            guard let schaetzung = a.analyse else { return .laedt }
            if EssenKiFotoLogik.keinEssen(schaetzung) { return .keinEssen(EssenKiFotoLogik.keinEssenText(schaetzung)) }
            return geladen == schaetzung ? .ergebnis : .laedt
        case .fehler, .unterbrochen:
            return .fehler(EssenKiAuftragLogik.anzeige(a) ?? EssenKiFotoLogik.fotoUnlesbar)
        }
    }

    private var aktive: [EssenKiKomponente] { komponenten.filter { !entfernt.contains($0.id) } }
    private var versteckteKcal: Int { versteckt.reduce(0) { $0 + $1.kcal } }
    private var liste: [EssenEintrag] {
        EssenKiFotoLogik.eintraege(komponenten: aktive, versteckt: versteckt, versteckteZaehlen: versteckteZaehlen, mahlzeit: mahlzeitWahl, datum: datum)
    }
    /// Unverändert gegenüber der Schätzung: dann gilt der Bereich der KI noch.
    private var unveraendert: Bool {
        entfernt.isEmpty && komponenten.allSatisfy { k in urspruenglich[k.id].map { abs($0 - k.gramm) < 1 } ?? false }
    }

    var body: some View {
        NavigationStack {
            inhalt
                .animation(anim, value: phase)
                .navigationTitle("Essen fotografieren")
                .navigationBarTitleDisplayMode(.inline)
                .lumenHintergrund()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if auftragId == nil {
                            Button("Abbrechen") { leseAufgabe?.cancel(); dismiss() }
                        } else {
                            Button("Schließen") { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { zustimmungOffen = true } label: { Image(systemName: "hand.raised") }
                            .accessibilityLabel("Zustimmung zur Foto-Schätzung")
                            .disabled(store == nil)
                    }
                }
        }
        .confirmationDialog("Schätzung verwerfen?", isPresented: $verwerfenFrage, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) { verwerfen() }
            Button("Weiter prüfen", role: .cancel) {}
        } message: {
            Text("Das Foto zählt schon für heute.")
        }
        .sheet(isPresented: $zustimmungOffen) {
            if let store { EssenKiZustimmungBlatt(store: store) }
        }
        .fullScreenCover(isPresented: $kameraOffen) {
            EssenKamera { daten in kameraFertig(daten) }.ignoresSafeArea()
        }
        .haptik(.warnung, bei: fehlerZaehler)
        .haptik(.erfolg, bei: geschaetzt)
        .task {
            // Erst nach dem Aufklappen des Blatts: ein Cover im selben Frame wird von SwiftUI manchmal verschluckt.
            guard autoKamera, store?.zustimmung.erlaubt == true else { return }
            try? await Task.sleep(for: .milliseconds(350))
            if autoKamera, !Task.isCancelled { kameraOffen = true }
        }
        .task(id: auftragId) { await vorschauVonPlatte() }
        .onChange(of: auswahl) { _, neu in fotoGewaehlt(neu) }
        .onChange(of: scenePhase) { _, neu in if neu == .active { gesperrt = Self.kameraGesperrt } }
        .onChange(of: auftrag?.analyse, initial: true) { alt, neu in ergebnisUebernehmen(neu, meldet: alt != neu) }
        .onChange(of: auftrag?.status) { alt, neu in
            if alt == .laeuft, neu == .fehler || neu == .unterbrochen { fehlerZaehler += 1 }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch phase {
        case .start: startAnsicht
        case .laedt: ladeAnsicht
        case .ergebnis: ergebnisAnsicht
        case .keinEssen(let text):
            meldung(symbol: "fork.knife", titel: "Kein Essen erkannt", text: text) {
                Button("Anderes Foto") { neuesFoto() }.buttonStyle(.lumenHauptknopf)
                Button("Von Hand eintragen") { vonHandEintragen() }.buttonStyle(.bordered)
            }
        case .fehler(let a):
            meldung(symbol: a.symbol, titel: a.titel, text: a.text) { fehlerKnoepfe(a) }
        }
    }

    // MARK: - Bildschirme

    private var startAnsicht: some View {
        ScrollView {
            VStack(spacing: Abstand.xl) {
                LeerZustand(stimmung: .bereit, satz: gesperrt
                    ? "Lumen Fit darf die Kamera nicht nutzen. Du kannst es in den Einstellungen erlauben oder ein Foto aus deiner Bibliothek wählen."
                    : "Fotografier dein Essen von oben. Die KI schätzt Zutaten und Kalorien, du prüfst und passt an.")
                VStack(spacing: Abstand.m) {
                    if gesperrt {
                        Button { einstellungenOeffnen() } label: { Text("Einstellungen öffnen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                            .buttonStyle(.lumenHauptknopf)
                    } else if Self.kameraVorhanden {
                        Button { kameraOffen = true } label: { Label("Foto aufnehmen", systemImage: "camera.fill").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                            .buttonStyle(.lumenHauptknopf)
                    }
                    PhotosPicker(selection: $auswahl, matching: .images) {
                        Label("Aus Fotos wählen", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                    Button("Von Hand eintragen") { vonHandEintragen() }
                        .frame(minHeight: Abstand.tippflaeche)
                }
                Text("Das Foto wird verkleinert und ohne Ort und Zeit an den Lumen-Server und von dort zur Auswertung an OpenAI geschickt. Gespeichert wird nur auf diesem Gerät.")
                    .font(.footnote)
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.center)
            }
            .padding(Abstand.l)
        }
    }

    private var ladeAnsicht: some View {
        ScrollView {
            VStack(spacing: Abstand.xl) {
                if let vorschau {
                    Image(uiImage: vorschau)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
                        .accessibilityHidden(true)
                }
                if let a = auftrag {
                    EssenKiSchritte(seit: a.gestartet)
                    Text("Du kannst den Bildschirm verlassen, es läuft weiter.")
                        .font(.footnote)
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.center)
                    VStack(spacing: Abstand.m) {
                        Button { dismiss() } label: { Text("Im Hintergrund weiter").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                            .buttonStyle(.lumenHauptknopf)
                        Button(a.analyse == nil ? "Analyse abbrechen" : "Neu schätzen abbrechen", role: .destructive) { analyseAbbrechen() }
                            .frame(minHeight: Abstand.tippflaeche)
                    }
                } else {
                    ProgressView("Foto wird geladen …")
                }
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity)
        }
    }

    private func meldung<Knoepfe: View>(symbol: String, titel: String, text: String, @ViewBuilder knoepfe: () -> Knoepfe) -> some View {
        VStack(spacing: Abstand.l) {
            Spacer()
            Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(palette.text2).accessibilityHidden(true)
            Text(titel).font(.title2.bold()).foregroundStyle(palette.text)
            Text(text).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            VStack(spacing: Abstand.m) { knoepfe() }.padding(.top, Abstand.s)
            Spacer()
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func fehlerKnoepfe(_ a: EssenKiAnzeige) -> some View {
        if a.nochmal { Button("Nochmal versuchen") { nochmal() }.buttonStyle(.lumenHauptknopf) }
        if a.neuesFoto {
            if a.nochmal {
                Button("Anderes Foto") { neuesFoto() }.buttonStyle(.bordered)
            } else {
                Button("Anderes Foto") { neuesFoto() }.buttonStyle(.lumenHauptknopf)
            }
        }
        Button("Von Hand eintragen") { vonHandEintragen() }.buttonStyle(.bordered)
    }

    private var ergebnisAnsicht: some View {
        let eintraege = liste
        let gesamt = EssenKiFotoLogik.kcal(eintraege)
        return ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                kopf(summe: ErnaehrungLogik.summe(eintraege), kcal: gesamt)
                zutatenKarte
                if !entfernt.isEmpty { entferntKarte }
                if !versteckt.isEmpty { versteckteKarte }
                if let frage = geladen?.frage, !frage.isEmpty { frageKarte(frage) }
                mahlzeitKarte
                Button("Analyse verwerfen", role: .destructive) { verwerfenFrage = true }
                    .frame(minHeight: Abstand.tippflaeche)
                Text("Mit Schließen bleibt die Analyse in Essen, bis du sie übernimmst oder verwirfst.")
                    .font(.footnote)
                    .foregroundStyle(palette.text2)
            }
            .padding(Abstand.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { EssenTastatur.schliessen() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { eintragen() } label: {
                Text(eintraege.isEmpty ? "Nichts zum Eintragen" : "\(ErnaehrungLogik.zahl(Double(gesamt))) kcal eintragen")
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.lumenHauptknopf)
            .disabled(eintraege.isEmpty || speichert)
            .padding(.horizontal, Abstand.l).padding(.vertical, Abstand.m)
            .lumenLeiste()
        }
    }

    private func kopf(summe: Naehrwerte, kcal: Int) -> some View {
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                if let vorschau {
                    Image(uiImage: vorschau)
                        .resizable().scaledToFill()
                        .frame(height: 140)
                        .clipShape(.rect(cornerRadius: Rundung.klein, style: .continuous))
                        .accessibilityHidden(true)
                }
                Text("ca. \(ErnaehrungLogik.zahl(Double(kcal))) kcal")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
                    .animation(anim, value: kcal)
                if unveraendert, let a = geladen,
                   let b = EssenKiFotoLogik.bereich(a.gesamt, versteckteKcal: versteckteKcal, gezaehlt: versteckteZaehlen) {
                    Text("wahrscheinlich zwischen \(b.lowerBound) und \(b.upperBound)").font(.footnote)
                }
                Text("Eiweiß \(ErnaehrungLogik.zahl(summe.protein)) g · Kohlenhydrate \(ErnaehrungLogik.zahl(summe.kohlenhydrate)) g · Fett \(ErnaehrungLogik.zahl(summe.fett)) g")
                    .font(.caption)
                if let b = geladen?.bemerkung, !b.isEmpty { Text(b).font(.caption) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var zutatenKarte: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Erkannt").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            ListenKarte {
                ForEach($komponenten) { $k in
                    if !entfernt.contains(k.id) {
                        EssenKiZutatZeile(zutat: $k) { entfernen(k.id) }
                        Haarlinie()
                    }
                }
                if aktive.isEmpty {
                    Text("Alles entfernt. Hol unten etwas zurück oder brich ab.").foregroundStyle(palette.text2).padding(Abstand.l)
                }
            }
        }
    }

    private var entferntKarte: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Entfernt").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            ListenKarte {
                ForEach(komponenten.filter { entfernt.contains($0.id) }) { k in
                    HStack {
                        Text(k.name).foregroundStyle(palette.text2)
                        Spacer()
                        Button("Zurück") { zurueckholen(k.id) }
                            .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
                            .accessibilityLabel("\(k.name) zurückholen")
                    }
                    .padding(.horizontal, Abstand.l)
                    Haarlinie()
                }
            }
        }
    }

    private var versteckteKarte: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ListenKarte {
                Toggle(isOn: $versteckteZaehlen) {
                    VStack(alignment: .leading, spacing: Abstand.xs) {
                        Text("Nicht Sichtbares mitzählen").foregroundStyle(palette.text)
                        Text(versteckt.map { "\($0.name) \(ErnaehrungLogik.zahl($0.gramm)) g" }.joined(separator: ", ") + " · \(versteckteKcal) kcal")
                            .font(.caption).foregroundStyle(palette.text2)
                    }
                }
                .padding(Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
            }
            Text("Öl, Butter oder Soße sieht man auf dem Foto nicht. Schalte aus, wenn bei dir nichts davon drin ist.")
                .font(.footnote).foregroundStyle(palette.text2)
        }
    }

    private func frageKarte(_ frage: String) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Label("Rückfrage der KI", systemImage: "questionmark.bubble").font(.headline).foregroundStyle(palette.text)
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    Text(frage).foregroundStyle(palette.text)
                    TextField("Deine Antwort", text: $antwort).submitLabel(.done).frame(minHeight: Abstand.tippflaeche)
                    Button("Neu schätzen") { neuSchaetzen(frage: frage) }
                        .disabled(antwort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .frame(minHeight: Abstand.tippflaeche)
                    if let f = auftrag?.neuFehler { Text(f).font(.footnote).foregroundStyle(palette.text2) }
                }
                .padding(Abstand.l)
            }
            Text("Zählt als weiteres Foto. Deine Änderungen an den Gramm gehen dabei verloren.").font(.footnote).foregroundStyle(palette.text2)
        }
    }

    private var mahlzeitKarte: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ListenKarte {
                Picker("Eintragen bei", selection: $mahlzeitWahl) {
                    ForEach(Mahlzeit.allCases) { Text(mahlzeitName($0)).tag($0) }
                }
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
            }
            if let rest = EssenKiFotoLogik.restText(geladen?.rest) {
                Text(rest).font(.footnote).foregroundStyle(palette.text2)
            }
        }
    }

    // MARK: - Ablauf

    private func einstellungenOeffnen() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    private func kameraFertig(_ daten: Data?) {
        kameraOffen = false
        gesperrt = Self.kameraGesperrt
        let auto = autoKamera
        autoKamera = false
        guard let daten else {
            // Erste Kamera abgebrochen: zurück. Gesperrt: die Erklärung zeigen.
            if auto, !gesperrt { dismiss() }
            return
        }
        starten(daten)
    }

    /// Nicht an dieses Blatt gebunden: ein Foto, das ausgewählt wurde, wird auch dann analysiert, wenn das Blatt zugeht, bevor es gelesen ist.
    /// Nur "Abbrechen" stoppt das Lesen.
    private func fotoGewaehlt(_ item: PhotosPickerItem?) {
        guard let item else { return }
        auswahl = nil
        liest = true
        fotoFehler = false
        leseAufgabe = Task {
            let gelesen = try? await item.loadTransferable(type: Data.self)
            liest = false
            guard !Task.isCancelled else { return }
            guard let daten = gelesen else {
                fehlerZaehler += 1
                fotoFehler = true
                return
            }
            starten(daten)
        }
    }

    /// Foto an den Store übergeben. Er verkleinert (Dateigröße, kein Ort und keine Zeit), speichert und schätzt.
    private func starten(_ roh: Data) {
        fotoFehler = false
        vorschauSetzen(roh)
        auftragId = store?.neu(foto: roh, mahlzeit: mahlzeitWahl, datum: datum)
    }

    /// Kleine Vorschau aus dem Rohfoto; das verkleinerte Foto liegt erst etwas später im Store.
    private func vorschauSetzen(_ roh: Data) {
        Task {
            let klein = await Task.detached(priority: .userInitiated) { EssenKiBild.verkleinern(roh, maxKante: 640) }.value
            vorschau = klein.flatMap { UIImage(data: $0) }
        }
    }

    /// Aus Essen geöffnet: das Foto liegt schon auf der Platte.
    private func vorschauVonPlatte() async {
        guard vorschau == nil, let id = auftragId, let url = store?.bildURL(id) else { return }
        let daten = await Task.detached { try? Data(contentsOf: url) }.value
        if vorschau == nil { vorschau = daten.flatMap { UIImage(data: $0) } }
    }

    /// Eine neue Schätzung ist da: Zutaten, Gramm und Rückfrage frisch aufbauen.
    private func ergebnisUebernehmen(_ a: EssenKiAnalyse?, meldet: Bool) {
        guard let a else { geladen = nil; return }
        guard a != geladen else { return }
        geladen = a
        guard !EssenKiFotoLogik.keinEssen(a) else {
            if meldet { fehlerZaehler += 1 }
            return
        }
        let w = Self.werte(a)
        komponenten = w.komponenten
        urspruenglich = w.urspruenglich
        versteckt = w.versteckt
        entfernt = []
        versteckteZaehlen = true
        antwort = ""
        if meldet { geschaetzt += 1 }
    }

    /// Abbrechen, solange es läuft: mit früherer Schätzung zurück zu ihr, sonst ist der Auftrag weg.
    private func analyseAbbrechen() {
        guard let id = auftragId else { return }
        store?.abbrechen(id)
        if store?.auftrag(id) == nil {
            auftragId = nil
            vorschau = nil
            geladen = nil
        }
    }

    private func nochmal() {
        guard let id = auftragId else { return }
        store?.nochmal(id)
    }

    private func neuSchaetzen(frage: String) {
        guard let id = auftragId else { return }
        store?.nochmal(id, hinweis: EssenKiFotoLogik.hinweis(frage: frage, antwort: antwort))
    }

    private func neuesFoto() {
        if let id = auftragId { store?.entfernen(id) }
        auftragId = nil
        vorschau = nil
        geladen = nil
        komponenten = []
        fotoFehler = false
        gesperrt = Self.kameraGesperrt
        if Self.kameraVorhanden, !gesperrt { kameraOffen = true }
    }

    /// Kein Essen auf dem Foto oder von Hand gewünscht: die Analyse ist nutzlos, also weg, dann von Hand.
    private func vonHandEintragen() {
        if let id = auftragId { store?.entfernen(id) }
        dismiss()
        vonHand()
    }

    private func verwerfen() {
        speichert = true
        if let id = auftragId { store?.entfernen(id) }
        dismiss()
    }

    private func entfernen(_ id: UUID) {
        withAnimation(anim) { _ = entfernt.insert(id) }
    }

    private func zurueckholen(_ id: UUID) {
        withAnimation(anim) { _ = entfernt.remove(id) }
    }

    private func eintragen() {
        guard !speichert, let essen = umgebung.daten?.essen else { return }
        let neu = liste
        guard !neu.isEmpty else { return }
        speichert = true
        for e in neu {
            essen.eintragen(e.lebensmittel, menge: e.menge, einheit: e.einheit, mahlzeit: e.mahlzeit, datum: e.datum, id: e.id)
        }
        let name = EssenKiFotoLogik.titel(aktive)
        // Erst jetzt, nach dem Eintragen, ist die Analyse erledigt.
        if let id = auftragId { store?.entfernen(id) }
        dismiss()
        fertig(name)
    }
}

/// Eine erkannte Zutat: Name, kcal, Sicherheit als Wort und Symbol, Gramm per Zahlenfeld und Schritt, Entfernen.
private struct EssenKiZutatZeile: View {
    @Binding var zutat: EssenKiKomponente
    let entfernen: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        let s = EssenKiFotoLogik.sicherheit(zutat.sicherheit)
        VStack(alignment: .leading, spacing: Abstand.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(zutat.name).font(.headline).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.s)
                Text("\(zutat.kcal) kcal").font(.subheadline.monospacedDigit()).foregroundStyle(palette.text2)
            }
            Pille(text: s.text, symbolName: s.symbol)
            HStack(spacing: Abstand.s) {
                EssenKiGrammFeld(gramm: $zutat.gramm)
                Text("g").foregroundStyle(palette.text2)
                Stepper("Gramm \(zutat.name)", value: $zutat.gramm, in: 0...EssenKiFotoLogik.maxGramm, step: 5).labelsHidden()
                Spacer(minLength: Abstand.s)
                Button(role: .destructive) { entfernen() } label: {
                    Image(systemName: "trash").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .accessibilityLabel("\(zutat.name) entfernen")
            }
        }
        .padding(Abstand.l)
        .accessibilityElement(children: .contain)
    }
}

/// Gramm per Zahlentastatur. Leer heißt 0 g (die Zutat zählt dann nicht); über 5000 g wird gekappt.
private struct EssenKiGrammFeld: View {
    @Binding var gramm: Double
    @State private var text = ""
    @Environment(\.palette) private var palette

    var body: some View {
        TextField("g", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 56, maxWidth: 80, minHeight: Abstand.tippflaeche)
            .padding(.horizontal, Abstand.m)
            .background(palette.grund, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
            .accessibilityLabel("Gramm")
            .onAppear { text = ErnaehrungLogik.zahl(gramm) }
            .onChange(of: text) { _, neu in
                let x = min(ErnaehrungLogik.eingabe(neu) ?? 0, EssenKiFotoLogik.maxGramm)
                if x != gramm { gramm = x }
            }
            .onChange(of: gramm) { _, neu in
                if (ErnaehrungLogik.eingabe(text) ?? 0) != neu { text = ErnaehrungLogik.zahl(neu) }
            }
    }
}
