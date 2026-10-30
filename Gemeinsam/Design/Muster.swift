import SwiftUI

enum MusterOrt: Sendable { case kopf, karte, hero }

/// Das Muster eines Themes: Punkte (Monochrom), Diagonalen (Graphit), Raster (Stahl), Wellen (Glut), Höhenlinien (Wald). Lovea hat keins: dort sind Grund und Karten flach.
/// Ein `Canvas` mit `drawingGroup()` (Metal-Textur im Cache), kein `TimelineView`, keine Dauerbewegung. Bei erhöhtem Kontrast aus,
/// immer für VoiceOver verborgen. Nicht hinter Diagramme legen.
struct MusterFlaeche: View {
    let thema: ThemaID
    let ort: MusterOrt
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        if kontrast == .increased || !MusterZeichner.hatMuster(thema) {
            Color.clear.accessibilityHidden(true)
        } else {
            let farbe = ort == .hero ? palette.aufAkzent : palette.akzent
            let deckkraft = MusterZeichner.deckkraft(thema: thema, dunkel: schema == .dark, ort: ort)
            Canvas { kontext, groesse in
                MusterZeichner.zeichne(thema: thema, ort: ort, groesse: groesse, farbe: farbe.opacity(deckkraft), in: &kontext)
            }
            .drawingGroup()
            .mask(alignment: .top) { MusterMaske(ort: ort) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

private struct MusterMaske: View {
    let ort: MusterOrt

    var body: some View {
        if ort == .kopf {
            // Oben volle Stärke, bei 35 % Höhe 55 %, unten 15 % (design.md Abschnitt 6).
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.55), location: 0.35),
                                   .init(color: .black.opacity(0.15), location: 1)], startPoint: .top, endPoint: .bottom)
        } else {
            Color.black
        }
    }
}

/// Reine Zeichen- und Zahlenlogik der Muster (getestet ohne Oberfläche).
enum MusterZeichner {
    /// Deckkraft der Linien: Theme-Wert, auf Karten 45 %, auf der Hauptkarte 10 % (hell) bzw. 12 % (dunkel).
    nonisolated static func deckkraft(thema: ThemaID, dunkel: Bool, ort: MusterOrt) -> Double {
        if ort == .hero { return dunkel ? 0.12 : 0.10 }
        let basis: Double = switch thema {
        case .monochrom: 0.12
        case .graphit: 0.10
        case .stahl: 0.14
        case .glut: dunkel ? 0.20 : 0.14
        case .wald: 0.18
        case .lovea: 0
        }
        return ort == .karte ? basis * 0.45 : basis
    }

    /// Lovea zeichnet in Health und Home keine Muster (nur System-Flächen); dort malt auch die Hauptkarte keine Streifen.
    nonisolated static func hatMuster(_ thema: ThemaID) -> Bool { thema != .lovea }

    nonisolated static func zeichne(thema: ThemaID, ort: MusterOrt, groesse: CGSize, farbe: Color, in kontext: inout GraphicsContext) {
        guard groesse.width > 0, groesse.height > 0, hatMuster(thema) else { return }
        if ort == .hero {
            kontext.stroke(streifen(groesse, winkel: 120, abstand: 11), with: .color(farbe), lineWidth: 2)
            return
        }
        switch thema {
        case .monochrom: kontext.fill(punkte(groesse, raster: 12, radius: 0.55), with: .color(farbe))
        case .graphit: kontext.stroke(streifen(groesse, winkel: 135, abstand: 8), with: .color(farbe), lineWidth: 1)
        case .stahl: kontext.stroke(raster(groesse, abstand: 16), with: .color(farbe), lineWidth: 1)
        case .glut: kontext.stroke(kreise(groesse, mitte: CGPoint(x: groesse.width * 0.85, y: 0), abstand: 10), with: .color(farbe), lineWidth: 1)
        case .wald: kontext.stroke(hoehenlinien(groesse), with: .color(farbe), lineWidth: 1)
        case .lovea: break
        }
    }

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

    nonisolated static func raster(_ g: CGSize, abstand: CGFloat) -> Path {
        var pfad = Path()
        var x: CGFloat = 0
        while x <= g.width { pfad.move(to: CGPoint(x: x, y: 0)); pfad.addLine(to: CGPoint(x: x, y: g.height)); x += abstand }
        var y: CGFloat = 0
        while y <= g.height { pfad.move(to: CGPoint(x: 0, y: y)); pfad.addLine(to: CGPoint(x: g.width, y: y)); y += abstand }
        return pfad
    }

    nonisolated static func kreise(_ g: CGSize, mitte: CGPoint, abstand: CGFloat) -> Path {
        var pfad = Path()
        let maximal = hypot(max(mitte.x, g.width - mitte.x), max(mitte.y, g.height - mitte.y))
        var r = abstand
        while r <= maximal {
            pfad.addEllipse(in: CGRect(x: mitte.x - r, y: mitte.y - r, width: r * 2, height: r * 2))
            r += abstand
        }
        return pfad
    }

    /// Zwei Ellipsen-Sets um (20 %, 10 %) mit Abstand 10 pt und (90 %, 80 %) mit Abstand 13 pt.
    nonisolated static func hoehenlinien(_ g: CGSize) -> Path {
        var pfad = Path()
        for (mitte, abstand) in [(CGPoint(x: g.width * 0.2, y: g.height * 0.1), CGFloat(10)), (CGPoint(x: g.width * 0.9, y: g.height * 0.8), CGFloat(13))] {
            let maximal = hypot(g.width, g.height)
            var r = abstand
            while r <= maximal {
                pfad.addEllipse(in: CGRect(x: mitte.x - r * 1.5, y: mitte.y - r, width: r * 3, height: r * 2))
                r += abstand
            }
        }
        return pfad
    }
}
