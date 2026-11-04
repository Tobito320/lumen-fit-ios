import Foundation

/// Wartezeit vor dem nächsten `connect`, nachdem eins fehlschlug (`didFailToConnect`). Sofort neu verbinden dreht bei einem
/// dauerhaften Fehler (z. B. Kopplung am Band gelöscht) eine Schleife, die die App im Hintergrund immer wieder weckt.
enum BandVerbindenPause {
    /// `fehlversuche` zählt ab 1; nach dem vierten bleibt es bei 5 Minuten, iOS darf das Band also weiter finden.
    static func sekunden(fehlversuche: Int) -> TimeInterval {
        [5, 15, 60, 300][min(max(fehlversuche, 1), 4) - 1]
    }
}
