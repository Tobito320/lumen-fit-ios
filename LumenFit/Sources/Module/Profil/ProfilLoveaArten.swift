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
        "schritte.setzen", "schlaf.setzen", "schlaf.zeiten", "stimmung.setzen",
        "zyklus.tag", "zyklus.einstellung",
    ]

    /// Health-Arten ohne Leser in Lumen Fit. Roh behalten, im Bericht genannt. `einkauf.liste` und `kuehl.*` sind Essens-Vorräte (Einkaufsliste, Kühlschrank)
    /// aus älteren Lovea-Fassungen: kein Leser hier, aber nichts geht verloren.
    static let rohBehalten: Set<String> = ["coach.nachricht", "einkauf.liste", "kuehl.setzen", "kuehl.weg"]

    /// Schlüssel von `einstellung.setzen`, die zu Health gehören: Ziele (Ernährung, Muskeln, Gym), Coach und die Konsistenz-Kategorien. Der Rest ist Lovea-Oberfläche.
    static let einstellungPraefixe = ["ziel.", "coach.", "konsistenz."]

    private static let gruppen: [(grund: String, exakt: Set<String>, praefixe: [String])] = [
        ("Chat", ["entwurf.setzen", "geste", "gruss", "gefuehl.setzen"], ["nachricht.", "snap.", "sprachpost.", "medium.", "brief."]),
        ("Notizen", ["notiz.setzen", "wir.notiz", "liste.setzen", "spiegel.setzen"], ["notizbuch."]),
        ("Kalender und Orte", ["jahrestag.setzen", "dates.idee", "puenktlich.setzen", "muster.setzen", "muster.loeschen", "ausnahme.setzen"], ["termin.", "treffen.", "ort."]),
        ("Wecker und Erinnerungen", ["wecker.setzen"], []),
        ("Figuren und Shop", ["stern"], ["figur.", "look.", "katze.", "shop.", "punkte."]),
        ("Spiele", ["wuerfel.gezogen"], ["spiel.", "frage."]),
        ("Lovea-Technik", ["app.kann"], []),
        ("Zeichnen und Galerie", [], ["zeichnung.", "galerie.", "geschenkbox.", "umzug."]),
    ]

    /// `d` wird nur für `einstellung.setzen` gelesen (Schlüssel).
    static func behandlung(art: String, d: Data) -> ProfilLoveaBehandlung {
        if art == "einstellung.setzen" {
            let schluessel = einstellungSchluessel(d) ?? ""
            return einstellungPraefixe.contains { schluessel.hasPrefix($0) } ? .uebernehmen : .ausschliessen("Lovea-Oberfläche (Chat, Zimmer, Profil)")
        }
        if uebernehmen.contains(art) { return .uebernehmen }
        if rohBehalten.contains(art) { return .rohBehalten }
        for g in gruppen where g.exakt.contains(art) || g.praefixe.contains(where: { art.hasPrefix($0) }) { return .ausschliessen(g.grund) }
        return .unbekannt
    }

    /// Der Schlüssel einer `einstellung.setzen`-Op (`ziel.schritte` ...); nil, wenn die Op keinen hat.
    static func einstellungSchluessel(_ d: Data) -> String? { (try? JSONDecoder().decode(EinstellungSchluessel.self, from: d))?.schluessel }

    private struct EinstellungSchluessel: Decodable { var schluessel: String? }
}
