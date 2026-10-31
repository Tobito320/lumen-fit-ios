import PhotosUI
import SwiftUI

/// Mein Code: ein QR-Code mit zufälligem Token vom Server. Zehn Minuten gültig, nur einmal nutzbar; im Code steht kein Wert aus Health.
/// Wer ihn scannt, schickt eine Anfrage; erst wenn du sie annimmst, fließen Daten.
struct VerbindungCodeBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var einladung: EigeneEinladung?
    @State private var bild: UIImage?
    @State private var fehlgeschlagen = false
    @State private var anfragenAnfang = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: Abstand.l) {
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
                                Button("Neuen Code zeigen") { Task { await erzeugen() } }.buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    Text("Die andere Person scannt den Code in Lumen Fit unter Verbindungen. Danach musst du sie annehmen.")
                        .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
                    ShareLink(item: VerbindungenLogik.link(token: einladung.token), message: Text("Verbinde dich mit mir in Lumen Fit. Der Link gilt 10 Minuten.")) {
                        Label("Link teilen", systemImage: "link")
                    }
                    .frame(minHeight: Abstand.tippflaeche)
                } else if fehlgeschlagen {
                    FehlerKarte(titel: "Kein Code möglich", hilfe: "Prüfe das Netz und versuche es nochmal.")
                    Button("Nochmal") { Task { await erzeugen() } }.buttonStyle(.borderedProminent)
                } else {
                    ProgressView().task { await erzeugen() }
                }
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity)
            .lumenHintergrund()
            .navigationTitle("Mein Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .task { await warteAufAnfrage() }
        }
    }

    private func erzeugen() async {
        fehlgeschlagen = false
        guard let e = await umgebung.konto.einladungErzeugen() else { einladung = nil; bild = nil; fehlgeschlagen = true; return }
        bild = FreundeQR.bild(VerbindungenLogik.link(token: e.token).absoluteString)
        einladung = e
    }

    /// Solange das Blatt offen ist, alle fünf Sekunden nachsehen. Kommt eine Anfrage, schließt es; sie steht dann oben in der Liste.
    private func warteAufAnfrage() async {
        anfragenAnfang = umgebung.konto.verbindungen.anfragen.count
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { return }
            await umgebung.konto.verbindungenNeuLaden()
            if umgebung.konto.verbindungen.anfragen.count > anfragenAnfang { dismiss(); return }
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
        case fertig(String)
        case fehler(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Abstand.l) {
                switch phase {
                case .scannen: scannen
                case .pruefen, .sendet: ProgressView()
                case .frage(let name): frage(name)
                case .fertig(let name):
                    Image(systemName: "checkmark.circle").font(.system(size: 48)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    Text("Anfrage gesendet").font(.headline)
                    Text("\(name) muss sie annehmen. Erst dann siehst du etwas.").multilineTextAlignment(.center).foregroundStyle(palette.text2)
                    Button("Fertig") { dismiss() }.buttonStyle(.borderedProminent).frame(minHeight: Abstand.tippflaeche)
                case .fehler(let text):
                    FehlerKarte(titel: "Das hat nicht geklappt", hilfe: text)
                    Button("Nochmal") { aktuell = nil; phase = .scannen }.buttonStyle(.borderedProminent).frame(minHeight: Abstand.tippflaeche)
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
            Text("\(name) bekommt eine Anfrage und muss sie annehmen. Du zeigst zuerst nur Schritte und Gym; das änderst du danach unter Verbindungen.")
                .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            Button("Anfrage senden") { Task { await senden(name) } }.buttonStyle(.borderedProminent).frame(minHeight: Abstand.tippflaeche)
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
        case .fertig: phase = .fehler("Das hat nicht geklappt.")
        }
    }

    private func senden(_ name: String) async {
        guard let t = aktuell else { return }
        phase = .sendet
        switch await umgebung.konto.einladungEinloesen(t) {
        case .fertig, .person: phase = .fertig(name)
        case .fehler(let text): phase = .fehler(text)
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
