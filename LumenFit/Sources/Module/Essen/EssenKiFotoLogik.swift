// Quelle: Lovea Health/Ernaehrung/KiFoto.swift (KiFotoLogik)
import Foundation

/// Was der Fehlerbildschirm zeigt und anbietet.
struct EssenKiAnzeige: Equatable, Codable, Sendable {
    let titel: String
    let text: String
    let symbol: String
    /// Dasselbe Foto noch einmal schicken (Netz, Auslastung, kaputte Antwort).
    let nochmal: Bool
    /// Ein neues Foto machen hilft (Foto unlesbar oder zu groß).
    let neuesFoto: Bool
}

/// Gramm, die jemand gegenüber der Schätzung geändert hat. Der Server von Lumen Fit lernt daraus nichts (kein Portionsgedächtnis); die Logik steht bereit.
struct EssenKiKorrektur: Equatable, Sendable {
    let name: String
    let gramm: Double
}

/// Reine Logik hinter "Essen fotografieren": Tagebuch-Einträge aus der Schätzung, Fehlertexte, Bereich, Rückfrage.
/// Ohne Views und ohne Store, damit die Tests nie ein echtes Tagebuch berühren.
enum EssenKiFotoLogik {
    nonisolated static let maxGramm = 5000.0

    nonisolated static let fotoUnlesbar = EssenKiAnzeige(
        titel: String(localized: "Foto nicht lesbar"), text: String(localized: "Mach bitte ein neues Foto."),
        symbol: "photo.badge.exclamationmark", nochmal: false, neuesFoto: true)

    /// Ohne Zustimmung im Blatt geht kein Foto raus (auch nicht beim Nochmal).
    nonisolated static let ohneZustimmung = EssenKiAnzeige(
        titel: String(localized: "Foto-Schätzung nicht erlaubt"),
        text: String(localized: "Erlaube sie zuerst: oben im Foto-Blatt auf das Hand-Symbol tippen. Ohne deine Zustimmung geht kein Foto raus."),
        symbol: "hand.raised", nochmal: false, neuesFoto: false)

    /// Freundlich und mit der Zahl des Servers; ohne Zahl (oder bei 0) ohne Zahl.
    static func tageslimitText(max: Int?) -> String {
        let weiter = String(localized: "Morgen geht es weiter, suchen geht immer.")
        guard let max, max > 0 else { return String(localized: "Das Foto-Limit für heute ist erreicht. \(weiter)") }
        return max == 1 ? String(localized: "Heute ist dein Foto verbraucht. \(weiter)") : String(localized: "Heute sind deine \(max) Fotos verbraucht. \(weiter)")
    }

    static func anzeige(_ f: EssenKiFehler) -> EssenKiAnzeige {
        switch f {
        case .netz:
            EssenKiAnzeige(titel: String(localized: "Keine Verbindung"), text: String(localized: "Prüf dein Netz und versuch es nochmal."),
                           symbol: "wifi.slash", nochmal: true, neuesFoto: false)
        case .zuVieleAnfragen:
            EssenKiAnzeige(titel: String(localized: "Gerade viel los"), text: String(localized: "Versuch es in einem Moment nochmal."),
                           symbol: "hourglass", nochmal: true, neuesFoto: false)
        case .ungueltig, .unbekannt:
            EssenKiAnzeige(titel: String(localized: "Das hat nicht geklappt"), text: String(localized: "Versuch es nochmal oder mach ein neues Foto."),
                           symbol: "exclamationmark.triangle", nochmal: true, neuesFoto: true)
        case .bildZuGross:
            EssenKiAnzeige(titel: String(localized: "Foto zu groß"), text: String(localized: "Mach bitte ein neues Foto."),
                           symbol: "photo.badge.exclamationmark", nochmal: false, neuesFoto: true)
        case .tageslimit(let max):
            EssenKiAnzeige(titel: String(localized: "Foto-Limit erreicht"), text: tageslimitText(max: max),
                           symbol: "moon.zzz", nochmal: false, neuesFoto: false)
        case .guthaben, .nichtEingerichtet:
            EssenKiAnzeige(titel: String(localized: "KI gerade nicht erreichbar"), text: String(localized: "Trag die Mahlzeit solange von Hand ein."),
                           symbol: "bolt.slash", nochmal: false, neuesFoto: false)
        }
    }

    /// Auf dem Foto ist nichts zu essen, oder die KI hat nichts erkannt.
    static func keinEssen(_ a: EssenKiAnalyse) -> Bool { !a.istEssen || a.items.isEmpty }

    static func keinEssenText(_ a: EssenKiAnalyse) -> String {
        let t = a.bemerkung.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? String(localized: "Auf dem Foto ist kein Essen zu erkennen.") : t
    }

    /// Ein Tagebuch-Eintrag je Zutat (in g) und je unsichtbarer Zutat. Die Zahl auf dem Knopf ist `kcal(eintraege)`,
    /// also genau das, was danach im Tagebuch steht.
    static func eintraege(komponenten: [EssenKiKomponente], versteckt: [EssenKiVersteckt], versteckteZaehlen: Bool,
                          mahlzeit: Mahlzeit, datum: String) -> [EssenEintrag] {
        func eintrag(_ name: String, gramm: Double, pro100: Naehrwerte) -> EssenEintrag {
            let l = Lebensmittel(id: "ki-\(UUID().uuidString)", name: name, marke: "KI-Schätzung", pro100: pro100)
            return EssenEintrag(id: UUID().uuidString, datum: datum, mahlzeit: mahlzeit, menge: gramm, einheit: .g,
                                lebensmittel: l, geloescht: nil)
        }
        let zutaten = komponenten.filter { $0.gramm > 0 }.map {
            eintrag($0.name, gramm: min($0.gramm, maxGramm),
                    pro100: Naehrwerte(kcal: $0.kcalPro100, protein: $0.proteinPro100,
                                       kohlenhydrate: $0.kohlenhydratePro100, fett: $0.fettPro100))
        }
        guard versteckteZaehlen else { return zutaten }
        // Unsichtbares ist meist Öl oder Butter, also als Fett rechnen (9 kcal pro g).
        let unsichtbar = versteckt.filter { $0.kcal > 0 }.map { v in
            let g = v.gramm > 0 ? v.gramm : 100
            let kcalProG = Double(v.kcal) / g
            return eintrag("\(v.name) (nicht sichtbar)", gramm: g,
                           pro100: Naehrwerte(kcal: kcalProG * 100, fett: kcalProG / 9 * 100))
        }
        return zutaten + unsichtbar
    }

    static func kcal(_ liste: [EssenEintrag]) -> Int { Int(ErnaehrungLogik.summe(liste).kcal.rounded()) }

    /// Name für die Bestätigung: die ersten zwei Zutaten.
    static func titel(_ komponenten: [EssenKiKomponente]) -> String {
        let namen = komponenten.prefix(2).map(\.name).joined(separator: ", ")
        if namen.isEmpty { return String(localized: "Foto-Mahlzeit") }
        return komponenten.count > 2 ? namen + " …" : namen
    }

    /// "wahrscheinlich zwischen X und Y": nur sinnvoll, solange niemand Gramm geändert oder Zutaten entfernt hat.
    /// Der Server rechnet `kcal_min` nur aus den Zutaten, `kcal_max` aber schon mit den versteckten Kalorien.
    static func bereich(_ g: EssenKiAnalyse.Gesamt, versteckteKcal v: Int, gezaehlt: Bool) -> ClosedRange<Int>? {
        guard g.kcalMin > 0 else { return nil }
        let unten = g.kcalMin + (gezaehlt ? v : 0)
        let oben = gezaehlt ? g.kcalMax : g.kcalMax - v
        guard oben > unten else { return nil }
        return unten...oben
    }

    /// Wie sicher die KI bei einer Zutat ist, als Wort, nicht nur als Symbol.
    static func sicherheit(_ s: String) -> (text: String, symbol: String) {
        switch s {
        case "hoch": (String(localized: "sicher"), "checkmark.circle.fill")
        case "niedrig": (String(localized: "unsicher"), "questionmark.circle.fill")
        default: (String(localized: "ungefähr"), "circle.lefthalf.filled")
        }
    }

    /// Gramm, die der Nutzer gegenüber der Schätzung geändert hat.
    static func korrekturen(_ komponenten: [EssenKiKomponente], urspruenglich: [UUID: Double], entfernt: Set<UUID>) -> [EssenKiKorrektur] {
        komponenten.compactMap { k in
            guard !entfernt.contains(k.id), k.gramm > 0, let alt = urspruenglich[k.id], abs(k.gramm - alt) >= 1 else { return nil }
            return EssenKiKorrektur(name: k.name, gramm: k.gramm)
        }
    }

    /// Der Server liest höchstens 300 Zeichen. Bei Überlänge bleibt das Ende, also die Antwort.
    static func hinweis(frage: String, antwort: String) -> String {
        String("Frage: \(frage) Antwort: \(antwort.trimmingCharacters(in: .whitespacesAndNewlines))".suffix(300))
    }

    /// Erst kurz vor Schluss sagen, wie viele Fotos heute noch gehen.
    static func restText(_ rest: Int?) -> String? {
        guard let rest, rest <= 5 else { return nil }
        switch rest {
        case ..<1: return String(localized: "Das war dein letztes Foto für heute.")
        case 1: return String(localized: "Noch 1 Foto für heute.")
        default: return String(localized: "Noch \(rest) Fotos für heute.")

        }
    }
}
