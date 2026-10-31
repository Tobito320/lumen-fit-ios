// Quelle: Lovea Zyklus/ZyklusStil.swift, ZyklusDeko.swift (nur im Thema Lovea; andere Themen behalten den Lumen-Stil)
import SwiftUI

/// Die eigene Zyklus-Palette von Lovea: Zuckerrosa, Himbeere, Perlmutt; im dunklen Modus tiefes Beerenrot statt Schwarz.
enum ZyklusLoveaFarbe {
    static func zuckerrosa(_ dunkel: Bool) -> Color { LumenFarben.farbe(dunkel ? 0xF48FB8 : 0xF9A8C9) }
    static func himbeere(_ dunkel: Bool) -> Color { LumenFarben.farbe(dunkel ? 0xFF6FA5 : 0xC2185B) }
    static func perlmutt(_ dunkel: Bool) -> Color { LumenFarben.farbe(dunkel ? 0x4A1B3E : 0xFFF8FB) }
    /// Fließtext auf Perlmutt und Hintergrund (Lovea: mindestens 7:1).
    static func tinte(_ dunkel: Bool) -> Color { LumenFarben.farbe(dunkel ? 0xFFEAF3 : 0x5B1C3F) }
    /// Zweitrangiger Text (Lovea: mindestens 4,5:1 auf Karten).
    static func tinteLeise(_ dunkel: Bool) -> Color { LumenFarben.farbe(dunkel ? 0xE8BCD3 : 0x8A4A68) }
    static func aufHimbeere(_ dunkel: Bool) -> Color { LumenFarben.farbe(dunkel ? 0x2D0A1E : 0xFFFFFF) }

    /// Palette für alle Zyklus-Seiten im Thema Lovea.
    static func palette(_ dunkel: Bool) -> Palette {
        Palette(grund: perlmutt(dunkel), flaeche: perlmutt(dunkel), text: tinte(dunkel), text2: tinteLeise(dunkel),
                rand: zuckerrosa(dunkel), haar: zuckerrosa(dunkel).opacity(0.5), akzent: himbeere(dunkel), aufAkzent: aufHimbeere(dunkel))
    }

    /// Phasenfarbe wie Lovea `ZyklusPhasenTon` (Linien und Symbole, nie als Text).
    static func phase(_ phase: ZyklusPhase, dunkel: Bool) -> Color {
        let hex: (hell: UInt32, dunkel: UInt32) = switch phase {
        case .periode: (0xD81B60, 0xFF5C93)
        case .follikel: (0xE0703A, 0xFFB08A)
        case .fruchtbar: (0x8E44CE, 0xC49BFF)
        case .eisprung: (0x0E9C98, 0x5EE0D8)
        case .luteal: (0xB05A8A, 0xE59BC4)
        }
        return LumenFarben.farbe(dunkel ? hex.dunkel : hex.hell)
    }
}

/// Weicher Verlauf (Fliederweiß bis Zuckerrosa, dunkel tiefes Beerenrot) mit Herzen, Blüten und Sternchen.
struct ZyklusLoveaHintergrund: View {
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let dunkel = schema == .dark
        ZStack {
            LinearGradient(
                colors: dunkel
                    ? [LumenFarben.farbe(0x2A0F24), LumenFarben.farbe(0x4A1738), LumenFarben.farbe(0x3A1230)]
                    : [LumenFarben.farbe(0xFFF1F7), LumenFarben.farbe(0xFFD9E8), LumenFarben.farbe(0xF3E8FC)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            ZyklusLoveaDeko()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Verstreute Herzen, Blüten und Sternchen (Lovea `ZyklusDeko.swift:66-113`): sie schweben sanft auf und ab (3 pt, 2,4 s plus 0,3 s je Stück); Bewegung reduzieren und Stromsparmodus: still.
private struct ZyklusLoveaDeko: View {
    private enum Art { case herz, bluete, stern }
    private struct Stueck {
        let x: CGFloat, y: CGFloat, groesse: CGFloat, winkel: Double
        let art: Art
        let ton: Int
    }

    private static let stuecke: [Stueck] = [
        Stueck(x: 0.08, y: 0.10, groesse: 22, winkel: -12, art: .herz, ton: 0),
        Stueck(x: 0.88, y: 0.07, groesse: 26, winkel: 10, art: .bluete, ton: 1),
        Stueck(x: 0.52, y: 0.05, groesse: 14, winkel: 0, art: .stern, ton: 2),
        Stueck(x: 0.93, y: 0.42, groesse: 18, winkel: 14, art: .herz, ton: 1),
        Stueck(x: 0.05, y: 0.46, groesse: 24, winkel: -8, art: .bluete, ton: 0),
        Stueck(x: 0.20, y: 0.80, groesse: 16, winkel: 0, art: .stern, ton: 1),
        Stueck(x: 0.82, y: 0.88, groesse: 24, winkel: -10, art: .herz, ton: 0),
        Stueck(x: 0.50, y: 0.93, groesse: 20, winkel: 8, art: .bluete, ton: 2),
        Stueck(x: 0.70, y: 0.25, groesse: 12, winkel: 0, art: .stern, ton: 0),
        Stueck(x: 0.30, y: 0.30, groesse: 10, winkel: 0, art: .stern, ton: 2),
    ]

    @Environment(\.colorScheme) private var schema
    @Environment(\.bewegungAus) private var bewegungAus
    @Environment(\.stromsparmodus) private var spar
    @State private var schwebt = false

    var body: some View {
        let still = bewegungAus || spar
        GeometryReader { geo in
            ForEach(0..<Self.stuecke.count, id: \.self) { i in
                let s = Self.stuecke[i]
                form(s)
                    .frame(width: s.groesse, height: s.groesse)
                    .rotationEffect(.degrees(s.winkel))
                    .offset(y: still ? 0 : (schwebt ? -3 : 3))
                    .animation(still ? nil : .easeInOut(duration: 2.4 + Double(i) * 0.3).repeatForever(autoreverses: true), value: schwebt)
                    .position(x: geo.size.width * s.x, y: geo.size.height * s.y)
            }
        }
        .allowsHitTesting(false)
        .onAppear { schwebt = !still }
        .onDisappear { schwebt = false }
    }

    @ViewBuilder
    private func form(_ s: Stueck) -> some View {
        let dunkel = schema == .dark
        let ton = [ZyklusLoveaFarbe.zuckerrosa(dunkel), ZyklusLoveaFarbe.himbeere(dunkel), LumenFarben.farbe(dunkel ? 0xFFA98A : 0xFFC9A8)][s.ton].opacity(dunkel ? 0.35 : 0.55)
        switch s.art {
        case .herz: ZyklusLoveaHerzForm().fill(ton)
        case .bluete: ZyklusLoveaBluetenForm().fill(ton)
        case .stern: ZyklusLoveaSternForm().fill(ton)
        }
    }
}

/// Herz (Lovea `ZyklusHerzForm`), auch im Ring über der Zahl.
struct ZyklusLoveaHerzForm: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + w * x, y: rect.minY + h * y) }
        var pfad = Path()
        pfad.move(to: p(0.5, 0.95))
        pfad.addCurve(to: p(0, 0.32), control1: p(0.35, 0.82), control2: p(0, 0.62))
        pfad.addCurve(to: p(0.5, 0.25), control1: p(0, -0.05), control2: p(0.42, -0.02))
        pfad.addCurve(to: p(1, 0.32), control1: p(0.58, -0.02), control2: p(1, -0.05))
        pfad.addCurve(to: p(0.5, 0.95), control1: p(1, 0.62), control2: p(0.65, 0.82))
        pfad.closeSubpath()
        return pfad
    }
}

private struct ZyklusLoveaBluetenForm: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        var pfad = Path()
        for i in 0..<5 {
            let blatt = Path(ellipseIn: CGRect(x: -r * 0.34, y: -r, width: r * 0.68, height: r * 0.98))
            let drehung = CGAffineTransform(rotationAngle: CGFloat(i) * 2 * .pi / 5).concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY))
            pfad.addPath(blatt.applying(drehung))
        }
        return pfad
    }
}

private struct ZyklusLoveaSternForm: Shape {
    func path(in rect: CGRect) -> Path {
        let mitte = CGPoint(x: rect.midX, y: rect.midY)
        var pfad = Path()
        pfad.move(to: CGPoint(x: rect.midX, y: rect.minY))
        pfad.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: mitte)
        pfad.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: mitte)
        pfad.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: mitte)
        pfad.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: mitte)
        pfad.closeSubpath()
        return pfad
    }
}

/// Perlmutt-Karte (Lovea `ZyklusKarte`): Radius 26, Rosa-Verlauf, Rand 1,5 pt, weicher Schatten.
private struct ZyklusLoveaKartenGrund: ViewModifier {
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    func body(content: Content) -> some View {
        let dunkel = schema == .dark
        let form = RoundedRectangle(cornerRadius: 26, style: .continuous)
        let ton = ZyklusLoveaFarbe.zuckerrosa(dunkel)
        content.background {
            form.fill(ZyklusLoveaFarbe.perlmutt(dunkel))
                .overlay(form.fill(LinearGradient(colors: [ton.opacity(0.28), ton.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(form.strokeBorder(ton.opacity(kontrast == .increased ? 0.9 : 0.5), lineWidth: 1.5))
                .shadow(color: ZyklusLoveaFarbe.himbeere(dunkel).opacity(dunkel ? 0.25 : 0.14), radius: 12, y: 5)
        }
    }
}

private struct ZyklusHintergrundModifier: ViewModifier {
    @Environment(\.lumenThema) private var thema
    @Environment(\.colorScheme) private var schema

    func body(content: Content) -> some View {
        if thema == .lovea {
            content
                .environment(\.palette, ZyklusLoveaFarbe.palette(schema == .dark))
                .tint(ZyklusLoveaFarbe.himbeere(schema == .dark))
                .background { ZyklusLoveaHintergrund() }
        } else {
            content.lumenHintergrund()
        }
    }
}

extension View {
    /// Hintergrund der Zyklus-Seiten: Lumen-Grund, im Thema Lovea der rosa Verlauf mit Deko und die Zyklus-Palette.
    func lumenZyklusHintergrund() -> some View { modifier(ZyklusHintergrundModifier()) }

    /// Kartenfläche der Zyklus-Karten: Lumen-Fläche, im Thema Lovea die Perlmutt-Karte.
    func zyklusKartenFlaeche() -> some View { modifier(ZyklusKartenFlaecheModifier()) }
}

private struct ZyklusKartenFlaecheModifier: ViewModifier {
    @Environment(\.lumenThema) private var thema

    func body(content: Content) -> some View {
        if thema == .lovea { content.modifier(ZyklusLoveaKartenGrund()) } else { content.lumenKartenFlaeche() }
    }
}

/// Himbeer-Knopf (Lovea `ZyklusKnopf`): Kapsel mit Verlauf und weichem Schatten, mindestens 48 pt hoch, Schrift rund und fett.
struct ZyklusLoveaKnopfStil: ButtonStyle {
    @Environment(\.colorScheme) private var schema
    @Environment(\.isEnabled) private var aktiv
    @ScaledMetric(relativeTo: .body) private var hoehe: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        let himbeere = ZyklusLoveaFarbe.himbeere(schema == .dark)
        configuration.label
            .font(.system(.body, design: .rounded).weight(.bold))
            .foregroundStyle(ZyklusLoveaFarbe.aufHimbeere(schema == .dark))
            .padding(.horizontal, 22)
            .frame(minHeight: hoehe)
            .background {
                Capsule().fill(LinearGradient(colors: [himbeere, himbeere.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: himbeere.opacity(0.35), radius: 8, y: 4)
            }
            .opacity(configuration.isPressed ? 0.85 : (aktiv ? 1 : 0.4))
            .contentShape(.capsule)
    }
}

private struct ZyklusHauptknopfModifier: ViewModifier {
    @Environment(\.lumenThema) private var thema

    func body(content: Content) -> some View {
        if thema == .lovea { content.buttonStyle(ZyklusLoveaKnopfStil()) } else { content.buttonStyle(.lumenHauptknopf) }
    }
}

extension View {
    /// Hauptknopf der Zyklus-Seiten: Lumen-Hauptknopf, im Thema Lovea der Himbeer-Knopf mit Verlauf.
    func zyklusHauptknopf() -> some View { modifier(ZyklusHauptknopfModifier()) }
}
