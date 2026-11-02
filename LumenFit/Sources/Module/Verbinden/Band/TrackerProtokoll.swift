// Quelle: Lovea Health/Tracker/TrackerProtokoll.swift
import Foundation

/// Paketformat des iSo-Tech-Trackers H59MAX (Colmi-artiges 16-Byte-Protokoll). Reine Rechnung ohne
/// CoreBluetooth, damit sie ohne Gerät testbar ist.
///
/// Am 08.10.2026 gegen das echte Gerät belegt (Firmware 1.00.13): Akku (0x03) und die Lesebefehle
/// 0x16, 0x2C, 0x36, 0x38. Schritte (0x43): Aufbau der Pakete passt zu echten Antworten (Datum als BCD,
/// Zeitindex, kcal, Schritte, Meter); Nutzer hat am 10.10.2026 bestätigt, dass die Schrittzahl stimmt
/// (Tracker 15.000, iPhone 10.000, der Tracker hat recht).
/// Nicht belegt: Schlaf, kcal. Der Pulsverlauf (0x15) wird nur gelesen, Layout aus colmi_r02_client, am Gerät ungeprüft.
/// Ebenfalls nur gelesen und am Gerät ungeprüft (Gadgetbridge, `YawellRingDeviceSupport` und `YawellRingPacketHandler`, Grad B): der Verlauf
/// von Stress (0x37) und HRV (0x39). Dazu `pulsMessenAnfrage` (0x69): eine einzelne Pulsmessung, wie Gadgetbridge sie startet.
/// Geschrieben wird nur über `Aenderung` (Puls- und SpO2/Stress/HRV-Dauermessung, Layout aus der
/// Referenz-Implementierung colmi_r02_client und zwei weiteren, am Gerät noch nicht belegt),
/// `findenAnfrage` und die Uhr (`zeitSetzenAnfrage`, einmal je Verbindung); Lumen Fit liest danach jede Einstellung zurück. Kein freies Senden: Reset (0xFF) und
/// Ausschalten (0x08) gehören zur selben Familie und gibt es hier nicht.
enum TrackerProtokoll {
    static let dienst = "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E"
    static let schreiben = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    static let antwort = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    static let namenspraefix = "H59"

    enum Befehl: UInt8, CaseIterable {
        case zeitSetzen = 0x01
        case akku = 0x03
        case pulsVerlauf = 0x15
        case pulsEinstellung = 0x16
        case spo2Einstellung = 0x2C
        case stressEinstellung = 0x36
        case stressVerlauf = 0x37
        case hrvEinstellung = 0x38
        case hrvVerlauf = 0x39
        case schritte = 0x43
        case finden = 0x50
        case pulsMessen = 0x69
    }

    /// Dauermessung außer Puls: eine Einstellung je Messart, gleiches Layout (Byte 1 = 1 lesen / 2 schreiben,
    /// Byte 2 = 1 an, 0 aus; die Antwort auf "lesen" ist am Gerät belegt).
    enum Dauermessung: CaseIterable, Sendable {
        case spo2, stress, hrv

        var befehl: Befehl {
            switch self {
            case .spo2: .spo2Einstellung
            case .stress: .stressEinstellung
            case .hrv: .hrvEinstellung
            }
        }

        var name: String {
            switch self {
            case .spo2: "Blutsauerstoff"
            case .stress: "Stress"
            case .hrv: "HRV"
            }
        }
    }

    /// Eine Einstellung, die Lumen Fit am Tracker ändert. `schreiben` setzt sie, `lesen` holt danach, was der
    /// Tracker wirklich hat.
    enum Aenderung: Equatable {
        case puls(an: Bool, minuten: Int)
        case messung(Dauermessung, an: Bool)

        var schreiben: Data {
            switch self {
            case .puls(let an, let minuten):
                // Puls: 1 = an, 2 = aus (anders als bei den anderen Messarten), dann der Abstand in Minuten.
                return TrackerProtokoll.paket(.pulsEinstellung, [2, an ? 1 : 2, UInt8(clamping: minuten)])
            case .messung(let art, let an):
                return TrackerProtokoll.paket(art.befehl, [2, an ? 1 : 0])
            }
        }

        var lesen: Data {
            switch self {
            case .puls: TrackerProtokoll.pulsEinstellungAnfrage
            case .messung(let art, _): TrackerProtokoll.einstellungAnfrage(art)
            }
        }
    }

    /// 16 Byte: Byte 0 Befehl, dann Nutzdaten, Byte 15 Summe der ersten 15 Byte modulo 256.
    static func paket(_ befehl: Befehl, _ daten: [UInt8] = []) -> Data {
        var b = [UInt8](repeating: 0, count: 16)
        b[0] = befehl.rawValue
        for (i, wert) in daten.prefix(14).enumerated() { b[1 + i] = wert }
        b[15] = pruefsumme(Array(b[0..<15]))
        return Data(b)
    }

    static func pruefsumme(_ bytes: [UInt8]) -> UInt8 {
        UInt8(truncatingIfNeeded: bytes.reduce(0) { $0 &+ Int($1) })
    }

    static func istGueltig(_ daten: Data) -> Bool {
        let b = [UInt8](daten)
        return b.count == 16 && pruefsumme(Array(b[0..<15])) == b[15]
    }

    static let akkuAnfrage = paket(.akku)

    /// Stellt die Uhr des Bands (Befehl 0x01, Byte 1 bis 6 = Jahr ab 2000, Monat, Tag, Stunde, Minute, Sekunde als BCD, Byte 7 bis 14 leer).
    /// Gadgetbridge (`YawellRingDeviceSupport.setDateTime`, Grad B, dieselbe Familie) schickt genau das bei jeder Verbindung, in Ortszeit,
    /// ohne Sprach-Byte; die Antwort ist laut colmi_r02_client ein Merkmalspaket (Grad B), kein Löschen oder Zurücksetzen. Das Band kennt keine
    /// Sommerzeit und lief nach dem 25.10.2026 60 Minuten vor: Schlaf, Puls und Schritte hängen an dieser Uhr. Berliner Zeit, wie
    /// `TrackerSchlaf` die Bandminuten liest. Am Gerät ungeprüft: ob das H59MAX den Befehl annimmt (siehe Log-Art "zeit").
    static func zeitSetzenAnfrage(_ jetzt: Date, kalender: Calendar = Datum.kalender) -> Data {
        let t = kalender.dateComponents([.year, .month, .day, .hour, .minute, .second], from: jetzt)
        func ziffern(_ wert: Int?) -> UInt8 {
            let z = min(max(wert ?? 0, 0), 99)
            return UInt8(((z / 10) << 4) | (z % 10)) // Klammern nötig: in Swift bindet << stärker als /
        }
        return paket(.zeitSetzen, [ziffern((t.year ?? 2000) - 2000), ziffern(t.month), ziffern(t.day), ziffern(t.hour), ziffern(t.minute), ziffern(t.second)])
    }
    /// 0x16 mit Byte 1 = 1 liest die Einstellung (am Gerät belegt: Antwort "an, 10 Minuten").
    static let pulsEinstellungAnfrage = paket(.pulsEinstellung, [1])
    static func einstellungAnfrage(_ art: Dauermessung) -> Data { paket(art.befehl, [1]) }
    /// Lässt den Tracker vibrieren (Byte 1 und 2 = 0x55, 0xAA laut Referenz); ohne Antwort.
    /// Das ist der einzige Vibrationsbefehl, den die Quellen für diese Familie kennen (Gadgetbridge `YawellRingDeviceSupport.onFindDevice`, Grad B;
    /// am Band von Nutzer ausgelöst, Grad A). Es gibt kein Stärke-Byte, keine Dauer und kein Stopp-Paket (`onFindDevice(false)` tut dort nichts):
    /// Stärke und Länge legt die Firmware fest, laut Nutzer (15.10.) je Befehl ein kräftiger Puls von etwa 5 bis 10 Sekunden. Übrig bleiben
    /// Anzahl, Abstand und Wiederholung (`BandNachrichtRegel.zeiten`).
    /// Nicht benutzt, weil es keine Vibration belegt: 0x73 geht vom Band zum Handy (Meldung, kein Nachricht-Push nach Typ); 0x10 "blink twice" der Colmi R02 (LED-Ring, Grad C).
    static let findenAnfrage = paket(.finden, [0x55, 0xAA])
    /// Annahme: so lange vibriert das Band nach einem Finden-Befehl (Nutzer 15.10.: "5 bis 10 s", nicht am Band gemessen). Pulse, die getrennt zu
    /// spüren sein sollen, brauchen einen größeren Abstand.
    static let findenPulsDauerAnnahme: TimeInterval = 8
    /// Die Pulslänge, mit der Lumen Fit rechnet: die im Band-Labor gemessene, wenn Nutzer sie dort übernommen und eingeschaltet hat
    /// (`BandLaborSpeicher.pulsDauer`), sonst die Annahme.
    static var findenPulsDauer: TimeInterval { BandLaborSpeicher.pulsDauer() ?? findenPulsDauerAnnahme }
    /// Stress-Verlauf von heute: nur der Befehl (Gadgetbridge `fetchHistoryStress`). Antwort: Kopf (Byte 1 = 0), vier Pakete mit Werten, 0xFF = keine Daten.
    static let stressVerlaufAnfrage = paket(.stressVerlauf)
    /// HRV-Verlauf eines Tages: Byte 1 bis 4 = Tage zurück als Zahl, little endian (Gadgetbridge `fetchHistoryHRV`).
    static func hrvVerlaufAnfrage(tageZurueck: Int) -> Data {
        paket(.hrvVerlauf, (0..<4).map { UInt8(truncatingIfNeeded: UInt32(clamping: tageZurueck) >> (8 * UInt32($0))) })
    }
    /// Startet eine Pulsmessung (Byte 1 = 1 für Puls; Gadgetbridge `onHeartRateTest`). Das Band meldet Fehlercode und Wert, bis es fertig ist.
    static let pulsMessenAnfrage = paket(.pulsMessen, [1])
    /// Schritte eines Tages: Byte 1 = Tage zurück (0 = heute), dann Zeitindex 0 bis 0x5F (96 Viertelstunden).
    static func schritteAnfrage(tagVersatz: Int) -> Data {
        paket(.schritte, [UInt8(clamping: tagVersatz), 0x0F, 0, 0x5F, 1])
    }
    static let schritteHeuteAnfrage = schritteAnfrage(tagVersatz: 0)
    /// Pulsverlauf eines Tages: Byte 1 bis 4 = Mitternacht (`tagSekunden`) als Zahl, little endian.
    static func pulsVerlaufAnfrage(tag: UInt32) -> Data {
        paket(.pulsVerlauf, (0..<4).map { UInt8(truncatingIfNeeded: tag >> (8 * UInt32($0))) })
    }

    /// Mitternacht des Kalendertags von `datum`, gelesen als UTC. Der Tracker führt die Ortszeit, die Referenz
    /// nennt die Uhrzeit UTC: Tag und Uhrzeit bleiben so gleich, egal in welcher Zeitzone das iPhone steht.
    static func tagSekunden(_ datum: Date, kalender: Calendar = .current) -> UInt32 {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let tag = utc.date(from: kalender.dateComponents([.year, .month, .day], from: datum)) ?? datum
        return UInt32(clamping: Int(tag.timeIntervalSince1970))
    }

    struct Akku: Equatable {
        var prozent: Int
        var laedt: Bool
    }

    struct PulsEinstellung: Equatable {
        var an: Bool
        var intervallMinuten: Int
    }

    /// Eine Antwortzeile: Datum (BCD in Byte 1 bis 3), Zeitindex in Viertelstunden (0x44 = 17:00), Zeile
    /// `index` von `anzahl` (Byte 5 und 6), dann kcal, Schritte, Meter (Byte 7 bis 12, little endian).
    struct SchrittSlot: Equatable {
        var tag: String
        var slot: Int
        var index: Int
        var anzahl: Int
        var kcal: Int
        var schritte: Int
        var meter: Int

        /// Die letzte Zeile der Antwort: danach kann die nächste Frage gehen.
        var letzte: Bool { index + 1 >= anzahl }
    }

    /// Ein Paket der Antwort auf den Stress- oder HRV-Verlauf. Die Werte stehen im Halbstundentakt ab 00:00: Paket 1 trägt zwölf (Byte 3 bis 14,
    /// Byte 2 ist etwas anderes), jedes weitere dreizehn (Byte 2 bis 14).
    enum VerlaufPaket: Equatable {
        case kopf(pakete: Int)
        case werte(nr: Int, werte: [UInt8])
        case ende
    }

    enum Antwort: Equatable {
        case akku(Akku)
        case pulsEinstellung(PulsEinstellung)
        case dauermessung(Dauermessung, an: Bool)
        /// Antwort auf eine geschriebene Einstellung (Byte 1 = 2): Ob sie gilt, zeigt erst das Zurücklesen.
        case quittung(UInt8)
        /// Antwort auf `zeitSetzenAnfrage` (Byte 0 = 0x01); der Inhalt (Merkmale des Bands) wird nicht gelesen, nur roh ins Log gestellt.
        case zeitQuittung
        /// Kopfpaket einer Schritt-Antwort (Byte 1 = 0xF0): Zeilen folgen.
        case schritteKopf
        case schritte(SchrittSlot)
        /// Byte 1 = 0xFF: nichts (mehr) für diese Frage.
        case schritteEnde
        /// Pulsverlauf: Kopf (Pakete, Abstand in Minuten), Start (Tag, neun Werte), weitere Werte (je 13), 0xFF = keine Daten.
        case pulsKopf(pakete: Int, abstand: Int)
        case pulsStart(zeit: UInt32, werte: [UInt8])
        case pulsWerte(nr: Int, werte: [UInt8])
        case pulsEnde
        /// Verlauf von Stress oder HRV (`Dauermessung.stress` oder `.hrv`).
        case verlauf(Dauermessung, VerlaufPaket)
        /// Antwort auf `pulsMessenAnfrage`: Fehlercode (0 = gut, 1 = sitzt falsch am Arm, 2 = vorübergehend ohne Wert) und Puls.
        case pulsMessung(fehler: Int, wert: Int)
        case unbekannt(UInt8)
    }

    /// `nil` bei falscher Länge oder Prüfsumme.
    static func lesen(_ daten: Data) -> Antwort? {
        guard istGueltig(daten) else { return nil }
        let b = [UInt8](daten)
        switch b[0] {
        case Befehl.zeitSetzen.rawValue:
            return .zeitQuittung
        case Befehl.akku.rawValue:
            return .akku(Akku(prozent: Int(b[1]), laedt: b[2] != 0))
        case Befehl.pulsVerlauf.rawValue:
            switch b[1] {
            case 0: return .pulsKopf(pakete: Int(b[2]), abstand: Int(b[3]))
            case 1:
                let low = UInt32(b[2]) | UInt32(b[3]) << 8
                let high = UInt32(b[4]) << 16 | UInt32(b[5]) << 24
                return .pulsStart(zeit: low | high, werte: Array(b[6..<15]))
            case 0xFF: return .pulsEnde
            default: return .pulsWerte(nr: Int(b[1]), werte: Array(b[2..<15]))
            }
        case Befehl.stressVerlauf.rawValue, Befehl.hrvVerlauf.rawValue:
            let art: Dauermessung = b[0] == Befehl.stressVerlauf.rawValue ? .stress : .hrv
            switch b[1] {
            case 0xFF: return .verlauf(art, .ende)
            case 0: return .verlauf(art, .kopf(pakete: Int(b[2])))
            case 1: return .verlauf(art, .werte(nr: 1, werte: Array(b[3..<15])))
            default: return .verlauf(art, .werte(nr: Int(b[1]), werte: Array(b[2..<15])))
            }
        case Befehl.pulsMessen.rawValue:
            guard b[1] == 1 else { return .unbekannt(b[0]) } // nur die Messart Puls
            return .pulsMessung(fehler: Int(b[2]), wert: Int(b[3]))
        case Befehl.pulsEinstellung.rawValue:
            guard b[1] == 1 else { return .quittung(b[0]) }
            return .pulsEinstellung(PulsEinstellung(an: b[2] == 1, intervallMinuten: Int(b[3])))
        case Befehl.spo2Einstellung.rawValue, Befehl.stressEinstellung.rawValue, Befehl.hrvEinstellung.rawValue:
            guard let art = Dauermessung.allCases.first(where: { $0.befehl.rawValue == b[0] }) else { return .unbekannt(b[0]) }
            return b[1] == 1 ? .dauermessung(art, an: b[2] == 1) : .quittung(b[0])
        case Befehl.schritte.rawValue:
            if b[1] == 0xF0 { return .schritteKopf }
            if b[1] == 0xFF { return .schritteEnde }
            guard let tag = datumText(b[1], b[2], b[3]), b[4] < 96 else { return .unbekannt(b[0]) }
            return .schritte(SchrittSlot(tag: tag, slot: Int(b[4]), index: Int(b[5]), anzahl: Int(b[6]),
                                         kcal: Int(b[7]) | Int(b[8]) << 8,
                                         schritte: Int(b[9]) | Int(b[10]) << 8,
                                         meter: Int(b[11]) | Int(b[12]) << 8))
        default:
            return .unbekannt(b[0])
        }
    }

    /// Zwei BCD-Ziffern (0x26 = 26); `nil` bei einer Nicht-Ziffer.
    private static func bcd(_ byte: UInt8) -> Int? {
        let zehner = Int(byte >> 4), einer = Int(byte & 0x0F)
        return zehner < 10 && einer < 10 ? zehner * 10 + einer : nil
    }

    /// `yyyy-MM-dd` aus Jahr (ab 2000), Monat und Tag als BCD.
    private static func datumText(_ jahr: UInt8, _ monat: UInt8, _ tag: UInt8) -> String? {
        guard let j = bcd(jahr), let m = bcd(monat), let t = bcd(tag), (1...12).contains(m), (1...31).contains(t) else { return nil }
        return String(format: "%04d-%02d-%02d", 2000 + j, m, t)
    }
}
