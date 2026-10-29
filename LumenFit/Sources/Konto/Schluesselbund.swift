import Foundation

/// Der Schlüsselbund hinter einem Port: das Profil überlebt so ein Update und meist auch eine Neuinstallation.
protocol Schluesselbund: Sendable {
    func lese(_ schluessel: String) -> Data?
    func schreibe(_ daten: Data, fuer schluessel: String) throws
    func entferne(_ schluessel: String)
}
