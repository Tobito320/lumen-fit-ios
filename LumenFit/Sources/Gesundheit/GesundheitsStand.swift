import Foundation
import Observation

/// Der Gesundheitsstand für alle Tabs: Tageswerte, Nächte, Vitalwerte und Gewicht aus Health (über den Port). Schritte und Strecke nur aus Health
/// (Besitzer 10.11.2026), Einträge von Hand nur an Tagen ohne Health-Schritte; Nächte mit Hand und Band (`naechte`).
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
    @ObservationIgnored private let hand: @MainActor () -> [String: Int]
    @ObservationIgnored private let importVerlauf: @MainActor () -> ImportVerlaufStand
    @ObservationIgnored private let eigeneNaechte: @MainActor () -> SchlafEigeneQuellen
    @ObservationIgnored private var erstGeholt = false
    /// Für diese Typen wurde schon nach den Rechten gefragt; kommt ein Bereich dazu, fragt `aktualisiere` nur die fehlenden.
    @ObservationIgnored private var erfragt: Set<HealthTyp> = []
    /// Die Nächte wurden schon einmal ganz geholt; wer Schlaf erst später einschaltet, bekommt beim ersten Mal die vollen 60 Tage.
    @ObservationIgnored private var naechteGeholt = false
    @ObservationIgnored private let typen: @MainActor () -> Set<HealthTyp>
    /// Ob die App nach Leserechten fragen darf (die Person hat Health im Onboarding oder unter Health-Zugriff erlaubt). Sonst liest sie nur,
    /// was schon erlaubt ist, und zeigt nie still beim Start das Health-Blatt (09.11.2026: Rechte erst bei der Nutzung).
    @ObservationIgnored private let darfFragen: @MainActor () -> Bool
    /// Datei für den letzten Stand (im Profilordner, geht mit dem Profil weg). Der Start zeigt ihn sofort, bis Health antwortet (Startzeit 11.11.2026).
    @ObservationIgnored private let vorratDatei: @MainActor () -> URL?

    /// Was der Start aus der Datei zeigt, bis der erste Abruf da ist. Nur auf dem Gerät, nie gesendet.
    private struct Vorrat: Codable {
        var tage: [TagesWerte]
        var naechte: [SchlafNacht]
        var vitale: [VitalArt: [VitalMesswert]]
        var gewichte: [GewichtsMesswert]
    }

    /// `hand` liefert die Schritte von Hand je Tag (Ops `fit.schritte.hand` des aktiven Profils, `AppUmgebung` verdrahtet es). Die Band-Ops `fit.band.tag`
    /// zählen seit 10.11.2026 nicht mehr für die Schritte (die Daten bleiben gespeichert).
    /// `importVerlauf` liefert den Stand der importierten Lovea-Ops (Schritte, Schlaf); er füllt nur, was Health nicht hat (`ImportVerlaufLogik`).
    /// `eigeneNaechte` liefert die Nächte von Hand und vom Band des aktiven Profils (`AppUmgebung` verdrahtet es); ohne sie gilt nur Health.
    init(leser: any HealthLeser, uhr: @escaping Uhr, hand: @escaping @MainActor () -> [String: Int] = { [:] },
         importVerlauf: @escaping @MainActor () -> ImportVerlaufStand = { ImportVerlaufStand() },
         eigeneNaechte: @escaping @MainActor () -> SchlafEigeneQuellen = { SchlafEigeneQuellen() },
         typen: @escaping @MainActor () -> Set<HealthTyp> = { Set(HealthTyp.allCases) },
         darfFragen: @escaping @MainActor () -> Bool = { true },
         vorratDatei: @escaping @MainActor () -> URL? = { nil }) {
        self.vorratDatei = vorratDatei
        self.typen = typen
        self.darfFragen = darfFragen
        self.eigeneNaechte = eigeneNaechte
        self.leser = leser
        self.uhr = uhr
        self.hand = hand
        self.importVerlauf = importVerlauf
    }

    /// Tageswerte je Tag: Health; Schritte von Hand nur an Tagen ohne Health-Schritte (`SchritteHandLogik.zusammen`).
    var tage: [String: TagesWerte] {
        ImportVerlaufLogik.tage(SchritteHandLogik.zusammen(health: healthTage, hand: hand()), stand: importVerlauf())
    }

    /// Nächte je Aufwachtag, wie sie überall gelten (Heute, Wochenstreifen, Widget, Lovea-Brücke, Freundeskarte, Medaillen, Upload):
    /// Hand, Band, dann Health (`gewaehlteNaechte`). Nie nur Health.
    var naechte: [String: SchlafNacht] {
        Dictionary(gewaehlteNaechte(eigene: eigeneNaechte()).map { ($0.nacht.tag, $0.nacht) }, uniquingKeysWith: { $1 })
    }

    /// Nur Health: eigener Eintrag aus Lovea, Health, dann importierte Nächte nur an Tagen ohne Health. Ohne Band und ohne Nächte von Hand;
    /// der Schlaf-Tab gibt sie der Quellenwahl getrennt, damit jede Nacht ihre Quelle behält.
    var naechteAusHealth: [String: SchlafNacht] { ImportVerlaufLogik.naechte(health: healthNaechte, stand: importVerlauf()) }

    /// Die eine Wahl für Schlaf (`SchlafQuellenWahl.waehle`): von Hand vor Band vor Health (Phasen zählen mehr als jeder Rang, ein Band mit Phasen
    /// gilt vor der Uhr), je Nacht die genaueste Quelle. `eigene` sind die Nächte von Hand und vom Band des Profils (`SchlafEigeneQuellen.lesen`).
    /// Tage, die der Lovea-Import gesperrt hat, bleiben leer, außer der Nutzer trägt sie selbst ein.
    func gewaehlteNaechte(eigene: SchlafEigeneQuellen) -> [SchlafGewaehlteNacht] {
        let stand = importVerlauf()
        var eingetragen = stand.schlafEigen
        eingetragen.merge(eigene.hand) { _, neu in neu }
        let liste = SchlafQuellenWahl.waehle(health: naechteAusHealth, band: eigene.band, eingetragen: eingetragen)
        return liste.filter { !stand.schlafGesperrt.contains($0.nacht.tag) || eigene.hand[$0.nacht.tag] != nil }
    }

    /// Schritte je Tag nur aus Health, ohne Band (Schlaf-Beleg: beide Quellen getrennt sehen).
    var schritteAusHealth: [String: Int] { healthTage.mapValues(\.schritte) }

    /// Läuft schon ein Abruf (Heute, Schlaf und der Hintergrund-Abruf rufen bei derselben Health-Meldung), warten alle auf diesen einen statt je zehn Abfragen zu starten.
    @ObservationIgnored private var laufend: Task<Void, Never>?
    /// Kam ein Aufruf während des Abrufs, hat der laufende neue Werte oder einen neuen Bereich vielleicht verpasst: danach genau ein Folgeabruf für alle Wartenden.
    @ObservationIgnored private var nochmal = false

    /// Erster Aufruf holt 60 Tage und fragt die Rechte, spätere nur das Neue (die letzten Tage, weil Health Daten nachträgt).
    func aktualisiere() async {
        if let laufend {
            nochmal = true
            await laufend.value
            return
        }
        let abruf = Task {
            repeat {
                nochmal = false
                await abrufen()
            } while nochmal
            laufend = nil   // ohne `await` nach der Prüfung: kein Aufruf kann sich an einen schon fertigen Abruf hängen
        }
        laufend = abruf
        await abruf.value
    }

    private func abrufen() async {
        let heute = Datum.text(uhr())
        let anzahl = erstGeholt ? Self.nachladeTage : Self.ersteTage
        let von = Datum.addTage(heute, -(anzahl - 1))
        let gewollt = typen()
        if !gewollt.isSubset(of: erfragt), darfFragen() {
            zugriff = await leser.zugriff(fuer: gewollt)
            // Ein Fehler (z. B. Health gesperrt, weil iOS die App im Hintergrund bei gesperrtem iPhone startet) wird nicht gemerkt, sonst bliebe Health bis zum Neustart leer.
            if zugriff != .nichtVerfuegbar { erfragt.formUnion(gewollt) }
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
        sichereVorrat()
    }

    /// Füllt beim Start den letzten Stand aus der Datei (nur solange noch nichts geholt ist); der erste Abruf überschreibt ihn.
    func ladeVorrat() {
        guard !erstGeholt, healthTage.isEmpty, let datei = vorratDatei(), let daten = try? Data(contentsOf: datei),
              let v = try? JSONDecoder().decode(Vorrat.self, from: daten) else { return }
        healthTage = Dictionary(v.tage.map { ($0.tag, $0) }, uniquingKeysWith: { $1 })
        healthNaechte = Dictionary(v.naechte.map { ($0.tag, $0) }, uniquingKeysWith: { $1 })
        vitale = v.vitale
        gewichte = v.gewichte
    }

    private func sichereVorrat() {
        guard let datei = vorratDatei() else { return }
        let v = Vorrat(tage: Array(healthTage.values), naechte: Array(healthNaechte.values), vitale: vitale, gewichte: gewichte)
        guard let daten = try? JSONEncoder().encode(v) else { return }
        try? daten.write(to: datei, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
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
