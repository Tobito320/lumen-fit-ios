import Foundation

/// Das Modul Schlaf: der Tab, der Verlauf und die Nachtansicht. Es hat keinen eigenen Zustand und keinen Hintergrund-Abruf;
/// Health holt und beobachtet das Grundgerüst (`GesundheitsStand`, `AppUmgebung.beobachteHealth`), die Band-Nächte stehen in den Ops `fit.band.schlaf`.
enum SchlafModul {
    /// Art der Ops mit den Band-Nächten (schreibt das Modul verbinden).
    nonisolated static let bandArt = "fit.band.schlaf"

    /// Idempotent und synchron: es gibt nichts zu starten (keine Ports, keine Aufgaben).
    @MainActor static func start(_ umgebung: AppUmgebung) {}

    /// Füllt für `-lumenFitDemo` das Band: sechs erfundene Band-Nächte mit Phasen, leicht versetzt zur Nacht der Demo-Uhr, damit "doppelte Nacht",
    /// Quelle und Vergleich zu sehen sind. Feste Op-Kennungen je Tag: zweimal säen ändert nichts.
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {
        guard let raum = umgebung.daten?.raum else { return }
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        for i in 1...6 {
            let tag = Datum.addTage(heute, -i)
            let ende = Datum.datum(tag).addingTimeInterval(7 * 3600 + Double((i * 5) % 11 - 5) * 60)
            let minuten = 400 + Double((i * 37) % 60)
            let start = ende.addingTimeInterval(-minuten * 60 + Double(8 + i * 2) * 60)
            let sekunden = ende.timeIntervalSince(start)
            let a = start.addingTimeInterval(sekunden * 0.3), b = start.addingTimeInterval(sekunden * 0.5)
            let c = start.addingTimeInterval(sekunden * 0.75)
            let phasen = [SchlafAbschnitt(phase: .kern, von: start, bis: a), SchlafAbschnitt(phase: .tief, von: a, bis: b),
                          SchlafAbschnitt(phase: .kern, von: b, bis: c), SchlafAbschnitt(phase: .rem, von: c, bis: ende)]
            let rumpf = BandSchlafOp(tag: tag, start: start, ende: ende, phasen: phasen)
            guard let daten = try? JSONEncoder().encode(rumpf) else { continue }
            raum.einreihen(Op(id: "demo-schlaf-band-\(tag)", art: bandArt, von: raum.profil, zeit: jetzt, d: daten))
        }
    }
}

/// Holt die Daten des Tabs aus der Umgebung: Health (`GesundheitsStand`), Band-Ops, Ziel.
@MainActor
enum SchlafDaten {
    /// Die Band-Nächte des aktiven Profils in der Reihenfolge des Eingangs. Der Raum meldet Änderungen nicht an die Oberfläche,
    /// darum liest die Ansicht beim Öffnen und bei Health-Ereignissen neu.
    static func bandOps(_ umgebung: AppUmgebung) -> [BandSchlafOp] { SchlafEigeneQuellen.bandOps(umgebung.daten?.raum) }

    /// Die Nächte von Hand (Op `fit.schlaf.hand`), je Aufwachtag die zuletzt eingetroffene.
    static func eingetragen(_ umgebung: AppUmgebung) -> [String: SchlafNacht] { SchlafEigeneQuellen.handNaechte(umgebung.daten?.raum) }

    static func zielExtra(_ umgebung: AppUmgebung) -> SchlafZielExtra {
        guard let raum = umgebung.daten?.raum else { return SchlafZielExtra() }
        return SchlafZielLogik.extra(ops: raum.ops(arten: [SchlafZielLogik.art]))
    }

    static func uebersicht(_ umgebung: AppUmgebung, band: [BandSchlafOp]) -> SchlafUebersicht {
        // Nur Health (mit Import): Band und Hand gibt die Quellenwahl selbst dazu, sonst stünden sie doppelt und als "Uhr" oder "Handy" da.
        SchlafUebersicht.bauen(health: umgebung.gesundheit.naechteAusHealth, band: band, vitale: umgebung.gesundheit.vitale,
                               zielMinuten: umgebung.daten?.ziele.ziele.schlafMinuten ?? 480, heute: Datum.text(umgebung.uhr()),
                               eingetragen: eingetragen(umgebung), zielExtra: zielExtra(umgebung))
    }
}
