// Quelle: Lovea Zyklus/ZyklusUebersetzer.swift (Texte ohne Geschlecht und Namen, für jede Person lesbar)
import Foundation

/// Übersetzt Phase und Eintrag von heute einer Person in kurze Hinweise für ihren Partner:
/// was sie sich heute wünscht und was man konkret tun kann. Keine Diagnose, nur Ideen.
enum ZyklusUebersetzer {
    struct Botschaft: Equatable, Sendable {
        let wunsch: String
        let satz: String
        let tipps: [String]
        let symbol: String
    }

    static func fuer(phase: ZyklusPhase?, tag: ZyklusTag?) -> Botschaft? {
        guard let phase else { return nil }
        let basis = basis(phase)
        let extra = hinweise(tag)
        // Die Stimmung von heute wiegt mehr als die Phase: sie kommt zuerst.
        var tipps: [String] = []
        for t in extra.tipps + basis.tipps where !tipps.contains(t) { tipps.append(t) }
        return Botschaft(wunsch: extra.wunsch ?? basis.wunsch,
                         satz: extra.satz ?? basis.satz,
                         tipps: Array(tipps.prefix(3)),
                         symbol: basis.symbol)
    }

    private static func basis(_ phase: ZyklusPhase) -> Botschaft {
        switch phase {
        case .periode:
            Botschaft(wunsch: "Wärme und Fürsorge",
                      satz: "Der Körper arbeitet heute hart. Es braucht keinen Plan, sondern dich.",
                      tipps: ["Frag, ob du etwas Warmes oder Süßes bringen kannst",
                              "Schreib zwischendurch, dass du an die Person denkst",
                              "Kein Druck, keine großen Diskussionen"],
                      symbol: "heart.circle.fill")
        case .follikel:
            Botschaft(wunsch: "Zeit zu zweit und Neues",
                      satz: "Die Energie kommt zurück. Gute Tage für Pläne und Abenteuer.",
                      tipps: ["Plan ein kleines Date oder etwas Neues zusammen",
                              "Lach zusammen, schick etwas Lustiges",
                              "Erzähl von deinem Tag, die Person will dabei sein"],
                      symbol: "sparkles")
        case .fruchtbar, .eisprung:
            Botschaft(wunsch: "Aufmerksamkeit und Komplimente",
                      satz: "Die Person fühlt sich heute oft strahlend. Zeig, dass du es siehst.",
                      tipps: ["Sag ganz konkret, was dir gefällt",
                              "Flirte wie am Anfang",
                              "Ruf an statt nur zu schreiben"],
                      symbol: "flame.fill")
        case .luteal:
            Botschaft(wunsch: "Geduld und liebe Worte",
                      satz: "Gefühle sind jetzt näher an der Oberfläche. Kleine Worte wiegen doppelt.",
                      tipps: ["Sag, dass du da bist und bleibst",
                              "Nimm Gereiztheit nicht persönlich",
                              "Ein Snack oder Schokolade wirkt Wunder"],
                      symbol: "bubble.left.and.text.bubble.right.fill")
        }
    }

    private static func hinweise(_ tag: ZyklusTag?) -> (wunsch: String?, satz: String?, tipps: [String]) {
        guard let tag else { return (nil, nil, []) }
        var wunsch: String?
        var satz: String?
        var tipps: [String] = []
        if !tag.stimmung.isDisjoint(with: [.traurig, .aengstlich]) {
            wunsch = "Sicherheit und Nähe"
            satz = "Die Person fühlt sich heute verletzlich. Es hilft zu hören, dass du da bist."
            tipps.append("Sag klar: Ich bin da und ich bleibe")
        }
        if tag.stimmung.contains(.gereizt) {
            wunsch = wunsch ?? "Geduld"
            tipps.append("Hör zu, statt zu erklären")
        }
        if tag.stimmung.contains(.gestresst) {
            wunsch = wunsch ?? "Entlastung"
            tipps.append("Frag, was du heute abnehmen kannst")
        }
        if tag.stimmung.contains(.empfindlich) {
            tipps.append("Sei heute besonders sanft mit Worten")
        }
        if !tag.symptome.isDisjoint(with: [.kraempfe, .rueckenschmerzen, .kopfschmerzen]) {
            tipps.append("Schmerzen heute: Wärmflasche, Tee, Ruhe")
        }
        if tag.symptome.contains(.muedigkeit) {
            tipps.append("Müde heute: lass den Abend ruhig sein")
        }
        if tag.symptome.contains(.heisshunger) {
            tipps.append("Überrasch mit dem Lieblingssnack")
        }
        return (wunsch, satz, tipps)
    }
}

/// Was der Partner von einem Zyklus zu sehen bekommt (Feld `zyklus` der Tageszusammenfassung): nur Phase, Tag und die kurzen Hinweise, nie einzelne Einträge.
/// Steht nur in der Datei, wenn die Person es in den Zyklus-Einstellungen erlaubt hat.
struct ZyklusZusammenfassung: Codable, Equatable, Hashable, Sendable {
    /// `ZyklusPhase.rawValue`.
    var phase: String
    /// 1 = erster Periodentag; nil, wenn der Tag nicht bekannt ist.
    var tag: Int?
    var wunsch: String
    var satz: String
    var tipps: [String]

    /// nil ohne Phase (zum Beispiel vor der ersten Periode).
    static func bauen(logik: ZyklusLogik, heute: String, eintrag: ZyklusTag?) -> ZyklusZusammenfassung? {
        guard logik.einstellung.modus == .zyklus, let phase = logik.phase(am: heute),
              let b = ZyklusUebersetzer.fuer(phase: phase, tag: eintrag) else { return nil }
        return ZyklusZusammenfassung(phase: phase.rawValue, tag: logik.zyklusTagNummer(am: heute), wunsch: b.wunsch, satz: b.satz, tipps: b.tipps)
    }
}
