// Quelle: Lovea Health/Heute/Tagesform/TagesformQuellen.swift
import Foundation

/// Die Regeln der Quellen, rein und ohne Modelle: welche Tage zählen, welcher Stand eines Tages, wann ein Wert fehlt. Alles
/// kommt als Parameter herein, damit es sich testen lässt; `TagesformQuellen` liest die Modelle und ruft sie auf.
enum TagesformQuellenLogik {
    /// Wasser zählt nur, wenn es an einem der letzten so vielen Tage eingetragen wurde.
    static let wasserTage = 8
    /// Ein Tag im Essens-Tagebuch zählt erst ab diesem Anteil des Kalorienziels. Darunter ist meist nur ein Snack eingetragen.
    static let mindestEssen = 0.4
    /// Schritte und Wasser: ab dieser Stunde zählt heute mit, `TagesformRechnung.uebergangStunden` später ganz.
    static let heuteAb = 8

    /// `anzahl` Tage, Index 0 = `tag`, dann je einer weiter zurück. Schlaf liegt am Aufwachtag: Index 0 ist die Nacht vor `tag`.
    static func tage(ab tag: String, anzahl: Int) -> [String] {
        (0..<anzahl).map { Datum.addTage(tag, -$0) }
    }

    /// Werte je Tag in der Reihenfolge von `tage`, nil für fehlende.
    static func reihe(_ werte: [String: Double], tage: [String]) -> [Double?] {
        tage.map { werte[$0] }
    }

    /// Muskel-Erholung und gezählte Sätze je Tag. Nur Einheiten bis zum Ende von `tag` zählen und nie welche nach `jetzt`: sonst
    /// gälte eine spätere Einheit als "gerade eben" und die Erholung fiele auf 0. `saetze`: Index 0 = `tag`, dann `anzahl - 1` Tage davor.
    static func training(_ sessions: [GymSession], tag: String, jetzt: Date, anzahl: Int,
                         katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> (muskeln: [TagesformMuskel], saetze: [Int]) {
        let bis: Date = min(jetzt, Datum.datum(Datum.addTage(tag, 1)))
        let bisher: [GymSession] = sessions.filter { $0.start <= bis }
        let erholung: [MuskelTeil: Int] = MuskelLogik.erholung(bisher, jetzt: bis, katalog: katalog)
        var muskeln: [TagesformMuskel] = []
        for (teil, prozent) in erholung where prozent < 100 {
            muskeln.append(TagesformMuskel(gruppe: teil.gruppe.name, prozent: prozent))
        }
        muskeln.sort { $0.prozent != $1.prozent ? $0.prozent < $1.prozent : $0.gruppe < $1.gruppe }
        var proTag: [String: Int] = [:]
        for s in bisher {
            let fertige: [UebungsLauf] = s.laeufe.filter { $0.fertig }
            let n: Int = fertige.reduce(0) { $0 + ($1.saetze?.count ?? 0) }
            proTag[Datum.text(s.start), default: 0] += n
        }
        let saetze: [Int] = tage(ab: tag, anzahl: anzahl).map { proTag[$0] ?? 0 }
        return (muskeln, saetze)
    }

    /// Kalorien und Eiweiß. Heute nie (ein halber Tag wäre ein falsches Minus), nur der Vortag; ein vergangener Tag (`stunde` 24)
    /// zählt selbst, fehlt er, der Tag davor. Jeder Tag gegen sein eigenes Ziel (flexible Tage haben mehr). Ein Tag unter
    /// `mindestEssen` des Kalorienziels fehlt, auch ohne Eintrag.
    static func essen(tag: Naehrwerte?, zielTag: ErnaehrungsZiele, vortag: Naehrwerte?, zielVortag: ErnaehrungsZiele,
                      stunde: Int) -> (kalorien: TagesformMass?, eiweiss: TagesformMass?) {
        func masse(_ n: Naehrwerte?, _ z: ErnaehrungsZiele, _ bezug: TagesformMass.Bezug) -> (kalorien: TagesformMass?, eiweiss: TagesformMass?) {
            guard let n, z.kcal > 0, n.kcal >= mindestEssen * Double(z.kcal) else { return (nil, nil) }
            let eiweiss: TagesformMass? = z.protein > 0 ? TagesformMass(ist: n.protein, ziel: Double(z.protein), bezug: bezug) : nil
            return (TagesformMass(ist: n.kcal, ziel: Double(z.kcal), bezug: bezug), eiweiss)
        }
        let gestern = masse(vortag, zielVortag, .vortag)
        guard stunde >= 24 else { return gestern }
        let selbst = masse(tag, zielTag, .tag)
        return (selbst.kalorien ?? gestern.kalorien, selbst.eiweiss ?? gestern.eiweiss)
    }

    /// Schritte kommen von selbst (iPhone, Band): der Vortag, ab `heuteAb` Uhr langsam heute gegen das Soll bis jetzt.
    static func schritte(heute: Int?, vortag: Int?, ziel: Int, stunde: Int) -> TagesformMass? {
        TagesformRechnung.tagesmass(heute: heute.map { Double($0) }, vortag: vortag.map { Double($0) }, ziel: Double(ziel),
                                    stunde: stunde, ab: heuteAb)
    }

    /// Wasser nur, wenn es an einem der ersten `wasserTage` Tage von `letzteTage` (Index 0 = der Tag selbst)
    /// eingetragen wurde, sonst hieße kein Eintrag "nichts getrunken". Sonst wie die Schritte.
    static func wasser(heute: Int, vortag: Int, letzteTage: [Int], ziel: Int, stunde: Int) -> TagesformMass? {
        guard letzteTage.prefix(wasserTage).contains(where: { $0 > 0 }) else { return nil }
        return TagesformRechnung.tagesmass(heute: Double(heute), vortag: Double(vortag), ziel: Double(ziel), stunde: stunde, ab: heuteAb)
    }
}
