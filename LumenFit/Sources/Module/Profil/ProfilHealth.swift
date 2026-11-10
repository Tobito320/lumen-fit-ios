import Foundation

/// Health-Zugriff im Klartext (Idee 75). HealthKit verrät nie, ob Lesen abgelehnt wurde (Datenschutz): die App sagt deshalb nie "erlaubt" oder
/// "abgelehnt", sondern nur, ob in den letzten 30 Tagen Daten angekommen sind. Die Probe liest nur; die Rechte-Abfrage macht sie nie.
enum ProfilHealthZeile: Equatable, Sendable {
    case datenDa, keineDaten
    /// Diesen Typ liest die App heute nicht so, dass sich eine Probe lohnt (Puls ohne Training).
    case nichtPruefbar
}

enum ProfilHealthProbe {
    static let tage = 30

    struct Befund: Sendable {
        var tage: [TagesWerte] = []
        var naechte: [SchlafNacht] = []
        var vitale: [VitalArt: [VitalMesswert]] = [:]
        var gewichte: [GewichtsMesswert] = []
        var workouts: [HealthWorkout] = []
    }

    /// Liest die letzten 30 Tage (bis einschließlich `heute`). Fragt keine Rechte.
    static func probe(leser: any HealthLeser, heute: String) async -> Befund {
        let von = Datum.addTage(heute, -(tage - 1))
        async let t = leser.tagesWerte(von: von, bis: heute)
        async let n = leser.schlafNaechte(von: von, bis: heute)
        async let g = leser.gewichte(von: von, bis: heute)
        async let w = leser.workouts(von: von, bis: heute)
        async let ruhepuls = leser.vitalwerte(.ruhepuls, von: von, bis: heute)
        async let hrv = leser.vitalwerte(.hrv, von: von, bis: heute)
        async let sauerstoff = leser.vitalwerte(.sauerstoff, von: von, bis: heute)
        async let atmung = leser.vitalwerte(.atemfrequenz, von: von, bis: heute)
        async let temperatur = leser.vitalwerte(.temperatur, von: von, bis: heute)
        async let vo2 = leser.vitalwerte(.vo2max, von: von, bis: heute)
        let (tageNeu, naechteNeu, gewichteNeu, workoutsNeu) = await (t, n, g, w)
        let vitale: [VitalArt: [VitalMesswert]] = await [.ruhepuls: ruhepuls, .hrv: hrv, .sauerstoff: sauerstoff,
                                                         .atemfrequenz: atmung, .temperatur: temperatur, .vo2max: vo2]
        return Befund(tage: tageNeu, naechte: naechteNeu, vitale: vitale, gewichte: gewichteNeu, workouts: workoutsNeu)
    }

    static func zeile(_ typ: HealthTyp, _ b: Befund) -> ProfilHealthZeile {
        func da(_ ja: Bool) -> ProfilHealthZeile { ja ? .datenDa : .keineDaten }
        func vital(_ art: VitalArt) -> ProfilHealthZeile { da(!(b.vitale[art] ?? []).isEmpty) }
        switch typ {
        case .schritte: return da(b.tage.contains { $0.schritte > 0 })
        case .distanz: return da(b.tage.contains { $0.distanzMeter > 0 })
        case .etagen: return da(b.tage.contains { $0.etagen > 0 })
        case .aktiveEnergie: return da(b.tage.contains { $0.aktiveKcal > 0 })
        case .training: return da(b.tage.contains { $0.trainingMinuten > 0 } || !b.workouts.isEmpty)
        case .schlaf: return da(!b.naechte.isEmpty)
        case .ruhepuls: return vital(.ruhepuls)
        case .hrv: return vital(.hrv)
        case .sauerstoff: return vital(.sauerstoff)
        case .atmung: return vital(.atemfrequenz)
        case .temperatur: return vital(.temperatur)
        case .vo2max: return vital(.vo2max)
        case .gewicht: return da(!b.gewichte.isEmpty)
        case .puls:
            let mitPuls = b.workouts.filter { $0.puls != nil }
            return mitPuls.isEmpty ? .nichtPruefbar : .datenDa
        }
    }

    /// Kurzer Wert für die Einstellungszeile: "2 von 14 mit Daten".
    /// `typen`: nur die Typen der gewählten Bereiche zählen.
    static func zusammenfassung(_ b: Befund, typen: Set<HealthTyp> = Set(HealthTyp.allCases)) -> String {
        let aktiv = HealthTyp.allCases.filter { typen.contains($0) }
        let mitDaten = aktiv.filter { zeile($0, b) == .datenDa }.count
        return String(localized: "\(mitDaten) von \(aktiv.count) mit Daten")
    }

    static func text(_ zeile: ProfilHealthZeile) -> String {
        switch zeile {
        case .datenDa: String(localized: "Daten da")
        case .keineDaten: String(localized: "keine Daten in \(tage) Tagen")
        case .nichtPruefbar: String(localized: "noch nicht prüfbar")
        }
    }

    static func name(_ typ: HealthTyp) -> String {
        switch typ {
        case .schritte: String(localized: "Schritte")
        case .distanz: String(localized: "Strecke")
        case .etagen: String(localized: "Etagen")
        case .aktiveEnergie: String(localized: "Aktive Energie")
        case .training: String(localized: "Training")
        case .schlaf: String(localized: "Schlaf")
        case .ruhepuls: String(localized: "Ruhepuls")
        case .hrv: String(localized: "Herzfrequenzvariabilität")
        case .sauerstoff: String(localized: "Blutsauerstoff")
        case .atmung: String(localized: "Atemfrequenz")
        case .temperatur: String(localized: "Handgelenktemperatur")
        case .vo2max: "VO2max"
        case .gewicht: String(localized: "Gewicht")
        case .puls: String(localized: "Puls")
        }
    }

    /// Warum die App den Typ braucht, in einem Satz.
    static func grund(_ typ: HealthTyp) -> String {
        switch typ {
        case .schritte: String(localized: "Für dein Schrittziel und den Tagesbogen.")
        case .distanz: String(localized: "Für die Strecke deines Tages.")
        case .etagen: String(localized: "Für gestiegene Etagen im Tagesverlauf.")
        case .aktiveEnergie: String(localized: "Für deine aktive Energie und das Bewegen-Ziel.")
        case .training: String(localized: "Damit Training aus anderen Apps und von der Uhr zählt.")
        case .schlaf: String(localized: "Für deine Nächte, Schlafphasen und die Bereitschaft am Morgen.")
        case .ruhepuls: String(localized: "Für deine Erholung: ein niedriger Ruhepuls ist ein gutes Zeichen.")
        case .hrv: String(localized: "Für deine Erholung: Lumi vergleicht mit deinem eigenen Schnitt.")
        case .sauerstoff: String(localized: "Für die Werte der Nacht.")
        case .atmung: String(localized: "Für die Werte der Nacht.")
        case .temperatur: String(localized: "Für die Werte der Nacht.")
        case .vo2max: String(localized: "Für deine Ausdauer im Fortschritt.")
        case .gewicht: String(localized: "Damit dein Gewicht aus Health in Verlauf und Zielen erscheint.")
        case .puls: String(localized: "Für den Puls im Training, wenn eine Uhr ihn misst.")
        }
    }

    /// SF-Symbol je Typ (Test `ProfilHealthTests` prüft, dass es jeden Namen gibt).
    static func symbol(_ typ: HealthTyp) -> String {
        switch typ {
        case .schritte: "figure.walk"
        case .distanz: "map"
        case .etagen: "figure.stairs"
        case .aktiveEnergie: "flame.fill"
        case .training: "dumbbell.fill"
        case .schlaf: "bed.double.fill"
        case .ruhepuls: "heart.fill"
        case .hrv: "waveform.path.ecg"
        case .sauerstoff: "lungs.fill"
        case .atmung: "wind"
        case .temperatur: "thermometer.medium"
        case .vo2max: "figure.run"
        case .gewicht: "scalemass.fill"
        case .puls: "heart.circle.fill"
        }
    }

    /// Der Weg in die Einstellungen, wenn sich etwas ändern soll.
    static let wegText = String(localized: "Einstellungen, Health, Datenzugriff und Geräte, Lumen Fit")
    static let erklaerung = String(localized: "Health verrät Apps nie, ob du das Lesen gesperrt hast. Lumen Fit zeigt deshalb nur, ob Daten ankommen. Ändern kannst du es jederzeit in den Einstellungen deines iPhones.")
}
