// Quelle: Lovea Health/HealthModell.swift (HealthKit-Abfragen, neu geschrieben hinter dem Port)
import Foundation
import HealthKit

/// Liest Health. HealthKit verrät nie, ob Lesen abgelehnt wurde (Datenschutz): "keine Daten" ist die einzige ehrliche Aussage.
// @unchecked Sendable: HKHealthStore ist thread-sicher, aber im SDK nicht als Sendable markiert; das Objekt hält sonst nur Konstanten.
final class HKHealthLeser: HealthLeser, @unchecked Sendable {
    private let speicher = HKHealthStore()

    init() {}

    // MARK: - Typen

    static func lesetypen(_ typ: HealthTyp) -> [HKObjectType] {
        switch typ {
        case .schritte: [HKQuantityType(.stepCount)]
        case .distanz: [HKQuantityType(.distanceWalkingRunning)]
        case .etagen: [HKQuantityType(.flightsClimbed)]
        case .aktiveEnergie: [HKQuantityType(.activeEnergyBurned)]
        case .training: [HKObjectType.workoutType(), HKQuantityType(.appleExerciseTime)]
        case .schlaf: [HKCategoryType(.sleepAnalysis)]
        case .ruhepuls: [HKQuantityType(.restingHeartRate)]
        case .hrv: [HKQuantityType(.heartRateVariabilitySDNN)]
        case .sauerstoff: [HKQuantityType(.oxygenSaturation)]
        case .atmung: [HKQuantityType(.respiratoryRate)]
        case .temperatur: [HKQuantityType(.appleSleepingWristTemperature)]
        case .vo2max: [HKQuantityType(.vo2Max)]
        case .gewicht: [HKQuantityType(.bodyMass)]
        case .puls: [HKQuantityType(.heartRate)]
        }
    }

    /// Fragt die Leserechte, je Typ nur einmal für immer (`HealthFrageGedaechtnis`). Das Ergebnis sagt nur, dass gefragt wurde, nicht was erlaubt ist.
    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff {
        guard HKHealthStore.isHealthDataAvailable() else { return .nichtVerfuegbar }
        let lesen = Set(typen.flatMap(Self.lesetypen)).filter { !HealthFrageGedaechtnis.gefragt(HealthFrageGedaechtnis.lesen($0)) }
        guard !lesen.isEmpty else { return .angefragt }
        do {
            try await speicher.requestAuthorization(toShare: [], read: lesen)
            // Erst nach Erfolg merken: ein Fehler (Health gesperrt im Hintergrund) darf die einzige Frage nicht verbrauchen.
            HealthFrageGedaechtnis.merke(lesen.map { HealthFrageGedaechtnis.lesen($0) })
            return .angefragt
        } catch { return .nichtVerfuegbar }
    }

    // MARK: - Hilfen

    private func fenster(von: String, bis: String) -> (start: Date, ende: Date)? {
        guard SchlafNachtLogik.gueltigerTag(von), SchlafNachtLogik.gueltigerTag(bis), von <= bis else { return nil }
        let start = Datum.kalender.startOfDay(for: Datum.datum(von))
        guard let ende = Datum.kalender.date(byAdding: .day, value: 1, to: Datum.kalender.startOfDay(for: Datum.datum(bis))) else { return nil }
        return (start, ende)
    }

    /// Eine Zahl je Tag: Summe (Schritte ...) oder Tagesschnitt (Ruhepuls ...).
    private func tageswerte(_ kennung: HKQuantityTypeIdentifier, einheit: HKUnit, summe: Bool, von: String, bis: String) async -> [String: Double] {
        guard let zeit = fenster(von: von, bis: bis) else { return [:] }
        let typ = HKQuantityType(kennung)
        let praedikat = HKQuery.predicateForSamples(withStart: zeit.start, end: zeit.ende, options: [])
        let optionen: HKStatisticsOptions = summe ? .cumulativeSum : .discreteAverage
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKStatisticsCollectionQuery(quantityType: typ, quantitySamplePredicate: praedikat, options: optionen,
                                                      anchorDate: zeit.start, intervalComponents: DateComponents(day: 1))
            abfrage.initialResultsHandler = { _, ergebnis, _ in
                var werte: [String: Double] = [:]
                ergebnis?.enumerateStatistics(from: zeit.start, to: zeit.ende) { statistik, _ in
                    let menge = summe ? statistik.sumQuantity() : statistik.averageQuantity()
                    if let menge { werte[Datum.text(statistik.startDate)] = menge.doubleValue(for: einheit) }
                }
                fortsetzung.resume(returning: werte)
            }
            speicher.execute(abfrage)
        }
    }

    // MARK: - Lesen

    func tagesWerte(von: String, bis: String) async -> [TagesWerte] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        async let schritte = tageswerte(.stepCount, einheit: .count(), summe: true, von: von, bis: bis)
        async let distanz = tageswerte(.distanceWalkingRunning, einheit: .meter(), summe: true, von: von, bis: bis)
        async let etagen = tageswerte(.flightsClimbed, einheit: .count(), summe: true, von: von, bis: bis)
        async let energie = tageswerte(.activeEnergyBurned, einheit: .kilocalorie(), summe: true, von: von, bis: bis)
        async let training = tageswerte(.appleExerciseTime, einheit: .minute(), summe: true, von: von, bis: bis)
        let (s, d, e, k, t) = await (schritte, distanz, etagen, energie, training)
        let tage = Set(s.keys).union(d.keys).union(e.keys).union(k.keys).union(t.keys).sorted()
        return tage.map { tag in
            TagesWerte(tag: tag, schritte: Int((s[tag] ?? 0).rounded()), distanzMeter: d[tag] ?? 0, etagen: Int((e[tag] ?? 0).rounded()),
                       aktiveKcal: k[tag] ?? 0, trainingMinuten: Int((t[tag] ?? 0).rounded()), stehStunden: nil)
        }
    }

    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] {
        guard HKHealthStore.isHealthDataAvailable(), let zeit = fenster(von: von, bis: bis),
              let anfang = Datum.kalender.date(byAdding: .hour, value: -30, to: zeit.start) else { return [] }
        let praedikat = HKQuery.predicateForSamples(withStart: anfang, end: zeit.ende, options: .strictStartDate)
        let roh: [SchlafNachtLogik.Roh] = await withCheckedContinuation { fortsetzung in
            let abfrage = HKSampleQuery(sampleType: HKCategoryType(.sleepAnalysis), predicate: praedikat, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, proben, _ in
                let liste = ((proben as? [HKCategorySample]) ?? []).compactMap { probe -> SchlafNachtLogik.Roh? in
                    Self.phase(probe.value).map { SchlafNachtLogik.Roh(phase: $0, von: probe.startDate, bis: probe.endDate) }
                }
                fortsetzung.resume(returning: liste)
            }
            speicher.execute(abfrage)
        }
        return SchlafAuswertung.naechte(roh, von: von, bis: bis)
    }

    /// Alle Schlafproben der Tage mit Rohwert und Quelle, ohne Auswahl (Schlaf-Beleg). Gleiches Fenster wie `schlafNaechte`.
    func schlafProben(von: String, bis: String) async -> [HealthSchlafProbe] {
        guard HKHealthStore.isHealthDataAvailable(), let zeit = fenster(von: von, bis: bis),
              let anfang = Datum.kalender.date(byAdding: .hour, value: -30, to: zeit.start) else { return [] }
        let praedikat = HKQuery.predicateForSamples(withStart: anfang, end: zeit.ende, options: .strictStartDate)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKSampleQuery(sampleType: HKCategoryType(.sleepAnalysis), predicate: praedikat, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, proben, _ in
                let liste = ((proben as? [HKCategorySample]) ?? []).map { probe in
                    HealthSchlafProbe(wert: probe.value, von: probe.startDate, bis: probe.endDate,
                                      quelle: probe.sourceRevision.source.bundleIdentifier, geraet: probe.sourceRevision.productType)
                }
                fortsetzung.resume(returning: liste)
            }
            speicher.execute(abfrage)
        }
    }

    /// Wach und "im Bett" zählen nicht als Schlaf; die Lücken zwischen den Abschnitten sind die Wachzeit.
    private static func phase(_ wert: Int) -> SchlafPhase? {
        switch HKCategoryValueSleepAnalysis(rawValue: wert) {
        case .asleepCore: .kern
        case .asleepDeep: .tief
        case .asleepREM: .rem
        case .asleepUnspecified: .unbestimmt
        default: nil
        }
    }

    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let werte: [String: Double]
        switch art {
        case .ruhepuls:
            werte = await tageswerte(.restingHeartRate, einheit: HKUnit.count().unitDivided(by: .minute()), summe: false, von: von, bis: bis)
        case .hrv:
            werte = await tageswerte(.heartRateVariabilitySDNN, einheit: .secondUnit(with: .milli), summe: false, von: von, bis: bis)
        case .sauerstoff:
            werte = await tageswerte(.oxygenSaturation, einheit: .percent(), summe: false, von: von, bis: bis).mapValues { $0 * 100 }
        case .atemfrequenz:
            werte = await tageswerte(.respiratoryRate, einheit: HKUnit.count().unitDivided(by: .minute()), summe: false, von: von, bis: bis)
        case .temperatur:
            werte = await tageswerte(.appleSleepingWristTemperature, einheit: .degreeCelsius(), summe: false, von: von, bis: bis)
        case .vo2max:
            werte = await tageswerte(.vo2Max, einheit: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute())), summe: false, von: von, bis: bis)
        }
        return werte.sorted { $0.key < $1.key }.map { VitalMesswert(art: art, tag: $0.key, wert: $0.value) }
    }

    func gewichte(von: String, bis: String) async -> [GewichtsMesswert] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let werte = await tageswerte(.bodyMass, einheit: .gramUnit(with: .kilo), summe: false, von: von, bis: bis)
        return werte.sorted { $0.key < $1.key }.map { GewichtsMesswert(tag: $0.key, kg: $0.value) }
    }

    func workouts(von: String, bis: String) async -> [HealthWorkout] {
        guard HKHealthStore.isHealthDataAvailable(), let zeit = fenster(von: von, bis: bis) else { return [] }
        let praedikat = HKQuery.predicateForSamples(withStart: zeit.start, end: zeit.ende, options: .strictStartDate)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: praedikat, limit: HKObjectQueryNoLimit,
                                        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, proben, _ in
                let liste = ((proben as? [HKWorkout]) ?? []).map { w in
                    HealthWorkout(id: w.uuid.uuidString, art: String(w.workoutActivityType.rawValue), start: w.startDate, ende: w.endDate,
                                  kcal: w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                                  puls: w.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                }
                fortsetzung.resume(returning: liste)
            }
            speicher.execute(abfrage)
        }
    }

    // MARK: - Hintergrundlieferung

    /// Meldet `aenderung`, sobald neue Daten ankommen, auch wenn iOS die App dafür im Hintergrund startet.
    /// Der Abschluss geht sofort nach dem Anstoßen; die Arbeit danach hält `AppUmgebung.beobachteHealth` mit eigener Hintergrundzeit wach.
    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) {
        beobachte(typen) { fertig in aenderung(); fertig() }
    }

    // @unchecked Sendable: der Abschluss-Block von HealthKit ist im SDK nicht als Sendable markiert, darf aber von jedem Thread einmal gerufen werden.
    private struct Abschluss: @unchecked Sendable { let rufen: () -> Void }

    func beobachte(_ typen: Set<HealthTyp>, mitAbschluss aenderung: @escaping @Sendable (_ fertig: @escaping @Sendable () -> Void) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        for typ in typen {
            for objekt in Self.lesetypen(typ) {
                guard let probe = objekt as? HKSampleType else { continue }
                let abfrage = HKObserverQuery(sampleType: probe, predicate: nil) { _, abschluss, fehler in
                    guard fehler == nil else { abschluss(); return }
                    // Erst fertig melden, wenn der Abruf durch ist; genau einmal, auch wenn der Aufrufer es doppelt ruft.
                    let block = Abschluss(rufen: abschluss)
                    let einmal = EinmalSchalter()
                    aenderung { if einmal.zuerst() { block.rufen() } }
                }
                speicher.execute(abfrage)
                speicher.enableBackgroundDelivery(for: probe, frequency: .immediate) { _, _ in }
            }
        }
    }
}
