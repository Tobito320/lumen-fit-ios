// Quelle: Lovea Health/SchlafVergleich.swift
import Foundation

// Das Band gegen Health (Uhr oder Handy) je Nacht und der Abgleich daraus. Reine Rechnung auf zwei Werten je Nacht.
// In Lovea stand hier "unsere Schätzung" (Punktesystem) gegen die Uhr; das Punktesystem bleibt dort. Lumen Fit hat zwei echte Quellen:
// die Nacht aus Health und die Nacht aus den Ops `fit.band.schlaf`. Der Verlauf wird aus beiden neu gerechnet (nichts wird gespeichert).
// Der Abgleich ist nur ein Vergleich: die Zahl im Tab bleibt die der gewählten Quelle (`SchlafQuellenWahl`).

/// Eine Schlaf-Messung einer Nacht: Einschlafen, Aufwachen, Schlafminuten (ohne Wachlücken, wie im Schlaf-Tab).
struct SchlafWert: Equatable, Sendable {
    var von: Date
    var bis: Date
    var minuten: Int
}

/// Beide Werte für dieselbe Nacht (Aufwachtag `tag`). Fehlt einer, ist er `nil`; es wird nie mit `nil` überschrieben.
struct SchlafVergleichNacht: Equatable, Sendable {
    var tag: String
    var band: SchlafWert?
    var health: SchlafWert?
    /// Die Nacht liegt vor heute: das Band hat sie vollständig übertragen. Nur fertige Nächte zählen für den Verlauf.
    var fertig: Bool
}

/// Unterschied Band minus Health in Minuten: positiv = Band später oder länger.
struct SchlafAbweichung: Equatable, Sendable {
    var einschlafen: Int
    var aufwachen: Int
    var dauer: Int
}

/// Ergebnis des Abgleichs für eine Nacht: welcher Wert gilt und warum.
struct SchlafUrteil: Equatable, Sendable {
    enum Quelle: Equatable, Sendable { case health, band, gemischt }
    enum Grund: Equatable, Sendable {
        case nurHealth
        case nurBand
        /// Weniger als `mindestNaechte` Nächte mit beiden Werten (inklusive dieser): bis dahin gilt Health.
        case zuWenig(naechte: Int)
        case ausreisser
        /// Anteil des Bands in Prozent.
        case gemischt(bandProzent: Int)
    }

    var quelle: Quelle
    var wert: SchlafWert
    var grund: Grund
}

enum SchlafVergleich {
    static let behalten = 60
    /// Nächte mit beiden Werten (inklusive der betrachteten), ab denen abgeglichen wird.
    static let mindestNaechte = 5
    /// Eine Nacht weicht ab, wenn ihre Dauer-Abweichung mehr als das 3-fache der üblichen Streuung (mindestens so viel) vom Üblichen liegt.
    static let ausreisserMindestens = 45.0
    // shortcut: Gewicht des Bands höchstens die Hälfte (Health kennt Phasen und Uhr zugleich), sinkt mit der Streuung. Mit Referenznächten ließe sich das lernen.
    static let hoechstGewicht = 0.5
    static let streuungsHalbwert = 30.0

    static func wert(_ nacht: SchlafNacht) -> SchlafWert {
        SchlafWert(von: nacht.von, bis: nacht.bis, minuten: nacht.schlafMinuten)
    }

    // MARK: - Abweichung

    /// Einschlafen, Aufwachen und Dauer: Band minus Health. `nil`, wenn einer der beiden Werte fehlt.
    static func abweichung(_ nacht: SchlafVergleichNacht) -> SchlafAbweichung? {
        guard let b = nacht.band, let h = nacht.health else { return nil }
        return SchlafAbweichung(einschlafen: minutenDazwischen(h.von, b.von), aufwachen: minutenDazwischen(h.bis, b.bis), dauer: b.minuten - h.minuten)
    }

    /// Mit `Date` gerechnet, nie mit Uhrzeiten: 23:50 gegen 00:10 sind 20 Minuten.
    private static func minutenDazwischen(_ von: Date, _ bis: Date) -> Int {
        Int((bis.timeIntervalSince(von) / 60).rounded())
    }

    /// "12 min später", "1 h 05 min früher", "gleich".
    static func abstand(_ minuten: Int, mehr: String, weniger: String) -> String {
        SchlafFormat.abstand(minuten, mehr: mehr, weniger: weniger)
    }

    // MARK: - Abgleich

    /// Welcher Wert für `nacht` gilt, gerechnet aus dem Verlauf der anderen Nächte mit beiden Werten.
    /// Ohne Verlauf (unter `mindestNaechte`) gilt Health. Sonst: Weicht die Dauer ungewöhnlich stark ab, gilt Health,
    /// außer es meldet weniger als eine Nacht (Uhr nicht getragen), dann das Band. Sonst wird verschmolzen: das Band
    /// um seine bisherige Abweichung zu Health korrigiert und mit einem Gewicht zu Health gemischt, das mit der Streuung der Abweichung sinkt.
    static func abgleich(_ nacht: SchlafVergleichNacht, verlauf: [SchlafVergleichNacht]) -> SchlafUrteil? {
        switch (nacht.band, nacht.health) {
        case (nil, nil): return nil
        case (let b?, nil): return SchlafUrteil(quelle: .band, wert: b, grund: .nurBand)
        case (nil, let h?): return SchlafUrteil(quelle: .health, wert: h, grund: .nurHealth)
        case let (b?, h?):
            let abweichungen = verlauf.filter { $0.tag != nacht.tag && $0.fertig }.compactMap(abweichung)
            guard abweichungen.count + 1 >= mindestNaechte else {
                return SchlafUrteil(quelle: .health, wert: h, grund: .zuWenig(naechte: abweichungen.count + 1))
            }
            let einschlafen = median(abweichungen.map { Double($0.einschlafen) })
            let aufwachen = median(abweichungen.map { Double($0.aufwachen) })
            let dauer = median(abweichungen.map { Double($0.dauer) })
            let streuung = median(abweichungen.map { abs(Double($0.dauer) - dauer) })
            let heute = Double(b.minuten - h.minuten)
            if abs(heute - dauer) > max(ausreisserMindestens, 3 * streuung) {
                let healthZuKurz = h.minuten < SchlafLogik.mindestNacht && b.minuten >= SchlafLogik.mindestNacht
                return SchlafUrteil(quelle: healthZuKurz ? .band : .health, wert: healthZuKurz ? b : h, grund: .ausreisser)
            }
            let gewicht = hoechstGewicht * streuungsHalbwert / (streuungsHalbwert + streuung)
            let von: Date = mischen(h.von, b.von.addingTimeInterval(-einschlafen * 60), gewicht)
            let bis: Date = mischen(h.bis, b.bis.addingTimeInterval(-aufwachen * 60), gewicht)
            let mischMinuten: Double = Double(h.minuten) * (1 - gewicht) + (Double(b.minuten) - dauer) * gewicht
            let gemischt = SchlafWert(von: von, bis: bis, minuten: max(0, Int(mischMinuten.rounded())))
            return SchlafUrteil(quelle: .gemischt, wert: gemischt, grund: .gemischt(bandProzent: Int((gewicht * 100).rounded())))
        }
    }

    /// Ein Satz für die Karte (und VoiceOver), warum dieser Wert gilt.
    static func satz(_ urteil: SchlafUrteil) -> String {
        switch urteil.grund {
        case .nurHealth: "Kein Band für diese Nacht. Es zählt Health."
        case .nurBand: "Keine Health-Daten für diese Nacht. Es zählt das Band."
        case .zuWenig(let n): "Abgleich ab \(mindestNaechte) Nächten mit Band und Health, bisher \(n). Bis dahin zählt Health."
        case .ausreisser:
            urteil.quelle == .band
                ? "Health meldet weniger als eine Nacht, das Band deutlich mehr (Uhr nicht getragen?). Es zählt das Band."
                : "Diese Nacht weicht ungewöhnlich stark ab. Es zählt Health."
        case .gemischt(let p): "Gemischt: \(100 - p) % Health, \(p) % Band, das Band um seine übliche Abweichung korrigiert."
        }
    }

    private static func mischen(_ a: Date, _ b: Date, _ anteilB: Double) -> Date {
        a.addingTimeInterval(b.timeIntervalSince(a) * anteilB)
    }

    private static func median(_ werte: [Double]) -> Double {
        let s = werte.sorted()
        guard !s.isEmpty else { return 0 }
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    // MARK: - Liste

    /// Neue Werte in die Liste: je Nacht ein Eintrag, nichts wird mit `nil` überschrieben, `fertig` bleibt, sortiert, die letzten `behalten`.
    static func einsetzen(_ liste: [SchlafVergleichNacht], _ neu: SchlafVergleichNacht) -> [SchlafVergleichNacht] {
        var n = neu
        if let alt = liste.first(where: { $0.tag == neu.tag }) {
            n.health = neu.health ?? alt.health
            n.band = neu.band ?? alt.band
            n.fertig = neu.fertig || alt.fertig
        }
        return Array((liste.filter { $0.tag != neu.tag } + [n]).sorted { $0.tag < $1.tag }.suffix(behalten))
    }

    /// Der Verlauf aus Health und den Band-Ops (je Tag gewinnt die zuletzt eingetroffene Op). `heute` ist noch nicht fertig.
    /// Nur Tage, an denen mindestens eine Quelle etwas hat.
    static func verlauf(health: [String: SchlafNacht], band: [BandSchlafOp], heute: String) -> [SchlafVergleichNacht] {
        var liste: [SchlafVergleichNacht] = []
        for n in health.values {
            liste = einsetzen(liste, SchlafVergleichNacht(tag: n.tag, band: nil, health: wert(n), fertig: n.tag < heute))
        }
        for op in band {
            guard let n = SchlafQuellenWahl.nacht(band: op) else { continue }
            // Die zuletzt eingetroffene Op gewinnt: das Band wird ersetzt, nicht aufgefüllt.
            var nacht = liste.first(where: { $0.tag == n.tag }) ?? SchlafVergleichNacht(tag: n.tag, band: nil, health: nil, fertig: n.tag < heute)
            nacht.band = wert(n)
            liste = einsetzen(liste, nacht)
        }
        return liste
    }
}
