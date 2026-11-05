import Foundation

#if DEBUG
/// Drei erfundene Personen für `-lumenFitDemo`: eine im Gym mit Mitlauf, eine heute da mit einem Rekord, eine noch nicht.
enum GymCrewDemo {
    static func eintraege(jetzt: Date) -> [VerbindungEintrag] {
        let heute = Datum.text(jetzt)
        func satz(_ wdh: Int, _ kg: Int, _ typ: String? = nil) -> PartnerSatzKurz { PartnerSatzKurz(wdh: wdh, kg: kg, typ: typ) }
        func datei(_ name: String, geschrieben: Date, verlauf: PartnerVerlauf) -> ZusammenfassungDatei {
            var tag = TagesZusammenfassung(tag: heute)
            tag.verlauf = verlauf
            return ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: geschrieben, profilName: name, freigaben: [.gym, .plan, .verlauf], heute: tag, ereignisse: [])
        }

        var laeuft = PartnerVerlauf(imGym: true, imGymSeit: jetzt.addingTimeInterval(-25 * 60), imGymName: nil, trainings: [])
        laeuft.einheiten = [PartnerEinheit(tag: heute, name: nil, minuten: nil, kcal: nil,
                                           uebungen: [PartnerUebungKurz(name: "Bankdrücken", saetze: [satz(10, 400, "w"), satz(8, 800), satz(8, 800), satz(8, 800)])])]

        var fertig = PartnerVerlauf(trainings: [PartnerTrainingKurz(tag: heute, name: nil, minuten: 54, saetze: 27, uebungen: 6, kcal: nil)])
        fertig.einheiten = [
            PartnerEinheit(tag: heute, name: nil, minuten: 54, kcal: nil, uebungen: [PartnerUebungKurz(name: "Kniebeuge", saetze: [satz(5, 1200)])]),
            PartnerEinheit(tag: Datum.addTage(heute, -30), name: nil, minuten: 50, kcal: nil, uebungen: [PartnerUebungKurz(name: "Kniebeuge", saetze: [satz(5, 1100)])])
        ]

        return [
            VerbindungEintrag(id: "demo-crew-c", name: "Beispiel Freund C", daten: datei("Beispiel Freund C", geschrieben: jetzt, verlauf: PartnerVerlauf(trainings: []))),
            VerbindungEintrag(id: "demo-crew-b", name: "Beispiel Freund B", daten: datei("Beispiel Freund B", geschrieben: jetzt, verlauf: fertig)),
            VerbindungEintrag(id: "demo-crew-a", name: "Beispiel Freund A", daten: datei("Beispiel Freund A", geschrieben: jetzt.addingTimeInterval(-60), verlauf: laeuft))
        ]
    }
}
#endif
