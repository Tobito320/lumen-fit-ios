import Foundation

enum GymBereich: String, Codable, Sendable { case training, plaene, fortschritt, geschafft } // Training laufend: geschafft = Seite nach dem Beenden
enum EssenBereich: String, Codable, Sendable { case heute, scan, favoriten }
enum SchlafBereich: String, Codable, Sendable { case letzteNacht, verlauf, werte }
enum ProfilBereich: String, Codable, Sendable {
    case uebersicht, einstellungen, aussehen, ziele, verbindungen, datensicherung, quellen, meilensteine, lumi
}

/// Jede Seite der App hat genau eine Route (und einen Link, `RouteURL`).
enum Route: Hashable, Codable, Sendable {
    case heute
    case gym(GymBereich)
    case essen(EssenBereich)
    case schlaf(SchlafBereich)
    case profil(ProfilBereich)
    case verlauf
    case einsichten                      // Einsichten und Hinweise des Tages (Zeile im Tab Fortschritt)
    case gewichtEintragen
    case uebung(id: String)
    case freund(daten: String?)          // Freundeskarte importieren (Nutzlast des Links) oder die Freunde-Seite öffnen
}
