import SwiftUI

/// Lumi: ein kleines Licht, rund wie ein Tropfen mit Locke, große Augen, Bäckchen, Ärmchen und Füßchen. Form und Farben stehen als SVG-Vorlagen
/// in `docs/research/lumi/` (viewBox 100 x 104, Stand v10); `SVGPfad` liest die Pfade, ein `Canvas` zeichnet sie. Keine Dauerbewegung.
/// Auf hellen Flächen bekommt der Körper eine 2-pt-Kontur. Dekoration: für VoiceOver verborgen, die Stimmung steht als Text daneben.
struct LumiView: View {
    let stimmung: LumiStimmung
    let groesse: CGFloat
    /// 1 bis 9 (`MeilensteinStore.stufe`): +3 % Größe je Stufe, ab 3 Hof, ab 6 Funken.
    var stufe: Int = 1
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let hell = schema == .light
        let aktuelleStufe = stufe
        Canvas { kontext, groesse in
            LumiZeichner.zeichne(stimmung: stimmung, stufe: aktuelleStufe, hell: hell, in: &kontext, groesse: groesse)
        }
        .frame(width: groesse, height: groesse * 1.04)
        .scaleEffect(LumiZeichner.faktor(stufe: stufe))
        .accessibilityHidden(true)
    }
}

enum LumiZeichner {
    nonisolated static let breite: CGFloat = 100
    nonisolated static let hoehe: CGFloat = 104

    /// +3 % je Stufe, Stufe 1 = 1,0; gültig 1 bis 9.
    nonisolated static func faktor(stufe: Int) -> CGFloat { 1 + 0.03 * CGFloat(min(max(stufe, 1), 9) - 1) }

    nonisolated static var koerperPfad: Path {
        SVGPfad.pfad("M50 10 C53 17 57 20 61 18 C60 24 64 28 70 33 C80 41 86 52 86 64 C86 84 70 94 50 94 C30 94 14 84 14 64 C14 50 22 40 32 33 C38 29 41 24 41 17 C45 20 49 17 50 10Z")
    }
    nonisolated static var glanzPfad: Path { SVGPfad.pfad("M30 42 C34 35 42 32 46 34 C40 37 35 41 33 48Z") }

    nonisolated static func zeichne(stimmung: LumiStimmung, stufe: Int, hell: Bool, in kontext: inout GraphicsContext, groesse: CGSize) {
        let f = groesse.width / breite
        guard f > 0 else { return }
        kontext.scaleBy(x: f, y: f)
        let c = stimmung.farbsatz
        func farbe(_ hex: UInt32, _ deckkraft: Double = 1) -> Color { LumenFarben.farbe(hex).opacity(deckkraft) }
        let dunkel = farbe(c.gesicht)

        // Hof ab Stufe 3 (und immer bei stolz), Schatten, Füße, Arme
        if stufe >= 3 || stimmung == .stolz {
            let hof = Gradient(stops: [.init(color: farbe(c.hof, 0.5), location: 0.45), .init(color: farbe(c.hof, 0), location: 1)])
            kontext.fill(Path(ellipseIn: CGRect(x: 2, y: 12, width: 96, height: 96)), with: .radialGradient(hof, center: CGPoint(x: 50, y: 60), startRadius: 0, endRadius: 48))
        }
        kontext.fill(Path(ellipseIn: CGRect(x: 28, y: 96.5, width: 44, height: 7)), with: .color(.black.opacity(0.13)))
        for x in [40.0, 60.0] { kontext.fill(Path(ellipseIn: CGRect(x: x - 7, y: 90.5, width: 14, height: 9)), with: .color(farbe(c.fuss))) }
        func arm(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ grad: Double) {
            var k = kontext
            k.translateBy(x: x, y: y)
            k.rotate(by: .degrees(grad))
            k.fill(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)), with: .color(farbe(c.arm)))
        }
        switch stimmung {
        case .bereit: arm(17, 68, 6, 8.5, 30); arm(85, 56, 6, 8.5, -40)
        case .denkt: arm(17, 68, 6, 8.5, 30); arm(83, 68, 6, 8.5, -25)
        case .muede, .schlaeft: arm(18, 70, 6, 8, 20); arm(82, 70, 6, 8, -20)
        case .stolz: arm(15, 50, 6, 8.5, 35); arm(85, 50, 6, 8.5, -35)
        }

        // Körper mit Verlauf (Mitte oben links), Kontur, Glanzlicht
        let verlauf = Gradient(stops: [
            .init(color: farbe(c.verlauf[0]), location: 0), .init(color: farbe(c.verlauf[1]), location: 0.45),
            .init(color: farbe(c.verlauf[2]), location: 0.85), .init(color: farbe(c.verlauf[3]), location: 1)])
        kontext.fill(koerperPfad, with: .radialGradient(verlauf, center: CGPoint(x: 42.8, y: 41.9), startRadius: 0, endRadius: 56))
        if hell {
            kontext.stroke(koerperPfad, with: .color(farbe(c.kontur)), lineWidth: 2 / f)
        } else {
            kontext.stroke(koerperPfad, with: .color(farbe(c.kontur, 0.35)), lineWidth: 1.2)
        }
        let glanz = Gradient(colors: [.white.opacity(0.9), .white.opacity(0)])
        kontext.fill(glanzPfad, with: .linearGradient(glanz, startPoint: CGPoint(x: 38, y: 32), endPoint: CGPoint(x: 38, y: 48)))
        kontext.fill(Path(ellipseIn: CGRect(x: 67.8, y: 41.8, width: 4.4, height: 4.4)), with: .color(.white.opacity(0.7)))
        let baeckchen = farbe(0xFF7C9A, 0.6)
        kontext.fill(Path(ellipseIn: CGRect(x: 22, y: 64.4, width: 12, height: 7.2)), with: .color(baeckchen))
        kontext.fill(Path(ellipseIn: CGRect(x: 66, y: 64.4, width: 12, height: 7.2)), with: .color(baeckchen))

        // Gesicht
        func augen(_ yMitte: Double) {
            for x in [38.0, 62.0] {
                kontext.fill(Path(ellipseIn: CGRect(x: x - 6.5, y: yMitte - 8, width: 13, height: 16)), with: .color(dunkel))
                kontext.fill(Path(ellipseIn: CGRect(x: x + 2.5 - 2.8, y: yMitte - 3.5 - 2.8, width: 5.6, height: 5.6)), with: .color(.white))
                kontext.fill(Path(ellipseIn: CGRect(x: x - 2 - 1.3, y: yMitte + 3 - 1.3, width: 2.6, height: 2.6)), with: .color(.white))
            }
        }
        func strich(_ daten: String, breite: CGFloat) {
            kontext.stroke(SVGPfad.pfad(daten), with: .color(dunkel), style: StrokeStyle(lineWidth: breite, lineCap: .round))
        }
        switch stimmung {
        case .bereit:
            augen(58)
            strich("M45 67 q5 6 10 0", breite: 3)
        case .denkt:
            augen(55)
            strich("M46 68 q4 2 8 0", breite: 3)
            for (x, y, r) in [(80.0, 30.0, 2.0), (86.0, 22.0, 3.0), (94.0, 12.0, 4.0)] {
                kontext.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(farbe(c.hof)))
            }
        case .muede:
            for x in [38.0, 62.0] {
                kontext.fill(Path(ellipseIn: CGRect(x: x - 5.5, y: 56.8, width: 11, height: 6.4)), with: .color(dunkel))
                kontext.fill(Path(ellipseIn: CGRect(x: x + 1.5 - 1.5, y: 58 - 1.5, width: 3, height: 3)), with: .color(.white))
            }
            strich("M31.5 56.5 q6.5 -2.5 13 0 M55.5 56.5 q6.5 -2.5 13 0", breite: 2.6)
            kontext.fill(Path(ellipseIn: CGRect(x: 46.8, y: 68.4, width: 6.4, height: 5.2)), with: .color(dunkel))
        case .schlaeft:
            strich("M33 60 q6 5 12 0 M55 60 q6 5 12 0", breite: 3.4)
            kontext.fill(Path(ellipseIn: CGRect(x: 46.8, y: 68.4, width: 6.4, height: 5.2)), with: .color(dunkel))
            kontext.draw(Text("Z").font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(farbe(c.arm)), at: CGPoint(x: 78, y: 26), anchor: .bottomLeading)
            kontext.draw(Text("z").font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(farbe(c.arm)), at: CGPoint(x: 88, y: 14), anchor: .bottomLeading)
        case .stolz:
            strich("M31 60 q7 -9 14 0 M55 60 q7 -9 14 0", breite: 3.6)
            kontext.fill(SVGPfad.pfad("M42 65 q8 13 16 0 z"), with: .color(dunkel))
            kontext.fill(SVGPfad.pfad("M45.5 69 q4.5 4 9 0"), with: .color(farbe(0xFF7C9A)))
        }

        // Funken: bei stolz immer, sonst ab Stufe 6
        if stimmung == .stolz || stufe >= 6 {
            kontext.fill(SVGPfad.pfad("M86 12 l2.6 6.4 6.4 2.6 -6.4 2.6 -2.6 6.4 -2.6 -6.4 -6.4 -2.6 6.4 -2.6z"), with: .color(farbe(0xFFD60A)))
            kontext.fill(SVGPfad.pfad("M12 18 l1.8 4.4 4.4 1.8 -4.4 1.8 -1.8 4.4 -1.8 -4.4 -4.4 -1.8 4.4 -1.8z"), with: .color(farbe(0xA6FF00)))
            kontext.fill(Path(ellipseIn: CGRect(x: 89.4, y: 41.4, width: 5.2, height: 5.2)), with: .color(farbe(0x00E0F0)))
            kontext.fill(Path(ellipseIn: CGRect(x: 4.7, y: 45.7, width: 4.6, height: 4.6)), with: .color(farbe(0xFA114F)))
        }
    }
}
