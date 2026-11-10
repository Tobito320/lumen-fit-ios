import SwiftUI

/// Lumi: ein goldener Tropfen mit Locke, großen Augen, Ärmchen und Füßchen, in 14 Zuständen (Lumi-Set vom 10.11.2026,
/// Vault `Lumen Fit/lumi/`, viewBox 100 x 104). `LumiPose` beschreibt den Zustand, `LumiZeichner` zeichnet ihn in einem `Canvas`.
/// Bewegung nur bei Ereignissen: beim Wechsel des Zustands blendet Lumi über, Freude-Zustände springen dabei leicht.
/// Reduce Motion: nur Überblendung; Stromsparmodus: gar keine Bewegung. Keine Dauerbewegung.
/// Auf hellen Flächen und bei erhöhtem Kontrast bekommt der Körper eine 2-pt-Kontur. Dekoration: für VoiceOver verborgen, die Stimmung steht als Text daneben.
struct LumiView: View {
    let stimmung: LumiStimmung
    let groesse: CGFloat
    /// 1 bis 9 (`MeilensteinStore.stufe`): +3 % Größe je Stufe, ab 3 Hof, ab 6 Funken.
    var stufe: Int = 1
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @Environment(\.accessibilityReduceMotion) private var reduziert

    var body: some View {
        let kontur = schema == .light || kontrast == .increased
        let aktuelleStufe = stufe
        let zustand = stimmung
        let klein = groesse < 30
        let sparen = ProcessInfo.processInfo.isLowPowerModeEnabled
        let feiert = LumiPose.fuer(zustand).feiert
        let wechsel: Animation? = sparen ? nil : .spring(duration: 0.45, bounce: feiert && !reduziert ? 0.45 : 0.15)
        let uebergang: AnyTransition = reduziert ? .opacity : .scale(scale: feiert ? 0.8 : 0.92, anchor: .bottom).combined(with: .opacity)
        ZStack {
            Canvas { kontext, flaeche in
                LumiZeichner.zeichne(stimmung: zustand, stufe: aktuelleStufe, hell: kontur, klein: klein, in: &kontext, groesse: flaeche)
            }
            .id(zustand)
            .transition(uebergang)
        }
        .frame(width: groesse, height: groesse * 1.04)
        .animation(wechsel, value: zustand)
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

    private nonisolated static let blau: UInt32 = 0x3A8DFF
    private nonisolated static let stahl: UInt32 = 0x46516A
    private nonisolated static let stahlDunkel: UInt32 = 0x2B3446
    private nonisolated static let stahlHell: UInt32 = 0x8994AA
    private nonisolated static let rosa: UInt32 = 0xFF7C9A

    /// `hell` = 2-pt-Kontur (helle Fläche oder erhöhter Kontrast). `klein` (unter 30 pt): ohne Hof, Funken und feine Deko.
    nonisolated static func zeichne(stimmung: LumiStimmung, stufe: Int, hell: Bool, klein: Bool = false, in kontext: inout GraphicsContext, groesse: CGSize) {
        let f = groesse.width / breite
        guard f > 0 else { return }
        kontext.scaleBy(x: f, y: f)
        let pose = LumiPose.fuer(stimmung)
        let c = stimmung.farbsatz
        func auswahl(_ teile: [LumiTeil]) -> [LumiTeil] { klein ? teile.filter { !$0.istDeko } : teile }

        // Hof ab Stufe 3 (und immer in Freude-Zuständen), Schatten, hintere Teile, Füße
        if !klein, stufe >= 3 || pose.feiert {
            let hof = Gradient(stops: [.init(color: farbe(c.hof, 0.5 * pose.hof), location: 0.45), .init(color: farbe(c.hof, 0), location: 1)])
            kontext.fill(Path(ellipseIn: CGRect(x: 2, y: 12, width: 96, height: 96)), with: .radialGradient(hof, center: CGPoint(x: 50, y: 60), startRadius: 0, endRadius: 48))
        }
        kontext.fill(oval(50, 100, 22, 3.5), with: .color(.black.opacity(0.13)))
        for t in auswahl(pose.hinten) { teil(t, c, kontext) }
        for x in [40.0, 60.0] { kontext.fill(oval(x, 95, 7, 4.5), with: .color(farbe(c.fuss))) }

        // Körper mit Verlauf (Mitte oben links), Kontur, Glanzlicht, Wangen, Band, Gesicht
        var k = kontext
        if pose.gestaucht { k.translateBy(x: 0, y: 3); k.scaleBy(x: 1, y: 0.97); k.translateBy(x: 0, y: -3) }
        let verlauf = Gradient(stops: [
            .init(color: farbe(c.verlauf[0]), location: 0), .init(color: farbe(c.verlauf[1]), location: 0.45),
            .init(color: farbe(c.verlauf[2]), location: 0.85), .init(color: farbe(c.verlauf[3]), location: 1)])
        k.fill(koerperPfad, with: .radialGradient(verlauf, center: CGPoint(x: 42.8, y: 41.9), startRadius: 0, endRadius: 56))
        if hell {
            k.stroke(koerperPfad, with: .color(farbe(c.kontur)), lineWidth: 2 / f)
        } else {
            k.stroke(koerperPfad, with: .color(farbe(c.kontur, 0.5)), lineWidth: 1.4)
        }
        let glanz = Gradient(colors: [.white.opacity(0.9), .white.opacity(0)])
        k.fill(glanzPfad, with: .linearGradient(glanz, startPoint: CGPoint(x: 38, y: 32), endPoint: CGPoint(x: 38, y: 48)))
        k.fill(kreis(70, 44, 2.2), with: .color(.white.opacity(0.7)))
        if pose.wangen {
            for x in [27.0, 73.0] { k.fill(oval(x, 68.5, 5.6, 3.3), with: .color(farbe(rosa, 0.55))) }
        }
        if pose.band {
            var b = k
            b.clip(to: koerperPfad)
            stirnband(b)
        }
        for t in pose.gesicht { teil(t, c, k) }

        for t in auswahl(pose.vorn) { teil(t, c, kontext) }

        // Funken ab Stufe 6 (Freude-Zustände haben eigene)
        if !klein, stufe >= 6, !pose.feiert {
            kontext.fill(SVGPfad.pfad("M86 12 l2.6 6.4 6.4 2.6 -6.4 2.6 -2.6 6.4 -2.6 -6.4 -6.4 -2.6 6.4 -2.6z"), with: .color(farbe(0xFFD60A)))
            kontext.fill(SVGPfad.pfad("M12 18 l1.8 4.4 4.4 1.8 -4.4 1.8 -1.8 4.4 -1.8 -4.4 -4.4 -1.8 4.4 -1.8z"), with: .color(farbe(0xA6FF00)))
            kontext.fill(kreis(92, 44, 2.6), with: .color(farbe(0x00E0F0)))
            kontext.fill(kreis(7, 48, 2.3), with: .color(farbe(0xFA114F)))
        }
    }

    // MARK: Teile

    private nonisolated static func stirnband(_ k: GraphicsContext) {
        k.fill(SVGPfad.pfad("M8 46.5 C28 36.5 72 36.5 92 46.5 L92 53.5 C72 43.5 28 43.5 8 53.5Z"), with: .color(.white))
        k.stroke(SVGPfad.pfad("M8 50 C28 40 72 40 92 50"), with: .color(farbe(blau)), lineWidth: 2.4)
        k.stroke(SVGPfad.pfad("M8 53.5 C28 43.5 72 43.5 92 53.5"), with: .color(.black.opacity(0.12)), lineWidth: 1.2)
    }

    private nonisolated static func teil(_ t: LumiTeil, _ c: LumiStimmung.Farbsatz, _ k: GraphicsContext) {
        let tinte = farbe(c.gesicht)
        switch t {
        case let .arm(x, y, rx, ry, grad):
            glied(gedreht(k, x, y, grad), oval(x, y, rx, ry), c)
        case let .faust(x, y):
            glied(k, kreis(x, y, 5.6), c)
        case let .augen(dy, lx, ly, gross):
            for x in [38.0, 62.0] { auge(k, x: x, dy: dy, lx: lx, ly: ly, gross: gross, tinte: tinte) }
        case let .auge(x):
            auge(k, x: x, dy: 0, lx: 0, ly: 0, gross: 1, tinte: tinte)
        case let .froh(x):
            strich(k, "M\(x - 7) 61 q7 -10 14 0", tinte, 3.6)
        case let .zu(x, dy):
            strich(k, "M\(x - 6) \(58 + dy) q6 5 12 0", tinte, 3.4)
        case let .halb(x, blick):
            // Untere Halbellipse mit geradem Lid (wie im Generator, Bezier-Näherung 0,5523)
            let y = 58.0, n = 0.5523
            var p = Path()
            p.move(to: CGPoint(x: x - 6.5, y: y - 1))
            p.addLine(to: CGPoint(x: x + 6.5, y: y - 1))
            p.addCurve(to: CGPoint(x: x, y: y + 6), control1: CGPoint(x: x + 6.5, y: y - 1 + 7 * n), control2: CGPoint(x: x + 6.5 * n, y: y + 6))
            p.addCurve(to: CGPoint(x: x - 6.5, y: y - 1), control1: CGPoint(x: x - 6.5 * n, y: y + 6), control2: CGPoint(x: x - 6.5, y: y - 1 + 7 * n))
            p.closeSubpath()
            k.fill(p, with: .color(tinte))
            k.fill(kreis(x + 2 + blick, y + 2.5, 1.9), with: .color(.white))
            strich(k, "M\(x - 7.5) \(y - 1.2) q7.5 -2 15 0", tinte, 2.6)
        case let .kneifen(x):
            strich(k, "M\(x - 5) 53 l9 5 -9 5", tinte, 3.2)
        case let .brauen(braue):
            strich(k, brauenPfad(braue), tinte, 3)
        case let .mund(mund):
            self.mund(mund, k, tinte)
        case let .o(dy):
            k.fill(oval(50, 70 + dy, 2.6, 2.4), with: .color(tinte))
        case .augenringe:
            strich(k, "M32 66 q6 3 12 0 M56 66 q6 3 12 0", farbe(0x9A8FE0, 0.8), 2)
        case let .kurzhantel(x, y, grad):
            let n = gedreht(k, x, y, grad)
            n.fill(eckig(x - 8, y - 1.7, 16, 3.4, 1.7), with: .color(farbe(stahl)))
            for px in [x - 10.5, x + 5.5] { scheibe(n, eckig(px, y - 6.5, 5, 13, 1.8)) }
        case let .langhantel(y):
            k.fill(eckig(3, y - 1.8, 94, 3.6, 1.8), with: .color(farbe(stahl)))
            for px in [4.0, 89.0] { scheibe(k, eckig(px, y - 8, 7, 16, 2)) }
            for px in [12.0, 86.0] { k.fill(eckig(px, y - 4, 2.4, 8, 1), with: .color(farbe(stahlHell))) }
        case let .flasche(x, y, grad):
            let n = gedreht(k, x, y, grad)
            let koerper = eckig(x - 5, y - 10, 10, 20, 3.5)
            n.fill(koerper, with: .color(farbe(blau)))
            n.stroke(koerper, with: .color(farbe(0x1F6FD6)), lineWidth: 0.8)
            n.fill(Path(CGRect(x: x - 5, y: y - 3, width: 10, height: 6)), with: .color(.white.opacity(0.9)))
            n.fill(eckig(x - 3, y - 14, 6, 4.5, 1.4), with: .color(farbe(stahlDunkel)))
            n.fill(eckig(x - 3.2, y - 8, 1.8, 4, 0.9), with: .color(.white.opacity(0.6)))
        case let .tasse(x, y):
            strich(k, "M\(x + 6) \(y - 2) C\(x + 8.21) \(y - 2) \(x + 10) \(y - 0.21) \(x + 10) \(y + 2) C\(x + 10) \(y + 4.21) \(x + 8.21) \(y + 6) \(x + 6) \(y + 6)",
                   farbe(0xC9D6EA), 2.4)
            let becher = eckig(x - 7, y - 6, 14, 14, 3.5)
            k.fill(becher, with: .color(.white))
            k.stroke(becher, with: .color(farbe(0xC9D6EA)), lineWidth: 0.8)
            k.fill(Path(CGRect(x: x - 7, y: y - 1, width: 14, height: 3)), with: .color(farbe(blau)))
            strich(k, "M\(x - 2.5) \(y - 10) q-2 -3 0 -6 M\(x + 2.5) \(y - 10) q2 -3 0 -6", farbe(0xB9C2D3), 1.8)
        case let .haken(x, y):
            k.fill(kreis(x, y, 9), with: .color(farbe(0x34C759)))
            strich(k, "M\(x - 4.2) \(y + 0.3) l3 3 5.6 -6", .white, 2.8)
        case let .flamme(x, y):
            var n = k
            n.translateBy(x: x, y: y)
            n.fill(SVGPfad.pfad("M0 -11 C4 -6 9 -2 9 4 C9 8.69 4.97 12.5 0 12.5 C-4.97 12.5 -9 8.69 -9 4 C-9 -1 -5 -3 -4 -8 C-2 -5 -1 -4 0 -11Z"), with: .color(farbe(0xFF6A2B)))
            n.fill(SVGPfad.pfad("M0 -2 C2.5 1 4.5 3 4.5 6 C4.5 8.32 2.49 10.2 0 10.2 C-2.49 10.2 -4.5 8.32 -4.5 6 C-4.5 3 -2 2 0 -2Z"), with: .color(farbe(0xFFD60A)))
        case let .pflaster(x, y, grad):
            for g in [grad, grad + 90] {
                let streifen = eckig(x - 8, y - 3, 16, 6, 3)
                let n = gedreht(k, x, y, g)
                n.fill(streifen, with: .color(farbe(0xF6D2A2)))
                n.stroke(streifen, with: .color(farbe(0xD9A86C)), lineWidth: 0.8)
            }
            gedreht(k, x, y, grad).fill(eckig(x - 3, y - 3, 6, 6, 1), with: .color(farbe(0xECC08A)))
        case let .tropfen(x, y, s):
            var n = k
            n.translateBy(x: x, y: y)
            n.scaleBy(x: s, y: s)
            let tropfen = SVGPfad.pfad("M0 -6 C2.5 -2 4 0 4 2.4 C4 4.61 2.21 6.4 0 6.4 C-2.21 6.4 -4 4.61 -4 2.4 C-4 0 -2.5 -2 0 -6Z")
            n.fill(tropfen, with: .color(farbe(0x5AC8FA)))
            n.stroke(tropfen, with: .color(farbe(0x1E8FD0)), lineWidth: 0.8)
            n.fill(kreis(-1.4, 1.6, 1), with: .color(.white.opacity(0.9)))
        case let .zz(x, y, s):
            let a = 9 * s
            strich(k, "M\(x) \(y) L\(x + a) \(y) L\(x) \(y + a) L\(x + a) \(y + a)", farbe(0x7D7AE8), 2.8 * s)
        case let .stern(x, y, r, hex):
            let q = r * 0.38 * 0.4
            var p = Path()
            p.move(to: CGPoint(x: x, y: y - r))
            p.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x + q, y: y - q))
            p.addQuadCurve(to: CGPoint(x: x, y: y + r), control: CGPoint(x: x + q, y: y + q))
            p.addQuadCurve(to: CGPoint(x: x - r, y: y), control: CGPoint(x: x - q, y: y + q))
            p.addQuadCurve(to: CGPoint(x: x, y: y - r), control: CGPoint(x: x - q, y: y - q))
            p.closeSubpath()
            k.fill(p, with: .color(farbe(hex)))
        case let .schwung(d):
            strich(k, d, farbe(0xFFAE1F, 0.9), 2.4)
        case let .blitz(x, y):
            strich(k, "M\(x) \(y) l5 -3 -1.5 5 5 -3", farbe(0xFF453A), 2.2)
        case .blasen:
            for (x, y, r) in [(80.0, 30.0, 2.2), (86.0, 21.0, 3.2), (92.0, 10.0, 4.4)] {
                k.fill(kreis(x, y, r), with: .color(.white))
                k.stroke(kreis(x, y, r), with: .color(farbe(0xB9C2D3)), lineWidth: 1.2)
            }
        case .konfetti:
            gedreht(k, 12, 22, 25).fill(eckig(10, 20, 4.5, 4.5, 1), with: .color(farbe(0xFF375F)))
            gedreht(k, 86, 34, -20).fill(eckig(84, 32, 4.5, 4.5, 1), with: .color(farbe(0x34C759)))
            k.fill(kreis(20, 9, 2.3), with: .color(farbe(blau)))
            k.fill(kreis(92, 50, 2.2), with: .color(farbe(0xFF9F0A)))
            gedreht(k, 8, 43, -30).fill(eckig(6, 40, 3.4, 6, 1.2), with: .color(farbe(0xBF5AF2)))
        }
    }

    private nonisolated static func mund(_ mund: LumiTeil.Mund, _ k: GraphicsContext, _ tinte: Color) {
        switch mund {
        case .laecheln: strich(k, "M45 67.5 q5 5.5 10 0", tinte, 3)
        case .grinsen: strich(k, "M44 67 q6 5.5 12 -1.5", tinte, 3)
        case .lachen:
            let p = SVGPfad.pfad("M41.5 65 q8.5 14 17 0z")
            k.fill(p, with: .color(tinte))
            k.stroke(p, with: .color(tinte), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            k.fill(SVGPfad.pfad("M45.5 70.5 q4.5 4 9 0 q-4.5 -2.5 -9 0z"), with: .color(farbe(rosa)))
        case .rufen:
            k.fill(oval(50, 70, 6, 6.5), with: .color(tinte))
            k.fill(oval(50, 73.5, 3.6, 2.4), with: .color(farbe(rosa)))
        case .hecheln:
            k.fill(oval(50, 70, 4, 4.4), with: .color(tinte))
            k.fill(oval(50, 73, 2.6, 2), with: .color(farbe(rosa)))
        case .gaehnen:
            k.fill(oval(50, 71, 4.6, 6.2), with: .color(tinte))
            k.fill(oval(50, 74.3, 2.8, 2), with: .color(farbe(rosa)))
        case .traurig: strich(k, "M45 71.5 q5 -5 10 0", tinte, 3)
        case .zaehne:
            k.fill(eckig(42, 65.5, 16, 8, 4), with: .color(tinte))
            k.fill(eckig(44, 67.2, 12, 4.6, 1.6), with: .color(.white))
            k.stroke(SVGPfad.pfad("M50 67.2 L50 71.8"), with: .color(tinte), lineWidth: 1)
        case .nachdenken: strich(k, "M46 69 q4 -1.2 8 0.6", tinte, 3)
        case .zufrieden: strich(k, "M46 67.5 q4 4 8 0", tinte, 3)
        }
    }

    private nonisolated static func brauenPfad(_ braue: LumiTeil.Braue) -> String {
        switch braue {
        case .fest: "M30.5 47.5l12 3.5M69.5 47.5l-12 3.5"
        case .traurig: "M31 50.5l11 -3.5M69 50.5l-11 -3.5"
        case .hoch: "M31 46.5q6 -3 12 0M57 46.5q6 -3 12 0"
        case .hochLinks: "M31 46.5q6 -3 12 0"
        case .denk: "M31 48.5q6 -2 12 0M57 45.5q6 -4 12 -1"
        }
    }

    // MARK: Helfer

    private nonisolated static func auge(_ k: GraphicsContext, x: Double, dy: Double, lx: Double, ly: Double, gross: Double, tinte: Color) {
        k.fill(oval(x, 58 + dy, 6.5 * gross, 8 * gross), with: .color(tinte))
        k.fill(kreis(x + 2.5 + lx, 54.5 + dy + ly, 2.8 * gross), with: .color(.white))
        k.fill(kreis(x - 2 + lx, 61 + dy + ly, 1.3), with: .color(.white))
    }

    private nonisolated static func glied(_ k: GraphicsContext, _ p: Path, _ c: LumiStimmung.Farbsatz) {
        k.fill(p, with: .color(farbe(c.arm)))
        k.stroke(p, with: .color(farbe(c.kontur, 0.45)), lineWidth: 1.2)
    }

    private nonisolated static func scheibe(_ k: GraphicsContext, _ p: Path) {
        k.fill(p, with: .color(farbe(stahlDunkel)))
        k.stroke(p, with: .color(farbe(stahlHell)), lineWidth: 0.8)
    }

    private nonisolated static func strich(_ k: GraphicsContext, _ daten: String, _ farbe: Color, _ breite: CGFloat) {
        k.stroke(SVGPfad.pfad(daten), with: .color(farbe), style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round))
    }

    /// Kopie des Kontexts, um (x, y) um `grad` gedreht.
    private nonisolated static func gedreht(_ k: GraphicsContext, _ x: Double, _ y: Double, _ grad: Double) -> GraphicsContext {
        guard grad != 0 else { return k }
        var n = k
        n.translateBy(x: x, y: y)
        n.rotate(by: .degrees(grad))
        n.translateBy(x: -x, y: -y)
        return n
    }

    private nonisolated static func farbe(_ hex: UInt32, _ deckkraft: Double = 1) -> Color { LumenFarben.farbe(hex).opacity(deckkraft) }
    private nonisolated static func oval(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
    }
    private nonisolated static func kreis(_ x: Double, _ y: Double, _ r: Double) -> Path { oval(x, y, r, r) }
    private nonisolated static func eckig(_ x: Double, _ y: Double, _ b: Double, _ h: Double, _ r: Double) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: b, height: h), cornerRadius: r)
    }
}
