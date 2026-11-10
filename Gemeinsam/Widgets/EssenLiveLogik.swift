// Quelle: Lovea Health/Ernaehrung/EssenLive.swift
import Foundation

/// Reine Rechnung der Essen-Live-Activity ohne ActivityKit: Stand aus dem Tagebuch, Anzeige-Texte, Bogenanteil, Entscheidung was mit der Activity geschieht.
enum EssenLiveLogik {
    /// Was mit der laufenden Activity geschehen soll.
    enum Aktion: Equatable, Sendable { case nichts, starten, aktualisieren, beenden }

    /// Der Stand von `tag` aus den Einträgen dieses Tages. `stunde` (0 bis 23) bestimmt die nächste Mahlzeit.
    static func stand(eintraege: [EssenEintrag], ziele: ErnaehrungsZiele, tag: String, stunde: Int) -> EssenLiveStand {
        let summe = ErnaehrungLogik.summe(eintraege)
        let mahlzeiten = Mahlzeit.allCases.map { m in
            Int(ErnaehrungLogik.summe(eintraege.filter { $0.mahlzeit == m }).kcal.rounded())
        }
        return EssenLiveStand(
            tag: tag, kcal: Int(summe.kcal.rounded()), kcalZiel: ziele.kcal,
            proteinG: Int(summe.protein.rounded()), proteinZiel: ziele.protein,
            kohlenhydrateG: Int(summe.kohlenhydrate.rounded()), kohlenhydrateZiel: ziele.kohlenhydrate,
            fettG: Int(summe.fett.rounded()), fettZiel: ziele.fett,
            mahlzeitenKcal: mahlzeiten, naechste: naechsteMahlzeit(mahlzeitenKcal: mahlzeiten, stunde: stunde)?.rawValue)
    }

    /// Die Mahlzeit der aktuellen Tageszeit, wenn sie noch leer ist, sonst die nächste leere danach; nil, wenn dahinter keine offen ist.
    static func naechsteMahlzeit(mahlzeitenKcal: [Int], stunde: Int) -> Mahlzeit? {
        let alle = Mahlzeit.allCases
        guard mahlzeitenKcal.count == alle.count, let start = alle.firstIndex(of: Mahlzeit.zurZeit(stunde: stunde)) else { return nil }
        return alle[start...].first { mahlzeitenKcal[alle.firstIndex(of: $0) ?? 0] == 0 }
    }

    /// Anteil 0 bis 1 für Bogen und Balken; ohne Ziel 0, über dem Ziel gekappt (kein zweiter Umlauf).
    static func anteil(_ wert: Int, _ ziel: Int) -> Double {
        guard ziel > 0 else { return 0 }
        return min(max(Double(wert) / Double(ziel), 0), 1)
    }

    static func mahlzeitKcal(_ stand: EssenLiveStand, _ mahlzeit: Mahlzeit) -> Int {
        guard let i = Mahlzeit.allCases.firstIndex(of: mahlzeit), i < stand.mahlzeitenKcal.count else { return 0 }
        return stand.mahlzeitenKcal[i]
    }

    /// Anteil der Mahlzeit an ihrem Richtwert (Tagesziel mal `Mahlzeit.anteil`).
    static func mahlzeitAnteil(_ stand: EssenLiveStand, _ mahlzeit: Mahlzeit) -> Double {
        anteil(mahlzeitKcal(stand, mahlzeit), Int((Double(stand.kcalZiel) * mahlzeit.anteil).rounded()))
    }

    static func naechsteMahlzeit(_ stand: EssenLiveStand) -> Mahlzeit? {
        stand.naechste.flatMap { Mahlzeit(rawValue: $0) }
    }

    // MARK: - Texte

    static func zahl(_ wert: Int) -> String {
        wert.formatted(.number.grouping(.automatic).locale(Locale(identifier: "de_DE")))
    }

    /// "1.240 von 2.000 kcal"
    static func kcalText(_ stand: EssenLiveStand) -> String { String(localized: "\(zahl(stand.kcal)) von \(zahl(stand.kcalZiel)) kcal") }

    /// "760 kcal übrig" oder "240 kcal drüber"
    static func restText(_ stand: EssenLiveStand) -> String {
        let rest = stand.kcalZiel - stand.kcal
        return rest >= 0 ? String(localized: "\(zahl(rest)) kcal übrig") : String(localized: "\(zahl(-rest)) kcal drüber")
    }

    /// "Protein 85 von 120 g"
    static func proteinText(_ stand: EssenLiveStand) -> String { String(localized: "Protein \(String(stand.proteinG)) von \(String(stand.proteinZiel)) g") }

    /// "Als Nächstes: Abendessen" oder "Alle Mahlzeiten eingetragen" (nur wenn heute schon etwas steht, sonst "Noch nichts eingetragen").
    static func naechsteText(_ stand: EssenLiveStand) -> String {
        if let m = naechsteMahlzeit(stand) { return String(localized: "Als Nächstes: \(m.name)") }
        return stand.kcal > 0 ? String(localized: "Heute alles eingetragen") : String(localized: "Noch nichts eingetragen")
    }

    /// Ein Satz für VoiceOver über die ganze Karte.
    static func sprechtext(_ stand: EssenLiveStand) -> String {
        String(localized: "Essen heute: \(kcalText(stand)), \(restText(stand)). \(proteinText(stand)). Kohlenhydrate \(String(stand.kohlenhydrateG)) von \(String(stand.kohlenhydrateZiel)) Gramm, Fett \(String(stand.fettG)) von \(String(stand.fettZiel)) Gramm. \(naechsteText(stand)).")
    }

    // MARK: - Entscheidung

    /// Training läuft oder Schalter aus: beenden (falls etwas läuft). Läuft eine für `heute`: aktualisieren. Läuft keine oder eine vom Vortag: neu starten,
    /// außer die Person hat die von heute weggewischt (`vomNutzerBeendet`): dann bis zum nächsten Tag nichts.
    static func aktion(laufendTag: String?, heute: String, an: Bool, trainingLaeuft: Bool, vomNutzerBeendet: Bool) -> Aktion {
        guard an, !trainingLaeuft else { return laufendTag == nil ? .nichts : .beenden }
        if laufendTag == heute { return .aktualisieren }
        if laufendTag == nil && vomNutzerBeendet { return .nichts }
        return .starten
    }
}

/// Der Schalter der Essen-Live-Activity: nur ein Haken in UserDefaults mit eigenem Schlüssel (Standard aus, wie in Lovea), kein Profildatum und kein Sync.
enum EssenLiveEinstellung {
    nonisolated static let schluessel = "fit.essen.live"

    static func an(_ speicher: UserDefaults = .standard) -> Bool { speicher.bool(forKey: schluessel) }

    static func setze(_ an: Bool, _ speicher: UserDefaults = .standard) { speicher.set(an, forKey: schluessel) }
}
