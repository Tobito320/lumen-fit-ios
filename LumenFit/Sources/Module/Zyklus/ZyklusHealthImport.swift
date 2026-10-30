// Quelle: Lovea Zyklus/ZyklusHealthKit.swift (dazu das Gewicht über den vorhandenen Health-Leser)
import Foundation
import HealthKit

/// Zyklus-Verknüpfung mit Apple Health, nur lesend und nur mit dem Schalter in den Zyklus-Einstellungen.
/// Gelesen werden Menstruationsfluss und Basaltemperatur der letzten Wochen (eigener Lesezugriff) und das Gewicht (über `HealthLeser`);
/// sie landen nur in Tagen, in denen das Feld noch leer ist (was die Person selbst eingetragen hat, bleibt). Lumen Fit schreibt nichts nach Health.
/// Rechte-, Abbildungs- und Leselogik stehen hier; der Teil ohne Health-Zugriff ist ohne Gerät testbar.
enum ZyklusHealthImport {
    /// Der erste Import schaut so viele Tage zurück.
    nonisolated static let rueckblickTage = 60

    /// Genau die Typen, die dieser Import selbst anfragt. Schreibrechte fragt Lumen Fit hier nie an. Das Gewicht kommt über den Health-Leser der App.
    static var leseTypen: Set<HKObjectType> {
        [HKCategoryType(.menstrualFlow), HKQuantityType(.basalBodyTemperature)]
    }

    /// `.unspecified` heißt Blutung ohne Stärke, wir nehmen mittel. `.none` ist keine Blutung.
    static func blutung(von fluss: HKCategoryValueMenstrualFlow) -> ZyklusBlutung? {
        switch fluss {
        case .light: .leicht
        case .medium: .mittel
        case .heavy: .stark
        case .unspecified: .mittel
        default: nil
        }
    }

    static func blutung(vonRohwert wert: Int) -> ZyklusBlutung? {
        HKCategoryValueMenstrualFlow(rawValue: wert).flatMap(blutung(von:))
    }

    // MARK: Zusammenführen (ohne Health-Zugriff)

    /// Was Health für einen Tag weiß.
    struct Gelesen: Equatable, Sendable {
        var blutung: ZyklusBlutung?
        var temperatur: Double?
        var gewicht: Double?
    }

    typealias Probe = (zeit: Date, wert: Double)

    /// Fasst die Proben zu Tageswerten zusammen: Blutung = die stärkste des Tages, Temperatur = die letzte Messung des Tages, Gewicht = der Tageswert.
    /// Unmögliche Werte (Temperatur außerhalb 30 bis 43 Grad, Gewicht außerhalb 20 bis 300 kg) werden verworfen.
    static func tageswerte(fluss: [Probe], temperatur: [Probe], gewichte: [GewichtsMesswert] = []) -> [String: Gelesen] {
        var tage: [String: Gelesen] = [:]
        func rang(_ b: ZyklusBlutung?) -> Int { b.flatMap { ZyklusBlutung.allCases.firstIndex(of: $0) } ?? -1 }
        for p in fluss {
            guard let b = blutung(vonRohwert: Int(p.wert)) else { continue }
            let tag = Datum.text(p.zeit)
            if rang(b) > rang(tage[tag]?.blutung) { tage[tag, default: Gelesen()].blutung = b }
        }
        for p in temperatur.sorted(by: { $0.zeit < $1.zeit }) where (30...43).contains(p.wert) {
            tage[Datum.text(p.zeit), default: Gelesen()].temperatur = (p.wert * 10).rounded() / 10
        }
        for g in gewichte where (20...300).contains(g.kg) {
            tage[g.tag, default: Gelesen()].gewicht = (g.kg * 10).rounded() / 10
        }
        return tage
    }

    /// Die Tage, die sich ändern, wenn man `gelesen` in `bestehend` einträgt: nur leere Felder werden gefüllt. Tage ohne Änderung fehlen.
    static func zusammenfuehren(bestehend: [String: ZyklusTag], gelesen: [String: Gelesen]) -> [ZyklusTag] {
        gelesen.keys.sorted().compactMap { tag -> ZyklusTag? in
            guard let g = gelesen[tag] else { return nil }
            var t = bestehend[tag] ?? ZyklusTag(id: tag)
            var geaendert = false
            if t.blutung == nil, let b = g.blutung { t.blutung = b; geaendert = true }
            if t.temperatur == nil, let w = g.temperatur { t.temperatur = w; geaendert = true }
            if t.gewicht == nil, let w = g.gewicht { t.gewicht = w; geaendert = true }
            return geaendert ? t : nil
        }
    }

    /// Ab wann gelesen wird: ein Tag vor dem letzten Import, höchstens `rueckblickTage` zurück. Ohne früheren Import: der ganze Rückblick.
    /// Das eine Tag Spielraum verhindert, dass ein Tag, den die Person geleert hat, bei jedem Öffnen wiederkommt.
    static func startpunkt(letzter: Date?, jetzt: Date) -> Date {
        let grenze = jetzt.addingTimeInterval(-Double(rueckblickTage) * 86_400)
        guard let letzter else { return grenze }
        return max(grenze, letzter.addingTimeInterval(-86_400))
    }

    // MARK: Rechte und Lesen

    /// Fragt die Leserechte. iOS meldet nie, ob Lesen erlaubt wurde: kommen keine Einträge, steht der Hinweis in den Einstellungen.
    @MainActor
    @discardableResult
    static func anfragen(zyklus: ZyklusStore, store: HKHealthStore = HKHealthStore()) async throws -> Bool {
        guard zyklus.werte.healthLesen, HKHealthStore.isHealthDataAvailable() else { return false }
        try await store.requestAuthorization(toShare: [], read: leseTypen)
        return true
    }

    /// Liest Health und trägt neue Werte über `zyklus.setze` ein (derselbe Weg wie eine Eingabe von Hand, also auch als `zyklus.*`-Op).
    /// Läuft nur mit Schalter. Gibt die Zahl der geänderten Tage zurück.
    @MainActor
    @discardableResult
    static func importieren(zyklus: ZyklusStore, leser: any HealthLeser, jetzt: Date = Date(), store: HKHealthStore = HKHealthStore()) async -> Int {
        guard zyklus.werte.healthLesen, HKHealthStore.isHealthDataAvailable() else { return 0 }
        let start = startpunkt(letzter: zyklus.werte.healthStand, jetzt: jetzt)
        let fluss = await proben(.fluss, seit: start, store: store)
        let temperatur = await proben(.temperatur, seit: start, store: store)
        let gewichte = await leser.gewichte(von: Datum.text(start), bis: Datum.text(jetzt))
        let neu = zusammenfuehren(bestehend: zyklus.tage, gelesen: tageswerte(fluss: fluss, temperatur: temperatur, gewichte: gewichte))
        for tag in neu { zyklus.setze(tag) }
        zyklus.aendere { $0.healthStand = jetzt }
        return neu.count
    }

    private enum Art: Sendable { case fluss, temperatur }

    @MainActor
    private static func proben(_ art: Art, seit start: Date, store: HKHealthStore) async -> [Probe] {
        let typ: HKSampleType
        switch art {
        case .fluss: typ = HKCategoryType(.menstrualFlow)
        case .temperatur: typ = HKQuantityType(.basalBodyTemperature)
        }
        let praedikat = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKSampleQuery(sampleType: typ, predicate: praedikat, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, ergebnis, _ in
                // Die Einheit entsteht erst hier im Handler (HKUnit wandert nicht über die Warteschlange).
                let liste: [Probe]
                switch art {
                case .fluss:
                    liste = ((ergebnis as? [HKCategorySample]) ?? []).map { (zeit: $0.startDate, wert: Double($0.value)) }
                case .temperatur:
                    let grad = HKUnit.degreeCelsius()
                    liste = ((ergebnis as? [HKQuantitySample]) ?? []).map { (zeit: $0.startDate, wert: $0.quantity.doubleValue(for: grad)) }
                }
                fortsetzung.resume(returning: liste)
            }
            store.execute(abfrage)
        }
    }
}
