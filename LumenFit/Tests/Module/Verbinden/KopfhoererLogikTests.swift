import XCTest
@testable import LumenFit

/// Einordnung der Audio-Route und wann eine Ansage im Training kommt.
final class KopfhoererLogikTests: XCTestCase {
    private let lautsprecher = AudioAusgang(art: .lautsprecher, name: "Lautsprecher")
    private let airPods = AudioAusgang(art: .bluetooth, name: "Meine AirPods Pro")
    private let box = AudioAusgang(art: .bluetooth, name: "Küchenbox")
    private let kabel = AudioAusgang(art: .kabel, name: "Kopfhörer")

    func testNurLautsprecherIstNichtsAngeschlossen() {
        XCTAssertEqual(KopfhoererLogik.status([lautsprecher]), .keine)
        XCTAssertEqual(KopfhoererLogik.status([]), .keine)
    }

    func testAirPodsErkenntManAmNamenOhneAufGrossschreibungZuAchten() {
        XCTAssertEqual(KopfhoererLogik.status([airPods]), .bluetooth(name: "Meine AirPods Pro", airPods: true))
        XCTAssertTrue(KopfhoererLogik.istAirPods("meine AIRPODS"))
        XCTAssertFalse(KopfhoererLogik.istAirPods("Küchenbox"))
    }

    func testAndereBluetoothGeraeteHeissenBluetoothAudio() {
        XCTAssertEqual(KopfhoererLogik.status([box]), .bluetooth(name: "Küchenbox", airPods: false))
        XCTAssertEqual(KopfhoererLogik.titel(.bluetooth(name: "Küchenbox", airPods: false)), "Bluetooth-Audio verbunden")
    }

    func testBluetoothGehtVorKabelUndLautsprecher() {
        XCTAssertEqual(KopfhoererLogik.status([lautsprecher, kabel, airPods]), .bluetooth(name: "Meine AirPods Pro", airPods: true))
        XCTAssertEqual(KopfhoererLogik.status([lautsprecher, kabel]), .kabel(name: "Kopfhörer"))
    }

    func testTexteJeStatus() {
        XCTAssertEqual(KopfhoererLogik.titel(.keine), "Nichts angeschlossen")
        XCTAssertEqual(KopfhoererLogik.titel(.bluetooth(name: "x", airPods: true)), "AirPods verbunden")
        XCTAssertEqual(KopfhoererLogik.titel(.kabel(name: "x")), "Kopfhörer mit Kabel")
        XCTAssertNil(KopfhoererLogik.name(.keine))
        XCTAssertEqual(KopfhoererLogik.name(.kabel(name: "K")), "K")
        XCTAssertEqual(KopfhoererLogik.zeile(.keine), "Nichts verbunden")
        XCTAssertEqual(KopfhoererLogik.zeile(.bluetooth(name: "B", airPods: false)), "B")
        XCTAssertEqual(KopfhoererLogik.symbol(.bluetooth(name: "B", airPods: true)), "airpods")
        XCTAssertEqual(KopfhoererLogik.symbol(.keine), "headphones")
    }

    func testAnsageNurWennAnUndMitKopfhoerern() {
        let mit = KopfhoererStatus.bluetooth(name: "x", airPods: true)
        XCTAssertFalse(AnsageRegel.sprechen(an: false, nurMitKopfhoerern: false, status: mit), "aus bleibt aus")
        XCTAssertTrue(AnsageRegel.sprechen(an: true, nurMitKopfhoerern: true, status: mit))
        XCTAssertTrue(AnsageRegel.sprechen(an: true, nurMitKopfhoerern: true, status: .kabel(name: "k")))
        XCTAssertFalse(AnsageRegel.sprechen(an: true, nurMitKopfhoerern: true, status: .keine), "nie über den Lautsprecher, wenn nur mit Kopfhörern")
        XCTAssertTrue(AnsageRegel.sprechen(an: true, nurMitKopfhoerern: false, status: .keine))
    }

    func testSchluesselUndTexte() {
        XCTAssertEqual(Set([AnsageRegel.pauseSchluessel, AnsageRegel.rekordSchluessel, AnsageRegel.nurKopfhoererSchluessel]).count, 3)
        XCTAssertFalse(AnsageRegel.pauseText.isEmpty)
        XCTAssertFalse(AnsageRegel.rekordText.isEmpty)
    }
}
