import Foundation

/// Ein Teil von Lumis Zeichnung. Namen und Zahlen 1:1 aus dem Generator des Lumi-Sets (Vault, `Lumen Fit/lumi/lumi-set-erzeugen.py`),
/// Koordinaten im Rahmen 100 x 104. `LumiZeichner` zeichnet jeden Teil.
enum LumiTeil: Sendable, Equatable {
    enum Braue: Sendable { case fest, traurig, hoch, hochLinks, denk }
    enum Mund: Sendable { case laecheln, grinsen, lachen, rufen, hecheln, gaehnen, traurig, zaehne, nachdenken, zufrieden }

    case arm(x: Double, y: Double, rx: Double, ry: Double, grad: Double)
    case faust(x: Double, y: Double)
    case augen(dy: Double = 0, lx: Double = 0, ly: Double = 0, gross: Double = 1)
    case auge(x: Double)
    case froh(x: Double)
    case zu(x: Double, dy: Double = 0)
    case halb(x: Double, blick: Double = 0)
    case kneifen(x: Double)
    case brauen(Braue)
    case mund(Mund)
    case o(dy: Double = 0)
    case augenringe
    case kurzhantel(x: Double, y: Double, grad: Double)
    case langhantel(y: Double)
    case flasche(x: Double, y: Double, grad: Double)
    case tasse(x: Double, y: Double)
    case haken(x: Double, y: Double)
    case flamme(x: Double, y: Double)
    case pflaster(x: Double, y: Double, grad: Double)
    case tropfen(x: Double, y: Double, s: Double)
    case zz(x: Double, y: Double, s: Double)
    case stern(x: Double, y: Double, r: Double, farbe: UInt32)
    case schwung(String)
    case blitz(x: Double, y: Double)
    case blasen
    case konfetti

    /// Feine Deko, die unter 30 pt wegfällt (Live Activity, kleine Widgets): Gesicht, Band und Haupt-Requisit bleiben.
    var istDeko: Bool {
        switch self {
        case .schwung, .stern, .konfetti, .blitz, .blasen: true
        default: false
        }
    }
}

/// Wie Lumi in einem Zustand aussieht. Reihenfolge beim Zeichnen: Hof, Schatten, `hinten`, Füße, Körper (mit Band, Wangen, `gesicht`), `vorn`.
struct LumiPose: Sendable, Equatable {
    var hinten: [LumiTeil] = []
    var gesicht: [LumiTeil]
    var vorn: [LumiTeil] = []
    var wangen = false
    /// Stirnband nur im laufenden Training (anfeuern, pause).
    var band = false
    /// Deckkraft des Hofs (der Hof selbst erscheint ab Stufe 3 oder bei `feiert`).
    var hof: Double = 1
    /// Körper leicht gestaucht (erschöpft).
    var gestaucht = false
    /// Freude-Zustand: Hof immer, ein Hüpfer beim Wechsel, keine zusätzlichen Stufen-Funken.
    var feiert = false

    static func fuer(_ zustand: LumiZustand) -> LumiPose {
        switch zustand {
        case .bereit:
            LumiPose(hinten: [.arm(x: 17, y: 68, rx: 6, ry: 8.5, grad: 30)], gesicht: [.augen(), .brauen(.fest), .mund(.grinsen)],
                     vorn: [.kurzhantel(x: 88, y: 45, grad: -25), .arm(x: 84, y: 55, rx: 6, ry: 8.5, grad: -40)])
        case .willkommen:
            LumiPose(hinten: [.arm(x: 17, y: 68, rx: 6, ry: 8.5, grad: 30)], gesicht: [.augen(gross: 1.05), .brauen(.hoch), .mund(.lachen)],
                     vorn: [.arm(x: 86, y: 42, rx: 6, ry: 9, grad: -25), .schwung("M92 28 q5 6 3 13"), .schwung("M96 22 q7 8 4 18"),
                            .stern(x: 12, y: 24, r: 6, farbe: 0xFFD60A)],
                     wangen: true, feiert: true)
        case .anfeuern:
            LumiPose(hinten: [.arm(x: 17, y: 70, rx: 6, ry: 8.5, grad: 25)], gesicht: [.augen(), .brauen(.fest), .mund(.rufen)],
                     vorn: [.arm(x: 84, y: 40, rx: 5.5, ry: 10, grad: -12), .faust(x: 86, y: 28),
                            .schwung("M94 22 l5 -2"), .schwung("M95 30 l5 0"), .schwung("M77 18 l-3 -4")], band: true)
        case .pause:
            LumiPose(hinten: [.arm(x: 17, y: 70, rx: 6, ry: 8.5, grad: 25)], gesicht: [.zu(x: 38), .zu(x: 62), .o()],
                     vorn: [.flasche(x: 85, y: 58, grad: 15), .arm(x: 80, y: 66, rx: 6, ry: 8.5, grad: -20)], band: true)
        case .stolz:
            LumiPose(hinten: [.langhantel(y: 8)], gesicht: [.froh(x: 38), .froh(x: 62), .mund(.lachen)],
                     vorn: [.arm(x: 18, y: 24, rx: 5.5, ry: 11, grad: 18), .arm(x: 82, y: 24, rx: 5.5, ry: 11, grad: -18),
                            .stern(x: 30, y: 4.5, r: 4.5, farbe: 0x3A8DFF), .stern(x: 94, y: 28, r: 5, farbe: 0xFFD60A), .stern(x: 6, y: 30, r: 4, farbe: 0xA6E22E)],
                     wangen: true, feiert: true)
        case .ziel:
            LumiPose(gesicht: [.froh(x: 38), .froh(x: 62), .mund(.lachen)],
                     vorn: [.arm(x: 14, y: 46, rx: 6, ry: 9, grad: 40), .arm(x: 86, y: 46, rx: 6, ry: 9, grad: -40), .konfetti, .haken(x: 82, y: 16)],
                     wangen: true, feiert: true)
        case .serie:
            LumiPose(hinten: [.arm(x: 17, y: 68, rx: 6, ry: 8.5, grad: 30)], gesicht: [.auge(x: 38), .froh(x: 62), .brauen(.hochLinks), .mund(.grinsen)],
                     vorn: [.arm(x: 86, y: 54, rx: 6, ry: 8.5, grad: -20), .arm(x: 88, y: 44, rx: 2.6, ry: 4.2, grad: 10), .flamme(x: 14, y: 26)],
                     wangen: true, feiert: true)
        case .erschoepft:
            LumiPose(hinten: [.arm(x: 16, y: 76, rx: 6, ry: 8, grad: 10), .arm(x: 84, y: 76, rx: 6, ry: 8, grad: -10)],
                     gesicht: [.halb(x: 38, blick: -1), .halb(x: 62, blick: -1), .mund(.hecheln)],
                     vorn: [.tropfen(x: 16, y: 40, s: 1), .tropfen(x: 85, y: 34, s: 1.15), .tropfen(x: 90, y: 50, s: 0.8)],
                     hof: 0.5, gestaucht: true)
        case .muede:
            LumiPose(hinten: [.arm(x: 18, y: 72, rx: 6, ry: 8, grad: 20), .arm(x: 82, y: 72, rx: 6, ry: 8, grad: -20)],
                     gesicht: [.halb(x: 38), .halb(x: 62), .augenringe, .mund(.gaehnen)],
                     vorn: [.zz(x: 78, y: 14, s: 1), .zz(x: 90, y: 6, s: 0.65)], hof: 0.5)
        case .schlaeft:
            LumiPose(hinten: [.arm(x: 18, y: 72, rx: 6, ry: 8, grad: 20), .arm(x: 82, y: 72, rx: 6, ry: 8, grad: -20)],
                     gesicht: [.zu(x: 38, dy: 2), .zu(x: 62, dy: 2), .o(dy: 2)],
                     vorn: [.zz(x: 76, y: 18, s: 1), .zz(x: 88, y: 8, s: 0.65)], hof: 0.4)
        case .ruhetag:
            LumiPose(hinten: [.arm(x: 17, y: 70, rx: 6, ry: 8.5, grad: 25)], gesicht: [.zu(x: 38, dy: -1), .zu(x: 62, dy: -1), .mund(.zufrieden)],
                     vorn: [.tasse(x: 80, y: 70), .arm(x: 74, y: 76, rx: 5.5, ry: 8, grad: -60)], wangen: true)
        case .muskelkater:
            LumiPose(hinten: [.arm(x: 84, y: 70, rx: 6, ry: 8.5, grad: -20)], gesicht: [.kneifen(x: 38), .auge(x: 62), .brauen(.traurig), .mund(.zaehne)],
                     vorn: [.pflaster(x: 68, y: 38, grad: 20), .arm(x: 28, y: 78, rx: 5.5, ry: 9, grad: 70), .blitz(x: 88, y: 50), .blitz(x: 84, y: 22)])
        case .vermisst:
            LumiPose(hinten: [.arm(x: 17, y: 72, rx: 6, ry: 8.5, grad: 20)], gesicht: [.augen(ly: -0.5, gross: 1.1), .brauen(.traurig), .mund(.traurig)],
                     vorn: [.arm(x: 84, y: 72, rx: 6, ry: 8.5, grad: -20), .tropfen(x: 70, y: 71, s: 0.65)], hof: 0.6)
        case .denkt:
            LumiPose(hinten: [.arm(x: 17, y: 68, rx: 6, ry: 8.5, grad: 30), .arm(x: 83, y: 68, rx: 6, ry: 8.5, grad: -25)],
                     gesicht: [.augen(lx: 1.5, ly: -2), .brauen(.denk), .mund(.nachdenken)], vorn: [.blasen])
        }
    }
}
