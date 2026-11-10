// Quelle: Lovea Health/Heute/Tagesform/TagesformKlartext.swift
import Foundation

// Tagesform in Klartext (Wunsch vom 15.10.: "aktuell ist es so vage"). Reine Logik, ohne Modelle: aus den Werten, die `TagesformRechnung` schon
// hat, kommen zwei bis drei Gründe mit echten Zahlen und eine Empfehlung mit Grund. Fehlt ein Wert, fällt der Satz weg; nichts wird
// angenommen. Die Karte (`TagesformKarte`) zeichnet nur, was hier herauskommt.

enum TagesformKlartext {
    /// Ein Grund auf der Karte. `bremst`: zieht die Zahl nach unten, sonst hebt er sie.
    struct Zeile: Equatable, Sendable {
        var art: TagesformArt
        var bremst: Bool
        var text: String
    }

    struct Inhalt: Equatable, Sendable {
        var gruende: [Zeile] = []
        var empfehlung: String? = nil
        /// Kleiner Satz unter den Gründen: nichts bremst, oder die Zahl ist grob.
        var hinweis: String? = nil
    }

    /// Eine Muskelgruppe unter diesem Wert (Prozent Erholung) gilt für die Empfehlung als müde.
    static let muedeBis = 70
    /// Die Stufen wie `EnergieLogik`: ab 70 volles Training, ab 50 leichter, darunter Pause.
    static let vollAb = 70
    static let leichtAb = 50

    static func inhalt(_ e: TagesformEingabe, _ r: TagesformErgebnis, plan: EnergieEingabe?) -> Inhalt {
        var zeilen: [Zeile] = []
        for f in r.gruende {
            zeilen.append(Zeile(art: f.art, bremst: f.einfluss < 0, text: text(f, e, kappe: r.kappe)))
        }
        var hinweise: [String] = []
        if r.akku != nil, zeilen.isEmpty { hinweise.append(String(localized: "Nichts bremst dich, alles im normalen Bereich.")) }
        if r.akku != nil, r.deckung < TagesformRechnung.mittelDeckung { hinweise.append(String(localized: "Wenig Daten, die Zahl ist grob.")) }
        let hauptgrund: TagesformArt? = r.gruende.first(where: { $0.einfluss < 0 })?.art
        return Inhalt(gruende: zeilen,
                      empfehlung: empfehlung(akku: r.akku, muskeln: e.muskeln, hauptgrund: hauptgrund, plan: plan),
                      hinweis: hinweise.isEmpty ? nil : hinweise.joined(separator: " "))
    }

    // MARK: Gründe

    /// Schlaf und Muskeln mit den Werten, die der Satz vorher nur andeutete ("unter deinem Schnitt"); alles andere sagt `kurz` schon konkret.
    static func text(_ f: TagesformFaktor, _ e: TagesformEingabe, kappe: TagesformKappe?) -> String {
        switch f.art {
        case .schlaf: return schlafText(f, e, kappe: kappe)
        case .erholung: return erholungText(e) ?? f.kurz
        default: return f.kurz
        }
    }

    private static func schlafText(_ f: TagesformFaktor, _ e: TagesformEingabe, kappe: TagesformKappe?) -> String {
        let erste: Int? = e.schlaf.first.flatMap { $0 }
        guard let letzte = erste, e.schlafZiel > 0 else { return f.kurz }
        var satz = String(localized: "Schlaf \(dauer(letzte))")
        if Double(letzte) >= 0.95 * Double(e.schlafZiel) {
            satz += String(localized: ", Ziel erreicht")
        } else {
            satz += String(localized: ", \(dauer(e.schlafZiel - letzte)) unter deinem Ziel")
        }
        if let kappe, kappe.art == .schlaf { satz += String(localized: ", deckelt dich bei \(kappe.grenze) %") }
        return satz
    }

    private static func erholungText(_ e: TagesformEingabe) -> String? {
        let muede = muedeGruppen(e.muskeln, unter: 90)
        guard !muede.isEmpty else { return nil }
        var teile: [String] = []
        for m in muede.prefix(2) { teile.append("\(m.gruppe) \(m.prozent) %") }
        return String(localized: "Noch nicht erholt: \(teile.joined(separator: ", "))")
    }

    /// Gruppen unter `grenze` Prozent, je Gruppe der tiefste Teil, die müdeste zuerst.
    static func muedeGruppen(_ muskeln: [TagesformMuskel], unter grenze: Int) -> [TagesformMuskel] {
        var tiefste: [String: Int] = [:]
        for m in muskeln { tiefste[m.gruppe] = min(tiefste[m.gruppe] ?? 100, m.prozent) }
        var liste: [TagesformMuskel] = []
        for (gruppe, prozent) in tiefste where prozent < grenze { liste.append(TagesformMuskel(gruppe: gruppe, prozent: prozent)) }
        return liste.sorted { $0.prozent != $1.prozent ? $0.prozent < $1.prozent : $0.gruppe < $1.gruppe }
    }

    // MARK: Empfehlung

    /// Was heute zu tun ist, mit dem Grund. Die Stufe kommt aus der Zahl der Karte (nicht aus `EnergieRat`, der anders rechnet), der
    /// Plan aus `EnergieEingabe`. Ohne Zahl oder ohne Plan gibt es keine Empfehlung.
    static func empfehlung(akku: Int?, muskeln: [TagesformMuskel], hauptgrund: TagesformArt?, plan: EnergieEingabe?) -> String? {
        guard let akku, let plan else { return nil }
        if plan.heuteSchonGym { return String(localized: "Gym heute erledigt.") }
        if plan.ruhetag { return String(localized: "Ruhetag laut Plan.") }
        if !plan.trainingstag && !plan.planLeer { return String(localized: "Kein Gym geplant.") }

        var was: String
        var grund: String? = nil
        let wegen: String? = hauptgrund.map { String(localized: "vor allem wegen \($0.titel)") }
        if akku < leichtAb {
            was = String(localized: "Besser kein Gym und kein Cardio")
            grund = wegen
        } else {
            let leicht: Bool = akku < vollAb || plan.gymInFolge >= 3
            let muede = muedeGruppen(muskeln, unter: muedeBis)
            if let tiefste = muede.first {
                let nurBeine: Bool = muede.allSatisfy { $0.gruppe == MuskelGruppe.beine.name }
                if nurBeine {
                    was = leicht ? String(localized: "Lieber Oberkörper leicht") : String(localized: "Lieber Oberkörper")
                } else {
                    let namen: String = muede.prefix(2).map { $0.gruppe }.joined(separator: String(localized: " und "))
                    was = leicht ? String(localized: "Leichter, ohne \(namen) trainieren") : String(localized: "Ohne \(namen) trainieren")
                }
                grund = String(localized: "\(tiefste.gruppe) erst zu \(tiefste.prozent) % erholt")
            } else if plan.gymInFolge >= 3 {
                was = String(localized: "Leichter trainieren")
                grund = String(localized: "schon \(plan.gymInFolge) Tage am Stück Gym")
            } else if leicht {
                was = String(localized: "Leichter trainieren")
                grund = wegen
            } else {
                was = String(localized: "Volles Training passt")
            }
            if akku < vollAb { was += String(localized: ", Cardio höchstens 15 min") }
        }
        if let grund { was += " – " + grund }
        return was + "."
    }

    /// "5 h 56 min"; unter einer Stunde nur die Minuten.
    private static func dauer(_ minuten: Int) -> String {
        minuten < 60 ? "\(minuten) min" : EnergieLogik.dauer(minuten)
    }
}
