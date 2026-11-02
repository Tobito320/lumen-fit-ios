// Quelle: Lovea Health/Tracker/TrackerSchlaf.swift
import Foundation

/// Schlaf vom Armband (W-033, Phase 1): Rahmen, Zusammensetzen der Antwort und Auswertung der Nacht. Reine Rechnung ohne
/// CoreBluetooth, damit sie ohne Gerät testbar ist. Das Band wird nur gelesen: Lumen Fit sendet genau eine feste Anfrage
/// (`anfrage`), sonst nichts an Dienst 2.
///
/// Alles hier folgt der Gadgetbridge-Beschreibung des Colmi/Yawell-Rings (Beleggrad B, siehe Vault-Notiz "Lumen Fit – Armband
/// Protokoll (H59MAX)"): am Band des H59MAX noch nicht geprüft. Darum geht die Rohantwort immer erst ins versteckte
/// Tracker-Log (`TrackerMeldung`), bevor sie ausgewertet wird, und jede Nacht, die nicht stimmig aussieht, wird verworfen.
enum TrackerSchlaf {
    /// Dienst 2 ("Big Data"): Schreiben auf `schreiben`, Antworten kommen als Benachrichtigung auf `antwort`.
    static let dienst = "DE5BF728-D711-4E47-AF26-65E3012A5DC7"
    static let schreiben = "DE5BF72A-D711-4E47-AF26-65E3012A5DC7"
    static let antwort = "DE5BF729-D711-4E47-AF26-65E3012A5DC7"
    static let kopf: UInt8 = 0xBC
    static let typ: UInt8 = 0x27

    /// Die eine Lese-Anfrage: `BC 27 01 00 FF 00 FF` (Typ 0x27, Länge 1, CRC 0x00FF, Nutzdaten 0xFF).
    static let anfrage: Data = rahmen(typ: typ, nutzdaten: [0xFF])

    /// Frühestens so viele Sekunden zwischen zwei Anfragen (Akku des Bands).
    static let abstand: TimeInterval = 30 * 60
    /// Weniger Schlafminuten als das ist keine Nacht (Mittagsschlaf, Sofa); wie die Mindestnacht der Schlaf-Rechnung.
    static let mindestNacht = 180
    /// So viele Minuten dürfen die Phasen von der Zeit zwischen Einschlafen und Aufwachen abweichen. Geraten, am Gerät ungeprüft:
    /// verwirft das Band-Format zu viele echte Nächte, zeigt das Log den Grund, dann hier anpassen.
    static let phasenToleranz = 15
    /// Zeit, die ein Aufwachen in der Zukunft liegen darf (Uhr des Bands geht anders als die des iPhones).
    static let zukunftToleranz: TimeInterval = 5 * 60

    enum Phase {
        static let leicht = 2, tief = 3, rem = 4, wach = 5
        /// Art 0 kommt am echten Band mitten in sonst stimmigen Nächten vor (Lovea-Log, Summe der Phasen gleich der Zeit): Annahme "keine Daten",
        /// zählt nicht als Schlaf und erscheint im Diagramm als Lücke (wach). Am Gerät ungeprüft; die Nacht wird deshalb nicht verworfen.
        static let keineDaten = 0
        static let alle: Set<Int> = [keineDaten, leicht, tief, rem, wach]
        static let zaehltNichtAlsSchlaf: Set<Int> = [keineDaten, wach]
    }

    // MARK: Rahmen

    /// CRC-16/MODBUS (Polynom 0xA001 gespiegelt, Start 0xFFFF, ohne Schluss-XOR).
    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1
            }
        }
        return crc
    }

    /// `BC`, Typ, Länge (u16, little endian), CRC der Nutzdaten (u16, little endian), Nutzdaten.
    static func rahmen(typ: UInt8, nutzdaten: [UInt8]) -> Data {
        let laenge = UInt16(clamping: nutzdaten.count)
        let crc = crc16(nutzdaten)
        let kopf: [UInt8] = [Self.kopf, typ, UInt8(laenge & 0xFF), UInt8(laenge >> 8), UInt8(crc & 0xFF), UInt8(crc >> 8)]
        return Data(kopf + nutzdaten)
    }

    /// Setzt die Antwort aus den Benachrichtigungen zusammen: ein Rahmen kann auf mehrere Pakete verteilt sein, fertig ist er bei
    /// Länge + 6 Byte. Zu viele Byte hinter dem Rahmen werden verworfen. Eine neue Anfrage braucht einen neuen Sammler.
    struct Sammler: Equatable, Sendable {
        /// Obergrenze für den Rahmen: eine Woche Schlaf sind wenige hundert Byte; was größer sein will, ist kaputt.
        static let hoechstBytes = 4096

        enum Stand: Equatable, Sendable {
            case wartet
            case fertig(nutzdaten: [UInt8])
            case ungueltig(String)
        }

        private(set) var bytes: [UInt8] = []

        /// Alles, was bisher ankam, als Hex (für das Log, auch bei Fehlern und halben Antworten).
        var hex: String { bytes.map { String(format: "%02x", $0) }.joined() }

        mutating func aufnehmen(_ stueck: Data) -> Stand {
            bytes.append(contentsOf: stueck)
            guard let erstes = bytes.first else { return .wartet }
            guard erstes == TrackerSchlaf.kopf else { return .ungueltig("Rahmen beginnt nicht mit BC") }
            if bytes.count >= 2, bytes[1] != TrackerSchlaf.typ {
                return .ungueltig(String(format: "Typ 0x%02X statt 0x%02X", bytes[1], TrackerSchlaf.typ))
            }
            guard bytes.count >= 4 else { return .wartet }
            let laenge: Int = Int(bytes[2]) | (Int(bytes[3]) << 8)
            guard laenge + 6 <= Self.hoechstBytes else { return .ungueltig("Länge \(laenge) unsinnig") }
            guard bytes.count >= laenge + 6 else { return .wartet }
            let nutzdaten = Array(bytes[6..<(6 + laenge)])
            let imRahmen: UInt16 = UInt16(bytes[4]) | (UInt16(bytes[5]) << 8)
            let berechnet = TrackerSchlaf.crc16(nutzdaten)
            guard imRahmen == berechnet else {
                return .ungueltig(String(format: "CRC im Rahmen 0x%04X, berechnet 0x%04X", imRahmen, berechnet))
            }
            return .fertig(nutzdaten: nutzdaten)
        }
    }

    // MARK: Nacht

    struct Phasenzeit: Codable, Equatable, Sendable {
        /// 2 leicht, 3 tief, 4 REM, 5 wach.
        var art: Int
        var minuten: Int
    }

    /// Eine Nacht, dem Tag des Aufwachens zugeordnet (wie `HealthModell.schlaf`). `minuten` zählt ohne die Wach-Phasen.
    struct Nacht: Codable, Equatable, Sendable {
        var tag: String
        var von: Date
        var bis: Date
        var minuten: Int
        var phasen: [Phasenzeit]
    }

    struct Auswertung: Equatable, Sendable {
        var naechte: [Nacht] = []
        /// Je verworfene Nacht ein Satz mit dem Grund, fürs Log.
        var verworfen: [String] = []
    }

    private struct Verwurf: Error { var grund: String }

    /// Nutzdaten der Antwort: Byte 0 = Anzahl Tage, je Tag `tageZurück`, `tagBytes`, Einschlafen und Aufwachen (je u16 little endian,
    /// Minuten ab Mitternacht), danach Paare aus Phase und Minuten. Nichts hier darf bei kaputten Daten abstürzen: jeder Zugriff ist geprüft,
    /// ein kaputter Tag beendet die Auswertung (danach ist die Lage der nächsten Tage unbekannt), die Tage davor bleiben.
    static func auswerten(nutzdaten: [UInt8], heute: String, jetzt: Date) -> Auswertung {
        var ergebnis = Auswertung()
        guard let erstes = nutzdaten.first, erstes > 0 else { return ergebnis }
        let anzahl = Int(erstes)
        var index = 1
        for nr in 1...anzahl {
            guard index + 2 <= nutzdaten.count else {
                ergebnis.verworfen.append("Tag \(nr) von \(anzahl): Antwort endet vor dem Tageskopf")
                break
            }
            let zurueck = Int(nutzdaten[index])
            let tagBytes = Int(nutzdaten[index + 1])
            index += 2
            guard tagBytes >= 4, tagBytes % 2 == 0, index + tagBytes <= nutzdaten.count else {
                ergebnis.verworfen.append("Tag \(nr) von \(anzahl) (vor \(zurueck) Tagen): Länge \(tagBytes) passt nicht zur Antwort (\(nutzdaten.count - index) Byte übrig)")
                break
            }
            let start: Int = Int(nutzdaten[index]) | (Int(nutzdaten[index + 1]) << 8)
            let ende: Int = Int(nutzdaten[index + 2]) | (Int(nutzdaten[index + 3]) << 8)
            var phasen: [Phasenzeit] = []
            var j = index + 4
            while j + 1 < index + tagBytes {
                let minuten = Int(nutzdaten[j + 1])
                if minuten > 0 { phasen.append(Phasenzeit(art: Int(nutzdaten[j]), minuten: minuten)) } // Minuten 0: Eintrag ignorieren
                j += 2
            }
            index += tagBytes
            switch pruefen(zurueck: zurueck, start: start, ende: ende, phasen: phasen, heute: heute, jetzt: jetzt) {
            case .success(let nacht):
                if let alt = ergebnis.naechte.firstIndex(where: { $0.tag == nacht.tag }) {
                    if nacht.minuten > ergebnis.naechte[alt].minuten { ergebnis.naechte[alt] = nacht }
                } else {
                    ergebnis.naechte.append(nacht)
                }
            case .failure(let verwurf):
                ergebnis.verworfen.append("Tag vor \(zurueck) Tagen: \(verwurf.grund)")
            }
        }
        return ergebnis
    }

    /// Plausibel ist eine Nacht, wenn sie mindestens `TrackerSchlaf.mindestNacht` Schlafminuten hat, nicht in der Zukunft endet und die
    /// Phasen lückenlos zur Zeit zwischen Einschlafen und Aufwachen passen (Summe aller Phasen, auch "wach").
    private static func pruefen(zurueck: Int, start: Int, ende: Int, phasen: [Phasenzeit], heute: String, jetzt: Date) -> Result<Nacht, Verwurf> {
        guard (0...30).contains(zurueck) else { return .failure(Verwurf(grund: "Tage zurück unsinnig")) }
        guard start < 1440, ende < 1440 else { return .failure(Verwurf(grund: "Einschlafen \(start) oder Aufwachen \(ende) nicht in 0 bis 1439")) }
        // Einschlafen größer als Aufwachen: der Schlaf begann am Vortag vor Mitternacht.
        let spanne = start > ende ? ende + 1440 - start : ende - start
        guard spanne > 0 else { return .failure(Verwurf(grund: "Einschlafen und Aufwachen gleich")) }
        guard !phasen.isEmpty else { return .failure(Verwurf(grund: "keine Phasen")) }
        if let fremd = phasen.first(where: { !Phase.alle.contains($0.art) }) {
            return .failure(Verwurf(grund: "unbekannte Phase \(fremd.art)"))
        }
        let summe = phasen.reduce(0) { $0 + $1.minuten }
        guard abs(summe - spanne) <= phasenToleranz else {
            return .failure(Verwurf(grund: "Phasen \(summe) min, Zeit zwischen Einschlafen und Aufwachen \(spanne) min"))
        }
        let schlaf = phasen.filter { !Phase.zaehltNichtAlsSchlaf.contains($0.art) }.reduce(0) { $0 + $1.minuten }
        guard schlaf >= TrackerSchlaf.mindestNacht else { return .failure(Verwurf(grund: "nur \(schlaf) min Schlaf, unter der Mindestnacht")) }
        let tag = Datum.addTage(heute, -zurueck)
        let bis = zeitpunkt(tag, minute: ende)
        let von = start > ende ? zeitpunkt(Datum.addTage(tag, -1), minute: start) : zeitpunkt(tag, minute: start)
        guard bis.timeIntervalSince(jetzt) <= zukunftToleranz else { return .failure(Verwurf(grund: "Aufwachen liegt in der Zukunft, Nacht noch nicht fertig")) }
        return .success(Nacht(tag: tag, von: von, bis: bis, minuten: schlaf, phasen: phasen))
    }

    /// Die Uhrzeit (Minuten ab Mitternacht) an einem Tag, in Berlin wie alle Tage der App.
    private static func zeitpunkt(_ tag: String, minute: Int) -> Date {
        let tagStart = Datum.datum(tag)
        return Datum.kalender.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: tagStart)
            ?? tagStart.addingTimeInterval(Double(minute) * 60)
    }

    // MARK: Diagramm

    /// Phase des Bands (2 leicht, 3 tief, 4 REM, 5 wach) als Phase des Nacht-Diagramms (`SchlafNachtDiagramm`); leicht heißt dort "Kern".
    private static func diagrammPhase(_ art: Int) -> SchlafPhase? {
        switch art {
        case Phase.leicht: .kern
        case Phase.tief: .tief
        case Phase.rem: .rem
        case Phase.wach, Phase.keineDaten: .wach
        default: nil
        }
    }

    /// Die Phasen der Nacht als Zeitleiste für das Nacht-Diagramm: lückenlos ab dem Einschlafen, gleiche Nachbarn zusammengelegt. Das Band
    /// nennt nur Dauern, keine Zeiten; die Leiste endet beim Aufwachen oder, wenn die Phasen kürzer sind, wo die letzte Phase endet. `nil`
    /// ohne eine bekannte Phase.
    static func diagramm(_ nacht: Nacht) -> SchlafNacht? {
        var abschnitte: [SchlafAbschnitt] = []
        var stand = nacht.von
        for phasenzeit in nacht.phasen {
            guard let phase = diagrammPhase(phasenzeit.art) else { continue }
            let ende = min(stand.addingTimeInterval(TimeInterval(phasenzeit.minuten * 60)), nacht.bis)
            guard ende > stand else { break }
            if let letzter = abschnitte.last, letzter.phase == phase {
                abschnitte[abschnitte.count - 1] = SchlafAbschnitt(phase: phase, von: letzter.von, bis: ende)
            } else {
                abschnitte.append(SchlafAbschnitt(phase: phase, von: stand, bis: ende))
            }
            stand = ende
        }
        guard !abschnitte.isEmpty else { return nil }
        return SchlafNacht(tag: nacht.tag, von: nacht.von, bis: stand, abschnitte: abschnitte, schlafMinuten: nacht.minuten)
    }

    // MARK: Wann fragen

    /// Ob jetzt gefragt wird: höchstens alle `abstand` Sekunden, und nicht mehr, wenn die Nacht von heute schon gelesen ist, nachdem
    /// sie zu Ende war. Springt die Uhr zurück (letzte Frage "in der Zukunft"), ist die Frage fällig.
    static func faellig(letzte: Date?, naechte: [String: Nacht], heute: String, jetzt: Date, abstand: TimeInterval = abstand) -> Bool {
        guard let letzte else { return true }
        let seitdem = jetzt.timeIntervalSince(letzte)
        guard seitdem >= 0 else { return true }
        if seitdem < abstand { return false }
        if let nacht = naechte[heute], letzte >= nacht.bis { return false }
        return true
    }
}

/// Die Nächte, die das Armband zuletzt geliefert hat und die plausibel waren (nur im Speicher). Dauerhaft ist die Op `fit.band.schlaf`
/// (`BandSchlafOp`, eine je Tag, die letzte gewinnt), die das Modul schlaf in seiner Quellenwahl liest. Je Tag zählt die neueste Auswertung.
struct BandSchlaf: Codable, Equatable, Sendable {
    static let behalten = 14

    var naechte: [String: TrackerSchlaf.Nacht] = [:]

    /// `true`, wenn sich etwas geändert hat.
    @discardableResult
    mutating func aufnehmen(_ neu: [TrackerSchlaf.Nacht]) -> Bool {
        var geaendert = false
        for nacht in neu where naechte[nacht.tag] != nacht {
            naechte[nacht.tag] = nacht
            geaendert = true
        }
        return geaendert
    }

    /// Wirft Tage vor dem Fenster weg. Tage sind `yyyy-MM-dd`, also stimmt der Textvergleich.
    mutating func kuerzen(heute: String) {
        let grenze = Datum.addTage(heute, -(Self.behalten - 1))
        naechte = naechte.filter { $0.key >= grenze }
    }
}

extension TrackerSchlaf {
    /// Die Op `fit.band.schlaf` zu einer Nacht: Zeitleiste lückenlos ab dem Einschlafen (`diagramm`). `nil` ohne bekannte Phase.
    static func op(_ nacht: Nacht) -> BandSchlafOp? {
        guard let leiste = diagramm(nacht) else { return nil }
        return BandSchlafOp(tag: nacht.tag, start: nacht.von, ende: nacht.bis, phasen: leiste.abschnitte)
    }
}
