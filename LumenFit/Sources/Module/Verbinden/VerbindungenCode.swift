import PhotosUI
import SwiftUI

/// "Freund einladen" (W-033, ab Build 19): oben groß der QR-Code, darunter klein "Stattdessen mit Code". Der QR-Code trägt die Seite des Servers
/// (`https://…/f/<Token>`): die iPhone-Kamera öffnet damit Lumen Fit, ohne App zeigt die Seite TestFlight. Er gilt zehn Minuten (vor Ort), der Code
/// 24 Stunden, beide nur einmal; in keinem steht ein Wert aus Health. Wer einen davon benutzt, ist sofort verbunden: das Blatt zeigt dann
/// "Verbunden mit NAME" und die Wahl, was die Person sieht (Standard Schritte und Gym).
struct VerbindungCodeBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var einladung: EigeneEinladung?
    @State private var bild: UIImage?
    @State private var fehlgeschlagen = false
    @State private var bekannt: Set<String> = []
    @State private var verbunden: String?
    @State private var code: EigenerCode?
    @State private var codeLaedt = false
    @State private var codeFehler = false
    @State private var kopiert = false

    private var speicher: VerbindungenSpeicher { umgebung.konto.verbindungen }

    var body: some View {
        NavigationStack {
            VStack(spacing: Abstand.l) {
                if let verbunden {
                    VerbindungVerbundenAnsicht(id: verbunden)
                } else {
                    qrAnsicht
                    codeAnsicht
                }
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity)
            .lumenHintergrund()
            .navigationTitle("Freund einladen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .task { await ablauf() }
        }
    }

    // MARK: QR-Code

    @ViewBuilder
    private var qrAnsicht: some View {
        if let einladung, let bild {
            Image(uiImage: bild)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(Abstand.m)
                .background(Color.white, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                .frame(maxWidth: 280)
                .accessibilityLabel("QR-Code zum Einladen")
            TimelineView(.periodic(from: .now, by: 1)) { zeit in
                let rest = Int(einladung.laeuftAb.timeIntervalSince(zeit.date))
                if rest > 0 {
                    Text("Gültig noch \(rest / 60):\(String(format: "%02d", rest % 60))").monospacedDigit().foregroundStyle(palette.text2)
                } else {
                    VStack(spacing: Abstand.s) {
                        Text("Der QR-Code ist abgelaufen.").foregroundStyle(palette.text2)
                        Button("Neuen QR-Code zeigen") { Task { await erzeugen() } }.buttonStyle(.lumenHauptknopf)
                    }
                }
            }
            Text("Dein Freund scannt ihn mit der iPhone-Kamera. Dann seid ihr sofort verbunden.")
                .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
        } else if fehlgeschlagen {
            FehlerKarte(titel: "Kein QR-Code möglich", hilfe: "Die App konnte dein Konto nicht erreichen. Prüfe das Netz und versuche es nochmal.")
            Button("Nochmal") { Task { await erzeugen() } }.buttonStyle(.lumenHauptknopf)
        } else {
            ProgressView()
        }
    }

    // MARK: Code

    @ViewBuilder
    private var codeAnsicht: some View {
        if let code {
            VStack(spacing: Abstand.s) {
                Text(code.code)
                    .font(.title.weight(.semibold).monospaced())
                    .foregroundStyle(palette.text)
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = code.code
                    kopiert = true
                } label: {
                    Label(kopiert ? "Kopiert" : "Code kopieren", systemImage: kopiert ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .frame(minHeight: Abstand.tippflaeche)
                .sensoryFeedback(.success, trigger: kopiert)
                Text("Gilt 24 Stunden für eine Person. Dein Freund tippt ihn in Lumen Fit unter Freunde bei \"Code eingeben\" ein.")
                    .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            }
        } else {
            Button { Task { await codeHolen() } } label: {
                if codeLaedt { ProgressView() } else { Text(codeFehler ? "Kein Netz. Nochmal mit Code versuchen" : "Stattdessen mit Code") }
            }
            .font(.footnote.weight(.semibold))
            .disabled(codeLaedt)
            .frame(minHeight: Abstand.tippflaeche)
        }
    }

    // MARK: Ablauf

    private func erzeugen() async {
        fehlgeschlagen = false
        guard let e = await umgebung.konto.einladungErzeugen() else { einladung = nil; bild = nil; fehlgeschlagen = true; return }
        let ziel = KontoZugang.lade().map { VerbindungenLogik.seite(server: $0.server, token: e.token) } ?? VerbindungenLogik.link(token: e.token)
        bild = FreundeQR.bild(ziel.absoluteString)
        einladung = e
    }

    private func codeHolen() async {
        codeLaedt = true
        code = await umgebung.konto.codeErzeugen()
        codeFehler = code == nil
        codeLaedt = false
    }

    /// Erst die Liste neu holen und merken, wer schon da ist, dann den QR-Code zeigen; danach alle drei Sekunden nachsehen. Wer über den QR-Code
    /// oder den Code dazukommt, steht gleich im Blatt.
    private func ablauf() async {
        await umgebung.konto.verbindungenNeuLaden()
        bekannt = Set(speicher.eintraege.map(\.id))
        await erzeugen()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            await umgebung.konto.verbindungenNeuLaden()
            guard verbunden == nil, let neu = VerbindungenLogik.neuePerson(speicher.eintraege, bekannt: bekannt) else { continue }
            bekannt.insert(neu.id)
            verbunden = neu.id
        }
    }
}

/// "Verbunden mit NAME": die Wahl "Wenig" oder "Alles" und darunter jeder Bereich einzeln (Standard Schritte und Gym, wie es der Server setzt),
/// ein Knopf zur Person und "Fertig". Die Liste scrollt, "Fertig" bleibt unten stehen. Für beide Seiten, im Blatt "Freund einladen" und in "Code eingeben".
struct VerbindungVerbundenAnsicht: View {
    let id: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var an: Set<VerbindungBereich> = VerbindungenLogik.standardZeigt
    @State private var speichernFehler = false

    private var eintrag: VerbindungEintrag? { umgebung.konto.verbindungen.eintraege.first { $0.id == id } }

    var body: some View {
        let name = eintrag?.anzeigeName ?? "der Person"
        VStack(spacing: Abstand.m) {
            ScrollView {
                VStack(spacing: Abstand.m) {
                    Image(systemName: "checkmark.circle").font(.system(size: 48)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    Text("Verbunden mit \(name)").font(.headline).multilineTextAlignment(.center)
                    Text("Was soll \(name) von dir sehen?").font(.footnote).foregroundStyle(palette.text2)
                    FreigabeAuswahl(an: an, einklappbar: nil) { wahl($0) }
                    if speichernFehler {
                        Text("Das ließ sich nicht speichern. Prüfe das Netz und versuche es nochmal.").font(.footnote).foregroundStyle(palette.text2)
                    }
                    if eintrag != nil {
                        NavigationLink { VerbindungPersonView(id: id) } label: { Label("Zur Person", systemImage: "person.crop.circle") }
                            .frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
            Button("Fertig") { dismiss() }.buttonStyle(.lumenHauptknopf).frame(minHeight: Abstand.tippflaeche)
        }
        .onAppear { if let e = eintrag { an = e.ich.zeigtBereiche } }
    }

    private func wahl(_ neu: Set<VerbindungBereich>) {
        let alt = an
        an = neu
        speichernFehler = false
        Task {
            if !(await umgebung.konto.verbindungAendern(id, FreigabeStufe.felder(neu))) { an = alt; speichernFehler = true }
        }
    }
}

/// "Code eingeben": zuerst das Feld für den Code eines Freundes, darunter Scannen mit der Kamera (erst auf Tipp) oder ein Foto; dann "Mit NAME verbinden?".
/// QR-Code und Code verbinden sofort, ein alter Link aus Build 18 wartet auf die Annahme. Mit `token` (Link, QR-Code mit der Kamera-App) direkt der
/// Schritt "wer ist das?".
struct VerbindungScanBlatt: View {
    var token: String?
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var aktuell: String?
    @State private var phase: Phase = .scannen
    @State private var foto: PhotosPickerItem?
    @State private var eingabe = ""
    @State private var kamera = false

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
            .navigationTitle(token == nil ? "Code eingeben" : "Verbinden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .task { if let token { await ansehen(token) } }
            .task(id: phase) { if case .wartet(let name, let id) = phase { await warte(id, name: name) } }
            .onChange(of: foto) { _, neu in if let neu { Task { await fotoLesen(neu) } } }
        }
        .nutzungAblauf(.qr, stufe: "scannen")
        .onChange(of: phase) { _, neu in nutzungStufe(neu) }
    }

    /// Zählt die Stufe des Ablaufs (nur feste Namen). Verbunden, abgelehnt und "wartet auf die andere Person" sind das Ende dieses Ablaufs; ein Abbruch ist Schließen vorher.
    private func nutzungStufe(_ phase: Phase) {
        let zaehler = umgebung.konto.nutzung
        switch phase {
        case .scannen: zaehler.ablauf(.qr, stufe: "scannen")
        case .pruefen: zaehler.ablauf(.qr, stufe: "pruefen")
        case .frage: zaehler.ablauf(.qr, stufe: "frage")
        case .sendet: zaehler.ablauf(.qr, stufe: "sendet")
        case .fehler: zaehler.ablauf(.qr, stufe: "fehler")
        case .wartet, .verbunden, .abgelehnt: zaehler.ablaufFertig(.qr)
        }
    }

    @ViewBuilder
    private var scannen: some View {
        Text("Tippe den Code ein, den dein Freund dir geschickt hat.").foregroundStyle(palette.text2).multilineTextAlignment(.center)
        TextField("K7Q2-9FX", text: $eingabe)
            .font(.title2.monospaced())
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.characters).autocorrectionDisabled()
            .submitLabel(.go).onSubmit { Task { await gelesen(eingabe) } }
            .textFieldStyle(.roundedBorder)
            .frame(minHeight: Abstand.tippflaeche)
            .accessibilityLabel("Code deines Freundes")
        Button("Weiter") { Task { await gelesen(eingabe) } }
            .buttonStyle(.lumenHauptknopf).frame(minHeight: Abstand.tippflaeche)
            .disabled(eingabe.trimmingCharacters(in: .whitespaces).isEmpty)
        if kamera {
            EssenBarcodeKamera(gefunden: { text in Task { await gelesen(text) } }, symbologien: [.qr])
                .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
                .frame(maxHeight: 300)
                .accessibilityLabel("Kamera zum Scannen des QR-Codes")
        } else if EssenBarcodeKamera.verfuegbar {
            Button { kamera = true } label: { Label("QR-Code mit der Kamera scannen", systemImage: "qrcode.viewfinder") }
                .frame(minHeight: Abstand.tippflaeche)
        }
        PhotosPicker(selection: $foto, matching: .images) { Label("Foto mit QR-Code wählen", systemImage: "photo") }
            .frame(minHeight: Abstand.tippflaeche)
    }

    private func frage(_ name: String) -> some View {
        VStack(spacing: Abstand.m) {
            Image(systemName: "person.crop.circle.badge.questionmark").font(.system(size: 48)).foregroundStyle(palette.text2).accessibilityHidden(true)
            Text("Mit \(name) verbinden?").font(.headline).multilineTextAlignment(.center)
            Text("Ihr seht euch danach gegenseitig. Du zeigst zuerst nur Schritte und Gym; das änderst du gleich danach.")
                .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            Button("Verbinden") { Task { await senden(name) } }.buttonStyle(.lumenHauptknopf).frame(minHeight: Abstand.tippflaeche)
            Button("Abbrechen", role: .cancel) { dismiss() }.frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func gelesen(_ text: String) async {
        guard aktuell == nil, phase == .scannen else { return }
        guard let t = VerbindungenLogik.einladung(aus: text) else {
            phase = .fehler("Das ist kein Code von Lumen Fit. Ein Code hat 8 Zeichen, zum Beispiel K7Q2-9FX.")
            return
        }
        await ansehen(t)
    }

    private func ansehen(_ t: String) async {
        aktuell = t
        phase = .pruefen
        switch await umgebung.konto.einladungAnsehen(t) {
        case .person(let name): phase = .frage(name)
        case .fehler(let text): phase = .fehler(text)
        case .angefragt, .verbunden: phase = .fehler("Das hat nicht geklappt.")
        }
    }

    private func senden(_ name: String) async {
        guard let t = aktuell else { return }
        phase = .sendet
        switch await umgebung.konto.einladungEinloesen(t) {
        case .angefragt(let id): phase = .wartet(name: name, id: id)
        case .verbunden(let id): phase = .verbunden(id: id)
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
