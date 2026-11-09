import Foundation
import Testing
@testable import LumenFit

/// Satz-Vorschlag (Auftrag 09.11.2026): Epley mit Reserve, doppelte Progression, Autoregulation im Training, Pause, Deload, Aufwärmen, Drop.
/// Die erwarteten Zahlen sind von Hand nachgerechnet (Epley: 1RM = kg × (1 + (Wdh + Reserve) / 30), Reserve ohne RPE = 2).
struct SatzVorhersageLogikTests {
    private let heute = "2026-11-09"

    private func satz(_ wdh: Int, _ kg: Double?, rpe: Double? = nil, versagen: Bool = false, typ: String? = nil, ok: Bool = true) -> PlanSatz {
        var s = PlanSatz(wdh: wdh, kg: kg, failure: versagen, typ: typ)
        s.rpe = rpe
        s.ok = ok ? true : nil
        return s
    }

    private func einheit(_ tag: String, _ saetze: [PlanSatz]) -> UebungTag {
        UebungTag(id: tag, datum: Datum.datum(tag).addingTimeInterval(18 * 3600), saetze: saetze)
    }

    /// Drei offene Zeilen wie aus dem Plan.
    private var offen: [PlanSatz] { [satz(10, 60, ok: false), satz(10, 60, ok: false), satz(10, 60, ok: false)] }

    /// Vorschlag für den ersten Satz, die letzte Einheit lag am `tag`.
    private func ersterSatz(_ alt: [PlanSatz], art: VorhersageArt = .isolation, schritt: Double = 2.5, tag: String = "2026-11-02") -> SatzVorschlag? {
        SatzVorhersageLogik.vorschlag(zeile: 0, saetze: offen, historie: [einheit(tag, alt)], art: art, schritt: schritt, heute: heute)
    }

    /// Vorschlag für Zeile `zeile` im laufenden Training, ohne Historie.
    private func imTraining(_ zeilen: [PlanSatz], zeile: Int = 1, art: VorhersageArt = .isolation, pause: Int = 120) -> SatzVorschlag? {
        SatzVorhersageLogik.vorschlag(zeile: zeile, saetze: zeilen, historie: [], art: art, schritt: 2.5, pause: pause, heute: heute)
    }

    // MARK: - Formeln

    @Test("Epley: 10 Wiederholungen sind 75 %, eine ist das 1RM selbst")
    func epley() {
        #expect(SatzVorhersageLogik.anteil(1) == 1)
        #expect(SatzVorhersageLogik.anteil(10) == 0.75)
        #expect(SatzVorhersageLogik.e1rm(kg: 60, wdh: 10, reserve: 0) == 80)
        #expect(SatzVorhersageLogik.wiederholungen(anteil: 1) == 1)
        #expect(SatzVorhersageLogik.wiederholungen(anteil: 0.4) == 30)
    }

    @Test("Anteil und Wiederholungen sind Umkehrungen", arguments: [2.0, 5, 8, 12, 20])
    func umkehrung(n: Double) {
        #expect(abs(SatzVorhersageLogik.wiederholungen(anteil: SatzVorhersageLogik.anteil(n)) - n) < 1e-9)
    }

    @Test("Reserve aus Versagen und RPE, ohne Angabe nil")
    func reserve() {
        #expect(SatzVorhersageLogik.reserve(satz(8, 60, versagen: true)) == 0)
        #expect(SatzVorhersageLogik.reserve(satz(8, 60, rpe: 8)) == 2)
        #expect(SatzVorhersageLogik.reserve(satz(8, 60, rpe: 3)) == 5)
        #expect(SatzVorhersageLogik.reserve(satz(8, 60)) == nil)
    }

    @Test("Stärke: Sätze bis 12 Wiederholungen bis zum Versagen gehen vor")
    func staerke() throws {
        // 60 × 10 (+2 Reserve) = 84; 70 × 15 (+2) wäre 109,7, zählt aber nur, wenn es nichts Genaueres gibt.
        let beide = try #require(SatzVorhersageLogik.staerke([satz(10, 60), satz(15, 70)]))
        #expect(abs(beide - 84) < 1e-9)
        let nurViele = try #require(SatzVorhersageLogik.staerke([satz(15, 70)]))
        #expect(abs(nurViele - 70 * (1 + 17.0 / 30)) < 1e-9)
        #expect(SatzVorhersageLogik.staerke([satz(12, nil), satz(10, 40, typ: "w")]) == nil)
    }

    // MARK: - Art, Bereich, Reserve

    @Test("Art aus Katalog und Name")
    func art() {
        func u(_ name: String, _ geraet: String, _ muskel: String, _ neben: [String], koerper: String = "Brust") -> (Uebung, String) {
            (Uebung(id: "t", name: name, en: "", muskel: muskel, koerper: koerper, geraet: geraet, neben: neben), name)
        }
        let faelle: [((Uebung, String), VorhersageArt?)] = [
            (u("Bankdrücken mit Langhantel", "Langhantel", "Brust", ["Schultern", "Trizeps"]), .grund),
            (u("Kniebeuge mit Langhantel", "Langhantel", "Quadrizeps", ["Po", "Beinbeuger", "Waden"]), .grund),
            (u("Latzug am Kabelzug", "Kabelzug", "Latissimus", ["Bizeps", "Unterarme"]), .maschine),
            (u("Beinpresse 45°", "Schlitten", "Po", ["Beinbeuger", "Quadrizeps", "Waden"]), .maschine),
            (u("Bizepscurl mit Kurzhanteln", "Kurzhantel", "Bizeps", ["Unterarme"]), .isolation),
            (u("Trizepsdrücken am Kabelzug", "Kabelzug", "Trizeps", []), .isolation),
            (u("Beinbeuger liegend an der Maschine", "Maschine", "Beinbeuger", []), .isolation),
            (u("Seitheben mit Kurzhanteln", "Kurzhantel", "Schultern", ["Trapez"]), .klein),
            (u("Wadenheben an der Maschine", "Maschine", "Waden", []), .klein),
            (u("Klimmzug assistiert", "Assistiert", "Latissimus", ["Bizeps"]), nil),
            (u("Laufband", "Maschine", "Herz-Kreislauf", [], koerper: "Cardio"), nil),
        ]
        for ((uebung, name), erwartet) in faelle {
            #expect(SatzVorhersageLogik.art(uebung, name: name) == erwartet, "\(name)")
        }
        #expect(SatzVorhersageLogik.art(nil, name: "Eigene Übung") == .isolation)
    }

    @Test("Bereiche je Ziel und Reserve je Satz")
    func bereicheUndReserve() {
        #expect(SatzVorhersageLogik.bereich(.grund, ziel: .schwer) == 4...8)
        #expect(SatzVorhersageLogik.bereich(.isolation, ziel: .schwer) == 6...10)
        #expect(SatzVorhersageLogik.bereich(.klein, ziel: .klassisch) == 10...15)
        #expect(SatzVorhersageLogik.zielReserve(.grund, letzter: false, versagen: false) == 2)
        #expect(SatzVorhersageLogik.zielReserve(.grund, letzter: true, versagen: false) == 1)
        #expect(SatzVorhersageLogik.zielReserve(.isolation, letzter: true, versagen: false) == 0)
        #expect(SatzVorhersageLogik.zielReserve(.maschine, letzter: false, versagen: true) == 0)
    }

    // MARK: - Erster Satz: doppelte Progression

    @Test("Oben im Bereich geschafft: ein Schritt mehr Gewicht")
    func obenImBereich() {
        // 84 kg 1RM, mit 62,5 kg bleiben 10,3 Wiederholungen bis zum Versagen, mit 1 Reserve 9.
        #expect(ersterSatz([satz(10, 60), satz(10, 60), satz(9, 60)]) == SatzVorschlag(kg: 62.5, wdh: 9, reserve: 1, grund: .mehrGewicht(2.5)))
    }

    @Test("Im Bereich: gleiches Gewicht, eine Wiederholung mehr")
    func imBereich() {
        #expect(ersterSatz([satz(8, 60), satz(8, 60), satz(7, 60)]) == SatzVorschlag(kg: 60, wdh: 9, reserve: 1, grund: .mehrWiederholungen))
        #expect(ersterSatz([satz(8, 60, rpe: 8)]) == SatzVorschlag(kg: 60, wdh: 9, reserve: 1, grund: .mehrWiederholungen))
    }

    @Test("Bis zum Versagen im Bereich: erst halten")
    func versagenHalten() {
        #expect(ersterSatz([satz(8, 60, versagen: true)]) == SatzVorschlag(kg: 60, wdh: 8, reserve: 1, grund: .halten))
    }

    @Test("Unter dem Bereich: leichter, bis der untere Rand passt")
    func unterBereich() {
        #expect(ersterSatz([satz(4, 80), satz(4, 80)]) == SatzVorschlag(kg: 77.5, wdh: 6, reserve: 1, grund: .leichter(2.5)))
    }

    @Test("Weit über dem Bereich: mehr Gewicht, weniger Wiederholungen")
    func weitDrueber() {
        #expect(ersterSatz([satz(14, 45), satz(13, 45)], art: .maschine, schritt: 5) == SatzVorschlag(kg: 50, wdh: 10, reserve: 1, grund: .inDenBereich(5)))
        #expect(ersterSatz([satz(16, 70), satz(15, 70)], art: .maschine, schritt: 5) == SatzVorschlag(kg: 75, wdh: 10, reserve: 1, grund: .inDenBereich(5)))
        #expect(ersterSatz([satz(10, 80), satz(9, 80), satz(8, 80)], art: .grund) == SatzVorschlag(kg: 82.5, wdh: 8, reserve: 2, grund: .inDenBereich(2.5)))
    }

    @Test("Grundübung oben im Bereich: Schritt hoch mit 2 Reserve")
    func grundUebung() {
        #expect(ersterSatz([satz(8, 100), satz(8, 100), satz(7, 100)], art: .grund) == SatzVorschlag(kg: 102.5, wdh: 7, reserve: 2, grund: .mehrGewicht(2.5)))
    }

    @Test("Zu großer Schritt (grobe Stufen): erst eine Wiederholung mehr")
    func grobeStufen() {
        #expect(ersterSatz([satz(10, 20), satz(10, 20)], art: .maschine, schritt: 5) == SatzVorschlag(kg: 20, wdh: 11, reserve: 1, grund: .mehrWiederholungen))
        #expect(ersterSatz([satz(12, 10), satz(12, 10), satz(11, 10)], art: .klein, schritt: 2) == SatzVorschlag(kg: 10, wdh: 13, reserve: 1, grund: .mehrWiederholungen))
    }

    @Test("Pyramide: der schwerste Satz zählt")
    func pyramide() {
        #expect(ersterSatz([satz(10, 60), satz(8, 65), satz(6, 70)]) == SatzVorschlag(kg: 70, wdh: 7, reserve: 1, grund: .mehrWiederholungen))
    }

    @Test("Ohne Gewicht: eine Wiederholung mehr; ohne Historie kein Vorschlag")
    func ohneGewichtUndOhneDaten() {
        #expect(ersterSatz([satz(12, nil), satz(10, nil)]) == SatzVorschlag(kg: nil, wdh: 13, reserve: 1, grund: .ohneGewicht))
        #expect(SatzVorhersageLogik.vorschlag(zeile: 0, saetze: offen, historie: [], art: .isolation, schritt: 2.5, heute: heute) == nil)
    }

    @Test("Nach einer Pause: 5 % (über 14 Tage) oder 10 % (über 28 Tage) leichter")
    func nachPause() {
        #expect(ersterSatz([satz(8, 60)], tag: "2026-10-10") == SatzVorschlag(kg: 52.5, wdh: 8, reserve: 1, grund: .nachPause(30)))
        #expect(ersterSatz([satz(8, 60)], tag: "2026-10-20") == SatzVorschlag(kg: 55, wdh: 8, reserve: 1, grund: .nachPause(20)))
    }

    // MARK: - Stillstand und Deload

    private let wochen = ["2026-10-05", "2026-10-12", "2026-10-19", "2026-10-26", "2026-11-02"]

    @Test("Drei Einheiten ohne neuen Bestwert: Deload mit 10 % weniger und mehr Reserve")
    func deload() {
        let historie = wochen.map { einheit($0, [satz(8, 60), satz(8, 60)]) }
        let v = SatzVorhersageLogik.vorschlag(zeile: 0, saetze: offen, historie: historie, art: .isolation, schritt: 2.5, heute: heute)
        #expect(v == SatzVorschlag(kg: 52.5, wdh: 8, reserve: 3, grund: .deload))
    }

    @Test("Vier Einheiten reichen nicht für einen Deload")
    func keinDeloadZuFrueh() {
        let historie = wochen.dropFirst().map { einheit($0, [satz(8, 60)]) }
        let v = SatzVorhersageLogik.vorschlag(zeile: 0, saetze: offen, historie: historie, art: .isolation, schritt: 2.5, heute: heute)
        #expect(v == SatzVorschlag(kg: 60, wdh: 9, reserve: 1, grund: .mehrWiederholungen))
    }

    @Test("Nach dem Deload geht es vom Stand davor weiter")
    func nachDeload() {
        var historie = wochen.dropLast().map { einheit($0, [satz(8, 60)]) }
        historie.append(einheit("2026-11-02", [satz(8, 52.5)]))
        let v = SatzVorhersageLogik.vorschlag(zeile: 0, saetze: offen, historie: historie, art: .isolation, schritt: 2.5, heute: heute)
        #expect(v == SatzVorschlag(kg: 60, wdh: 9, reserve: 1, grund: .mehrWiederholungen))
    }

    @Test("Stillstand nur ohne Fortschritt und ohne leichte Einheit unter den letzten drei")
    func stillstand() {
        #expect(SatzVorhersageLogik.stillstand([100, 100, 100, 100, 100]))
        #expect(SatzVorhersageLogik.stillstand([100, 101, 102, 103, 104]) == false)
        #expect(SatzVorhersageLogik.stillstand([100, 100, 100, 100]) == false)
        #expect(SatzVorhersageLogik.stillstand([100, 100, 90, 100, 100]) == false)
    }

    // MARK: - Im Training

    @Test("Nächster Satz: gleiches Gewicht, Ermüdung eingerechnet")
    func ermuedung() {
        // 60 × 8 mit 2 Reserve: 10 bis zum Versagen, minus 0,94 Ermüdung, minus 1 Ziel-Reserve, abgerundet 8.
        #expect(imTraining([satz(8, 60), satz(10, 60, ok: false), satz(10, 60, ok: false)]) == SatzVorschlag(kg: 60, wdh: 8, reserve: 1, grund: .ermuedung))
    }

    @Test("Kurze Pause kostet mehr Wiederholungen")
    func kurzePause() {
        #expect(imTraining([satz(8, 60, rpe: 9), satz(8, 60, ok: false), satz(8, 60, ok: false)], pause: 60)
            == SatzVorschlag(kg: 60, wdh: 6, reserve: 1, grund: .ermuedung))
    }

    @Test("Der letzte Satz war leicht: mehr Gewicht")
    func leichterSatz() {
        #expect(imTraining([satz(12, 60, rpe: 7), satz(10, 60, ok: false), satz(10, 60, ok: false)])
            == SatzVorschlag(kg: 62.5, wdh: 10, reserve: 1, grund: .schwerer(2.5)))
    }

    @Test("Wiederholungen fallen unter den Bereich: leichter")
    func fallendeWiederholungen() {
        #expect(imTraining([satz(6, 60, versagen: true), satz(6, 60, ok: false), satz(6, 60, ok: false)])
            == SatzVorschlag(kg: 55, wdh: 6, reserve: 1, grund: .leichter(5)))
    }

    @Test("Letzter Satz der Übung: bis kurz vor Schluss")
    func letzterSatz() {
        #expect(imTraining([satz(9, 60), satz(9, 60, ok: false)]) == SatzVorschlag(kg: 60, wdh: 10, reserve: 0, grund: .ermuedung))
    }

    @Test("Ohne Gewicht im Training und abgehakte Zeilen")
    func ohneGewichtImTraining() {
        // 12 mit 2 Reserve: 14, minus 0,94 Ermüdung; letzter Satz, also Reserve 0: 13.
        #expect(imTraining([satz(12, nil), satz(12, nil, ok: false)], zeile: 1) == SatzVorschlag(kg: nil, wdh: 13, reserve: 0, grund: .ermuedung))
        #expect(imTraining([satz(12, 60), satz(12, 60, ok: false)], zeile: 0) == nil)
    }

    // MARK: - Aufwärmen, Drop, Anzeige

    @Test("Aufwärmzeilen in Prozent vom vorgeschlagenen Arbeitsgewicht")
    func aufwaermen() {
        let historie = [einheit("2026-11-02", [satz(10, 60), satz(10, 60), satz(9, 60)])]
        let warm = satz(10, 20, typ: "w", ok: false)
        let drei = [warm, warm, warm] + offen
        #expect(SatzVorhersageLogik.vorschlag(zeile: 0, saetze: drei, historie: historie, art: .isolation, schritt: 2.5, heute: heute)
            == SatzVorschlag(kg: 25, wdh: 10, reserve: 0, grund: .aufwaermen(40)))
        #expect(SatzVorhersageLogik.vorschlag(zeile: 2, saetze: drei, historie: historie, art: .isolation, schritt: 2.5, heute: heute)
            == SatzVorschlag(kg: 50, wdh: 3, reserve: 0, grund: .aufwaermen(80)))
        let zwei = [warm, warm] + offen
        #expect(SatzVorhersageLogik.vorschlag(zeile: 1, saetze: zwei, historie: historie, art: .isolation, schritt: 2.5, heute: heute)
            == SatzVorschlag(kg: 52.5, wdh: 2, reserve: 0, grund: .aufwaermen(85)))
    }

    @Test("Dropsatz: 20 % leichter als der Satz davor")
    func drop() {
        #expect(imTraining([satz(8, 60), satz(8, 60, typ: "d", ok: false)]) == SatzVorschlag(kg: 47.5, wdh: 8, reserve: 0, grund: .drop))
    }

    @Test("Texte, Scheiben und Vergleich mit der Zeile")
    func anzeige() {
        let v = SatzVorschlag(kg: 62.5, wdh: 8, reserve: 1, grund: .mehrGewicht(2.5))
        #expect(v.text == "62,5 kg × 8")
        #expect(v.reserveText == "1 Wdh Reserve")
        #expect(SatzVorschlag(kg: 40, wdh: 5, reserve: 0, grund: .aufwaermen(65)).reserveText == nil)
        #expect(v.passt(satz(8, 62.5, ok: false)))
        #expect(v.passt(satz(7, 62.5, ok: false)) == false)
        #expect(SatzVorhersageLogik.scheiben(kg: 62.5, geraet: "Langhantel") == "20, 1,25")
        #expect(SatzVorhersageLogik.scheiben(kg: 62.5, geraet: "Kurzhantel") == nil)
        #expect(SatzVorhersageLogik.scheiben(kg: 15, geraet: "Langhantel") == nil)
    }
}
