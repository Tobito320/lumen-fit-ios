import Foundation
import Observation

/// Der Gesundheitsstand für alle Tabs: Tageswerte, Nächte, Vitalwerte und Gewicht aus Health (über den Port), mit dem Band zusammen.
/// Der erste Aufruf von `aktualisiere` holt 60 Tage (Idee 8: der erste Tag ist schon voll), spätere nur die letzten Tage.
@MainActor @Observable
final class GesundheitsStand {
    nonisolated static let ersteTage = 60
    nonisolated static let nachladeTage = 3

    private(set) var zugriff: HealthZugriff = .unbekannt
    private var healthTage: [String: TagesWerte] = [:]
    private var healthNaechte: [String: SchlafNacht] = [:]
    private(set) var vitale: [VitalArt: [VitalMesswert]] = [:]
    private(set) var gewichte: [GewichtsMesswert] = []
    private(set) var letzteAktualisierung: Date?

    @ObservationIgnored private let leser: any HealthLeser
    @ObservationIgnored private let uhr: Uhr
    @ObservationIgnored private let band: @MainActor () -> [BandTagOp]
    @ObservationIgnored private let importVerlauf: @MainActor () -> ImportVerlaufStand
    @ObservationIgnored private var erstGeholt = false
    /// Für diese Typen wurde schon nach den Rechten gefragt; kommt ein Bereich dazu, fragt `aktualisiere` nur die fehlenden.
    @ObservationIgnored private var erfragt: Set<HealthTyp> = []
    /// Die Nächte wurden schon einmal ganz geholt; wer Schlaf erst später einschaltet, bekommt beim ersten Mal die vollen 60 Tage.
    @ObservationIgnored private var naechteGeholt = false
    @ObservationIgnored private let typen: @MainActor () -> Set<HealthTyp>

    /// `band` liefert die Tage der Ops `fit.band.tag` des aktiven Profils (`AppUmgebung` verdrahtet es); je Tag gilt das Maximum, nie die Summe.
    /// `importVerlauf` liefert den Stand der importierten Lovea-Ops (Schritte, Schlaf); er füllt nur, was Health nicht hat (`ImportVerlaufLogik`).
    init(leser: any HealthLeser, uhr: @escaping Uhr, band: @escaping @MainActor () -> [BandTagOp] = { [] },
         importVerlauf: @escaping @MainActor () -> ImportVerlaufStand = { ImportVerlaufStand() },
         typen: @escaping @MainActor () -> Set<HealthTyp> = { Set(HealthTyp.allCases) }) {
        self.typen = typen
        self.leser = leser
        self.uhr = uhr
        self.band = band
        self.importVerlauf = importVerlauf
    }

    /// Tageswerte je Tag: Health, mit dem Band je Tag das Maximum bei Schritten und Distanz.
    var tage: [String: TagesWerte] {
        ImportVerlaufLogik.tage(bandUndHealth, stand: importVerlauf())
    }

    /// Nächte je Aufwachtag: eigener Eintrag, Health, dann importierte Nächte nur an Tagen ohne Health.
    var naechte: [String: SchlafNacht] { ImportVerlaufLogik.naechte(health: healthNaechte, stand: importVerlauf()) }

    private var bandUndHealth: [String: TagesWerte] {
        var ergebnis = healthTage
        for b in band() {
            var t = ergebnis[b.tag] ?? TagesWerte(tag: b.tag)
            t.schritte = HealthLogik.schritteTag(health: ergebnis[b.tag]?.schritte, band: b.schritte) ?? t.schritte
            t.distanzMeter = max(t.distanzMeter, Double(b.meter))
            ergebnis[b.tag] = t
        }
        return ergebnis
    }

    /// Erster Aufruf holt 60 Tage und fragt die Rechte, spätere nur das Neue (die letzten Tage, weil Health Daten nachträgt).
    func aktualisiere() async {
        let heute = Datum.text(uhr())
        let anzahl = erstGeholt ? Self.nachladeTage : Self.ersteTage
        let von = Datum.addTage(heute, -(anzahl - 1))
        let gewollt = typen()
        if !gewollt.isSubset(of: erfragt) {
            zugriff = await leser.zugriff(fuer: gewollt)
            erfragt.formUnion(gewollt)
        }
        guard zugriff != .nichtVerfuegbar else { return }
        async let neueTage = leser.tagesWerte(von: von, bis: heute)
        async let neueNaechte = naechte(lesen: gewollt.contains(.schlaf), von: naechteGeholt ? von : Datum.addTage(heute, -(Self.ersteTage - 1)), bis: heute)
        async let neueGewichte = leser.gewichte(von: von, bis: heute)
        async let ruhepuls = leser.vitalwerte(.ruhepuls, von: von, bis: heute)
        async let hrv = leser.vitalwerte(.hrv, von: von, bis: heute)
        async let sauerstoff = leser.vitalwerte(.sauerstoff, von: von, bis: heute)
        async let atmung = leser.vitalwerte(.atemfrequenz, von: von, bis: heute)
        async let temperatur = leser.vitalwerte(.temperatur, von: von, bis: heute)
        async let vo2 = leser.vitalwerte(.vo2max, von: von, bis: heute)
        let (tageNeu, naechteNeu, gewichteNeu) = await (neueTage, neueNaechte, neueGewichte)
        let vitalNeu: [VitalArt: [VitalMesswert]] = await [.ruhepuls: ruhepuls, .hrv: hrv, .sauerstoff: sauerstoff,
                                                          .atemfrequenz: atmung, .temperatur: temperatur, .vo2max: vo2]
        for t in tageNeu { healthTage[t.tag] = t }
        for n in naechteNeu { healthNaechte[n.tag] = n }
        gewichte = Self.zusammen(gewichte, gewichteNeu, von: von)
        for (art, liste) in vitalNeu { vitale[art] = Self.zusammenV(vitale[art] ?? [], liste, von: von) }
        if gewollt.contains(.schlaf) { naechteGeholt = true }
        erstGeholt = true
        letzteAktualisierung = uhr()
    }

    /// Ohne Schlaf-Bereich fragt die App Health nach keiner Nacht.
    private func naechte(lesen: Bool, von: String, bis: String) async -> [SchlafNacht] {
        lesen ? await leser.schlafNaechte(von: von, bis: bis) : []
    }

    /// Alte Werte vor `von` bleiben, ab `von` gilt die neue Abfrage.
    private static func zusammen(_ alt: [GewichtsMesswert], _ neu: [GewichtsMesswert], von: String) -> [GewichtsMesswert] {
        (alt.filter { $0.tag < von } + neu).sorted { $0.tag < $1.tag }
    }

    private static func zusammenV(_ alt: [VitalMesswert], _ neu: [VitalMesswert], von: String) -> [VitalMesswert] {
        (alt.filter { $0.tag < von } + neu).sorted { $0.tag < $1.tag }
    }
}
