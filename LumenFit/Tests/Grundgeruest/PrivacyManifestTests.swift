import XCTest
@testable import LumenFit

/// Apple verlangt für jede "Required Reason API" einen Grund im Datenschutz-Manifest (SPEC 6). Der Test liest die Datei, die wirklich im Paket liegt.
final class PrivacyManifestTests: XCTestCase {
    private func manifest() throws -> [String: Any] {
        let url = try XCTUnwrap(Bundle(for: BundleAnker.self).url(forResource: "PrivacyInfo", withExtension: "xcprivacy"), "PrivacyInfo.xcprivacy fehlt im Paket")
        let daten = try Data(contentsOf: url)
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: daten, format: nil) as? [String: Any])
    }

    func testKeinTrackingNurKontoDaten() throws {
        let m = try manifest()
        XCTAssertEqual(m["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((m["NSPrivacyTrackingDomains"] as? [Any])?.count, 0)
        let erhoben = (m["NSPrivacyCollectedDataTypes"] as? [[String: Any]]) ?? []
        XCTAssertEqual(Set(erhoben.compactMap { $0["NSPrivacyCollectedDataType"] as? String }), ["NSPrivacyCollectedDataTypeName", "NSPrivacyCollectedDataTypeDeviceID", "NSPrivacyCollectedDataTypeProductInteraction", "NSPrivacyCollectedDataTypeFitness", "NSPrivacyCollectedDataTypeCrashData", "NSPrivacyCollectedDataTypePerformanceData"],
                       "Konto beim Server: Name, Gerätekennung, die freigegebene Partner-Zusammenfassung (Fitness); nach \"Ja\" Nutzungszähler, Abstürze und Ladezeiten (Analytics, am Konto)")
        for e in erhoben { XCTAssertEqual(e["NSPrivacyCollectedDataTypeTracking"] as? Bool, false) }
    }

    func testGenutzteRequiredReasonApisHabenEinenGrund() throws {
        let typen = try XCTUnwrap(try manifest()["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        var gruende: [String: [String]] = [:]
        for t in typen { gruende[t["NSPrivacyAccessedAPIType"] as? String ?? ""] = t["NSPrivacyAccessedAPITypeReasons"] as? [String] }
        XCTAssertEqual(gruende["NSPrivacyAccessedAPICategoryUserDefaults"], ["CA92.1"], "UserDefaults.standard und @AppStorage")
        XCTAssertEqual(gruende["NSPrivacyAccessedAPICategoryFileTimestamp"], ["C617.1"], "Änderungsdatum der Datei in der Gruppe (LoveaBruecke)")
    }
}
