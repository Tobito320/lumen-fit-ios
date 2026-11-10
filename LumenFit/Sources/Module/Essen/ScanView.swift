// Quelle: Lovea Health/Ernaehrung/BarcodeScanner.swift (Kamera und Ablauf; die Oberfläche ist neu im Lumen-Design)
import SwiftUI
import Vision
import VisionKit

/// Wohin ein Blatt im Essen-Bereich als Nächstes führt: ein Lebensmittel (Detail oder gespeichertes Gericht) oder die Eingabe von Hand.
enum EssenZiel: Hashable {
    case detail(Lebensmittel)
    case eigenes(barcode: String?)
}

/// Baut die Seite zu einem `EssenZiel`. `fertig(true)` schließt das ganze Blatt nach dem Eintragen.
struct EssenZielAnsicht: View {
    let ziel: EssenZiel
    let mahlzeit: Mahlzeit
    let tag: String
    /// Werte vom Etikett-Foto für die Eingabe von Hand.
    var vorlage: Naehrwerte?
    let fertig: @MainActor (Bool) -> Void
    /// Nach dem Anlegen von Hand geht es zur Detailseite des neuen Lebensmittels.
    let weiter: @MainActor (EssenZiel) -> Void
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        switch ziel {
        case .detail(let l):
            if let gericht = umgebung.daten?.essen.mahlzeitVorlage(l.id) {
                EssenGerichtView(vorlage: gericht, mahlzeit: mahlzeit, tag: tag, fertig: fertig)
            } else {
                EssenDetailView(lebensmittel: l, mahlzeit: mahlzeit, tag: tag, fertig: fertig)
            }
        case .eigenes(let code):
            EssenEigenesView(barcode: code, vorlage: vorlage, hinweis: hinweis(code)) { l in weiter(.detail(l)) }
        }
    }

    private func hinweis(_ code: String?) -> String? {
        if code != nil { return "Diesen Code kennt Open Food Facts nicht. Trag die Werte von der Packung ein oder fotografiere die Nährwerttabelle." }
        return vorlage == nil ? nil : "Prüfe die Zahlen, bevor du speicherst. Name und Marke fehlen noch."
    }
}

/// Barcode scannen (Idee 41): Kamera erkennt den Code, Treffer aus Speicher, BLS, dann Open Food Facts; unbekannt führt zur Eingabe von Hand.
/// Ohne Kamera (Simulator, keine Erlaubnis) bleibt die Eingabe des Codes. In Debug-Läufen mit `-lumenFitFixtures` sucht der Scan selbst den Fixture-Code,
/// damit CI-Bilder ohne Kamera entstehen.
struct ScanView: View {
    var mahlzeit: Mahlzeit = .snack
    var tag: String = ""
    var fertig: @MainActor (Bool) -> Void = { _ in }

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var pfad: [EssenZiel] = []
    @State private var code = ""
    @State private var zustand: Zustand = .bereit
    @State private var kameraNummer = 0
    /// Unbekannter Code, zu dem eine Namensquelle Vorschläge kennt ("Meintest du ...?"); heute leer, weil Lumen keine Namensquelle hat.
    @State private var vorschlaege: (name: String, liste: [Lebensmittel], code: String)?
    /// Was nach dem Vorschlags-Blatt geöffnet wird; erst beim Schließen, damit Blatt und Seite nicht gleichzeitig wechseln.
    @State private var vorschlagsZiel: EssenZiel?

    private enum Zustand: Equatable {
        case bereit, sucht
        case offline(String)
        case limit(String, Int)
        case fehler(String)
    }

    private var kannScannen: Bool { EssenBarcodeKamera.verfuegbar }
    private var tagText: String { tag.isEmpty ? Datum.text(umgebung.uhr()) : tag }

    var body: some View {
        NavigationStack(path: $pfad) {
            VStack(spacing: Abstand.l) {
                if kannScannen {
                    kamera
                } else {
                    LeerZustand(stimmung: .bereit, satz: "Die Kamera ist nicht verfügbar. Tippe den Code von der Packung ein, dann suche ich ihn.")
                    Button("Zu den Einstellungen") { einstellungenOeffnen() }.buttonStyle(.bordered).frame(minHeight: Abstand.tippflaeche)
                }
                meldung
                Spacer(minLength: 0)
                eingabe
            }
            .padding(Abstand.l)
            .navigationTitle("Scannen")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { fertig(false) } } }
            .navigationDestination(for: EssenZiel.self) { ziel in
                EssenZielAnsicht(ziel: ziel, mahlzeit: mahlzeit, tag: tagText, fertig: fertig) { pfad = [$0] }
            }
            .task { await debugFixtureScan() }
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
        }
    }

    /// Der gewählte Vorschlag wird als eigenes Lebensmittel mit dem gescannten Code gespeichert, damit der nächste Scan es auch ohne Netz findet.
    private func vorschlagWaehlen(_ l: Lebensmittel, code: String) {
        let eigenes = EssenMehrtrefferLogik.alsEigenes(l, code: code)
        umgebung.daten?.essen.eigenesSichern(eigenes)
        vorschlagsZiel = .detail(eigenes)
    }

    private var kamera: some View {
        ZStack {
            EssenBarcodeKamera { code in Task { await suchen(code) } }.id(kameraNummer)
            RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(.white, lineWidth: 3).frame(width: 260, height: 150).accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            Text("Barcode in den Rahmen halten")
                .font(.footnote.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, Abstand.m).padding(.vertical, Abstand.s)
                .background(.black.opacity(0.6), in: .capsule)
                .padding(.bottom, Abstand.l)
        }
        .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
        .aspectRatio(3 / 4, contentMode: .fit)
        .accessibilityLabel("Kamera für den Barcode")
    }

    private var eingabe: some View {
        VStack(spacing: Abstand.s) {
            TextField("Code eintippen", text: $code)
                .keyboardType(.numberPad)
                .padding(Abstand.m)
                .frame(minHeight: Abstand.tippflaeche)
                .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                .accessibilityLabel("Barcode eintippen")
            Button { Task { await suchen(code) } } label: {
                Text("Suchen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.lumenHauptknopf)
            .disabled(!BarcodeLogik.istBarcodeEingabe(BarcodeLogik.normal(code)) || zustand == .sucht)
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { EssenTastatur.schliessen() } } }
    }

    @ViewBuilder
    private var meldung: some View {
        switch zustand {
        case .bereit: EmptyView()
        case .sucht: ProgressView("Ich suche den Code …")
        case .offline(let c):
            FehlerKarte(titel: "Kein Netz", hilfe: "Der Code \(c) steht noch nicht auf deinem Gerät. Versuche es mit Netz noch einmal oder trag das Lebensmittel von Hand ein.")
            Button("Von Hand eintragen") { pfad = [.eigenes(barcode: c)] }.buttonStyle(.bordered).frame(minHeight: Abstand.tippflaeche)
            nochEinmal
        case .limit(_, let s):
            FehlerKarte(titel: "Kurz warten", hilfe: "Open Food Facts erlaubt nur 15 Abfragen in der Minute. In etwa \(s) Sekunden geht es wieder.")
            nochEinmal
        case .fehler(let c):
            FehlerKarte(titel: "Open Food Facts antwortet gerade nicht", hilfe: "Das liegt nicht an dir. Versuche es gleich noch einmal oder trag den Code \(c) von Hand ein.")
            Button("Von Hand eintragen") { pfad = [.eigenes(barcode: c)] }.buttonStyle(.bordered).frame(minHeight: Abstand.tippflaeche)
            nochEinmal
        }
    }

    /// Der Scanner meldet je Start nur einen Code; nach einem Fehler startet er auf Wunsch neu.
    @ViewBuilder
    private var nochEinmal: some View {
        if kannScannen {
            Button("Noch einmal scannen") { zustand = .bereit; kameraNummer += 1 }.buttonStyle(.bordered).frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func suchen(_ roh: String) async {
        guard zustand != .sucht else { return }
        zustand = .sucht
        let ergebnis = await EssenModul.suche(umgebung).barcode(roh)
        switch ergebnis {
        case .gefunden(let l):
            zustand = .bereit
            pfad = [.detail(l)]
        case .vorschlaege(let n, let liste, let c):
            zustand = .bereit
            vorschlaege = (n, liste, c)
        case .unbekannt(let c):
            zustand = .bereit
            pfad = [.eigenes(barcode: c)]
        case .offline(let c): zustand = .offline(c)
        case .limit(let c, let s): zustand = .limit(c, s)
        case .fehler(let c): zustand = .fehler(c)
        }
    }

    private func einstellungenOeffnen() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Nur Debug: mit `-lumenFitFixtures` und ohne Kamera den Fixture-Code suchen, damit CI-Bilder ohne Kamera gehen.
    private func debugFixtureScan() async {
        #if DEBUG
        guard !kannScannen, StartArgumente.lies().fixtures != nil else { return }
        try? await Task.sleep(for: .milliseconds(600))
        await suchen("4008400402222")
        #endif
    }
}

/// Die Kamera als `DataScannerViewController` (VisionKit). Nur wo sie verfügbar ist: nicht im Simulator, nicht ohne Erlaubnis.
struct EssenBarcodeKamera: UIViewControllerRepresentable {
    let gefunden: @MainActor (String) -> Void
    /// Standard: Barcodes auf Lebensmitteln. Die Verbindungen lesen damit QR-Codes (`[.qr]`).
    var symbologien: [VNBarcodeSymbology] = [.ean13, .ean8, .upce, .code128]

    static var verfuegbar: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologien)],
            qualityLevel: .balanced, recognizesMultipleItems: false, isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        return controller
    }

    /// `startScanning()` erst, sobald die Ansicht auf dem Bildschirm ist, nie in `makeUIViewController`.
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard !context.coordinator.gestartet else { return }
        context.coordinator.gestartet = true
        try? uiViewController.startScanning()
    }

    /// Kamera und Erkennung aus, sobald die Ansicht weg ist.
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Koordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Koordinator { Koordinator(gefunden: gefunden) }

    @MainActor
    final class Koordinator: NSObject, DataScannerViewControllerDelegate {
        let gefunden: @MainActor (String) -> Void
        var gestartet = false
        private var gemeldet = false

        init(gefunden: @escaping @MainActor (String) -> Void) { self.gefunden = gefunden }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !gemeldet else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item, let wert = barcode.payloadStringValue else { continue }
                gemeldet = true
                // Nach dem ersten Treffer meldet der Koordinator nichts mehr: Kamera und Vision aus, statt hinter der Detailseite weiterzulaufen (Akku).
                // "Noch einmal scannen" baut eine neue Kamera (`.id(kameraNummer)`).
                dataScanner.stopScanning()
                gefunden(wert)
                break
            }
        }
    }
}
