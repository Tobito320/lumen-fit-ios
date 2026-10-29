// Quelle: Lovea Health/Koerper/ErholungsLogik.swift
import Foundation

/// Das letzte Training eines Teils: die Einheit, auf die `MuskelLogik.erholung` rechnet, mit Tag und den
/// Übungen daraus, die dem Teil Sätze gaben.
struct KoerperLetztes: Equatable, Sendable {
    /// Ende der Einheit, sonst Start: ab dieser Zeit läuft die Erholung.
    let zeit: Date
    /// Tag des Starts, `yyyy-MM-dd`.
    let tag: String
    let uebungen: [String]

    /// "Mo 13.10. · Latzug eng, Rudern am Kabel"; ab vier Übungen "… und 2 weitere".
    var text: String {
        let namen = uebungen.prefix(3).joined(separator: ", ")
        let mehr = uebungen.count > 3 ? " und \(uebungen.count - 3) weitere" : ""
        return "\(KoerperLogik.tagKurz(tag)) · \(namen)\(mehr)"
    }
}

/// Wie erholt ein Teil ist und was ihn zuletzt trainiert hat: der Kopf des Blatts einer Muskelgruppe.
struct KoerperStand: Equatable, Sendable {
    let teil: MuskelTeil
    let prozent: Int
    let letztes: KoerperLetztes?

    var stufe: ErholungsStufe { MuskelLogik.stufe(prozent) }
}

/// Die Legende der Muskelkarte, damit die Farbe nie allein trägt: welche Teile noch nicht erholt sind (jeder mit
/// Prozent), welche Gruppen ganz erholt sind und welche noch kein erfasstes Training haben. Ein Teil, der nicht
/// in der Liste steht, ist erholt oder ohne Training (grau).
struct KoerperLegende: Equatable, Sendable {
    struct Eintrag: Equatable, Identifiable, Sendable {
        let teil: MuskelTeil
        let prozent: Int

        var id: MuskelTeil { teil }
        var gruppe: MuskelGruppe { teil.gruppe }
        var stufe: ErholungsStufe { MuskelLogik.stufe(prozent) }
        var name: String { KoerperLogik.teilName(teil) }
        var wort: String { KoerperLogik.stufenWort(stufe) }
    }

    /// Noch nicht erholt (unter 90 %), jeder Teil einzeln, der müdeste zuerst.
    let offen: [Eintrag]
    /// Training erfasst, alles darin bei 90 % oder mehr.
    let erholt: [MuskelGruppe]
    /// Kein Training erfasst.
    let leer: [MuskelGruppe]

    /// Noch gar nichts erfasst: die Karte bleibt grau und lädt zum Training ein.
    var keinTraining: Bool { offen.isEmpty && erholt.isEmpty }

    /// Für VoiceOver: dieselbe Auskunft wie die Liste unter der Karte.
    var sprechtext: String {
        if keinTraining { return "Noch kein Training erfasst." }
        var teile = offen.map { "\($0.name) \($0.prozent) Prozent, \($0.wort.lowercased())" }
        if !erholt.isEmpty { teile.append("Erholt: " + erholt.map(\.name).joined(separator: ", ")) }
        if !leer.isEmpty { teile.append("Kein Training erfasst: " + leer.map(\.name).joined(separator: ", ")) }
        return teile.joined(separator: ". ")
    }
}

extension KoerperLogik {
    /// "Erholt", "Fast erholt", "Müde".
    static func stufenWort(_ s: ErholungsStufe) -> String {
        s == .erholt ? "Erholt" : s == .fast ? "Fast erholt" : "Müde"
    }

    /// Der Teil mit dem niedrigsten Wert unter den Teilen, die Training haben; `nil`, wenn keiner eins hat.
    /// Bei Gleichstand der erste in der Reihenfolge von `teile`.
    static func grenzteil(_ erholung: [MuskelTeil: Int], _ teile: [MuskelTeil]) -> MuskelTeil? {
        teile.filter { erholung[$0] != nil }.min { (erholung[$0] ?? 100) < (erholung[$1] ?? 100) }
    }

    /// Der Teil, den ein Tipp auf eine Fläche (ihre `teile` in `gruppe`) dem Blatt meldet: der schlechteste mit
    /// Training. Ohne Training in der Fläche ihr erster Teil, wenn die Gruppe sonst Training hat: das Blatt sagt dann
    /// "Kein Training erfasst", statt den Stand eines anderen Teils der Gruppe zu zeigen. Ist die ganze Gruppe grau,
    /// `nil`: das Blatt zeigt nur die Gruppe.
    static func tippTeil(_ erholung: [MuskelTeil: Int], gruppe: MuskelGruppe, flaeche teile: [MuskelTeil]) -> MuskelTeil? {
        if let t = grenzteil(erholung, teile) { return t }
        let gruppeHatTraining = MuskelTeil.allCases.contains { $0.gruppe == gruppe && erholung[$0] != nil }
        return gruppeHatTraining ? teile.first : nil
    }

    /// Je Gruppe in `reihenfolge`: ihre Teile unter 90 % einzeln (müdeste zuerst, bei gleichem Wert in der Reihenfolge
    /// der Gruppen und Teile), sonst die Gruppe als erholt oder ohne erfasstes Training. Nicht nur der schlechteste
    /// Teil je Gruppe, sonst hätte ein orangefarbener Quadrizeps neben dem roten Po keinen Text.
    static func legende(_ erholung: [MuskelTeil: Int], reihenfolge: [MuskelGruppe]) -> KoerperLegende {
        var offen: [KoerperLegende.Eintrag] = []
        var erholt: [MuskelGruppe] = []
        var leer: [MuskelGruppe] = []
        for g in reihenfolge {
            var trainiert = false
            var unter: [KoerperLegende.Eintrag] = []
            for t in MuskelTeil.allCases where t.gruppe == g {
                guard let wert = erholung[t] else { continue }
                trainiert = true
                if wert < 90 { unter.append(KoerperLegende.Eintrag(teil: t, prozent: wert)) }
            }
            if !trainiert { leer.append(g) } else if unter.isEmpty { erholt.append(g) }
            offen += unter
        }
        let sortiert = offen.enumerated().sorted { a, b in
            a.element.prozent != b.element.prozent ? a.element.prozent < b.element.prozent : a.offset < b.offset
        }
        return KoerperLegende(offen: sortiert.map(\.element), erholt: erholt, leer: leer)
    }

    /// Je Teil das letzte Training: dieselbe Einheit, auf die `MuskelLogik.erholung` rechnet (gleiche Regel: nur
    /// fertige Läufe mit gezählten Sätzen, Zeit = Ende der Einheit, sonst Start, die jüngste gewinnt), dazu die
    /// Übungen daraus, auch als Mitarbeit (Trizeps beim Bankdrücken). `MuskelLogik.saetze` ist privat, darum steht
    /// die Regel hier noch einmal; ein Test hält beide zusammen.
    static func letzte(_ sessions: [GymSession], katalog: (String) -> Uebung?) -> [MuskelTeil: KoerperLetztes] {
        var ergebnis: [MuskelTeil: KoerperLetztes] = [:]
        for s in sessions {
            let zeit = s.ende ?? s.start
            var namen: [MuskelTeil: [String]] = [:]
            for lauf in s.laeufe where lauf.fertig {
                guard let u = katalog(lauf.uebung), let n = lauf.saetze?.count, n > 0 else { continue }
                for (teil, _) in MuskelLogik.teile(u) {
                    var liste = namen[teil] ?? []
                    if !liste.contains(u.name) { liste.append(u.name) }
                    namen[teil] = liste
                }
            }
            for (teil, liste) in namen where zeit > (ergebnis[teil]?.zeit ?? .distantPast) {
                ergebnis[teil] = KoerperLetztes(zeit: zeit, tag: Datum.text(s.start), uebungen: liste)
            }
        }
        return ergebnis
    }
}
