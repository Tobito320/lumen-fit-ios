import Foundation

/// Health-Zugriff im Klartext (Idee 75). HealthKit verrät nie, ob Lesen abgelehnt wurde (Datenschutz): die App sagt deshalb nie "erlaubt" oder
/// "abgelehnt", sondern nur, ob in den letzten 30 Tagen Daten angekommen sind. Die Probe liest nur; die Rechte-Abfrage macht sie nie.
enum ProfilHealthZeile: Equatable, Sendable {
    case datenDa, keineDaten
    /// Diesen Typ liest die App heute nicht so, dass sich eine Probe lohnt (Stehen, Puls ohne Training).
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
        case .stehen:
            // `HKHealthLeser` liefert heute keine Stehstunden; erst wenn welche ankommen, lässt sich die Frage beantworten.
            let gemessen = b.tage.filter { $0.stehStunden != nil }
            return gemessen.isEmpty ? .nichtPruefbar : da(gemessen.contains { ($0.stehStunden ?? 0) > 0 })
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

    /// Kurzer Wert für die Einstellungszeile: "2 von 15 mit Daten".
    static func zusammenfassung(_ b: Befund) -> String {
        let mitDaten = HealthTyp.allCases.filter { zeile($0, b) == .datenDa }.count
        return "\(mitDaten) von \(HealthTyp.allCases.count) mit Daten"
    }

    static func text(_ zeile: ProfilHealthZeile) -> String {
        switch zeile {
        case .datenDa: "Daten da"
        case .keineDaten: "keine Daten in \(tage) Tagen"
        case .nichtPruefbar: "noch nicht prüfbar"
        }
    }

    static func name(_ typ: HealthTyp) -> String {
        switch typ {
        case .schritte: "Schritte"
        case .distanz: "Strecke"
        case .etagen: "Etagen"
        case .aktiveEnergie: "Aktive Energie"
        case .training: "Training"
        case .stehen: "Stehen"
        case .schlaf: "Schlaf"
        case .ruhepuls: "Ruhepuls"
        case .hrv: "Herzfrequenzvariabilität"
        case .sauerstoff: "Blutsauerstoff"
        case .atmung: "Atemfrequenz"
        case .temperatur: "Handgelenktemperatur"
        case .vo2max: "VO2max"
        case .gewicht: "Gewicht"
        case .puls: "Puls"
        }
    }

    /// Warum die App den Typ braucht, in einem Satz.
    static func grund(_ typ: HealthTyp) -> String {
        switch typ {
        case .schritte: "Für dein Schrittziel und den Tagesbogen."
        case .distanz: "Für die Strecke deines Tages."
        case .etagen: "Für gestiegene Etagen im Tagesverlauf."
        case .aktiveEnergie: "Für deine aktive Energie und das Bewegen-Ziel."
        case .training: "Damit Training aus anderen Apps und von der Uhr zählt."
        case .stehen: "Für die Steh-Stunden im Tagesverlauf."
        case .schlaf: "Für deine Nächte, Schlafphasen und die Bereitschaft am Morgen."
        case .ruhepuls: "Für deine Erholung: ein niedriger Ruhepuls ist ein gutes Zeichen."
        case .hrv: "Für deine Erholung: Lumi vergleicht mit deinem eigenen Schnitt."
        case .sauerstoff: "Für die Werte der Nacht."
        case .atmung: "Für die Werte der Nacht."
        case .temperatur: "Für die Werte der Nacht."
        case .vo2max: "Für deine Ausdauer im Fortschritt."
        case .gewicht: "Damit dein Gewicht aus Health in Verlauf und Zielen erscheint."
        case .puls: "Für den Puls im Training, wenn eine Uhr ihn misst."
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
        case .stehen: "figure.stand"
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
    static let wegText = "Einstellungen, Health, Datenzugriff und Geräte, Lumen Fit"
    static let erklaerung = "Health verrät Apps nie, ob du das Lesen gesperrt hast. Lumen Fit zeigt deshalb nur, ob Daten ankommen. Ändern kannst du es jederzeit in den Einstellungen deines iPhones."
}
