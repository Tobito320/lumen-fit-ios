import Foundation

#if DEBUG
/// Feste Beispiel-Antwort von `GET /freunde` für `-lumenFitDemo`: ein laufendes Duell, eine Einladung zu einem gemeinsamen Ziel, drei Reaktionen.
/// Die Personen sind die erfundenen aus `GymCrewDemo` (gleiche Verbindungs-Ids).
enum CrewDemo {
    static func antwort(jetzt: Date) -> CrewAntwort {
        let heute = Datum.text(jetzt)
        let montag = Datum.datum(Datum.wochenstart(heute))
        let sonntag = CrewLogik.endeBisSonntag(jetzt: jetzt)
        func id(_ z: Character) -> String { String(repeating: z, count: 32) }
        let duell = CrewHerausforderung(id: id("d"), mass: .saetze, modus: .gegen, start: montag, ende: sonntag, ersteller: true, ich: "dabei", teilnehmer: [
            CrewTeilnehmer(id: id("1"), verbunden: false, ich: true, name: "Du", wert: 42, aktualisiert: jetzt),
            CrewTeilnehmer(id: "demo-crew-a", name: "Beispiel Freund A", wert: 38, aktualisiert: jetzt.addingTimeInterval(-600))
        ])
        let gemeinsam = CrewHerausforderung(id: id("e"), mass: .tage, modus: .gemeinsam, ziel: 12, start: jetzt.addingTimeInterval(-3600),
                                            ende: jetzt.addingTimeInterval(14 * 86_400), ich: "eingeladen", teilnehmer: [
            CrewTeilnehmer(id: id("2"), verbunden: false, ich: true, name: "Du", status: "eingeladen"),
            CrewTeilnehmer(id: "demo-crew-b", name: "Beispiel Freund B", wert: 1),
            CrewTeilnehmer(id: "demo-crew-c", name: "Beispiel Freund C", status: "eingeladen")
        ])
        let reaktionen = [
            CrewReaktion(id: "demo-r1", von: "demo-crew-a", name: "Beispiel Freund A", art: .respekt, ziel: CrewLogik.zielEinheit(tag: heute),
                         text: "Training von heute", zeit: jetzt.addingTimeInterval(-300)),
            CrewReaktion(id: "demo-r2", von: "demo-crew-b", name: "Beispiel Freund B", art: .anfeuern, ziel: CrewLogik.zielLive(tag: heute),
                         zeit: jetzt.addingTimeInterval(-1_800)),
            CrewReaktion(id: "demo-r3", von: "demo-crew-c", name: "Beispiel Freund C", art: .stups, ziel: CrewLogik.zielStups(tag: heute),
                         zeit: jetzt.addingTimeInterval(-7_200))
        ]
        let gesendet = [CrewGesendet(an: "demo-crew-b", art: .respekt, ziel: CrewLogik.zielRekord(tag: heute, uebung: "Kniebeuge"))]
        return CrewAntwort(herausforderungen: [duell, gemeinsam], reaktionen: reaktionen, gesendet: gesendet)
    }
}
#endif
