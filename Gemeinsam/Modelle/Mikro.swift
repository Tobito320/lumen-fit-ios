// Quelle: Lovea Health/Ernaehrung/Mikronaehrstoffe.swift
import Foundation

/// Vitamine, Mineralstoffe und weitere Werte, pro 100 g in `Naehrwerte.mikro` unter `rawValue`.
/// Quellen: USDA FoodData Central (SR Legacy, Nährstoffnummer `usda`) für Grund-Lebensmittel,
/// Open Food Facts (`off`, dort immer in Gramm) für gescannte Produkte.
/// `referenz` = Tagesreferenzmenge (NRV) aus Anhang XIII der EU-Verordnung 1169/2011.
enum Mikro: String, CaseIterable, Codable, Sendable, Identifiable {
    case vitaminA, vitaminD, vitaminE, vitaminK, vitaminC, vitaminB1, vitaminB2, niacin, pantothensaeure, vitaminB6, folat, vitaminB12
    case kalium, calcium, magnesium, phosphor, eisen, zink, kupfer, mangan, selen, natrium, jod
    case wasser, cholesterin, einfachUngesaettigt, mehrfachUngesaettigt, koffein, alkohol

    enum Gruppe: String, CaseIterable { case vitamine = "Vitamine", mineralstoffe = "Mineralstoffe", weitere = "Weitere" }

    var id: String { rawValue }

    var gruppe: Gruppe {
        switch self {
        case .vitaminA, .vitaminD, .vitaminE, .vitaminK, .vitaminC, .vitaminB1, .vitaminB2, .niacin, .pantothensaeure, .vitaminB6, .folat, .vitaminB12:
            .vitamine
        case .kalium, .calcium, .magnesium, .phosphor, .eisen, .zink, .kupfer, .mangan, .selen, .natrium, .jod:
            .mineralstoffe
        case .wasser, .cholesterin, .einfachUngesaettigt, .mehrfachUngesaettigt, .koffein, .alkohol:
            .weitere
        }
    }

    var name: String {
        switch self {
        case .vitaminA: String(localized: "Vitamin A")
        case .vitaminD: String(localized: "Vitamin D")
        case .vitaminE: String(localized: "Vitamin E")
        case .vitaminK: String(localized: "Vitamin K")
        case .vitaminC: String(localized: "Vitamin C")
        case .vitaminB1: String(localized: "Vitamin B1 (Thiamin)")
        case .vitaminB2: String(localized: "Vitamin B2 (Riboflavin)")
        case .niacin: String(localized: "Vitamin B3 (Niacin)")
        case .pantothensaeure: String(localized: "Vitamin B5 (Pantothensäure)")
        case .vitaminB6: String(localized: "Vitamin B6")
        case .folat: String(localized: "Folat (B9)")
        case .vitaminB12: String(localized: "Vitamin B12")
        case .kalium: String(localized: "Kalium")
        case .calcium: String(localized: "Calcium")
        case .magnesium: String(localized: "Magnesium")
        case .phosphor: String(localized: "Phosphor")
        case .eisen: String(localized: "Eisen")
        case .zink: String(localized: "Zink")
        case .kupfer: String(localized: "Kupfer")
        case .mangan: String(localized: "Mangan")
        case .selen: String(localized: "Selen")
        case .natrium: String(localized: "Natrium")
        case .jod: String(localized: "Jod")
        case .wasser: String(localized: "Wasser")
        case .cholesterin: String(localized: "Cholesterin")
        case .einfachUngesaettigt: String(localized: "Einfach ungesättigte Fettsäuren")
        case .mehrfachUngesaettigt: String(localized: "Mehrfach ungesättigte Fettsäuren")
        case .koffein: String(localized: "Koffein")
        case .alkohol: String(localized: "Alkohol")
        }
    }

    /// Einheit der gespeicherten Zahl.
    var einheit: String {
        switch self {
        case .vitaminA, .vitaminD, .vitaminK, .folat, .vitaminB12, .selen, .jod: "µg"
        case .wasser, .einfachUngesaettigt, .mehrfachUngesaettigt, .alkohol: "g"
        default: "mg"
        }
    }

    /// NRV nach EU 1169/2011 Anhang XIII, in `einheit`. nil = keine Referenzmenge festgelegt.
    var referenz: Double? {
        switch self {
        case .vitaminA: 800
        case .vitaminD: 5
        case .vitaminE: 12
        case .vitaminK: 75
        case .vitaminC: 80
        case .vitaminB1: 1.1
        case .vitaminB2: 1.4
        case .niacin: 16
        case .pantothensaeure: 6
        case .vitaminB6: 1.4
        case .folat: 200
        case .vitaminB12: 2.5
        case .kalium: 2000
        case .calcium: 800
        case .magnesium: 375
        case .phosphor: 700
        case .eisen: 14
        case .zink: 10
        case .kupfer: 1
        case .mangan: 2
        case .selen: 55
        case .jod: 150
        default: nil
        }
    }

    /// USDA-Nährstoffnummer (nutrient_nbr) in SR Legacy.
    var usda: String? {
        switch self {
        case .vitaminA: "320"
        case .vitaminD: "328"
        case .vitaminE: "323"
        case .vitaminK: "430"
        case .vitaminC: "401"
        case .vitaminB1: "404"
        case .vitaminB2: "405"
        case .niacin: "406"
        case .pantothensaeure: "410"
        case .vitaminB6: "415"
        case .folat: "435"
        case .vitaminB12: "418"
        case .kalium: "306"
        case .calcium: "301"
        case .magnesium: "304"
        case .phosphor: "305"
        case .eisen: "303"
        case .zink: "309"
        case .kupfer: "312"
        case .mangan: "315"
        case .selen: "317"
        case .natrium: "307"
        case .jod: nil
        case .wasser: "255"
        case .cholesterin: "601"
        case .einfachUngesaettigt: "645"
        case .mehrfachUngesaettigt: "646"
        case .koffein: "262"
        case .alkohol: "221"
        }
    }

    /// Schlüssel in Open Food Facts `nutriments` (ohne "_100g").
    var off: String {
        switch self {
        case .vitaminA: "vitamin-a"
        case .vitaminD: "vitamin-d"
        case .vitaminE: "vitamin-e"
        case .vitaminK: "vitamin-k"
        case .vitaminC: "vitamin-c"
        case .vitaminB1: "vitamin-b1"
        case .vitaminB2: "vitamin-b2"
        case .niacin: "vitamin-pp"
        case .pantothensaeure: "pantothenic-acid"
        case .vitaminB6: "vitamin-b6"
        case .folat: "vitamin-b9"
        case .vitaminB12: "vitamin-b12"
        case .kalium: "potassium"
        case .calcium: "calcium"
        case .magnesium: "magnesium"
        case .phosphor: "phosphorus"
        case .eisen: "iron"
        case .zink: "zinc"
        case .kupfer: "copper"
        case .mangan: "manganese"
        case .selen: "selenium"
        case .natrium: "sodium"
        case .jod: "iodine"
        case .wasser: "water"
        case .cholesterin: "cholesterol"
        case .einfachUngesaettigt: "monounsaturated-fat"
        case .mehrfachUngesaettigt: "polyunsaturated-fat"
        case .koffein: "caffeine"
        case .alkohol: "alcohol"
        }
    }

    /// Open Food Facts speichert `_100g` in Gramm (außer Alkohol, siehe `ausOpenFoodFacts`).
    var ausGramm: Double {
        switch einheit {
        case "µg": 1_000_000
        case "mg": 1000
        default: 1
        }
    }

    /// Alle Mikronährstoffe aus den `nutriments` eines Open-Food-Facts-Produkts, pro 100 g.
    static func ausOpenFoodFacts(_ n: [String: Any]) -> [String: Double]? {
        var werte: [String: Double] = [:]
        for m in Mikro.allCases {
            guard let g = ErnaehrungLogik.zahlWert(n["\(m.off)_100g"]), g >= 0 else { continue }
            // Alkohol steht dort in % vol: 1 % vol = 0,789 g pro 100 ml.
            werte[m.rawValue] = m == .alkohol ? g * 0.789 : g * m.ausGramm
        }
        return werte.isEmpty ? nil : werte
    }
}
