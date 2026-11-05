import Foundation

/// `schlicht` steht vorn: Standard für neue Profile und einmal für alle, die noch Monochrom hatten (`Einstellungen.schlichtEinmal`).
enum ThemaID: String, Codable, CaseIterable, Sendable { case schlicht, monochrom, graphit, stahl, glut, wald, lovea }
enum Erscheinung: String, Codable, CaseIterable, Sendable { case system, hell, dunkel }
enum GewichtsEinheit: String, Codable, Sendable { case kg, lb }
/// Die wählbaren Bereiche. Heute bleibt immer.
enum AppBereich: String, Codable, CaseIterable, Sendable { case gym, essen, schlaf }

/// Die Antwort auf die Frage nach der Nutzungsmeldung. Nur `.ja` erlaubt das Senden; "noch nicht gefragt" und "nein" senden nichts.
enum NutzungAntwort: String, Codable, Sendable { case offen, ja, nein }

/// Alle Felder haben Standardwerte; `init(from:)` nutzt `decodeIfPresent`, damit neue Felder alte Dateien nie unlesbar machen.
/// Ein unbekannter oder falsch getippter Wert (zum Beispiel ein Theme, das es später nicht mehr gibt) ergibt den Standard statt einer unlesbaren Datei.
struct Einstellungen: Codable, Equatable, Sendable {
    var thema: ThemaID = .schlicht
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
    /// Die Nutzungsmeldung an den Server (Datenschutz, hängt am Konto, ist nicht anonym). Nur nach einem "Ja" geht etwas raus; ein altes `nutzungZaehlen: true`
    /// aus früheren Versionen zählt nicht als Einwilligung und wird beim Lesen ignoriert.
    var nutzungAntwort: NutzungAntwort = .offen
    /// Tag (yyyy-MM-dd) des "Ja": Diagnosen, die davor lagen, werden nicht übernommen.
    var nutzungJaSeit: String?
    /// Bereiche wählen: aus = Tab, Karten und Einträge verschwinden, die Daten bleiben. Bestandsprofile behalten alles (Standard an).
    var gymAn = true
    var essenAn = true
    var schlafAn = true
    /// Intervallfasten im Essen-Tab: aus, bis man es einschaltet (Bestand mit Fasten-Daten behält es, siehe `EssenTagebuchLogik.fastenSichtbar`).
    var fastenAn = false
    /// Der einmalige Wechsel auf Schlicht ist gelaufen (W-003). Neue Profile starten schon schlicht; alte Dateien ohne das Feld bekommen ihn einmal.
    var schlichtGesetzt = true

    init() {}

    /// Einmal für alte Profile: wer noch den alten Standard Monochrom hat, bekommt Schlicht. Ein anderes Theme war eine eigene Wahl und bleibt.
    static func schlichtEinmal(_ alt: Einstellungen) -> Einstellungen {
        guard !alt.schlichtGesetzt else { return alt }
        var neu = alt
        if neu.thema == .monochrom { neu.thema = .schlicht }
        neu.schlichtGesetzt = true
        return neu
    }

    var nutzungErlaubt: Bool { nutzungAntwort == .ja }

    /// Hält die Antwort fest; das "Ja" merkt sich den Tag, ein Wechsel auf "Nein" oder "offen" löscht ihn.
    mutating func antworteNutzung(_ antwort: NutzungAntwort, tag: String) {
        if antwort == .ja { if nutzungAntwort != .ja { nutzungJaSeit = tag } } else { nutzungJaSeit = nil }
        nutzungAntwort = antwort
    }

    /// Das Band ist eingerichtet, wenn es an ist oder je bewusst ausgeschaltet wurde; sonst steht unter Geräte nur "Band einrichten".
    var bandEingerichtet: Bool { bandAktiv || bandBewusstAus }

    /// Die eine Abfrage für alle Ansichten: soll dieser Bereich erscheinen?
    func zeigt(_ bereich: AppBereich) -> Bool {
        switch bereich {
        case .gym: gymAn
        case .essen: essenAn
        case .schlaf: schlafAn
        }
    }

    /// Was die App zeigt: Schlaf, Armband und AirPods nur, wenn der Server es dem Konto erlaubt (`ServerConfig.schlafSichtbar`). Die gespeicherte Wahl
    /// bleibt unverändert; ist sonst nichts an, zeigt die App Gym, damit nie ein Profil ohne sichtbaren Bereich entsteht.
    func wirksam(schlafSichtbar: Bool) -> Einstellungen {
        guard !schlafSichtbar, schlafAn else { return self }
        var e = self
        e.schlafAn = false
        if !(e.gymAn || e.essenAn) { e.gymAn = true }
        return e
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
        case thema, erscheinung, haptik, gewichtsEinheit, healthSchreiben, bandAktiv, bandBewusstAus, loveaVerbunden, alarmWeckt, mitteilungen, healthGefragt, nutzungAntwort, nutzungJaSeit, gymAn, essenAn, schlafAn, fastenAn, schlichtGesetzt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        thema = (try? c.decodeIfPresent(ThemaID.self, forKey: .thema)) ?? .schlicht
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
        nutzungAntwort = (try? c.decodeIfPresent(NutzungAntwort.self, forKey: .nutzungAntwort)) ?? .offen
        nutzungJaSeit = (try? c.decodeIfPresent(String.self, forKey: .nutzungJaSeit)) ?? nil
        gymAn = (try? c.decodeIfPresent(Bool.self, forKey: .gymAn)) ?? true
        essenAn = (try? c.decodeIfPresent(Bool.self, forKey: .essenAn)) ?? true
        schlafAn = (try? c.decodeIfPresent(Bool.self, forKey: .schlafAn)) ?? true
        fastenAn = (try? c.decodeIfPresent(Bool.self, forKey: .fastenAn)) ?? false
        schlichtGesetzt = (try? c.decodeIfPresent(Bool.self, forKey: .schlichtGesetzt)) ?? false
        // Mindestens ein Bereich bleibt an: eine Datei mit allem aus (von Hand oder aus einem Fehler) zeigt wieder alles.
        if !(gymAn || essenAn || schlafAn) { gymAn = true; essenAn = true; schlafAn = true }
    }
}
