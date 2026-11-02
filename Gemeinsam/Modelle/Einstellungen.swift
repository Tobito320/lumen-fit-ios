import Foundation

enum ThemaID: String, Codable, CaseIterable, Sendable { case monochrom, graphit, stahl, glut, wald, lovea }
enum Erscheinung: String, Codable, CaseIterable, Sendable { case system, hell, dunkel }
enum GewichtsEinheit: String, Codable, Sendable { case kg, lb }
/// Die wählbaren Bereiche. Heute (und der Coach, den der Server steuert) bleiben immer.
enum AppBereich: String, Codable, CaseIterable, Sendable { case gym, essen, schlaf }

/// Alle Felder haben Standardwerte; `init(from:)` nutzt `decodeIfPresent`, damit neue Felder alte Dateien nie unlesbar machen.
/// Ein unbekannter oder falsch getippter Wert (zum Beispiel ein Theme, das es später nicht mehr gibt) ergibt den Standard statt einer unlesbaren Datei.
struct Einstellungen: Codable, Equatable, Sendable {
    var thema: ThemaID = .monochrom
    var erscheinung: Erscheinung = .system
    var haptik = true
    var gewichtsEinheit: GewichtsEinheit = .kg
    var healthSchreiben = false          // Training und Gewicht nach Health (Idee 17, 30)
    var bandAktiv = false                // Idee 85, Annahme 9
    /// Der Schalter "Band in Lumen Fit nutzen" wurde bewusst ausgeschaltet: dann schaltet auch der Server-Standard (`bandStandard`) ihn nie wieder ein.
    var bandBewusstAus = false
    var loveaVerbunden = false           // Idee 81
    var alarmWeckt = true                // Lumen Alarm darf das Band wecken (Gerät, Standard an)
    var mitteilungen: [String: Bool] = [:]
    var healthGefragt = false
    /// Die anonyme Nutzungsmeldung an den Server (Datenschutz). Aus = es geht kein Zähler raus.
    var nutzungZaehlen = true
    /// Bereiche wählen: aus = Tab, Karten und Einträge verschwinden, die Daten bleiben. Bestandsprofile behalten alles (Standard an).
    var gymAn = true
    var essenAn = true
    var schlafAn = true
    /// Intervallfasten im Essen-Tab: aus, bis man es einschaltet (Bestand mit Fasten-Daten behält es, siehe `EssenTagebuchLogik.fastenSichtbar`).
    var fastenAn = false

    init() {}

    /// Die eine Abfrage für alle Ansichten: soll dieser Bereich erscheinen?
    func zeigt(_ bereich: AppBereich) -> Bool {
        switch bereich {
        case .gym: gymAn
        case .essen: essenAn
        case .schlaf: schlafAn
        }
    }

    /// Schaltet einen Bereich. Der letzte eingeschaltete bleibt an: dann passiert nichts und die Antwort ist false.
    @discardableResult
    mutating func setze(_ bereich: AppBereich, an: Bool) -> Bool {
        guard an || AppBereich.allCases.contains(where: { $0 != bereich && zeigt($0) }) else { return false }
        switch bereich {
        case .gym: gymAn = an
        case .essen: essenAn = an
        case .schlaf: schlafAn = an
        }
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case thema, erscheinung, haptik, gewichtsEinheit, healthSchreiben, bandAktiv, bandBewusstAus, loveaVerbunden, alarmWeckt, mitteilungen, healthGefragt, nutzungZaehlen, gymAn, essenAn, schlafAn, fastenAn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        thema = (try? c.decodeIfPresent(ThemaID.self, forKey: .thema)) ?? .monochrom
        erscheinung = (try? c.decodeIfPresent(Erscheinung.self, forKey: .erscheinung)) ?? .system
        haptik = (try? c.decodeIfPresent(Bool.self, forKey: .haptik)) ?? true
        gewichtsEinheit = (try? c.decodeIfPresent(GewichtsEinheit.self, forKey: .gewichtsEinheit)) ?? .kg
        healthSchreiben = (try? c.decodeIfPresent(Bool.self, forKey: .healthSchreiben)) ?? false
        bandAktiv = (try? c.decodeIfPresent(Bool.self, forKey: .bandAktiv)) ?? false
        bandBewusstAus = (try? c.decodeIfPresent(Bool.self, forKey: .bandBewusstAus)) ?? false
        loveaVerbunden = (try? c.decodeIfPresent(Bool.self, forKey: .loveaVerbunden)) ?? false
        alarmWeckt = (try? c.decodeIfPresent(Bool.self, forKey: .alarmWeckt)) ?? true
        mitteilungen = (try? c.decodeIfPresent([String: Bool].self, forKey: .mitteilungen)) ?? [:]
        healthGefragt = (try? c.decodeIfPresent(Bool.self, forKey: .healthGefragt)) ?? false
        nutzungZaehlen = (try? c.decodeIfPresent(Bool.self, forKey: .nutzungZaehlen)) ?? true
        gymAn = (try? c.decodeIfPresent(Bool.self, forKey: .gymAn)) ?? true
        essenAn = (try? c.decodeIfPresent(Bool.self, forKey: .essenAn)) ?? true
        schlafAn = (try? c.decodeIfPresent(Bool.self, forKey: .schlafAn)) ?? true
        fastenAn = (try? c.decodeIfPresent(Bool.self, forKey: .fastenAn)) ?? false
        // Mindestens ein Bereich bleibt an: eine Datei mit allem aus (von Hand oder aus einem Fehler) zeigt wieder alles.
        if !(gymAn || essenAn || schlafAn) { gymAn = true; essenAn = true; schlafAn = true }
    }
}
