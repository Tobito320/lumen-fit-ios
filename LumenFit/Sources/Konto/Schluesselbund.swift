import Foundation

/// Der Schlüsselbund hinter einem Port: das Profil überlebt so ein Update und meist auch eine Neuinstallation.
/// `lese` unterscheidet "gibt es nicht" (nil) von "Lesen schlug fehl" (wirft): nur das erste darf wie ein leerer Schlüsselbund behandelt werden.
protocol Schluesselbund: Sendable {
    func lese(_ schluessel: String) throws -> Data?
    func schreibe(_ daten: Data, fuer schluessel: String) throws
    func entferne(_ schluessel: String)
}
