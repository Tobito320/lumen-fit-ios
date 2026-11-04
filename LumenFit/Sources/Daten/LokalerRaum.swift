import Foundation
import Observation

/// Die kleine Oberfläche, die Loveas Health-Code von `Raum.shared` brauchte, ohne Server: ein Raum je `DatenSatz` (je Profil).
/// Schreiben und Beobachten laufen synchron auf dem Hauptakteur, `leer()` ist deshalb sofort fertig; es bleibt für Aufrufer,
/// die später auf eine Hintergrund-Warteschlange wechseln.
// shortcut: Anhängen an die Datei läuft auf dem Hauptakteur (kleine Zeilen), bei spürbarem Ruckeln auf eine eigene Warteschlange legen.
@MainActor @Observable
final class LokalerRaum {
    let profil: ProfilID
    @ObservationIgnored private var log: LokalerOpLog
    @ObservationIgnored private var alle: [Op]
    @ObservationIgnored private var beobachter: [(arten: Set<String>, f: (Op) -> Void)] = []
    @ObservationIgnored private let uhr: Uhr
    /// Wird gerufen, wenn eine Op nicht geschrieben werden konnte (Speicher voll, Dateirechte). Das `DatenSatz` macht daraus ein Ereignis.
    @ObservationIgnored var beiSpeicherfehler: (@MainActor () -> Void)?

    /// `ordner` ist der Profilordner; der Log liegt als `ops.jsonl` darin.
    init(ordner: URL, profil: ProfilID, uhr: @escaping Uhr = { Date() }) {
        self.profil = profil
        self.uhr = uhr
        var log = LokalerOpLog(datei: ordner.appendingPathComponent("ops.jsonl"))
        self.alle = log.lade()
        self.log = log
    }

    /// Schreibt eine neue Op des Profils.
    func senden<T: Encodable>(_ art: String, _ d: T) {
        einreihen(Op.neu(art, d, von: profil, zeit: uhr()))
    }

    /// Nimmt eine fertige Op auf (zum Beispiel aus einer Datensicherung); doppelte `id` werden übersprungen.
    func einreihen(_ op: Op) {
        switch log.fuegeAn(op) {
        case .doppelt: return
        case .fehlgeschlagen:
            beiSpeicherfehler?()
            return
        case .angehaengt: break
        }
        alle.append(op)
        for b in beobachter where b.arten.contains(op.art) { b.f(op) }
    }

    /// Spielt zuerst alle vorhandenen Ops der Arten ab, danach live.
    func beobachten(_ arten: Set<String>, _ f: @escaping (Op) -> Void) {
        for op in alle where arten.contains(op.art) { f(op) }
        beobachter.append((arten: arten, f: f))
    }

    func ops(arten: Set<String>) -> [Op] { alle.filter { arten.contains($0.art) } }

    /// Wie viele Ops der Raum hat. Ops werden nur angehängt: gleiche Anzahl heißt gleicher Inhalt (Merk-Schlüssel für Leser, die alles durchgehen).
    var anzahl: Int { alle.count }

    /// Kehrt zurück, wenn alle geschriebenen Ops gefaltet sind (hier: sofort, alles läuft synchron).
    func leer() async {}
}
