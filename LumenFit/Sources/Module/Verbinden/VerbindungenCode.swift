import PhotosUI
import SwiftUI

/// Das eine Blatt "Kollegen verbinden" für beide Seiten: oben groß mein Code, darunter "Code scannen". Der Code ist ein zufälliges Token vom Server,
/// zehn Minuten gültig, nur einmal nutzbar; im Code steht kein Wert aus Health. Wer ihn scannt, schickt eine Anfrage; sie erscheint hier gleich mit
/// "Annehmen" und "Ablehnen", danach die Wahl "Wenig" oder "Alles". Erst nach dem Annehmen fließen Daten (der Server prüft das).
struct VerbindungCodeBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var einladung: EigeneEinladung?
    @State private var bild: UIImage?
    @State private var fehlgeschlagen = false
    @State private var bekannt: Set<String> = []
    @State private var offen: String?
    @State private var angenommen: String?
    @State private var scanOffen = false
    @State private var fehler: String?

    private var speicher: VerbindungenSpeicher { umgebung.konto.verbindungen }

    var body: some View {
        NavigationStack {
            VStack(spacing: Abstand.l) {
                if let angenommen {
                    VerbindungVerbundenAnsicht(id: angenommen)
                } else if let anfrage = speicher.anfragen.first(where: { $0.id == offen }) {
                    anfrageAnsicht(anfrage)
                } else {
                    codeAnsicht
                }
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity)
            .lumenHintergrund()
            .navigationTitle("Kollegen verbinden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .task { await ablauf() }
            .sheet(isPresented: $scanOffen) { VerbindungScanBlatt() }
            .alert("Das hat nicht geklappt", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(fehler ?? "") }
        }
    }

    // MARK: Mein Code

    @ViewBuilder
    private var codeAnsicht: some View {
        if let einladung, let bild {
            Image(uiImage: bild)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(Abstand.m)
                .background(Color.white, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                .frame(maxWidth: 280)
                .accessibilityLabel("QR-Code für eine Verbindung")
            TimelineView(.periodic(from: .now, by: 1)) { zeit in
                let rest = Int(einladung.laeuftAb.timeIntervalSince(zeit.date))
                if rest > 0 {
                    Text("Gültig noch \(rest / 60):\(String(format: "%02d", rest % 60))").monospacedDigit().foregroundStyle(palette.text2)
                } else {
                    VStack(spacing: Abstand.s) {
                        Text("Der Code ist abgelaufen.").foregroundStyle(palette.text2)
                        Button("Neuen Code zeigen") { Task { await erzeugen() } }.buttonStyle(.lumenHauptknopf)
                    }
                }
            }
            Text("Die andere Person scannt den Code mit der Kamera. Dann siehst du sie hier und nimmst sie an.")
                .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
        } else if fehlgeschlagen {
            FehlerKarte(titel: "Kein Code möglich", hilfe: "Die App konnte dein Konto nicht erreichen. Prüfe das Netz und versuche es nochmal.")
            Button("Nochmal") { Task { await erzeugen() } }.buttonStyle(.lumenHauptknopf)
        } else {
            ProgressView()
        }
        Button { scanOffen = true } label: { Label("Code scannen", systemImage: "qrcode.viewfinder") }
            .buttonStyle(.bordered)
            .frame(minHeight: Abstand.tippflaeche)
        if let einladung {
            ShareLink(item: VerbindungenLogik.link(token: einladung.token), message: Text("Verbinde dich mit mir in Lumen Fit. Der Link gilt 10 Minuten.")) {
                Label("Link teilen", systemImage: "link")
            }
            .frame(minHeight: Abstand.tippflaeche)
        }
    }

    // MARK: Anfrage

    private func anfrageAnsicht(_ a: VerbindungEintrag) -> some View {
        VStack(spacing: Abstand.m) {
            Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 48)).foregroundStyle(palette.text2).accessibilityHidden(true)
            Text("\(a.name) möchte sich verbinden").font(.headline).multilineTextAlignment(.center)
            Text("Erst nach Annehmen sieht die Person etwas, zuerst nur Schritte und Gym.")
                .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            Button("Annehmen") { Task { await annehmen(a.id) } }.buttonStyle(.lumenHauptknopf).frame(minHeight: Abstand.tippflaeche)
            Button("Ablehnen", role: .destructive) { Task { await ablehnen(a.id) } }.frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func annehmen(_ id: String) async {
        if await umgebung.konto.anfrageAnnehmen(id) { angenommen = id } else { fehler = "Das ließ sich nicht annehmen. Versuche es nochmal." }
    }

    private func ablehnen(_ id: String) async {
        guard await umgebung.konto.anfrageAblehnen(id) else { fehler = "Das ließ sich nicht ablehnen. Versuche es nochmal."; return }
        offen = nil
        await erzeugen()   // der Code der abgelehnten Anfrage ist verbraucht
    }

    // MARK: Ablauf

    private func erzeugen() async {
        fehlgeschlagen = false
        guard let e = await umgebung.konto.einladungErzeugen() else { einladung = nil; bild = nil; fehlgeschlagen = true; return }
        bild = FreundeQR.bild(VerbindungenLogik.link(token: e.token).absoluteString)
        einladung = e
    }

    /// Erst die Liste neu holen und merken, was schon da ist, dann den Code zeigen; danach alle drei Sekunden nachsehen. Eine neue Anfrage bleibt im Blatt.
    private func ablauf() async {
        await umgebung.konto.verbindungenNeuLaden()
        bekannt = Set(speicher.anfragen.map(\.id))
        await erzeugen()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            await umgebung.konto.verbindungenNeuLaden()
            guard angenommen == nil else { continue }
            if let id = offen, !speicher.anfragen.contains(where: { $0.id == id }) {
                offen = nil   // woanders beantwortet (Liste, anderes Gerät): zurück zum Code
                await erzeugen()
            } else if offen == nil, let neu = VerbindungenLogik.neueAnfrage(speicher.anfragen, bekannt: bekannt) {
                bekannt.insert(neu.id)
                offen = neu.id
            }
        }
    }
}

/// "Verbunden mit NAME": die Wahl "Wenig" oder "Alles" (Standard Wenig, wie es der Server setzt), ein Knopf zur Person und "Fertig".
/// Für beide Seiten, im Blatt "Kollegen verbinden" und im Scan-Blatt.
struct VerbindungVerbundenAnsicht: View {
    let id: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var stufe: FreigabeStufe = .wenig
    @State private var speichernFehler = false

    private var eintrag: VerbindungEintrag? { umgebung.konto.verbindungen.eintraege.first { $0.id == id } }

    var body: some View {
        let name = eintrag?.anzeigeName ?? "der Person"
        VStack(spacing: Abstand.m) {
            Image(systemName: "checkmark.circle").font(.system(size: 48)).foregroundStyle(palette.text2).accessibilityHidden(true)
            Text("Verbunden mit \(name)").font(.headline).multilineTextAlignment(.center)
            Text("Was soll \(name) von dir sehen?").font(.footnote).foregroundStyle(palette.text2)
            Picker("Wie viel", selection: Binding<FreigabeStufe>(get: { stufe }, set: { wahl($0) })) {
                ForEach(FreigabeStufe.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: Abstand.tippflaeche)
            Text(stufe == .wenig ? "Wenig: Schritte und Gym." : "Alles: alle Bereiche. Zyklus nie.")
                .font(.footnote).foregroundStyle(palette.text2)
            if speichernFehler {
                Text("Das ließ sich nicht speichern. Prüfe das Netz und versuche es nochmal.").font(.footnote).foregroundStyle(palette.text2)
            }
            if eintrag != nil {
                NavigationLink { VerbindungPersonView(id: id) } label: { Label("Zur Person", systemImage: "person.crop.circle") }
                    .frame(minHeight: Abstand.tippflaeche)
            }
            Button("Fertig") { dismiss() }.buttonStyle(.lumenHauptknopf).frame(minHeight: Abstand.tippflaeche)
        }
        .onAppear { if let e = eintrag, let s = FreigabeStufe.von(e.ich.zeigtBereiche) { stufe = s } }
    }

    private func wahl(_ neu: FreigabeStufe) {
        let alt = stufe
        stufe = neu
        speichernFehler = false
        let felder: [String: Any] = ["zeigt": neu.bereiche.map(\.rawValue).sorted()]
        Task {
            if !(await umgebung.konto.verbindungAendern(id, felder)) { stufe = alt; speichernFehler = true }
        }
    }
}

/// Einen Code einlesen (Kamera, Foto oder Link) und fragen, ob du dich mit dieser Person verbinden willst. Mit `token` direkt der Schritt "wer ist das?".
struct VerbindungScanBlatt: View {
    var token: String?
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var aktuell: String?
    @State private var phase: Phase = .scannen
    @State private var foto: PhotosPickerItem?
    @State private var eingabe = ""

    private enum Phase: Equatable {
        case scannen
        case pruefen
        case frage(String)
        case sendet
        case wartet(name: String, id: String)
        case verbunden(id: String)
        case abgelehnt(String)
        case fehler(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Abstand.l) {
                switch phase {
                case .scannen: scannen
                case .pruefen, .sendet: ProgressView()
                case .frage(let name): frage(name)
                case .wartet(let name, _):
                    ProgressView()
                    Text("Warte auf \(name)").font(.headline)
                    Text("\(name) muss die Anfrage annehmen. Schließt du das Blatt, erscheint die Verbindung danach in der Liste.")
                        .multilineTextAlignment(.center).foregroundStyle(palette.text2)
                    Button("Schließen") { dismiss() }.frame(minHeight: Abstand.tippflaeche)
                case .verbunden(let id):
                    VerbindungVerbundenAnsicht(id: id)
                case .abgelehnt(let name):
                    Image(systemName: "xmark.circle").font(.system(size: 48)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    Text("\(name) hat die Anfrage abgelehnt.").font(.headline).multilineTextAlignment(.center)
                    Button("Fertig") { dismiss() }.buttonStyle(.lumenHauptknopf).frame(minHeight: Abstand.tippflaeche)
                case .fehler(let text):
                    FehlerKarte(titel: "Das hat nicht geklappt", hilfe: text)
                    Button("Nochmal") { aktuell = nil; phase = .scannen }.buttonStyle(.lumenHauptknopf).frame(minHeight: Abstand.tippflaeche)
                }
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity)
            .lumenHintergrund()
            .navigationTitle("Code scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .task { if let token { await ansehen(token) } }
            .task(id: phase) { if case .wartet(let name, let id) = phase { await warte(id, name: name) } }
            .onChange(of: foto) { _, neu in if let neu { Task { await fotoLesen(neu) } } }
        }
    }

    @ViewBuilder
    private var scannen: some View {
        if EssenBarcodeKamera.verfuegbar {
            EssenBarcodeKamera(gefunden: { text in Task { await gelesen(text) } }, symbologien: [.qr])
                .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
                .frame(maxHeight: 360)
                .accessibilityLabel("Kamera zum Scannen des Codes")
        } else {
            Text("Die Kamera ist nicht verfügbar. Wähle ein Foto vom Code oder füge den Link ein.").foregroundStyle(palette.text2).multilineTextAlignment(.center)
        }
        PhotosPicker(selection: $foto, matching: .images) { Label("Foto mit Code wählen", systemImage: "photo") }
            .frame(minHeight: Abstand.tippflaeche)
        HStack {
            TextField("Link oder Code einfügen", text: $eingabe)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.go).onSubmit { Task { await gelesen(eingabe) } }
            Button("Prüfen") { Task { await gelesen(eingabe) } }.disabled(eingabe.isEmpty)
        }
        .frame(minHeight: Abstand.tippflaeche)
    }

    private func frage(_ name: String) -> some View {
        VStack(spacing: Abstand.m) {
            Image(systemName: "person.crop.circle.badge.questionmark").font(.system(size: 48)).foregroundStyle(palette.text2).accessibilityHidden(true)
            Text("Mit \(name) verbinden?").font(.headline).multilineTextAlignment(.center)
            Text("\(name) bekommt eine Anfrage und muss sie annehmen. Du zeigst zuerst nur Schritte und Gym; das änderst du danach.")
                .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            Button("Anfrage senden") { Task { await senden(name) } }.buttonStyle(.lumenHauptknopf).frame(minHeight: Abstand.tippflaeche)
            Button("Abbrechen", role: .cancel) { dismiss() }.frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func gelesen(_ text: String) async {
        guard aktuell == nil, phase == .scannen else { return }
        guard let t = VerbindungenLogik.token(aus: text) else { phase = .fehler("Das ist kein Code von Lumen Fit."); return }
        await ansehen(t)
    }

    private func ansehen(_ t: String) async {
        aktuell = t
        phase = .pruefen
        switch await umgebung.konto.einladungAnsehen(t) {
        case .person(let name): phase = .frage(name)
        case .fehler(let text): phase = .fehler(text)
        case .angefragt: phase = .fehler("Das hat nicht geklappt.")
        }
    }

    private func senden(_ name: String) async {
        guard let t = aktuell else { return }
        phase = .sendet
        switch await umgebung.konto.einladungEinloesen(t) {
        case .angefragt(let id): phase = .wartet(name: name, id: id)
        case .person: phase = .fehler("Das hat nicht geklappt.")
        case .fehler(let text): phase = .fehler(text)
        }
    }

    /// Alle drei Sekunden nachsehen (etwa vier Minuten lang): angenommen, abgelehnt oder noch offen.
    private func warte(_ id: String, name: String) async {
        var gesehen = umgebung.konto.verbindungen.eintraege.contains { $0.id == id }
        for _ in 0..<80 {
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            await umgebung.konto.verbindungenNeuLaden()
            let liste = umgebung.konto.verbindungen.eintraege
            gesehen = gesehen || liste.contains { $0.id == id }
            switch VerbindungenLogik.anfrageStand(id: id, gesehen: gesehen, in: liste) {
            case .wartet: continue
            case .verbunden: phase = .verbunden(id: id); return
            case .abgelehnt: phase = .abgelehnt(name); return
            }
        }
    }

    private func fotoLesen(_ auswahl: PhotosPickerItem) async {
        defer { foto = nil }
        guard let data = try? await auswahl.loadTransferable(type: Data.self), let bild = UIImage(data: data), let text = FreundeQR.text(in: bild) else {
            phase = .fehler("Auf dem Foto ist kein Code zu lesen. Er muss ganz und scharf drauf sein.")
            return
        }
        await gelesen(text)
    }
}
