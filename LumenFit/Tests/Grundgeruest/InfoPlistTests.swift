import XCTest
@testable import LumenFit

/// Die Schlüssel, ohne die Apple den Upload ablehnt oder Funktionen schweigend nicht gehen (SPEC 6, Bahnherz- und Lovea-Erfahrung).
final class InfoPlistTests: XCTestCase {
    private var info: [String: Any] { Bundle(for: BundleAnker.self).infoDictionary ?? [:] }

    func testHealthKitBrauchtBeideTexte() {
        for schluessel in ["NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"] {
            XCTAssertFalse((info[schluessel] as? String ?? "").isEmpty, schluessel)
        }
    }

    func testTexteFuerKameraBluetoothUndBewegung() {
        for schluessel in ["NSCameraUsageDescription", "NSBluetoothAlwaysUsageDescription", "NSMotionUsageDescription"] {
            XCTAssertFalse((info[schluessel] as? String ?? "").isEmpty, schluessel)
        }
    }

    func testHealthTextNenntKeinenZyklusMehr() {
        // Zyklus gehört nur in Lovea. Der Face-ID-Text bleibt, solange der alte Zyklus-Code im Ziel liegt.
        XCTAssertFalse((info["NSFaceIDUsageDescription"] as? String ?? "").isEmpty)
        let health = info["NSHealthShareUsageDescription"] as? String ?? ""
        XCTAssertFalse(health.contains("Zyklus"))
        XCTAssertFalse(health.contains("Menstruationsfluss"))
    }

    func testLinkSchemaLumenfit() throws {
        let typen = try XCTUnwrap(info["CFBundleURLTypes"] as? [[String: Any]])
        let schemata = typen.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertTrue(schemata.contains(RouteURL.schema))
    }

    func testHintergrundModiUndAbrufKennung() throws {
        let modi = try XCTUnwrap(info["UIBackgroundModes"] as? [String])
        XCTAssertTrue(modi.contains("bluetooth-central"))
        XCTAssertTrue(modi.contains("fetch"))
        let kennungen = try XCTUnwrap(info["BGTaskSchedulerPermittedIdentifiers"] as? [String])
        XCTAssertTrue(kennungen.contains(AbrufPlaner.kennung))
    }

    func testLiveActivitiesSindErlaubt() {
        XCTAssertEqual(info["NSSupportsLiveActivities"] as? Bool, true)
    }

    func testIPadBrauchtAlleVierAusrichtungenSonstLehntDerUploadAb() {
        // Fehler 90474: iPad-Ausrichtungen müssen vollständig sein, obwohl die App nur iPhone ist.
        // `Bundle.infoDictionary` blendet die Schlüssel für das andere Gerät aus, deshalb die Datei selbst lesen.
        let url = Bundle(for: BundleAnker.self).url(forResource: "Info", withExtension: "plist")
        let roh = url.flatMap { NSDictionary(contentsOf: $0) as? [String: Any] } ?? [:]
        let ipad = roh["UISupportedInterfaceOrientations~ipad"] as? [String] ?? []
        XCTAssertEqual(Set(ipad).count, 4, "\(ipad)")
    }

    func testKeineWeckerOderErinnerungen() {
        let schluessel = info.keys.map { $0.lowercased() }
        XCTAssertFalse(schluessel.contains { $0.contains("alarm") || $0.contains("reminder") || $0.contains("calendar") }, "\(schluessel)")
    }

    func testAnzeigename() {
        XCTAssertEqual(info["CFBundleDisplayName"] as? String, "Lumen Fit")
        XCTAssertEqual(Bundle(for: BundleAnker.self).bundleIdentifier, "com.onlyus.lumen-fit")
    }
}
