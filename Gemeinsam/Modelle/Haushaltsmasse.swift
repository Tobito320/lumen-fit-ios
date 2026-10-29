// Quelle: Lovea Health/Ernaehrung/ErnaehrungPortionen.swift (nur HaushaltsMasse)
import Foundation


/// Haushaltsmaße (Teelöffel, Esslöffel, Prise, Glas, Tasse, Messlöffel) aus dem Namen hergeleitet – auch
/// für Open-Food-Facts-Importe ohne eigene Portionen. Küchen-Richtwerte, keine Laborwerte
enum HaushaltsMasse {
    /// Eine Gruppe trifft, wenn jede ihrer Wortgruppen durch mindestens ein Namenswort erfüllt ist (UND
    /// zwischen den Gruppen, ODER innerhalb einer Gruppe) – z. B. "reis" UND "roh". Ein Namenswort erfüllt
    /// ein Stichwort nur, wenn es GENAU dem Stichwort entspricht oder darauf ENDET ("Rohrzucker" passt zu
    /// "zucker", das Stichwort steht als Kompositum-Kopf hinten). Nie bei bloßem Wortanfang: deutsche
    /// Komposita bleiben nach `LebensmittelBasis.normal` ein Token, "zuckermais"/"zuckerfrei" dürfen nicht
    /// auf "zucker" treffen, nur weil sie damit anfangen (Review R9, Critical #1, 01.10.).
    private struct Gruppe {
        let woerter: [[String]]
        let portionen: [(name: String, gramm: Double)]

        func trifft(_ namensWoerter: [Substring]) -> Bool {
            woerter.allSatisfy { stichwoerter in
                stichwoerter.contains { s in namensWoerter.contains { $0 == s || $0.hasSuffix(s) } }
            }
        }
    }

    /// Löffelbare trockene/feste Lebensmittel: je Gruppe Teelöffel/Esslöffel gestrichen und gehäuft,
    /// Salz und Gewürze zusätzlich mit Prise. Werte sind Küchen-Richtwerte, keine Laborangaben.
    private static let loeffelbar: [Gruppe] = [
        Gruppe(woerter: [["zucker"]], portionen: [("Teelöffel, gestrichen", 4), ("Teelöffel, gehäuft", 8), ("Esslöffel, gestrichen", 12), ("Esslöffel, gehäuft", 20)]),
        Gruppe(woerter: [["salz"]], portionen: [("Prise", 0.4), ("Teelöffel, gestrichen", 6), ("Teelöffel, gehäuft", 10), ("Esslöffel, gestrichen", 18), ("Esslöffel, gehäuft", 26)]),
        Gruppe(woerter: [["mehl"]], portionen: [("Teelöffel, gestrichen", 3), ("Teelöffel, gehäuft", 5), ("Esslöffel, gestrichen", 10), ("Esslöffel, gehäuft", 15)]),
        Gruppe(woerter: [["starke"]], portionen: [("Teelöffel, gestrichen", 3), ("Teelöffel, gehäuft", 5), ("Esslöffel, gestrichen", 8), ("Esslöffel, gehäuft", 12)]),
        Gruppe(woerter: [["griess"]], portionen: [("Teelöffel, gestrichen", 4), ("Teelöffel, gehäuft", 7), ("Esslöffel, gestrichen", 12), ("Esslöffel, gehäuft", 18)]),
        // "kakaopulver" steht als eigenes Stichwort daneben: "kakao" ist dort der Kompositum-ANFANG
        // ("Pulver" der Kopf am Ende), die reine Endungsregel würde das sonst verfehlen.
        Gruppe(woerter: [["kakao", "kakaopulver"]], portionen: [("Teelöffel, gestrichen", 3), ("Teelöffel, gehäuft", 5), ("Esslöffel, gestrichen", 6), ("Esslöffel, gehäuft", 9)]),
        Gruppe(woerter: [["backpulver"]], portionen: [("Teelöffel, gestrichen", 5), ("Teelöffel, gehäuft", 8), ("Esslöffel, gestrichen", 15), ("Esslöffel, gehäuft", 22)]),
        Gruppe(woerter: [["haferflocken"]], portionen: [("Teelöffel, gestrichen", 2), ("Teelöffel, gehäuft", 3), ("Esslöffel, gestrichen", 8), ("Esslöffel, gehäuft", 12)]),
        Gruppe(woerter: [["reis"], ["roh"]], portionen: [("Teelöffel, gestrichen", 4), ("Teelöffel, gehäuft", 6), ("Esslöffel, gestrichen", 12), ("Esslöffel, gehäuft", 18)]),
        Gruppe(woerter: [["chia"]], portionen: [("Teelöffel, gestrichen", 4), ("Teelöffel, gehäuft", 6), ("Esslöffel, gestrichen", 12), ("Esslöffel, gehäuft", 18)]),
        Gruppe(woerter: [["leinsamen"]], portionen: [("Teelöffel, gestrichen", 4), ("Teelöffel, gehäuft", 6), ("Esslöffel, gestrichen", 12), ("Esslöffel, gehäuft", 18)]),
        // "nusse" zusätzlich zu "nuss": "Nüsse" normalisiert zu "nusse" (Plural-e), die Endungsregel
        // allein träfe das nicht (kein Suffix von "nuss").
        Gruppe(woerter: [["nuss", "nusse"], ["gemahlen"]], portionen: [("Teelöffel, gestrichen", 3), ("Teelöffel, gehäuft", 5), ("Esslöffel, gestrichen", 8), ("Esslöffel, gehäuft", 12)]),
        Gruppe(woerter: [["gewurz", "zimt"]], portionen: [("Prise", 0.3), ("Teelöffel, gestrichen", 2), ("Teelöffel, gehäuft", 3), ("Esslöffel, gestrichen", 6), ("Esslöffel, gehäuft", 9)]),
        Gruppe(woerter: [["kaffee"], ["pulver"]], portionen: [("Teelöffel, gestrichen", 3), ("Teelöffel, gehäuft", 4), ("Esslöffel, gestrichen", 7), ("Esslöffel, gehäuft", 10)]),
        Gruppe(woerter: [["protein", "eiweiss"], ["pulver"]], portionen: [("Messlöffel", 30)]),
        Gruppe(woerter: [["whey"]], portionen: [("Messlöffel", 30)]),
        Gruppe(woerter: [["honig", "marmelade", "konfiture", "nussbutter", "erdnussbutter", "mandelmus", "aufstrich"]], portionen: [("Teelöffel", 8), ("Esslöffel", 20)]),
        Gruppe(woerter: [["butter", "margarine"]], portionen: [("Teelöffel", 5), ("Esslöffel", 12)]),
    ]

    /// Flüssigkeiten (nur bei `fluessig`): Teelöffel/Esslöffel in ml, Getränke zusätzlich Glas/Tasse.
    private static let fluessig: [(gruppe: Gruppe, getraenk: Bool)] = [
        (Gruppe(woerter: [["ol"]], portionen: []), false),
        (Gruppe(woerter: [["essig"]], portionen: []), false),
        (Gruppe(woerter: [["sojasosse", "sojasauce"]], portionen: []), false),
        (Gruppe(woerter: [["sirup"], ["flussig"]], portionen: []), false),
        (Gruppe(woerter: [["milch"]], portionen: []), true),
        (Gruppe(woerter: [["sahne"]], portionen: []), true),
        (Gruppe(woerter: [["saft"]], portionen: []), true),
    ]

    /// Zusätzliche Portionen für ein Lebensmittel, aus dem Namen hergeleitet. Erste treffende Gruppe
    /// gewinnt, damit sich z. B. "Mehl" und "Zucker" nicht überlagern.
    static func portionen(fuer l: Lebensmittel) -> [LebensmittelPortion] {
        let namensWoerter = LebensmittelBasis.normal(l.name).split(separator: " ")
        guard !namensWoerter.isEmpty else { return [] }

        if let treffer = loeffelbar.first(where: { $0.trifft(namensWoerter) }) {
            return treffer.portionen.map { LebensmittelPortion(name: $0.name, gramm: $0.gramm) }
        }
        if l.fluessig, let treffer = fluessig.first(where: { $0.gruppe.trifft(namensWoerter) }) {
            var portionen = [("Teelöffel", 5.0), ("Esslöffel", 15.0)]
            if treffer.getraenk { portionen += [("Glas", 200.0), ("Tasse", 180.0)] }
            return portionen.map { LebensmittelPortion(name: $0.0, gramm: $0.1) }
        }
        return []
    }
}

