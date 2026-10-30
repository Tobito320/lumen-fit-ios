// Quelle: Lovea Health/Ernaehrung/EssenAuftragStore.swift (ohne Mitteilung; Ordner im Profil statt Singleton)
import Foundation
import Observation
import UIKit

/// Hält die App nach dem Verlassen noch kurz wach, solange eine Analyse läuft. Ein Port, damit Tests UIKit nicht anfassen.
@MainActor
protocol EssenKiHintergrund: AnyObject {
    var vorne: Bool { get }
    func start()
    func ende()
}

/// Der echte Hintergrundlauf: iOS gibt grob 30 Sekunden.
@MainActor
final class EssenKiSystemHintergrund: EssenKiHintergrund {
    private var kennung = UIBackgroundTaskIdentifier.invalid

    var vorne: Bool { UIApplication.shared.applicationState == .active }

    func start() {
        guard kennung == .invalid else { return }
        kennung = UIApplication.shared.beginBackgroundTask(withName: "Lumen-Essen-Analyse") { [weak self] in
            MainActor.assumeIsolated { self?.ende() }
        }
    }

    func ende() {
        guard kennung != .invalid else { return }
        UIApplication.shared.endBackgroundTask(kennung)
        kennung = .invalid
    }
}

/// Besitzt die Foto-Analysen von "Essen fotografieren": den Netzaufruf, die Hintergrundzeit und die Datei. Eine Ansicht darf nur zuschauen.
/// Schließt jemand das Blatt, läuft die Analyse weiter, und das Ergebnis liegt in Essen, bis es übernommen oder verworfen wird.
///
/// Auf dem Gerät, im Ordner des Profils: `index.json` (Zustand und Ergebnis) und je Auftrag `<id>.jpg` (das verkleinerte Foto ohne Ort und Zeit).
/// Wer die Datei nicht lesen kann, bekommt nie eine leere Liste darübergeschrieben.
@MainActor
@Observable
final class EssenKiAuftragStore {
    nonisolated static let indexName = "index.json"

    /// Neueste zuerst.
    private(set) var auftraege: [EssenKiAuftrag] = []
    /// Zuletzt verworfen und noch rückgängig zu machen.
    private(set) var verworfen: EssenKiAuftrag?
    /// Zählt hoch, wenn ein Foto auf der Platte neu da ist: Karten laden ihre Vorschau dann nach, ohne Abfragen.
    private(set) var bildStand = 0

    @ObservationIgnored private let ordner: URL
    @ObservationIgnored private let sender: any EssenKiSender
    @ObservationIgnored private let hintergrund: any EssenKiHintergrund
    @ObservationIgnored private var aufgaben: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var verwerfenAufgabe: Task<Void, Never>?

    init(ordner: URL, sender: any EssenKiSender, hintergrund: any EssenKiHintergrund) {
        self.ordner = ordner
        self.sender = sender
        self.hintergrund = hintergrund
        laden()
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.fortsetzen() }
        }
    }

    // MARK: - Lesen

    func auftrag(_ id: UUID) -> EssenKiAuftrag? { auftraege.first { $0.id == id } }

    var anzahlFertig: Int { EssenKiAuftragLogik.anzahlFertig(auftraege) }

    func bildURL(_ id: UUID) -> URL { ordner.appendingPathComponent(id.uuidString + ".jpg") }

    func bildDaten(_ id: UUID) -> Data? { try? Data(contentsOf: bildURL(id)) }

    // MARK: - Aufträge

    /// Neuer Auftrag aus dem Foto (Kamera oder Bibliothek, noch nicht verkleinert). Der Auftrag steht sofort in der Liste;
    /// Verkleinern, Speichern und Schicken laufen im Speicher weiter, auch wenn das Blatt zugeht.
    @discardableResult
    func neu(foto roh: Data, mahlzeit: Mahlzeit, datum: String) -> UUID {
        let a = EssenKiAuftragLogik.neu(mahlzeit: mahlzeit, datum: datum)
        let id = a.id
        auftraege.insert(a, at: 0)
        sichern()
        hintergrund.start()
        aufgaben[id] = Task { [weak self] in
            let klein = await Task.detached(priority: .userInitiated) { EssenKiBild.verkleinern(roh) }.value
            guard !Task.isCancelled else { return }
            guard let klein else {
                self?.fehlerErhalten(id, anzeige: EssenKiFotoLogik.fotoUnlesbar, netz: false)
                return
            }
            self?.bildSichern(klein, id: id)
            await self?.senden(id, bild: klein)
        }
        return id
    }

    /// Dasselbe Foto noch einmal schicken: nach Fehler, nach Unterbrechung, oder mit `hinweis` für eine Rückfrage der KI.
    /// `automatisch` ist die eine Wiederholung nach einem Netzfehler.
    func nochmal(_ id: UUID, hinweis: String? = nil, automatisch: Bool = false) {
        guard let i = index(id), auftraege[i].status != .laeuft else { return }
        guard let bild = bildDaten(id) else {
            auftraege[i] = EssenKiAuftragLogik.fehlgeschlagen(auftraege[i], anzeige: EssenKiFotoLogik.fotoUnlesbar, netz: false)
            sichern()
            return
        }
        auftraege[i] = EssenKiAuftragLogik.neuStart(auftraege[i], hinweis: hinweis, automatisch: automatisch)
        sichern()
        hintergrund.start()
        aufgaben[id]?.cancel()
        aufgaben[id] = Task { [weak self] in await self?.senden(id, bild: bild) }
    }

    /// "Abbrechen" während es läuft: mit früherer Schätzung zurück zu ihr, sonst ganz weg.
    func abbrechen(_ id: UUID) {
        guard let i = index(id), let a = EssenKiAuftragLogik.abgebrochen(auftraege[i]) else { entfernen(id); return }
        aufgaben[id]?.cancel()
        aufgaben[id] = nil
        auftraege[i] = a
        sichern()
        aufraeumen()
    }

    /// Endgültig weg: übernommen, abgebrochen oder ein neues Foto gewählt.
    func entfernen(_ id: UUID) {
        aufgaben[id]?.cancel()
        aufgaben[id] = nil
        auftraege.removeAll { $0.id == id }
        bildLoeschen(id)
        sichern()
        aufraeumen()
    }

    /// Karte "Verwerfen": weg aus der Liste, das Foto bleibt noch kurz für "Rückgängig".
    func verwerfen(_ id: UUID) {
        guard let i = index(id) else { return }
        aufgaben[id]?.cancel()
        aufgaben[id] = nil
        verwerfenAbschliessen()
        verworfen = auftraege.remove(at: i)
        sichern()
        aufraeumen()
        verwerfenAufgabe = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.verwerfenAbschliessen()
        }
    }

    func rueckgaengig() {
        guard let a = verworfen else { return }
        verwerfenAufgabe?.cancel()
        verwerfenAufgabe = nil
        verworfen = nil
        // Lief es beim Verwerfen noch, ist es jetzt unterbrochen: "Nochmal" geht mit dem Foto.
        auftraege.append(contentsOf: EssenKiAuftragLogik.nachNeustart([a]))
        auftraege.sort { $0.erstellt > $1.erstellt }
        sichern()
    }

    private func verwerfenAbschliessen() {
        verwerfenAufgabe?.cancel()
        verwerfenAufgabe = nil
        guard let a = verworfen else { return }
        verworfen = nil
        bildLoeschen(a.id)
    }

    // MARK: - Netz

    private func senden(_ id: UUID, bild: Data) async {
        guard let a = auftrag(id) else { return }
        do {
            let analyse = try await sender.analysieren(bild: bild, hinweis: a.hinweis, mahlzeit: a.mahlzeit)
            // Ein Abbruch kommt von URLSession als Fehler zurück; wer abbricht, will keine Fehlermeldung.
            guard !Task.isCancelled else { return }
            ergebnisErhalten(id, analyse)
        } catch {
            guard !Task.isCancelled else { return }
            let f = (error as? EssenKiFehler) ?? .unbekannt
            fehlerErhalten(id, anzeige: EssenKiFotoLogik.anzeige(f), netz: f == .netz)
        }
    }

    private func ergebnisErhalten(_ id: UUID, _ analyse: EssenKiAnalyse) {
        aufgaben[id] = nil
        defer { aufraeumen() }
        guard let i = index(id) else { return }
        auftraege[i] = EssenKiAuftragLogik.ergebnis(auftraege[i], analyse)
        sichern()
    }

    private func fehlerErhalten(_ id: UUID, anzeige: EssenKiAnzeige, netz: Bool) {
        aufgaben[id] = nil
        defer { aufraeumen() }
        guard let i = index(id) else { return }
        auftraege[i] = EssenKiAuftragLogik.fehlgeschlagen(auftraege[i], anzeige: anzeige, netz: netz)
        sichern()
        // Kam der Netzfehler erst nach der Rückkehr in die App (iOS hat die Verbindung im Hintergrund gekappt), gibt es kein weiteres
        // "aktiv": gleich die eine Wiederholung. Sonst wartet sie bis zur Rückkehr.
        if auftraege[i].autoNochmal, hintergrund.vorne { nochmal(id, automatisch: true) }
    }

    /// Zurück in der App: die eine Wiederholung nach einem Netzfehler im Hintergrund.
    func fortsetzen() {
        for a in auftraege where a.status == .fehler && a.autoNochmal { nochmal(a.id, automatisch: true) }
    }

    private func aufraeumen() {
        if aufgaben.isEmpty { hintergrund.ende() }
    }

    // MARK: - Datei

    private func index(_ id: UUID) -> Int? { auftraege.firstIndex { $0.id == id } }

    private func laden() {
        let datei = ordner.appendingPathComponent(Self.indexName)
        guard let daten = try? Data(contentsOf: datei) else { return }
        guard let liste = EssenKiAuftragLogik.lesen(daten) else {
            // Nicht lesbar: zur Seite legen, nie überschreiben.
            let stempel = Int(Date().timeIntervalSince1970)
            try? FileManager.default.moveItem(at: datei, to: ordner.appendingPathComponent("index-defekt-\(stempel).json"))
            return
        }
        auftraege = EssenKiAuftragLogik.nachNeustart(liste)
        // Fotos ohne Auftrag (verworfen, dann wurde die App beendet) wegräumen.
        let behalten = Set(liste.map { $0.id.uuidString + ".jpg" })
        let vorhanden = (try? FileManager.default.contentsOfDirectory(atPath: ordner.path)) ?? []
        for name in vorhanden where name.hasSuffix(".jpg") && !behalten.contains(name) {
            try? FileManager.default.removeItem(at: ordner.appendingPathComponent(name))
        }
        if auftraege != liste { sichern() }
    }

    private func sichern() {
        guard let daten = EssenKiAuftragLogik.kodieren(auftraege) else { return }
        schreiben(daten, nach: ordner.appendingPathComponent(Self.indexName))
    }

    private func bildSichern(_ daten: Data, id: UUID) {
        schreiben(daten, nach: bildURL(id))
        bildStand += 1
    }

    private func bildLoeschen(_ id: UUID) { try? FileManager.default.removeItem(at: bildURL(id)) }

    /// "Bis zur ersten Entsperrung" statt "komplett": iOS beendet die Analyse bei gesperrtem Handy nicht, und das Ergebnis muss sich auch dann noch speichern lassen.
    private func schreiben(_ daten: Data, nach url: URL) {
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try? daten.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
