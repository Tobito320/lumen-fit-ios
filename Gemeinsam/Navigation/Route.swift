import Foundation

enum GymBereich: String, Codable, Sendable { case training, plaene, fortschritt }
enum EssenBereich: String, Codable, Sendable { case heute, scan, favoriten }
enum SchlafBereich: String, Codable, Sendable { case letzteNacht, verlauf, werte }
enum ProfilBereich: String, Codable, Sendable {
    case uebersicht, einstellungen, aussehen, ziele, verbindungen, datensicherung, quellen, meilensteine, lumi, zyklus
}

/// Jede Seite der App hat genau eine Route (und einen Link, `RouteURL`).
enum Route: Hashable, Codable, Sendable {
    case heute
    case gym(GymBereich)
    case essen(EssenBereich)
    case schlaf(SchlafBereich)
    case coach(frage: String?)
    case profil(ProfilBereich)
    case verlauf
    case gewichtEintragen
    case uebung(id: String)
    case freund(daten: String?)          // Freundeskarte importieren (Nutzlast des Links) oder die Freunde-Seite öffnen
}
