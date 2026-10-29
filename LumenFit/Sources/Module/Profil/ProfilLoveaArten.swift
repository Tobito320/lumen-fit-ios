import Foundation

/// Was der einmalige Import aus Lovea mit einer Op-Art macht. Diese eine Tabelle ist die Quelle für Filter, Abdeckungsbericht und Ergebnisanzeige.
enum ProfilLoveaBehandlung: Equatable, Sendable {
    /// Lumen Fit liest die Art unverändert (SPEC 5.3: Arten aus Lovea bleiben gleich).
    case uebernehmen
    /// Health-Art ohne Leser in Lumen Fit: bleibt unter der Originalart roh im Log, damit nichts verloren geht (und in der Sicherung landet).
    case rohBehalten
    /// Gehört nicht zu Health (Chat, Wecker, Notizen ...): wird nicht übernommen, mit Grund.
    case ausschliessen(String)
    /// Art nicht in der Tabelle: wird nicht übernommen, aber gezählt und aufgelistet.
    case unbekannt
}

enum ProfilLoveaArten {
    /// Health-Arten, die Lumen Fit versteht (Faltungen in `Gemeinsam/Modelle`). `einstellung.setzen` gilt nur für `einstellungPraefixe`.
    static let uebernehmen: Set<String> = [
        "gym.plan", "gym.checkin", "gym.uebung", "gym.checkout", "gym.loeschen", "cardio.setzen", "cardio.loeschen",
        "essen.setzen", "lebensmittel.setzen", "lebensmittel.favorit", "rezept.setzen", "fasten.setzen", "fasten.eintrag", "fasten.plan",
        "koerper.setzen", "food.anpassung",
        "habit.setzen", "habit.anlegen", "habit.aendern", "habit.ausblenden", "habit.loeschen",
    ]

    /// Health-Arten ohne Leser in Lumen Fit (Schlaf und Schritte kommen dort aus Health und Band, nicht aus Ops). Roh behalten, im Bericht genannt.
    static let rohBehalten: Set<String> = ["schlaf.setzen", "schlaf.zeiten", "schritte.setzen", "stimmung.setzen", "zyklus.tag", "coach.nachricht"]

    /// Schlüssel von `einstellung.setzen`, die zu Health gehören: Ziele (Ernährung, Muskeln, Gym) und Coach. Der Rest ist Lovea-Oberfläche.
    static let einstellungPraefixe = ["ziel.", "coach."]

    private static let gruppen: [(grund: String, exakt: Set<String>, praefixe: [String])] = [
        ("Chat", ["entwurf.setzen", "geste", "gruss", "gefuehl.setzen"], ["nachricht.", "snap.", "sprachpost.", "medium.", "brief."]),
        ("Notizen", ["notiz.setzen", "wir.notiz", "liste.setzen", "einkauf.liste"], ["notizbuch."]),
        ("Kalender und Orte", ["jahrestag.setzen", "dates.idee", "puenktlich.setzen", "muster.setzen", "muster.loeschen"], ["termin.", "treffen.", "ort."]),
        ("Wecker und Erinnerungen", ["wecker.setzen"], []),
        ("Figuren und Shop", ["stern"], ["figur.", "look.", "katze.", "shop.", "punkte."]),
        ("Spiele", ["wuerfel.gezogen"], ["spiel.", "frage."]),
        ("Zeichnen und Galerie", [], ["zeichnung.", "galerie.", "geschenkbox.", "umzug."]),
    ]

    /// `d` wird nur für `einstellung.setzen` gelesen (Schlüssel).
    static func behandlung(art: String, d: Data) -> ProfilLoveaBehandlung {
        if art == "einstellung.setzen" {
            let schluessel = (try? JSONDecoder().decode(EinstellungSchluessel.self, from: d))?.schluessel ?? ""
            return einstellungPraefixe.contains { schluessel.hasPrefix($0) } ? .uebernehmen : .ausschliessen("Lovea-Oberfläche (Chat, Zimmer, Profil)")
        }
        if uebernehmen.contains(art) { return .uebernehmen }
        if rohBehalten.contains(art) { return .rohBehalten }
        for g in gruppen where g.exakt.contains(art) || g.praefixe.contains(where: { art.hasPrefix($0) }) { return .ausschliessen(g.grund) }
        return .unbekannt
    }

    private struct EinstellungSchluessel: Decodable { var schluessel: String? }
}
