import Foundation

/// Ein Treffer von Open Food Facts mit den Feldern, nach denen die Rangfolge sortiert (`countries_tags`, `popularity_key`).
/// Wird nicht gespeichert: nur `essen` landet in der Liste.
struct SuchKandidat: Sendable {
    var essen: Lebensmittel
    var laender: [String]
    var beliebtheit: Double
}

/// Rangfolge der Online-Treffer (Open Food Facts liefert Relevanz, aber Marke "Bueno" in Spanien schlägt dort "Kinder Bueno").
/// Reine Logik, ohne Netz. Reihenfolge der Schlüssel, erste Stelle wiegt am meisten:
/// 1. eigene, Favoriten, Zuletzt (`vorne`), 2. mit Nährwerten vor ohne, 3. Namenstreffer vor Markentreffer,
///    ganzes Wort vor Wortanfang vor Teiltreffer, 4. Deutschland, dann Österreich/Schweiz, dann EU, dann Rest,
/// 5. beliebt vor selten, 6. Reihenfolge der Quelle. Müllnamen werden aus der Marke abgeleitet oder entfernt, Doppelte zusammengeführt.
enum SuchRang {
    static let dach = ["en:germany", "en:austria", "en:switzerland"]
    static let eu: Set<String> = [
        "en:belgium", "en:bulgaria", "en:croatia", "en:cyprus", "en:czech-republic", "en:denmark", "en:estonia", "en:finland",
        "en:france", "en:greece", "en:hungary", "en:ireland", "en:italy", "en:latvia", "en:lithuania", "en:luxembourg",
        "en:malta", "en:netherlands", "en:poland", "en:portugal", "en:romania", "en:slovakia", "en:slovenia", "en:spain", "en:sweden",
    ]

    /// Lucene-Zusatz für die Suchanfrage: nur Produkte aus DACH und EU.
    static var laenderFilter: String {
        "countries_tags:(" + (dach + eu.sorted()).map { "\"\($0)\"" }.joined(separator: " OR ") + ")"
    }

    /// 0 Deutschland, 1 Österreich/Schweiz, 2 EU, 3 Rest oder unbekannt.
    static func landStufe(_ laender: [String]) -> Int {
        if laender.contains("en:germany") { return 0 }
        if laender.contains(where: { dach.contains($0) }) { return 1 }
        if laender.contains(where: { eu.contains($0) }) { return 2 }
        return 3
    }

    /// Name leer, "Unbekanntes Produkt" oder nur Ziffern.
    static func nameIstMuell(_ name: String) -> Bool {
        let n = LebensmittelBasis.normal(name)
        return n.isEmpty || n == "unbekanntes produkt" || n.allSatisfy { $0.isNumber || $0 == " " }
    }

    /// Anzeige: Müllname wird zur Marke; ohne Marke gibt es nichts anzuzeigen (nil).
    static func bereinigt(_ l: Lebensmittel) -> Lebensmittel? {
        guard nameIstMuell(l.name) else { return l }
        guard let marke = l.marke?.trimmingCharacters(in: .whitespaces), !marke.isEmpty, !nameIstMuell(marke) else { return nil }
        var neu = l
        neu.name = marke
        neu.marke = nil
        return neu
    }

    static func hatNaehrwerte(_ l: Lebensmittel) -> Bool {
        let n = l.pro100
        return n.kcal > 0 || n.protein > 0 || n.kohlenhydrate > 0 || n.fett > 0
    }

    /// Wörter von Marke und Name ohne Wiederholung: "Kinder" + "Bueno", "Kinder bueno" + "" und "Kinder" + "Kinder Bueno" sind alle "kinder bueno".
    static func dublettenSchluessel(_ l: Lebensmittel) -> String {
        var gesehen = Set<Substring>()
        let w = LebensmittelBasis.normal((l.marke ?? "") + " " + l.name).split(separator: " ")
        return w.filter { gesehen.insert($0).inserted }.joined(separator: " ")
    }

    /// 0 ganzes Wort, 1 Wortanfang, 2 Teiltreffer, nil kein Treffer.
    private static func stufe(_ wort: String, in text: String) -> Int? {
        let ws = text.split(separator: " ")
        if ws.contains(where: { $0 == wort }) { return 0 }
        if ws.contains(where: { $0.hasPrefix(wort) }) { return 1 }
        return text.contains(wort) ? 2 : nil
    }

    /// Je Suchwort: Name 0 bis 2, Marke 3 bis 5, kein Treffer 9. Der schlechteste Wert aller Wörter zählt.
    static func trefferStufe(name: String, marke: String?, text: String) -> Int {
        let n = nameIstMuell(name) ? "" : LebensmittelBasis.normal(name)
        let m = LebensmittelBasis.normal(marke ?? "")
        let woerter = LebensmittelBasis.normal(text).split(separator: " ").map(String.init)
        guard !woerter.isEmpty else { return 0 }
        return woerter.map { w in
            [stufe(w, in: n), stufe(w, in: m).map { $0 + 3 }].compactMap { $0 }.min() ?? 9
        }.max() ?? 9
    }

    static func rangfolge(_ kandidaten: [SuchKandidat], text: String, vorne: Set<String> = []) -> [Lebensmittel] {
        struct Zeile { var essen: Lebensmittel; var schluessel: [Double]; var nr: Int }
        let zeilen: [Zeile] = kandidaten.enumerated().compactMap { nr, k in
            guard let sauber = bereinigt(k.essen) else { return nil }
            let schluessel: [Double] = [
                vorne.contains(k.essen.id) ? 0 : 1,
                hatNaehrwerte(k.essen) ? 0 : 1,
                Double(trefferStufe(name: k.essen.name, marke: k.essen.marke, text: text)),
                Double(landStufe(k.laender)),
                -k.beliebtheit,
            ]
            return Zeile(essen: sauber, schluessel: schluessel, nr: nr)
        }
        let sortiert = zeilen.sorted { a, b in
            for (x, y) in zip(a.schluessel, b.schluessel) where x != y { return x < y }
            return a.nr < b.nr
        }
        var gesehen = Set<String>()
        return sortiert.map(\.essen).filter { gesehen.insert(dublettenSchluessel($0)).inserted }
    }

    /// search.openfoodfacts.org `hits` samt Land und Beliebtheit (`popularity_key`, sonst `unique_scans_n`).
    static func kandidaten(_ data: Data) -> [SuchKandidat] {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let hits = json["hits"] as? [[String: Any]] else { return [] }
        return hits.compactMap { h in
            guard let l = ErnaehrungLogik.lebensmittel(offProdukt: h, code: nil) else { return nil }
            let beliebt = ErnaehrungLogik.zahlWert(h["popularity_key"]) ?? ErnaehrungLogik.zahlWert(h["unique_scans_n"]) ?? 0
            return SuchKandidat(essen: l, laender: h["countries_tags"] as? [String] ?? [], beliebtheit: beliebt)
        }
    }
}
