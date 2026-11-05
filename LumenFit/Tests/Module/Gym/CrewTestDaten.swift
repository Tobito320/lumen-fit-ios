import Foundation
@testable import LumenFit

/// Bausteine für die Tests der Crew (Zeilen, Mitlauf, Pinnwand): erfundene Personen, feste Uhr 2025-10-31 08:00 UTC.
enum CrewTestDaten {
    static let jetzt = Date(timeIntervalSince1970: 1_761_897_600)
    static var heute: String { Datum.text(jetzt) }

    /// Satz als (Wiederholungen, kg in Zehnteln, Typ).
    static func satz(_ wdh: Int, _ kg: Int?, _ typ: String? = nil) -> PartnerSatzKurz { PartnerSatzKurz(wdh: wdh, kg: kg, typ: typ) }

    static func einheit(_ tag: String, _ uebungen: [(String, [PartnerSatzKurz])]) -> PartnerEinheit {
        PartnerEinheit(tag: tag, name: nil, minuten: 50, kcal: nil, uebungen: uebungen.map { PartnerUebungKurz(name: $0.0, saetze: $0.1) })
    }

    static func datei(name: String = "Freund A", freigaben: [FreigabeArt] = [.gym, .plan, .verlauf], geschrieben: Date = jetzt,
                      verlauf: PartnerVerlauf? = nil, plan: PartnerPlan? = nil) -> ZusammenfassungDatei {
        var tag = TagesZusammenfassung(tag: heute)
        tag.verlauf = verlauf
        tag.plan = plan
        return ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: geschrieben, profilName: name, freigaben: freigaben, heute: tag, ereignisse: [])
    }

    /// Läuft gerade ein Training (seit `minuten`), mit den Einheiten.
    static func imGym(seitMinuten minuten: Double = 30, einheiten: [PartnerEinheit]? = nil) -> PartnerVerlauf {
        var v = PartnerVerlauf(imGym: true, imGymSeit: jetzt.addingTimeInterval(-minuten * 60), imGymName: nil, trainings: [])
        v.einheiten = einheiten
        return v
    }

    static func eintrag(_ id: String, name: String = "Freund A", lovea: Bool = false, pause: Bool = false, daten: ZusammenfassungDatei?) -> VerbindungEintrag {
        VerbindungEintrag(id: id, name: name, lovea: lovea, ich: VerbindungEinstellung(pause: pause), daten: daten)
    }
}
