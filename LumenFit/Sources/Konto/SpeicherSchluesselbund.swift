import Foundation
import Synchronization

/// Schlüsselbund im Speicher: Fake in den Tests und Rückfall, wenn `SecItem*` im unsignierten Simulator `-34018` meldet.
final class SpeicherSchluesselbund: Schluesselbund {
    private let eintraege = Mutex<[String: Data]>([:])

    init() {}

    func lese(_ schluessel: String) -> Data? { eintraege.withLock { $0[schluessel] } }
    func schreibe(_ daten: Data, fuer schluessel: String) throws { eintraege.withLock { $0[schluessel] = daten } }
    func entferne(_ schluessel: String) { _ = eintraege.withLock { $0.removeValue(forKey: schluessel) } }
}
