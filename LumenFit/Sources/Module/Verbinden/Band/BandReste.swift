import Foundation

/// Alles, was das Band in `UserDefaults` hinterlässt (Kennung, Name, Reihen, Akku-Verlauf, Regeln, Labor): alle Schlüssel mit der Vorsilbe `fit.band`.
/// Das Band gehört dem Gerät, nicht dem Profil (SPEC 5.6), darum geht es erst mit dem letzten Profil weg ("Alles löschen").
enum BandReste {
    nonisolated static let vorsilbe = "fit.band"

    static func loesche(_ defaults: UserDefaults = .standard) {
        for schluessel in defaults.dictionaryRepresentation().keys where schluessel.hasPrefix(vorsilbe) { defaults.removeObject(forKey: schluessel) }
    }
}
