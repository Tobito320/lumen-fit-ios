// Quelle: Lovea Health/Koerper/MuskelSeite.swift (Treffer mit Fingerradius; die Flächen sind hier selbst gezeichnet)
import SwiftUI

/// Welche Fläche der Körperkarte ein Tipp trifft. Ein Finger ist breiter als mancher Muskel: erst der Punkt selbst, dann Ringe bis `radius` (12 pt)
/// um ihn, die nächste Fläche gewinnt. Reine Geometrie, ohne Oberfläche testbar.
enum SilhouetteTreffer {
    /// Radien der Ringe (pt) und die Zahl der Proben je Ring.
    nonisolated private static let proben = 8

    static func flaeche(_ seite: SilhouetteSeite, bei punkt: CGPoint, in rahmen: CGRect, radius: CGFloat = 12) -> SilhouetteFlaeche? {
        let flaechen = SilhouetteBild.flaechen(seite).map { ($0, $0.pfad(in: rahmen)) }
        var abstand: CGFloat = 0
        while abstand <= radius {
            let winkelzahl = abstand == 0 ? 1 : proben
            for i in 0..<winkelzahl {
                let winkel = Double(i) / Double(winkelzahl) * 2 * .pi
                let probe = CGPoint(x: punkt.x + abstand * CGFloat(cos(winkel)), y: punkt.y + abstand * CGFloat(sin(winkel)))
                if let treffer = flaechen.first(where: { $0.1.contains(probe) }) { return treffer.0 }
            }
            abstand += 3
        }
        return nil
    }
}
