// Quelle: Lovea Health/Ernaehrung/EssenAmpel.swift
import Foundation

// Halal- und Zucker-Ampel nach dem Barcode-Scan. Reine Logik, ohne Netz.
// Nur ein Hinweis aus Zutatenliste und Nährwerten, keine Garantie: Zutatenlisten sind oft lückenhaft.

enum AmpelStufe: Int, Equatable, Sendable {
    case gruen, gelb, rot
}

struct AmpelUrteil: Equatable, Sendable {
    let stufe: AmpelStufe
    let grund: String
    /// Die Daten fehlen (keine Zutaten, kein Zuckerwert): die Stufe ist dann nur `gelb`, gemeint ist "unklar".
    let unklar: Bool

    init(stufe: AmpelStufe, grund: String, unklar: Bool = false) {
        self.stufe = stufe
        self.grund = grund
        self.unklar = unklar
    }
}

enum EssenAmpel {
    // MARK: Halal

    /// E-Nummern (nur die Ziffern) mit Namen. Rot: sicher tierisch/verboten. Gelb: tierisch oder pflanzlich, Herkunft offen.
    private static let eRot: [String: String] = ["441": String(localized: "Gelatine")]
    private static let eGelb: [String: String] = [
        "120": String(localized: "Karmin"), "422": String(localized: "Glycerin"), "470": String(localized: "Fettsäuresalze"), "471": String(localized: "Mono-/Diglyceride"), "472": String(localized: "Fettsäureester"),
        "473": String(localized: "Zuckerester"), "474": String(localized: "Zuckerglyceride"), "475": String(localized: "Polyglycerinester"), "476": String(localized: "Polyglycerin-Polyricinoleat"),
        "477": String(localized: "Propylenglycolester"), "478": String(localized: "Lactylierte Fettsäureester"), "479": String(localized: "Sojaöl-Ester"), "481": String(localized: "Natriumlactylat"),
        "482": String(localized: "Calciumlactylat"), "483": String(localized: "Stearyltartrat"), "491": String(localized: "Sorbitanester"), "492": String(localized: "Sorbitanester"),
        "493": String(localized: "Sorbitanester"), "494": String(localized: "Sorbitanester"), "495": String(localized: "Sorbitanester"), "542": String(localized: "Knochenphosphat"),
        "570": String(localized: "Stearinsäure"), "572": String(localized: "Magnesiumstearat"), "631": String(localized: "Inosinat"), "635": String(localized: "Ribonucleotide"),
        "904": String(localized: "Schellack"), "913": String(localized: "Lanolin"), "920": String(localized: "L-Cystein"),
    ]

    /// Ganzes Wort im Text (nach Kleinschreibung, ohne Umlaute, ß = ss).
    private static let halalRotWoerter: Set<String> = [
        "ham", "lard", "rum", "wine", "beer", "bier", "wein", "rotwein", "weisswein", "rosewein", "sekt", "likor", "likoer",
        "liqueur", "whisky", "whiskey", "vodka", "gin", "brandy", "cognac", "weinbrand", "branntwein", "pancetta", "prosciutto",
    ]
    /// Teil eines Worts (Komposita wie "Schweineschmalz").
    private static let halalRotTeile: [String] = ["schwein", "schinken", "speck", "gelatin", "alkohol", "alcohol", "ethanol", "pork", "bacon"]
    private static let halalGelbWoerter: Set<String> = [
        "karmin", "carmin", "cochenille", "cochineal", "schellack", "shellac", "glycerin", "glycerol", "cystein", "cysteine",
        "lab", "labferment", "rennet", "diglyceride", "monoglyceride", "diglycerides", "monoglycerides", "salami", "mirin",
        "fleisch", "rind", "kalb", "lamm", "pute", "ente", "gans", "beef", "meat", "turkey", "lamb", "veal", "weinessig",
    ]
    private static let halalGelbTeile: [String] = ["huhn", "hahnchen", "geflugel", "wurst", "chicken", "poultry", "rindfleisch", "hackfleisch"]

    /// Text klein, ohne Umlaute, "alkoholfrei" und Ähnliches entfernt, in Wörter zerlegt.
    private static func woerter(_ text: String) -> [String] {
        var t = text.replacingOccurrences(of: "ß", with: "ss").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        for satz in ["ohne alkohol", "alcohol free", "alcohol-free", "non alcoholic", "non-alcoholic"] {
            t = t.replacingOccurrences(of: satz, with: " ")
        }
        return t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// "e441", "e 441", "e472a" -> "441"; sonst nil.
    private static func eZiffern(_ w: [String], _ i: Int) -> String? {
        var t = w[i]
        if t == "e", i + 1 < w.count { t += w[i + 1] }
        guard t.count >= 4, t.count <= 7, t.hasPrefix("e") else { return nil }
        let rest = t.dropFirst()
        let ziffern = rest.prefix { $0.isNumber }
        guard ziffern.count >= 3, ziffern.count <= 4 else { return nil }
        let endung = rest.dropFirst(ziffern.count)
        guard endung.count <= 2, endung.allSatisfy(\.isLetter) else { return nil }
        return String(ziffern)
    }

    /// Fundstellen in der Zutatenliste: (rot, gelb) als Anzeigetexte.
    static func halalFunde(_ zutaten: String) -> (rot: [String], gelb: [String]) {
        let w = woerter(zutaten)
        var rot: [String] = []
        var gelb: [String] = []
        func merke(_ liste: inout [String], _ text: String) { if !liste.contains(text) { liste.append(text) } }
        for i in w.indices {
            let t = w[i]
            if let e = eZiffern(w, i) {
                if let name = eRot[e] { merke(&rot, "E\(e) (\(name))") }
                if let name = eGelb[e] { merke(&gelb, "E\(e) (\(name))") }
                continue
            }
            // "alkoholfrei", "gelatinefrei", "schweinefrei": Wort sagt selbst, dass es fehlt.
            if t.contains("frei") { continue }
            if halalRotWoerter.contains(t) || halalRotTeile.contains(where: { t.contains($0) }) {
                merke(&rot, t)
            } else if halalGelbWoerter.contains(t) || halalGelbTeile.contains(where: { t.contains($0) }) {
                merke(&gelb, t)
            }
        }
        return (rot, gelb)
    }

    static func halal(zutaten: String?, siegel: [String]?) -> AmpelUrteil {
        let text = zutaten?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hatSiegel = (siegel ?? []).contains { $0.lowercased().contains("halal") }
        if text.isEmpty {
            return hatSiegel ? AmpelUrteil(stufe: .gruen, grund: String(localized: "Halal-Siegel, Zutaten fehlen"))
                             : AmpelUrteil(stufe: .gelb, grund: String(localized: "Keine Zutaten bekannt, kein Halal-Siegel"), unklar: true)
        }
        let funde = halalFunde(text)
        if !funde.rot.isEmpty { return AmpelUrteil(stufe: .rot, grund: String(localized: "Enthält \(funde.rot.prefix(2).joined(separator: ", "))")) }
        if hatSiegel { return AmpelUrteil(stufe: .gruen, grund: String(localized: "Halal-Siegel")) }
        if !funde.gelb.isEmpty { return AmpelUrteil(stufe: .gelb, grund: String(localized: "Prüfen: \(funde.gelb.prefix(2).joined(separator: ", ")), kein Siegel")) }
        return AmpelUrteil(stufe: .gruen, grund: String(localized: "Nichts Auffälliges in den Zutaten"))
    }

    static func halal(_ l: Lebensmittel) -> AmpelUrteil { halal(zutaten: l.zutaten, siegel: l.siegel) }

    // MARK: Zucker

    /// Pro 100 g/ml: bis 0,5 zuckerfrei, bis 5 (Getränke 2,5) wenig, darüber rot. Gleiche Grenzen wie `FoodRating`.
    private static let zuckerWoerter: Set<String> = [
        "zucker", "sugar", "sirup", "syrup", "glukose", "glucose", "fruktose", "fructose", "dextrose", "saccharose", "sucrose",
        "honig", "honey", "maltose", "invertzucker", "maltodextrin", "glukosesirup", "fruktosesirup", "traubenzucker", "fruchtzucker",
    ]

    static func zucker(_ l: Lebensmittel) -> AmpelUrteil {
        let einheit = l.fluessig ? "ml" : "g"
        if let z = l.pro100.zucker {
            let wert = ErnaehrungLogik.zahl(z)
            if z <= 0.5 { return AmpelUrteil(stufe: .gruen, grund: String(localized: "Zuckerfrei, \(wert) g pro 100 \(einheit)")) }
            if z <= (l.fluessig ? 2.5 : 5) { return AmpelUrteil(stufe: .gelb, grund: String(localized: "Wenig Zucker, \(wert) g pro 100 \(einheit)")) }
            return AmpelUrteil(stufe: .rot, grund: String(localized: "\(wert) g Zucker pro 100 \(einheit)"))
        }
        if let text = l.zutaten, woerter(text).contains(where: { zuckerWoerter.contains($0) }) {
            return AmpelUrteil(stufe: .gelb, grund: String(localized: "Zucker in den Zutaten, Menge fehlt"), unklar: true)
        }
        return AmpelUrteil(stufe: .gelb, grund: String(localized: "Zuckerwert fehlt"), unklar: true)
    }
}

/// Zutaten einmalig bei Open Food Facts nachladen (Quelle: Lovea EssenAmpelKarte): reine Regeln, das Netz fragt `LebensmittelSuche.zutatenNachladen`.
enum EssenAmpelNachladen {
    /// Nur wenn Zutaten fehlen und ein Barcode da ist, und nie beim Bearbeiten eines Eintrags.
    static func braucht(_ l: Lebensmittel, bearbeiten: Bool) -> Bool {
        guard !bearbeiten, let code = l.barcode, !code.isEmpty else { return false }
        return (l.zutaten ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Das Lebensmittel mit Zutaten und Siegeln aus dem Nachgeladenen; ein vorhandener Zuckerwert bleibt. Ohne Nachgeladenes unverändert.
    static func zusammen(_ l: Lebensmittel, geladen: Lebensmittel?) -> Lebensmittel {
        guard let geladen else { return l }
        var neu = l
        neu.zutaten = geladen.zutaten
        neu.siegel = geladen.siegel
        if neu.pro100.zucker == nil { neu.pro100.zucker = geladen.pro100.zucker }
        return neu
    }
}

/// Was die Pille zeigt: immer Symbol und Text, nie nur Farbe. Fehlende Daten heißen "unklar".
struct EssenAmpelAnzeige: Equatable, Sendable {
    let symbol: String
    let text: String
    let grund: String

    static func halal(_ u: AmpelUrteil) -> EssenAmpelAnzeige {
        if u.unklar { return EssenAmpelAnzeige(symbol: "questionmark.circle.fill", text: String(localized: "Halal: unklar"), grund: u.grund) }
        switch u.stufe {
        case .gruen: return EssenAmpelAnzeige(symbol: "checkmark.circle.fill", text: String(localized: "Halal: unauffällig"), grund: u.grund)
        case .gelb: return EssenAmpelAnzeige(symbol: "exclamationmark.triangle.fill", text: String(localized: "Halal: prüfen"), grund: u.grund)
        case .rot: return EssenAmpelAnzeige(symbol: "xmark.circle.fill", text: String(localized: "Halal: nicht geeignet"), grund: u.grund)
        }
    }

    static func zucker(_ u: AmpelUrteil) -> EssenAmpelAnzeige {
        if u.unklar { return EssenAmpelAnzeige(symbol: "questionmark.circle.fill", text: String(localized: "Zucker: unklar"), grund: u.grund) }
        switch u.stufe {
        case .gruen: return EssenAmpelAnzeige(symbol: "checkmark.circle.fill", text: String(localized: "Zuckerfrei"), grund: u.grund)
        case .gelb: return EssenAmpelAnzeige(symbol: "exclamationmark.triangle.fill", text: String(localized: "Wenig Zucker"), grund: u.grund)
        case .rot: return EssenAmpelAnzeige(symbol: "xmark.circle.fill", text: String(localized: "Viel Zucker"), grund: u.grund)
        }
    }
}
