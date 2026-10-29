#if DEBUG
import Foundation

extension AppUmgebung {
    /// Start-Argument `-lumenFitDemo YES`: ein erfundenes Profil "Beispiel" mit Demo-Daten, ohne Onboarding. Nur Debug.
    /// Tab, Theme und Link aus den Start-Argumenten gelten gleich beim Start.
    static func demo(fixtures: URL?) -> AppUmgebung {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("lumenfit-demo-\(UUID().uuidString)", isDirectory: true)
        let umgebung = AppUmgebung(ordner: temp, schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: fixtures),
                                   mitteiler: StilleMitteilung(), leser: DemoHealthLeser(), healthSchreiber: KeinHealthSchreiber(),
                                   bruecke: KeinePartnerBruecke(), uhr: { Date() }, passwortRunden: 1_000)
        _ = try? umgebung.profil.anlegen(name: "Beispiel", passwort: "demo")
        umgebung.sperreWeitereProfile()
        let argumente = StartArgumente.lies()
        if let daten = umgebung.daten {
            if let thema = argumente.thema { daten.einstellungen.aendere { $0.thema = thema } }
            for id in ["erster-satz", "erste-woche", "fruehstueck"] { daten.meilensteine.markiere(id) }
        }
        ModulStart.saeDemo(umgebung)
        if let tab = argumente.tab { umgebung.router.tab = tab }
        if let link = argumente.route, let url = URL(string: link) { umgebung.router.oeffne(url: url, vertraut: true) }
        return umgebung
    }
}

/// Erfundene, aber glaubwürdige Health-Werte für die Demo (stabil je Tag, keine echten Daten, keine Rechte-Abfrage).
struct DemoHealthLeser: HealthLeser {
    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff { .angefragt }

    private func tage(_ von: String, _ bis: String) -> [String] {
        guard SchlafNachtLogik.gueltigerTag(von), SchlafNachtLogik.gueltigerTag(bis), von <= bis else { return [] }
        var liste: [String] = []
        var tag = von
        while tag <= bis { liste.append(tag); tag = Datum.addTage(tag, 1) }
        return liste
    }

    /// 0 bis 1, stabil je Tag und Salz.
    private func zufall(_ tag: String, _ salz: Int) -> Double {
        let wert = tag.utf8.reduce(salz &* 31) { ($0 &* 131 &+ Int($1)) & 0xFFFF }
        return Double(wert % 1000) / 1000
    }

    func tagesWerte(von: String, bis: String) async -> [TagesWerte] {
        tage(von, bis).map { tag in
            let z = zufall(tag, 1)
            return TagesWerte(tag: tag, schritte: 5_500 + Int(z * 7_000), distanzMeter: 4_000 + z * 5_000, etagen: 3 + Int(z * 10),
                              aktiveKcal: 320 + z * 420, trainingMinuten: Int(z * 60), stehStunden: 8 + Int(z * 5))
        }
    }

    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] {
        tage(von, bis).compactMap { tag in
            let minuten = 380 + Int(zufall(tag, 2) * 120)
            let ende = Datum.datum(tag).addingTimeInterval(7 * 3600)
            let start = ende.addingTimeInterval(-Double(minuten) * 60)
            let kern = Double(minuten) * 60 * 0.5, tief = Double(minuten) * 60 * 0.2
            let a = start, b = a.addingTimeInterval(kern * 0.5), c = b.addingTimeInterval(tief), d = c.addingTimeInterval(kern * 0.5)
            let e = d.addingTimeInterval(Double(minuten) * 60 * 0.15)
            let abschnitte = [SchlafAbschnitt(phase: .kern, von: a, bis: b), SchlafAbschnitt(phase: .tief, von: b, bis: c),
                              SchlafAbschnitt(phase: .kern, von: c, bis: d), SchlafAbschnitt(phase: .rem, von: d, bis: e),
                              SchlafAbschnitt(phase: .kern, von: e, bis: ende)]
            return SchlafNacht(tag: tag, von: start, bis: ende, abschnitte: abschnitte, schlafMinuten: minuten)
        }
    }

    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] {
        tage(von, bis).map { tag in
            let z = zufall(tag, 3 + (VitalArt.allCases.firstIndex(of: art) ?? 0))
            let wert: Double = switch art {
            case .ruhepuls: 54 + z * 8
            case .hrv: 42 + z * 30
            case .sauerstoff: 96 + z * 3
            case .atemfrequenz: 14 + z * 3
            case .temperatur: 35.8 + z * 0.8
            case .vo2max: 44 + z * 3
            }
            return VitalMesswert(art: art, tag: tag, wert: wert)
        }
    }

    func gewichte(von: String, bis: String) async -> [GewichtsMesswert] {
        tage(von, bis).enumerated().filter { $0.offset % 3 == 0 }.map { GewichtsMesswert(tag: $0.element, kg: 78 + zufall($0.element, 4) * 1.5) }
    }

    func workouts(von: String, bis: String) async -> [HealthWorkout] { [] }
    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) {}
}
#endif
