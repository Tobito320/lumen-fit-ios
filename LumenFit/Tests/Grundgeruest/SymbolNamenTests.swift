import UIKit
import XCTest
@testable import LumenFit

/// Jeder SF-Symbol-Name im Quelltext muss es auf iOS 26 geben. Ein falscher Name zeigt sonst ein leeres Bild.
final class SymbolNamenTests: XCTestCase {
    /// Namen, die nicht als `systemName: "..."` im Quelltext stehen (Auswahllisten, `symbolName`, Tabellen).
    private let feste = [
        "alarm.fill", "bed.double.fill", "bolt.fill", "book.fill", "books.vertical.fill", "brain.head.profile", "bubble.left.fill", "camera.fill",
        "carrot.fill", "cart.fill", "cross.case.fill", "cup.and.saucer.fill", "drop.fill", "dumbbell.fill", "eurosign.circle.fill",
        "exclamationmark.triangle.fill", "figure.hiking", "figure.mind.and.body", "figure.pool.swim", "figure.run", "figure.stair.stepper",
        "figure.strengthtraining.traditional", "figure.walk", "figure.walk.treadmill", "figure.yoga", "fork.knife", "gamecontroller.fill",
        "gift.fill", "graduationcap.fill", "guitars.fill", "heart.fill", "house.fill", "leaf.fill", "moon.stars.fill", "moon.zzz.fill",
        "music.note", "paintpalette.fill", "pawprint.fill", "phone.fill", "pills.fill", "scalemass.fill", "star.fill", "sun.max.fill", "sunrise.fill",
    ]

    func testFesteNamenGibtEsInSFSymbols() {
        for name in feste { XCTAssertNotNil(UIImage(systemName: name), "SF Symbol fehlt: \(name)") }
    }

    func testDieDreiDatenbereicheHabenEinSymbol() {
        for bereich in Datenbereich.allCases { XCTAssertNotNil(UIImage(systemName: bereich.symbolName), bereich.symbolName) }
    }

    /// `scripts/symbole-sammeln.sh` schreibt alle Namen aus `systemName:`, `systemImage:`, `symbol:` und `icon:` in `symbole.txt` (läuft in CI vor dem Bau).
    func testAlleGesammeltenNamenAusDemQuelltext() throws {
        let url = FixtureOrt.url("System", "symbole.txt")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("symbole.txt fehlt (wird nur in CI vor dem Bau erzeugt)")
        }
        let namen = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        for name in namen { XCTAssertNotNil(UIImage(systemName: name), "SF Symbol fehlt: \(name)") }
    }
}
