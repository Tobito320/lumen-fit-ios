// Quelle: Lovea Health/Koerper/KoerperView.swift (KoerperDaten; ohne Person und Modelle)
import Foundation

/// Alles, was das Fortschritt-Segment und das Blatt einer Muskelgruppe zeigen, als Werte. `bauen` rechnet, die Ansicht liest nur.
struct KoerperDaten: Sendable {
    let erholung: [MuskelTeil: Int]
    /// Je Teil das Training, auf das `erholung` rechnet (siehe `KoerperLogik.letzte`).
    let letzte: [MuskelTeil: KoerperLetztes]
    let woche: [MuskelTeil: Double]
    let ziele: KoerperZiele
    let streifen: KoerperWoche
    let naechstes: KoerperNaechstes?
    let gruppen: [MuskelGruppe: KoerperLogik.GruppenDaten]

    /// `wert` liest die Satzziele (`ziel.saetze.<gruppe>`); das Profil-Modul speichert sie, bis dahin gelten die Standardziele.
    static func bauen(sessions: [GymSession], plan: TrainingsPlan, wert: (String) -> Int? = { _ in nil }, jetzt: Date,
                      katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> KoerperDaten {
        let heute = Datum.text(jetzt)
        let ziele = KoerperZiele.lesen(wert: wert)
        let woche = MuskelLogik.wochenSaetze(sessions, woche: heute, katalog: katalog)
        let streifen = KoerperWoche.bauen(sessions: sessions, plan: plan, heute: heute, katalog: katalog)
        let faellig = KoerperLogik.faellig(prio: ziele.prio, ziele: ziele, woche: woche)
        return KoerperDaten(
            erholung: MuskelLogik.erholung(sessions, jetzt: jetzt, katalog: katalog),
            letzte: KoerperLogik.letzte(sessions, katalog: katalog),
            woche: woche, ziele: ziele, streifen: streifen,
            naechstes: KoerperLogik.naechstes(plan: plan, heute: heute, heuteFertig: streifen.tage.contains { $0.heute && $0.fertig },
                                             faellig: faellig, katalog: katalog),
            gruppen: Dictionary(uniqueKeysWithValues: MuskelGruppe.allCases.map {
                ($0, KoerperLogik.gruppe($0, sessions: sessions, jetzt: jetzt, katalog: katalog))
            })
        )
    }

    func prozent(_ t: MuskelTeil) -> Int { erholung[t] ?? 100 }
    func prozent(_ g: MuskelGruppe) -> Int { KoerperLogik.gruppenErholung(erholung, g) }

    /// Harte Sätze der Woche in der Gruppe, Mitarbeit zählt halb.
    func saetze(_ g: MuskelGruppe) -> Double {
        MuskelTeil.allCases.filter { $0.gruppe == g }.reduce(0) { $0 + (woche[$1] ?? 0) }
    }

    func stufe(_ g: MuskelGruppe) -> ErholungsStufe { MuskelLogik.stufe(prozent(g)) }

    /// Die Stufe einer Fläche der Körperkarte: der schlechteste ihrer Teile mit Training, `nil` ohne jedes.
    func stufe(teile: [MuskelTeil]) -> ErholungsStufe? {
        KoerperLogik.grenzteil(erholung, teile).flatMap { erholung[$0] }.map { MuskelLogik.stufe($0) }
    }

    /// Was das Blatt zeigt: der angetippte Teil, sonst der schlechteste der Gruppe (der die Gruppe färbt).
    /// `nil`, wenn dafür kein Training erfasst ist.
    func stand(_ g: MuskelGruppe, teil: MuskelTeil?) -> KoerperStand? {
        let kandidaten: [MuskelTeil] = teil.map { [$0] } ?? MuskelTeil.allCases.filter { $0.gruppe == g }
        guard let t = KoerperLogik.grenzteil(erholung, kandidaten), let wert = erholung[t] else { return nil }
        return KoerperStand(teil: t, prozent: wert, letztes: letzte[t])
    }

    /// Wort im Feld: "kein Training" ohne erfasstes Training in der Gruppe, sonst Prozent, solange nicht erholt,
    /// dann "geschafft" (Ziel erreicht) oder "erholt".
    func wort(_ g: MuskelGruppe) -> String {
        if stand(g, teil: nil) == nil { return "kein Training" }
        if stufe(g) != .erholt { return "\(prozent(g)) %" }
        guard let ziel = ziele.saetze[g] else { return "erholt" }
        return saetze(g) >= Double(ziel) ? "geschafft" : "erholt"
    }
}
