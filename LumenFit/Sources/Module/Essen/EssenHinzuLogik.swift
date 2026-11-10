// Quelle: Lovea Health/Ernaehrung/ErnaehrungHinzufuegen.swift (listeInhalt, suchKarten, typLabel) und HinzufuegenTeile.swift (Typen)
import Foundation

/// Welche Art Eintrag die Liste im Hinzufügen-Blatt zeigt.
enum EssenHinzuTyp: String, CaseIterable, Hashable, Sendable {
    case lebensmittel = "Lebensmittel", mahlzeiten = "Mahlzeiten", rezepte = "Rezepte"

    var titel: String {
        switch self {
        case .lebensmittel: String(localized: "Lebensmittel")
        case .mahlzeiten: String(localized: "Mahlzeiten")
        case .rezepte: String(localized: "Rezepte")
        }
    }
}

enum EssenHinzuSortierung: String, CaseIterable, Hashable, Sendable {
    case haeufig = "Häufig", zuletzt = "Zuletzt", favoriten = "Favoriten"

    var titel: String {
        switch self {
        case .haeufig: String(localized: "Häufig")
        case .zuletzt: String(localized: "Zuletzt")
        case .favoriten: String(localized: "Favoriten")
        }
    }
}

/// Filter über den Suchtreffern. Lumen hat keine feste Partner-Kennung: "Von anderen" heißt, ein anderes Profil hat es angelegt.
enum EssenSuchChip: Hashable, Sendable {
    case favoriten, vonMir, vonAnderen

    var titel: String {
        switch self {
        case .favoriten: String(localized: "Favoriten")
        case .vonMir: String(localized: "Von mir erstellt")
        case .vonAnderen: String(localized: "Von anderen")
        }
    }

    var symbol: String {
        switch self {
        case .favoriten: "star.fill"
        case .vonMir: "pencil"
        case .vonAnderen: "person.fill"
        }
    }
}

/// Wer ein Lebensmittel oder Rezept angelegt hat. `keine`: niemand (BLS, Open Food Facts), es ist nicht eigen.
enum EssenHerkunft: Equatable, Sendable { case ich, andere, keine }

/// Reine Regeln des Hinzufügen-Blatts: welche Liste unter welchem Typ und welcher Sortierung steht, was ein Chip filtert, womit ein Plus-Tipp einträgt.
enum EssenHinzuLogik {
    /// Typ und Sortierung wie in Lovea. Lebensmittel: Häufig, Zuletzt, Favoriten direkt. Mahlzeiten und Rezepte: dieselben Listen, nur auf
    /// `rezept-`-IDs gefiltert, der Rest folgt alphabetisch. `favoriten` darf Rezepte enthalten (`rezept-…`).
    static func liste(typ: EssenHinzuTyp, sortierung: EssenHinzuSortierung, haeufig: [Lebensmittel], zuletzt: [Lebensmittel],
                      favoriten: [Lebensmittel], rezepte: [Rezept]) -> [Lebensmittel] {
        switch typ {
        case .lebensmittel:
            switch sortierung {
            case .haeufig: return haeufig.filter { !$0.istRezept }
            case .zuletzt: return zuletzt.filter { !$0.istRezept }
            case .favoriten: return favoriten.filter { !$0.istRezept }
            }
        case .mahlzeiten, .rezepte:
            let wunsch = typ == .mahlzeiten
            let alle = rezepte.filter { $0.istMahlzeit == wunsch }.map(ErnaehrungLogik.alsLebensmittel)
            switch sortierung {
            case .favoriten:
                let ids = Set(favoriten.filter(\.istRezept).map(\.id))
                return alle.filter { ids.contains($0.id) }
            case .haeufig, .zuletzt:
                let ids = Set(alle.map(\.id))
                let basis = sortierung == .haeufig ? haeufig : zuletzt
                let erst = basis.filter { ids.contains($0.id) }
                let erstIds = Set(erst.map(\.id))
                let rest = alle.filter { !erstIds.contains($0.id) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                return erst + rest
            }
        }
    }

    /// Chip gewählt: filtert die Suchtreffer. Bei leerer Suche (keine Treffer) zeigt er direkt die passende Grundliste.
    static func suchKarten(chip: EssenSuchChip?, treffer: [Lebensmittel], favoriten: [Lebensmittel],
                           vonMir: [Lebensmittel], vonAnderen: [Lebensmittel]) -> [Lebensmittel] {
        guard let chip else { return treffer }
        let basis: [Lebensmittel]
        switch chip {
        case .favoriten: basis = favoriten
        case .vonMir: basis = vonMir
        case .vonAnderen: basis = vonAnderen
        }
        guard !treffer.isEmpty else { return basis }
        let ids = Set(treffer.map(\.id))
        return basis.filter { ids.contains($0.id) }
    }

    /// "Mahlzeit", "Rezept" oder "Lebensmittel" für das kleine Etikett in der Suchzeile.
    static func typLabel(_ l: Lebensmittel, rezepte: [Rezept]) -> String {
        guard let r = rezept(zu: l, in: rezepte) else { return String(localized: "Lebensmittel") }
        return r.istMahlzeit ? String(localized: "Mahlzeit") : String(localized: "Rezept")

    }

    /// Das Rezept hinter einem `rezept-…`-Lebensmittel.
    static func rezept(zu l: Lebensmittel, in rezepte: [Rezept]) -> Rezept? {
        guard l.istRezept else { return nil }
        let id = String(l.id.dropFirst("rezept-".count))
        return rezepte.first { $0.id == id }
    }

    static func herkunft(ersteller: ProfilID?, ich: ProfilID) -> EssenHerkunft {
        guard let ersteller else { return .keine }
        return ersteller == ich ? .ich : .andere
    }

    /// Plus-Tipp: letzte Menge, sonst Portion oder 100 g/ml.
    static func plusMenge(_ l: Lebensmittel, letzte: (menge: Double, einheit: Einheit)?) -> (menge: Double, einheit: Einheit) {
        letzte ?? ErnaehrungLogik.startMenge(l)
    }

    /// "1 Scheibe (30 g)" oder "100 g": die Standardportion in der Zeile.
    static func portionText(_ l: Lebensmittel) -> String {
        guard let menge = l.portionMenge else { return "100 \(l.basisEinheit.rawValue)" }
        return "1 \(ErnaehrungLogik.einheitName(.portion, l)) (\(ErnaehrungLogik.zahl(menge)) \(l.basisEinheit.rawValue))"
    }

    /// Energie der Standardportion, sonst je 100 g.
    static func portionKcal(_ l: Lebensmittel) -> Int {
        let kcal = l.portionMenge.map { l.pro100.kcal * $0 / 100 } ?? l.pro100.kcal
        return Int(kcal.rounded())
    }
}
