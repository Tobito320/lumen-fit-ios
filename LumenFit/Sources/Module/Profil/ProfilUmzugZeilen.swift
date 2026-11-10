import SwiftUI

/// Eine Übergangs-Zeile im Profil: Essen und Schlaf liegen hier, bis sie zu Lovea und Lumen Alarm umgezogen sind (Entscheidung vom 09./10.11.2026).
struct ProfilUmzugZeile: Equatable, Sendable, Identifiable {
    var titel: String
    var untertitel: String
    var symbol: String
    var route: Route
    var id: String { titel }
}

/// Welche Zeilen erscheinen: Essen nur mit Bereich Essen, Schlaf nur mit der Freigabe des Servers. Keine leere Zeile, kein leerer Abschnitt.
enum ProfilUmzugLogik {
    static func zeilen(essenAn: Bool, schlafSichtbar: Bool, loveaErlaubt: Bool) -> [ProfilUmzugZeile] {
        var liste: [ProfilUmzugZeile] = []
        if essenAn {
            liste.append(ProfilUmzugZeile(titel: "Essen", untertitel: loveaErlaubt ? "Zieht bald zu Lovea um" : "", symbol: "fork.knife", route: .essen(.heute)))
        }
        if schlafSichtbar {
            liste.append(ProfilUmzugZeile(titel: "Schlaf", untertitel: "Zieht bald zu Lumen Alarm um", symbol: "bed.double.fill", route: .schlaf(.letzteNacht)))
        }
        return liste
    }
}

/// Die zwei Zeilen oben im Profil, über Konto. Ein Tipp legt die Seite auf den Profil-Stapel (`Route`, wie ein Link von außen).
struct ProfilUmzugZeilen: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let zeilen = ProfilUmzugLogik.zeilen(essenAn: umgebung.bereicheWirksam.essenAn, schlafSichtbar: umgebung.konto.schlafSichtbar,
                                             loveaErlaubt: umgebung.konto.loveaErlaubt)
        if !zeilen.isEmpty {
            ProfilAbschnitt {
                ForEach(zeilen) { zeile in
                    NavigationLink(value: zeile.route) {
                        ProfilListenZeile(zeile.titel, symbol: zeile.symbol, wert: zeile.untertitel.isEmpty ? nil : zeile.untertitel)
                    }
                }
            }
        }
    }
}
