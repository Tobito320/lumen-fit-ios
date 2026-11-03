import Foundation

/// Sammelt die Quellen für den Schlaf-Beleg und schickt ihn an den Server, wenn der Server ihn für das Konto freigibt (`KontoDienst.schlafBelegAn`).
/// Sonst passiert nichts: kein Lesen, kein Netz. Höchstens einmal je Stunde (`SchlafBelegLogik.faellig`), der Zeitpunkt liegt in `UserDefaults`.
@MainActor
enum SchlafBelegDienst {
    static let letzterSchluessel = "fit.schlafbeleg.letzter"
    private static var laeuft = false

    static func sendeFallsFaellig(_ umgebung: AppUmgebung, defaults: UserDefaults = .standard) async {
        guard !laeuft, umgebung.konto.schlafBelegAn, umgebung.profil.hatProfil else { return }
        let jetzt = umgebung.uhr()
        let letzter = (defaults.object(forKey: letzterSchluessel) as? Double).map(Date.init(timeIntervalSince1970:))
        guard SchlafBelegLogik.faellig(letzter: letzter, jetzt: jetzt) else { return }
        // Der Zeitpunkt gilt vor dem Senden: auch ein Fehlversuch wartet eine Stunde (keine Last beim Server, kein Dauerfeuer bei Funkloch).
        defaults.set(jetzt.timeIntervalSince1970, forKey: letzterSchluessel)
        laeuft = true
        defer { laeuft = false }
        let heute = Datum.text(jetzt)
        let proben = await umgebung.healthLeser.schlafProben(von: Datum.addTage(heute, -(SchlafBelegLogik.tage - 1)), bis: heute)
        let raum = umgebung.daten?.raum
        let eigene = SchlafEigeneQuellen.lesen(raum)
        let modell = (umgebung.band as? BandDienstImpl)?.modell
        var bandSchritte: [String: Int] = [:]
        if let raum {
            for op in raum.ops(arten: ["fit.band.tag"]) { if let t = op.daten(BandTagOp.self) { bandSchritte[t.tag] = t.schritte } }
        }
        for (tag, werte) in modell?.bandTage.tage ?? [:] { bandSchritte[tag] = max(bandSchritte[tag] ?? 0, werte.schritte) }
        let eingabe = SchlafBelegLogik.Eingabe(
            jetzt: jetzt, build: build, zone: .current, gewaehlt: umgebung.gesundheit.gewaehlteNaechte(eigene: eigene), bandOps: eigene.band,
            bandRoh: modell?.schlafNaechteRoh ?? [], healthNaechte: umgebung.gesundheit.naechteAusHealth, healthProben: proben, hand: eigene.hand,
            bandSchritte: bandSchritte, healthSchritte: umgebung.gesundheit.schritteAusHealth, letzterBandSync: modell?.bandTage.stand,
            bandLog: modell?.bandLog ?? [])
        guard let koerper = SchlafBelegLogik.kodieren(SchlafBelegLogik.bauen(eingabe)) else { return }
        _ = await umgebung.konto.schlafBelegSenden(koerper)
    }

    private static var build: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let nummer = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(nummer))"
    }
}
