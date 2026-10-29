// Quelle: Lovea Health/Tracker/TrackerFunk.swift
import CoreBluetooth
import Foundation

/// Was die Funkschicht dem Modell meldet. Nur Werte, die sich sicher über Threads schicken lassen.
enum TrackerEreignis: Sendable {
    enum BluetoothStatus: Sendable { case an, aus, nichtErlaubt, nichtVerfuegbar }
    case bluetooth(BluetoothStatus)
    case sucht
    case nichtGefunden
    case verbindet
    case verbunden(name: String?)
    case getrennt
    case daten(Data)
    case fehler(String)
    /// Zeile fürs versteckte Tracker-Log (`TrackerMeldung`): Dienste des Bands, Fehler bei Dienst 2. Nie ein Fehler der Verbindung.
    case bandLog(art: String, text: String)
    /// Dienst 2 ist da und meldet (W-033): die Schlaf-Anfrage kann gehen.
    case schlafBereit
    /// Ein Paket der Antwort auf Dienst 2.
    case schlafDaten(Data)
}

/// Was `TrackerModell` vom Funk braucht. `BandDienstImpl` gibt dem Modell eine Fabrik: ohne `bandAktiv` wird sie nie aufgerufen und es entsteht kein
/// `CBCentralManager` (keine Bluetooth-Frage). Tests geben eine Fabrik mit einem Fake.
protocol BandFunk: Sendable {
    func starten()
    func trennen(vergessen: Bool)
    func schlafAnfragen()
    func senden(_ daten: Data)
}

/// Ein Gerät, das die Zentrale kennt: nur Kennung und Name, damit die Suche ohne CoreBluetooth-Typen testbar ist.
struct BandGeraetInfo: Equatable, Sendable {
    var kennung: UUID
    var name: String?
}

/// Die zwei Abfragen der Zentrale, die der Verbindungsweg braucht (`retrieveConnectedPeripherals` und `retrievePeripherals`). `FakeZentrale` in den Tests
/// zeichnet die Aufrufe auf.
protocol BandSuche {
    func verbundene(dienst: String) -> [BandGeraetInfo]
    func bekannte(_ kennungen: [UUID]) -> [BandGeraetInfo]
}

/// Verbindungsweg im zweiten Prozess (SPEC 5.6): erst ein Band, das schon verbunden ist (Lovea hält womöglich die Verbindung; ob iOS und das Band
/// das erlauben, zeigt erst das Gerät), dann das gemerkte Band, zuletzt Scan. Die Peripherie-Kennung ist je App verschieden: Loveas Kennung
/// hilft hier nicht, die eigene steht nach der ersten Verbindung in `TrackerFunk.gemerkteKennung`.
enum BandVerbindungsweg: Equatable, Sendable {
    case schonVerbunden(UUID)
    case bekannt(UUID)
    case scan

    static func waehle(_ suche: some BandSuche, gemerkt: UUID?) -> BandVerbindungsweg {
        let verbundene = suche.verbundene(dienst: TrackerProtokoll.dienst)
        let passend = verbundene.first { $0.kennung == gemerkt } ?? verbundene.first { $0.name?.hasPrefix(TrackerProtokoll.namenspraefix) == true }
        if let passend { return .schonVerbunden(passend.kennung) }
        if let gemerkt, let bekannt = suche.bekannte([gemerkt]).first { return .bekannt(bekannt.kennung) }
        return .scan
    }
}

/// Dünner CoreBluetooth-Rahmen um den Tracker. Alles CoreBluetooth läuft auf einer eigenen seriellen
/// Warteschlange; nach außen gehen nur `TrackerEreignis`-Werte. Das Zentralobjekt wird erst bei
/// `starten()` angelegt, nie beim App-Start, weil schon das Anlegen die Bluetooth-Abfrage zeigt.
///
/// Der Tracker nimmt nur eine Verbindung und sendet nach dem Trennen nicht mehr, bis man ihn antippt.
/// Darum bleibt ein `connect` offen: iOS verbindet von selbst, sobald er wieder sendet. Mit dem
/// Hintergrundmodus `bluetooth-central` und der Wiederherstellungs-Kennung weckt iOS die App dafür
/// auch dann, wenn sie beendet wurde (`willRestoreState`).
///
/// W-033: Steht Dienst 1 (Verbindung gemeldet), sucht `weitereDiensteSuchen` einmal alle Dienste und Merkmale und meldet sie ins
/// Log. Gibt es Dienst 2 (`TrackerSchlaf`), hört `TrackerFunk` dort zu und schickt auf Anfrage die eine feste Schlaf-Leseanfrage.
/// Dienst 1 läuft davon unberührt; was bei Dienst 2 schiefgeht, geht nur ins Log.
final class TrackerFunk: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, BandFunk, @unchecked Sendable {
    // @unchecked Sendable: alle veränderlichen Felder werden nur auf `queue` angefasst, `melden` ist Sendable.
    static let kennungSchluessel = "fit.band.kennung"
    private static let wiederherstellung = "com.onlyus.lumen-fit.band.zentrale"

    private let queue = DispatchQueue(label: "com.onlyus.lumen-fit.band.ble")
    private let melden: @Sendable (TrackerEreignis) -> Void
    private let dienstUUID = CBUUID(string: TrackerProtokoll.dienst)
    private let schreibenUUID = CBUUID(string: TrackerProtokoll.schreiben)
    private let antwortUUID = CBUUID(string: TrackerProtokoll.antwort)

    // Nur auf `queue` anfassen.
    private var zentrale: CBCentralManager?
    private var geraet: CBPeripheral?
    private var schreiber: CBCharacteristic?
    private var benachrichtigt = false
    private var gewolltGetrennt = false
    private var suchStopp: DispatchWorkItem?

    // Dienst 2 und die Suche nach allen Diensten (W-033), nur auf `queue` anfassen.
    private let schlafDienstUUID = CBUUID(string: TrackerSchlaf.dienst)
    private let schlafSchreibenUUID = CBUUID(string: TrackerSchlaf.schreiben)
    private let schlafAntwortUUID = CBUUID(string: TrackerSchlaf.antwort)
    private var schlafSchreiber: CBCharacteristic?
    private var schlafBenachrichtigt = false
    private var dienstSuche = false
    private var offeneDienste = 0
    private var dienstZeilen: [String] = []
    private var dienstLogGesendet = false

    init(melden: @escaping @Sendable (TrackerEreignis) -> Void) {
        self.melden = melden
        super.init()
    }

    static func gemerkteKennung(_ defaults: UserDefaults = .standard) -> UUID? {
        defaults.string(forKey: kennungSchluessel).flatMap(UUID.init(uuidString:))
    }

    // MARK: Von außen

    func starten() {
        queue.async {
            self.gewolltGetrennt = false
            if let zentrale = self.zentrale {
                if zentrale.state == .poweredOn { self.verbindenOderSuchen(zentrale) }
            } else {
                self.zentrale = CBCentralManager(delegate: self, queue: self.queue,
                                                 options: [CBCentralManagerOptionRestoreIdentifierKey: Self.wiederherstellung])
            }
        }
    }

    func trennen(vergessen: Bool) {
        queue.async {
            self.gewolltGetrennt = true
            self.suchStopp?.cancel()
            self.zentrale?.stopScan()
            if let geraet = self.geraet { self.zentrale?.cancelPeripheralConnection(geraet) }
            if vergessen {
                UserDefaults.standard.removeObject(forKey: Self.kennungSchluessel)
                self.geraet = nil
            }
            self.schreiber = nil
            self.benachrichtigt = false
            self.schlafZuruecksetzen()
            self.melden(.getrennt)
        }
    }

    /// Die eine Lese-Anfrage für den Schlaf, `TrackerSchlaf.anfrage`. Bewusst kein freies `senden` für Dienst 2: das Band wird dort nie
    /// beschrieben (keine Einstellung, kein Ausschalten, kein Reset).
    func schlafAnfragen() {
        queue.async {
            guard let geraet = self.geraet, let schreiber = self.schlafSchreiber, self.schlafBenachrichtigt else { return }
            let art: CBCharacteristicWriteType = schreiber.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            geraet.writeValue(TrackerSchlaf.anfrage, for: schreiber, type: art)
        }
    }

    func senden(_ daten: Data) {
        queue.async {
            guard let geraet = self.geraet, let schreiber = self.schreiber, self.benachrichtigt else { return }
            let art: CBCharacteristicWriteType = schreiber.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            geraet.writeValue(daten, for: schreiber, type: art)
        }
    }

    // MARK: Zentrale

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            melden(.bluetooth(.an))
            if !gewolltGetrennt { verbindenOderSuchen(central) }
        case .poweredOff:
            melden(.bluetooth(.aus))
        case .unauthorized:
            melden(.bluetooth(.nichtErlaubt))
        case .unsupported:
            melden(.bluetooth(.nichtVerfuegbar))
        default:
            break // .unknown und .resetting sind kurz nach dem Anlegen normal
        }
    }

    /// iOS hat die App für den Tracker neu gestartet oder geweckt und gibt das Gerät zurück. Der Rest
    /// läuft wie beim normalen Start (`verbindenOderSuchen`, dann Dienste und Benachrichtigung).
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let wiederhergestellt = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first else { return }
        geraet = wiederhergestellt
        wiederhergestellt.delegate = self
        melden(.verbindet)
    }

    private func verbindenOderSuchen(_ zentrale: CBCentralManager) {
        let suche = ZentraleSuche(zentrale: zentrale, dienst: dienstUUID)
        switch BandVerbindungsweg.waehle(suche, gemerkt: Self.gemerkteKennung()) {
        case .schonVerbunden(let kennung):
            melden(.bandLog(art: "weg", text: "Band war schon verbunden (retrieveConnectedPeripherals)"))
            // Ein Band, das nur dem System verbunden ist, braucht für diese App trotzdem ein connect.
            if let geraet = suche.gefunden[kennung] { verbinden(geraet, ueber: zentrale, verbindenErzwingen: true); return }
        case .bekannt(let kennung):
            melden(.bandLog(art: "weg", text: "Band über die gemerkte Kennung (retrievePeripherals)"))
            if let geraet = suche.gefunden[kennung] { verbinden(geraet, ueber: zentrale); return }
        case .scan:
            melden(.bandLog(art: "weg", text: "Scan nach Bändern mit Namen H59"))
        }
        melden(.sucht)
        zentrale.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        let stopp = DispatchWorkItem { [weak self] in
            guard let self, self.geraet == nil else { return }
            self.zentrale?.stopScan()
            self.melden(.nichtGefunden)
        }
        suchStopp = stopp
        queue.asyncAfter(deadline: .now() + 30, execute: stopp)
    }

    private func verbinden(_ peripheral: CBPeripheral, ueber zentrale: CBCentralManager, verbindenErzwingen: Bool = false) {
        geraet = peripheral
        peripheral.delegate = self
        melden(.verbindet)
        if peripheral.state == .connected, !verbindenErzwingen {
            peripheral.discoverServices([dienstUUID]) // schon verbunden (wiederhergestellt): nicht noch einmal verbinden
        } else {
            zentrale.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        guard let name, name.hasPrefix(TrackerProtokoll.namenspraefix) else { return }
        suchStopp?.cancel()
        central.stopScan()
        verbinden(peripheral, ueber: central)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        schlafZuruecksetzen()
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.kennungSchluessel)
        peripheral.discoverServices([dienstUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard !gewolltGetrennt else { return }
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        schreiber = nil
        benachrichtigt = false
        schlafZuruecksetzen()
        guard !gewolltGetrennt else { return }
        melden(.getrennt)
        // Offenes connect: iOS verbindet, sobald der Tracker wieder sendet (Antippen, Bewegung).
        central.connect(peripheral)
    }

    // MARK: Gerät

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if dienstSuche {
            dienstePruefen(peripheral, error: error) // zweite Suche (W-033), nie ein Fehler der Verbindung
            return
        }
        guard let dienst = peripheral.services?.first(where: { $0.uuid == dienstUUID }) else {
            melden(.fehler("Funkdienst des Trackers nicht gefunden"))
            return
        }
        peripheral.discoverCharacteristics([schreibenUUID, antwortUUID], for: dienst)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard service.uuid == dienstUUID else {
            weitererDienst(peripheral, service, error: error) // W-033: andere Dienste fassen `schreiber` und `benachrichtigt` nie an
            return
        }
        let merkmale = service.characteristics ?? []
        schreiber = merkmale.first { $0.uuid == schreibenUUID }
        if let antwort = merkmale.first(where: { $0.uuid == antwortUUID }) {
            peripheral.setNotifyValue(true, for: antwort)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == schlafAntwortUUID {
            if let error {
                melden(.bandLog(art: "funk", text: "Benachrichtigung auf Dienst 2 nicht eingeschaltet: \(error.localizedDescription)"))
            } else if characteristic.isNotifying, schlafSchreiber != nil {
                schlafBenachrichtigt = true
                melden(.schlafBereit)
            }
            return
        }
        guard characteristic.uuid == antwortUUID, characteristic.isNotifying, schreiber != nil else { return }
        benachrichtigt = true
        melden(.verbunden(name: peripheral.name))
        weitereDiensteSuchen(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == schlafSchreibenUUID, let error else { return }
        melden(.bandLog(art: "funk", text: "Schlaf-Anfrage nicht geschrieben: \(error.localizedDescription)"))
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == schlafAntwortUUID {
            if let wert = characteristic.value { melden(.schlafDaten(wert)) }
            return
        }
        guard characteristic.uuid == antwortUUID, let wert = characteristic.value else { return }
        melden(.daten(wert))
    }

    // MARK: Dienst 2 und Diagnose (W-033)

    private func schlafZuruecksetzen() {
        schlafSchreiber = nil
        schlafBenachrichtigt = false
        dienstSuche = false
        offeneDienste = 0
        dienstZeilen = []
        dienstLogGesendet = false
    }

    /// Einmal je Verbindung, erst wenn Dienst 1 steht: alle Dienste des Bands suchen. Eine eigene Suche statt einer weiteren Dienst-Liste
    /// beim Verbinden, damit Dienst 1 genau so kommt wie vorher.
    private func weitereDiensteSuchen(_ peripheral: CBPeripheral) {
        guard !dienstSuche else { return }
        dienstSuche = true
        dienstLogGesendet = false
        dienstZeilen = []
        peripheral.discoverServices(nil)
        queue.asyncAfter(deadline: .now() + 15) { [weak self] in self?.dienstLogSenden() } // falls ein Dienst nie antwortet
    }

    private func dienstePruefen(_ peripheral: CBPeripheral, error: Error?) {
        if let error {
            melden(.bandLog(art: "dienste", text: "Suche nach allen Diensten fehlgeschlagen: \(error.localizedDescription)"))
            return
        }
        offeneDienste = 0
        for dienst in peripheral.services ?? [] {
            if dienst.uuid == dienstUUID {
                // Dienst 1 kennt seine Merkmale schon (zwei gesuchte): nicht noch einmal suchen, sein Ablauf bleibt unberührt.
                dienstZeilen.append(Self.zeile(dienst, vermerk: " (nur die beiden genutzten Merkmale gesucht)"))
            } else {
                offeneDienste += 1
                peripheral.discoverCharacteristics(nil, for: dienst)
            }
        }
        if offeneDienste == 0 { dienstLogSenden() }
    }

    private func weitererDienst(_ peripheral: CBPeripheral, _ service: CBService, error: Error?) {
        if let error {
            dienstZeilen.append("\(service.uuid.uuidString): Merkmale nicht lesbar (\(error.localizedDescription))")
        } else {
            dienstZeilen.append(Self.zeile(service, vermerk: ""))
            if service.uuid == schlafDienstUUID { schlafAufnehmen(peripheral, service) }
        }
        offeneDienste = max(0, offeneDienste - 1)
        if offeneDienste == 0 { dienstLogSenden() }
    }

    /// Dienst 2: Schreib- und Antwort-Merkmal merken und auf der Antwort zuhören. Fehlt eines, bleibt es beim Log.
    private func schlafAufnehmen(_ peripheral: CBPeripheral, _ service: CBService) {
        let merkmale = service.characteristics ?? []
        guard let schreiber = merkmale.first(where: { $0.uuid == schlafSchreibenUUID }),
              let antwort = merkmale.first(where: { $0.uuid == schlafAntwortUUID }) else {
            melden(.bandLog(art: "funk", text: "Dienst 2 da, aber Schreib- oder Antwort-Merkmal fehlt"))
            return
        }
        schlafSchreiber = schreiber
        peripheral.setNotifyValue(true, for: antwort)
    }

    private func dienstLogSenden() {
        guard dienstSuche, !dienstLogGesendet else { return }
        dienstLogGesendet = true
        let text = dienstZeilen.isEmpty ? "keine Dienste gemeldet" : dienstZeilen.joined(separator: "; ")
        melden(.bandLog(art: "dienste", text: text))
    }

    /// "UUID: Merkmal (Eigenschaften), ...", nur UUIDs und Eigenschaften, nichts wird gelesen.
    private static func zeile(_ dienst: CBService, vermerk: String) -> String {
        let merkmale = (dienst.characteristics ?? []).map { "\($0.uuid.uuidString) [\(eigenschaften($0.properties))]" }
        return "\(dienst.uuid.uuidString)\(vermerk): " + (merkmale.isEmpty ? "keine Merkmale" : merkmale.joined(separator: ", "))
    }

    private static func eigenschaften(_ p: CBCharacteristicProperties) -> String {
        var teile: [String] = []
        if p.contains(.read) { teile.append("lesen") }
        if p.contains(.write) { teile.append("schreiben") }
        if p.contains(.writeWithoutResponse) { teile.append("schreiben ohne Antwort") }
        if p.contains(.notify) { teile.append("melden") }
        if p.contains(.indicate) { teile.append("anzeigen") }
        return teile.joined(separator: "/")
    }
}

/// Die echte Suche über den `CBCentralManager`; merkt die Geräte, damit der Verbindungsweg nur Kennungen weiterreichen muss.
private final class ZentraleSuche: BandSuche {
    private let zentrale: CBCentralManager
    private let dienst: CBUUID
    private(set) var gefunden: [UUID: CBPeripheral] = [:]

    init(zentrale: CBCentralManager, dienst: CBUUID) {
        self.zentrale = zentrale
        self.dienst = dienst
    }

    func verbundene(dienst _: String) -> [BandGeraetInfo] {
        aufnehmen(zentrale.retrieveConnectedPeripherals(withServices: [dienst]))
    }

    func bekannte(_ kennungen: [UUID]) -> [BandGeraetInfo] {
        aufnehmen(zentrale.retrievePeripherals(withIdentifiers: kennungen))
    }

    private func aufnehmen(_ liste: [CBPeripheral]) -> [BandGeraetInfo] {
        for g in liste { gefunden[g.identifier] = g }
        return liste.map { BandGeraetInfo(kennung: $0.identifier, name: $0.name) }
    }
}
