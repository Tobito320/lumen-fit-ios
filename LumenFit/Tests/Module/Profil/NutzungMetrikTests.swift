import XCTest
@testable import LumenFit

final class NutzungMetrikTests: XCTestCase {
    func testAbsturzArtKommtNurAusSignalUndAusnahme() {
        XCTAssertEqual(NutzungMetrik.art(signal: 5, ausnahme: 6), .absturzFalle, "Swift-Falle: SIGTRAP, EXC_BREAKPOINT")
        XCTAssertEqual(NutzungMetrik.art(signal: nil, ausnahme: 6), .absturzFalle)
        XCTAssertEqual(NutzungMetrik.art(signal: 11, ausnahme: 1), .absturzZugriff)
        XCTAssertEqual(NutzungMetrik.art(signal: 10, ausnahme: nil), .absturzZugriff)
        XCTAssertEqual(NutzungMetrik.art(signal: 6, ausnahme: 10), .absturzAbbruch, "SIGABRT, z. B. eine Objective-C-Ausnahme")
        XCTAssertEqual(NutzungMetrik.art(signal: 9, ausnahme: 10), .absturzBeendet, "SIGKILL: Watchdog oder System")
        XCTAssertEqual(NutzungMetrik.art(signal: nil, ausnahme: nil), .absturzAnders)
    }
}
