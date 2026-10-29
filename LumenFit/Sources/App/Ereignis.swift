import Foundation

enum Ereignis: Sendable {
    case profilGewechselt(ProfilID)
    case profilGeloescht              // das letzte Profil ist weg (Alles löschen, Zurücksetzen): Reste aufräumen
    case einstellungenGeaendert
    case trainingGestartet(session: String)
    case satzFertig(session: String, rekord: Bool)
    case trainingBeendet(session: String)
    case mahlzeitGespeichert(tag: String)
    case gewichtGespeichert(tag: String)
    case habitGeaendert(tag: String)
    case meilensteinErreicht(id: String)
    case partnerAktualisiert
    case speichernFehlgeschlagen      // eine Eingabe (Satz, Mahlzeit, Gewicht) konnte nicht geschrieben werden: die Oberfläche sagt es (Idee 10)
    case healthAktualisiert
    case vordergrund                  // scenePhase wird .active (auch Rückkehr aus dem Hintergrund)
}

/// Ein Kanal für alle Ereignisse der App; jeder `strom()` bekommt alle späteren Ereignisse.
@MainActor final class EreignisKanal {
    private var abnehmer: [UUID: AsyncStream<Ereignis>.Continuation] = [:]

    func senden(_ ereignis: Ereignis) {
        for fortsetzung in abnehmer.values { fortsetzung.yield(ereignis) }
    }

    func strom() -> AsyncStream<Ereignis> {
        let id = UUID()
        let (strom, fortsetzung) = AsyncStream.makeStream(of: Ereignis.self)
        abnehmer[id] = fortsetzung
        fortsetzung.onTermination = { [weak self] _ in
            Task { @MainActor in self?.abnehmer[id] = nil }
        }
        return strom
    }
}
