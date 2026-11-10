// Quelle: Lovea Health/Verlauf/VerlaufWocheLogik.swift (ohne VerlaufStart: der Start-Knopf gehört dem Modul gym)
import Foundation

/// Reine Zahlen der ruhigen Verlauf-Seite (Gym-Tab aufräumen, 25.10.): Wochen-Zusammenfassung, Gruppenliste
/// mit Balken, Start-Knopf-Text, Highlights. Ohne Zustand, ohne Modellzugriff, alles aus den Einheiten.
enum VerlaufWoche {
    struct Zusammenfassung: Equatable {
        var besuche = 0
        var minuten = 0
        var saetze = 0
    }

    /// Mo bis So von `heute`. Ein Besuch ist ein Trainingstag: eine Einheit oder nur das Gym-Häkchen
    /// (`GymTageLogik.nurAbgehakt`), mit oder ohne Sätze (wie ein Check-in im Studio). Minuten nur aus
    /// ausgecheckten Einheiten, je Einheit höchstens `TrainingLogik.langNach` (vergessenes Auschecken).
    /// Sätze sind die gezählten Sätze der Läufe, nicht die Gruppenwerte (Hilfsmuskeln zählen dort halb).
    static func zusammenfassung(_ sessions: [GymSession], laeufe: [VerlaufLogik.Lauf], gym: [String: Int], heute: String) -> Zusammenfassung {
        let montag = Datum.montagDerWoche(heute)
        let inWoche: (String) -> Bool = { Datum.montagDerWoche($0) == montag }
        let eigene = sessions.filter { inWoche(Datum.text($0.start)) }
        var tage = Set(eigene.map { Datum.text($0.start) })
        tage.formUnion(GymTageLogik.nurAbgehakt(sessions: sessions, gym: gym).filter(inWoche))
        let sekunden = eigene.compactMap { s in s.ende.map { min(max(0, $0.timeIntervalSince(s.start)), TrainingLogik.langNach) } }
        return Zusammenfassung(
            besuche: tage.count,
            minuten: Int(sekunden.reduce(0, +) / 60),
            saetze: laeufe.filter { inWoche($0.tag) }.reduce(0) { $0 + $1.saetze.count }
        )
    }

    // MARK: Gruppenliste

    struct Zeile: Equatable, Identifiable {
        let gruppe: MuskelGruppe
        let saetze: Double
        /// Wochenziel in Sätzen; nil ohne Ziel (auch Ziel 0).
        let ziel: Int?
        /// nil = für die Gruppe ist kein Training erfasst (kein Punkt, nicht als erholt lesen).
        let erholung: ErholungsStufe?
        var id: MuskelGruppe { gruppe }

        /// 0...1 gegen das Wochenziel; nil ohne Ziel.
        var anteil: Double? { ziel.map { min(1, max(0, saetze / Double($0))) } }
    }

    struct Liste: Equatable {
        /// Gruppen mit Sätzen diese Woche.
        var aktiv: [Zeile]
        /// Gruppen ohne Sätze diese Woche, zusammengeklappt unter "Weitere Gruppen".
        var weitere: [Zeile]
    }

    static func liste(saetze: [MuskelGruppe: Double], ziele: [MuskelGruppe: Int], erholung: [MuskelGruppe: ErholungsStufe],
                      reihenfolge: [MuskelGruppe] = MuskelGruppe.allCases) -> Liste {
        let zeilen = reihenfolge.map { g in
            Zeile(gruppe: g, saetze: saetze[g] ?? 0, ziel: ziele[g].flatMap { $0 > 0 ? $0 : nil }, erholung: erholung[g])
        }
        return Liste(aktiv: zeilen.filter { $0.saetze > 0 }, weitere: zeilen.filter { $0.saetze <= 0 })
    }

    // MARK: Start-Knopf

    /// "Heute: Push starten". Name leer = "Training", kein Plantag heute = freies Training.
    static func startText(_ knopf: VerlaufStartArt, tagName: String?) -> String {
        let name = tagName.map { $0.isEmpty ? String(localized: "Training") : $0 } ?? String(localized: "Freies Training")
        switch knopf {
        case .starten: return String(localized: "Heute: \(name) starten")
        case .weiter: return String(localized: "Heute: \(name) weiter")
        case .fortsetzen: return String(localized: "Heute: \(name) fortsetzen")
        }
    }

    // MARK: Besuche ohne Sätze

    /// "1 Besuch ohne Sätze", "2 Besuche ohne Sätze".
    static func ohneSaetzeText(_ anzahl: Int) -> String {
        anzahl == 1 ? String(localized: "1 Besuch ohne Sätze") : String(localized: "\(anzahl) Besuche ohne Sätze")
    }
}

/// Was der Start-Knopf des Gym-Tabs gerade tut (das Modul gym kennt dieselben drei Fälle). Hier nur für den Text.
enum VerlaufStartArt: Equatable, Sendable { case starten, weiter, fortsetzen }

/// Rekorde und Plateaus aus den Läufen (`VerlaufLogik.e1rm`). Höchstens `sichtbar` stehen offen, der Rest hinter "Mehr".
enum VerlaufHighlights {
    static let sichtbar = 3
    /// Ab so vielen Einheiten mit Gewicht ist ein Plateau möglich; die letzten `plateauLetzte` schlagen den Bestand nicht.
    static let plateauMin = 4
    static let plateauLetzte = 3
    /// Ein Plateau zählt nur für Übungen, die in den letzten Tagen noch gemacht wurden.
    static let aktivTage = 28

    struct Eintrag: Equatable, Identifiable {
        enum Art: Equatable { case rekord, plateau }
        let art: Art
        let uebung: Uebung
        /// Bester e1RM in kg: bei einem Rekord der neue, beim Plateau der Bestand.
        let e1rm: Double
        var id: String { "\(art == .rekord ? "r" : "p")-\(uebung.id)" }
    }

    /// Rekorde dieser Woche zuerst (höchster e1RM zuerst), dann Plateaus. Ein erster Wert ohne Vorgänger ist kein Rekord.
    static func berechnen(_ laeufe: [VerlaufLogik.Lauf], heute: String) -> [Eintrag] {
        let montag = Datum.montagDerWoche(heute)
        var rekorde: [Eintrag] = [], plateaus: [Eintrag] = []
        for (_, gruppe) in Dictionary(grouping: laeufe, by: { $0.uebung.id }) {
            guard let uebung = gruppe.first?.uebung else { continue }
            // Bester e1RM je Tag, älteste zuerst.
            var proTag: [String: Double] = [:]
            for l in gruppe { if let e = l.saetze.compactMap(VerlaufLogik.e1rm).max() { proTag[l.tag] = max(proTag[l.tag] ?? 0, e) } }
            let tage = proTag.sorted { $0.key < $1.key }
            guard let neuester = tage.last else { continue }
            let frueher = tage.filter { Datum.montagDerWoche($0.key) < montag }.map(\.value).max()
            let dieseWoche = tage.filter { Datum.montagDerWoche($0.key) == montag }.map(\.value).max()
            if let frueher, let dieseWoche, dieseWoche > frueher {
                rekorde.append(Eintrag(art: .rekord, uebung: uebung, e1rm: dieseWoche))
            } else if tage.count >= plateauMin, Datum.tageZwischen(neuester.key, heute) <= aktivTage {
                let letzte = tage.suffix(plateauLetzte).map(\.value).max() ?? 0
                let bestand = tage.dropLast(plateauLetzte).map(\.value).max() ?? 0
                if letzte <= bestand { plateaus.append(Eintrag(art: .plateau, uebung: uebung, e1rm: bestand)) }
            }
        }
        rekorde.sort { $0.e1rm != $1.e1rm ? $0.e1rm > $1.e1rm : $0.uebung.name < $1.uebung.name }
        plateaus.sort { $0.uebung.name < $1.uebung.name }
        return rekorde + plateaus
    }

    /// Die ersten `sichtbar` und der Rest.
    static func kappen(_ liste: [Eintrag]) -> (offen: [Eintrag], mehr: [Eintrag]) {
        (Array(liste.prefix(sichtbar)), Array(liste.dropFirst(sichtbar)))
    }
}
