import Foundation

/// Ein Ausgang der aktuellen Audio-Route, ohne AVFoundation: so lässt sich die Einordnung ohne Gerät testen. Das iPhone verrät nur Art und Namen des Ausgangs,
/// nie den Akku von AirPods und keine Hörer-Daten (kein öffentlicher Weg in iOS).
struct AudioAusgang: Equatable, Sendable {
    enum Art: Equatable, Sendable { case bluetooth, kabel, lautsprecher, anderes }
    var art: Art
    var name: String
}

enum KopfhoererStatus: Equatable, Sendable {
    case keine
    case bluetooth(name: String, airPods: Bool)
    case kabel(name: String)
}

/// Einordnung der Route und Texte der Kopfhörer-Seite (Profil > Geräte > Kopfhörer und AirPods).
enum KopfhoererLogik {
    /// Bluetooth zuerst: ein Bluetooth-Ausgang ist es auch dann, wenn nebenbei der Lautsprecher in der Liste steht.
    static func status(_ ausgaenge: [AudioAusgang]) -> KopfhoererStatus {
        if let b = ausgaenge.first(where: { $0.art == .bluetooth }) { return .bluetooth(name: b.name, airPods: istAirPods(b.name)) }
        if let k = ausgaenge.first(where: { $0.art == .kabel }) { return .kabel(name: k.name) }
        return .keine
    }

    /// AirPods erkennt man nur am Namen, den der Besitzer ihnen gegeben hat ("AirPods" steht bei Auslieferung darin). Bluetooth-Lautsprecher und Auto sind hier ebenfalls "Bluetooth".
    static func istAirPods(_ name: String) -> Bool { name.localizedCaseInsensitiveContains("airpods") }

    static func titel(_ status: KopfhoererStatus) -> String {
        switch status {
        case .keine: "Nichts angeschlossen"
        case .bluetooth(_, let airPods): airPods ? "AirPods verbunden" : "Bluetooth-Audio verbunden"
        case .kabel: "Kopfhörer mit Kabel"
        }
    }

    static func name(_ status: KopfhoererStatus) -> String? {
        switch status {
        case .keine: nil
        case .bluetooth(let name, _), .kabel(let name): name
        }
    }

    /// Kurzer Text für die Zeile in der Geräteliste.
    static func zeile(_ status: KopfhoererStatus) -> String {
        switch status {
        case .keine: "Nichts verbunden"
        case .bluetooth(let name, _), .kabel(let name): name
        }
    }

    static func symbol(_ status: KopfhoererStatus) -> String {
        switch status {
        case .keine: "headphones"
        case .bluetooth(_, let airPods): airPods ? "airpods" : "headphones"
        case .kabel: "headphones"
        }
    }
}

/// Wann Lumen Fit im Training etwas ansagt. Standard aus; mit "Nur mit Kopfhörern" (Standard an) spricht es nie über den Lautsprecher des iPhones.
enum AnsageRegel {
    nonisolated static let pauseSchluessel = "fit.kopfhoerer.ansage.pause"
    nonisolated static let rekordSchluessel = "fit.kopfhoerer.ansage.rekord"
    nonisolated static let nurKopfhoererSchluessel = "fit.kopfhoerer.ansage.nurkopfhoerer"

    static let pauseText = "Pause vorbei. Nächster Satz."
    static let rekordText = "Neuer Rekord!"

    static func sprechen(an: Bool, nurMitKopfhoerern: Bool, status: KopfhoererStatus) -> Bool {
        guard an else { return false }
        guard nurMitKopfhoerern else { return true }
        return status != .keine
    }
}
