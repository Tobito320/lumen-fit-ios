// Quelle: Lovea Health/Ernaehrung/NaehrwertFoto.swift (Kamera und Ablauf; die Oberfläche ist neu im Lumen-Design)
import PhotosUI
import SwiftUI
import UIKit

/// Etikett-Foto (Idee 48): die Nährwerttabelle fotografieren oder aus Fotos wählen, Vision liest die Zahlen auf dem Gerät (kein Server),
/// der Nutzer prüft sie im Formular und speichert. Erste Zahl je Zeile gilt als Wert pro 100 g.
struct NaehrwertFotoView: View {
    let uebernehmen: @MainActor (Naehrwerte) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var kameraOffen = false
    @State private var wahl: PhotosPickerItem?
    @State private var zustand: Zustand = .bereit
    /// Zählt gelesene Tabellen: löst die Erfolgs-Haptik aus (Lovea: `Haptik.erfolg()` beim Übernehmen).
    @State private var gelesen = 0

    private enum Zustand: Equatable {
        case bereit, liest, nichtGelesen
    }

    private var kameraDa: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        NavigationStack {
            VStack(spacing: Abstand.l) {
                LeerZustand(stimmung: zustand == .liest ? .denkt : .bereit, satz: satz)
                if zustand == .nichtGelesen {
                    FehlerKarte(titel: "Ich konnte keine Zahlen lesen", hilfe: "Halte die Tabelle gerade und gut beleuchtet ins Bild, so dass Energie und Nährwerte scharf sind. Oder tippe die Werte von Hand ein.")
                }
                if zustand == .liest {
                    ProgressView("Ich lese die Tabelle …")
                } else {
                    if kameraDa {
                        Button { kameraOffen = true } label: {
                            Label("Foto aufnehmen", systemImage: "camera.fill").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                        }
                        .buttonStyle(.lumenHauptknopf)
                    }
                    PhotosPicker(selection: $wahl, matching: .images) {
                        Label("Aus Fotos wählen", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .haptik(.erfolg, bei: gelesen)
            .navigationTitle("Etikett lesen")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .fullScreenCover(isPresented: $kameraOffen) {
                EssenKamera { daten in
                    kameraOffen = false
                    if let daten { Task { await lesen(daten) } }
                }
                .ignoresSafeArea()
            }
            .onChange(of: wahl) { _, neu in
                guard let neu else { return }
                Task {
                    if let daten = try? await neu.loadTransferable(type: Data.self) { await lesen(daten) } else { zustand = .nichtGelesen }
                    wahl = nil
                }
            }
        }
    }

    private var satz: String {
        switch zustand {
        case .bereit: "Fotografiere die Nährwerttabelle auf der Packung. Ich lese die Zahlen, du prüfst sie."
        case .liest: "Einen Moment."
        case .nichtGelesen: "Das hat nicht geklappt."
        }
    }

    private func lesen(_ daten: Data) async {
        zustand = .liest
        let zeilen = await NaehrwertLeser.erkennen(bildDaten: daten)
        if let werte = NaehrwertLeser.parsen(zeilen) {
            gelesen += 1
            // Kurz warten, damit die Haptik noch auf der sichtbaren Seite ausgelöst wird, bevor das Blatt schließt.
            try? await Task.sleep(for: .milliseconds(200))
            uebernehmen(werte)
        } else {
            zustand = .nichtGelesen
        }
    }
}

/// Kamera für ein Foto, als JPEG-Daten (`nil` bei Abbruch). Nur auf Geräten mit Kamera.
struct EssenKamera: UIViewControllerRepresentable {
    let aufgenommen: @MainActor (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(aufgenommen: aufgenommen) }

    @MainActor
    final class Koordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let aufgenommen: @MainActor (Data?) -> Void
        init(aufgenommen: @escaping @MainActor (Data?) -> Void) { self.aufgenommen = aufgenommen }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            aufgenommen((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            aufgenommen(nil)
        }
    }
}
