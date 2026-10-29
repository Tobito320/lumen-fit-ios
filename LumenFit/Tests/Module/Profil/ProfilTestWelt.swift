import XCTest
@testable import LumenFit

/// Hilfen der Profil-Tests: eine `AppUmgebung` mit Schlüsselbund-Fake und kleiner Rundenzahl (der Standard braucht je Aufruf spürbar Zeit).
@MainActor
enum ProfilTestWelt {
    static func umgebung(ordner: URL, bund: SpeicherSchluesselbund = SpeicherSchluesselbund(), leser: any HealthLeser = LeererHealthLeser(),
                         uhr: TestUhr = TestUhr()) -> AppUmgebung {
        AppUmgebung(ordner: ordner, schluesselbund: bund, http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(), leser: leser,
                    healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
    }

    /// Eine Umgebung mit angelegtem Profil und einer Einheit, einem Frühstück und einem Wasser-Haken.
    static func gefuellt(ordner: URL, name: String = "Quelle", bund: SpeicherSchluesselbund = SpeicherSchluesselbund()) throws -> (umgebung: AppUmgebung, daten: DatenSatz) {
        let u = umgebung(ordner: ordner, bund: bund)
        try u.profil.anlegen(name: name, passwort: "abcd")
        let d = try XCTUnwrap(u.daten)
        let start = TestUhr().lesen
        let ops = TestDaten.gymOps(von: d.profil, start: start) + TestDaten.essenOps(von: d.profil, datum: "2026-09-23", zeit: start)
            + TestDaten.habitOps(von: d.profil, datum: "2026-09-23", zeit: start)
        for op in ops { d.raum.einreihen(op) }
        return (u, d)
    }
}
