import XCTest
@testable import LumenFit

/// Eine Health-Lieferung im Hintergrund gilt erst als verarbeitet, wenn der Abruf durch ist (`fertig` kommt nach den Abruf-Aufgaben), und je Lieferung
/// gibt es genau ein Ereignis `healthAktualisiert`, auch wenn Health mehrmals kurz hintereinander ruft.
@MainActor
final class HealthLieferungTests: XCTestCase {
    /// Merkt sich den Rückruf der Beobachtung, damit der Test eine Lieferung auslösen kann.
    // @unchecked Sendable: nur im Test, der Rückruf wird einmal auf dem Hauptakteur gesetzt und gelesen.
    private final class LieferLeser: HealthLeser, @unchecked Sendable {
        var lieferung: (@Sendable (@escaping @Sendable () -> Void) -> Void)?
        func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff { .angefragt }
        func tagesWerte(von: String, bis: String) async -> [TagesWerte] { [] }
        func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] { [] }
        func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] { [] }
        func gewichte(von: String, bis: String) async -> [GewichtsMesswert] { [] }
        func workouts(von: String, bis: String) async -> [HealthWorkout] { [] }
        func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) {}
        func beobachte(_ typen: Set<HealthTyp>, mitAbschluss aenderung: @escaping @Sendable (_ fertig: @escaping @Sendable () -> Void) -> Void) {
            lieferung = aenderung
        }
    }

    @MainActor private final class Merker { var eintraege: [String] = [] }

    func testFertigKommtNachDemAbrufUndJedeLieferungMeldetGenauEinmal() async throws {
        let leser = LieferLeser()
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                            leser: leser, healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: { Date() }, passwortRunden: 1_000)
        _ = try u.profil.anlegen(name: "Test", passwort: "")
        let merker = Merker()
        u.beiAbruf { merker.eintraege.append("abruf") }
        let strom = u.ereignisse.strom()
        let sammler = Task { @MainActor in
            for await e in strom { if case .healthAktualisiert = e { merker.eintraege.append("ereignis") } }
        }
        u.beobachteHealth()
        let lieferung = try XCTUnwrap(leser.lieferung, "die Beobachtung ist angemeldet")
        // Zwei Lieferungen kurz hintereinander (Health ruft je Typ): ein Abruf, ein Ereignis, aber beide melden fertig.
        lieferung { Task { @MainActor in merker.eintraege.append("fertig") } }
        lieferung { Task { @MainActor in merker.eintraege.append("fertig") } }
        for _ in 0..<100 where merker.eintraege.filter({ $0 == "fertig" }).count < 2 { try await Task.sleep(for: .milliseconds(20)) }
        sammler.cancel()
        let abruf = try XCTUnwrap(merker.eintraege.firstIndex(of: "abruf"))
        let fertig = try XCTUnwrap(merker.eintraege.firstIndex(of: "fertig"))
        XCTAssertLessThan(abruf, fertig, "Health wartet, bis der Abruf durch ist")
        XCTAssertEqual(merker.eintraege.filter { $0 == "abruf" }.count, 1, "die zweite Lieferung startet keinen zweiten Abruf")
        XCTAssertEqual(merker.eintraege.filter { $0 == "fertig" }.count, 2)
        XCTAssertEqual(merker.eintraege.filter { $0 == "ereignis" }.count, 1, "ein Ereignis je Abruf, nicht je Rückruf")
    }
}
