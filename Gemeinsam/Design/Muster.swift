import SwiftUI

/// Zeichen-Muster für Datenflächen (Silhouette, Schlafphasen): die Farbe trägt nie allein, jede Stufe hat ein eigenes Muster.
/// Das Theme-Muster (Hintergrund, Karten, Hero, Widgets) gibt es seit dem einen Theme nicht mehr (Auftrag 09.11.).
enum MusterZeichner {
    nonisolated static func punkte(_ g: CGSize, raster: CGFloat, radius: CGFloat) -> Path {
        var pfad = Path()
        var y = raster / 2
        while y < g.height {
            var x = raster / 2
            while x < g.width {
                pfad.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                x += raster
            }
            y += raster
        }
        return pfad
    }

    /// Parallele Linien im Winkel (Grad, wie CSS gegen die Senkrechte) mit Abstand senkrecht zur Linie.
    nonisolated static func streifen(_ g: CGSize, winkel: Double, abstand: CGFloat) -> Path {
        var pfad = Path()
        let radiant = (winkel - 90) * .pi / 180          // Richtung der Linie
        let richtung = CGPoint(x: cos(radiant), y: sin(radiant))
        let normale = CGPoint(x: -richtung.y, y: richtung.x)
        let diagonale = hypot(g.width, g.height)
        let mitte = CGPoint(x: g.width / 2, y: g.height / 2)
        var versatz = -diagonale / 2
        while versatz <= diagonale / 2 {
            let o = CGPoint(x: mitte.x + normale.x * versatz, y: mitte.y + normale.y * versatz)
            pfad.move(to: CGPoint(x: o.x - richtung.x * diagonale, y: o.y - richtung.y * diagonale))
            pfad.addLine(to: CGPoint(x: o.x + richtung.x * diagonale, y: o.y + richtung.y * diagonale))
            versatz += abstand
        }
        return pfad
    }
}
