import SwiftUI

/// Die Körperkarte, selbst aus einfachen Formen gebaut (Ellipsen, Rundrechtecke, Vielecke) in einem Raum von 100 x 200.
/// Keine Daten aus `muskelkarte.json` (openGym, AGPL-3.0): Form und Lage sind hier gezeichnet, nicht abgeleitet (SPEC 5.8 Punkt 5, Annahme 13).
enum SilhouetteSeite: String, CaseIterable, Sendable {
    case vorne, hinten

    var name: String { self == .vorne ? "Vorne" : "Hinten" }
}

/// Eine Grundform im Raum 100 x 200.
enum SilhouetteForm: Sendable {
    case ellipse(CGRect)
    case rund(CGRect, radius: CGFloat)
    case vieleck([CGPoint])

    /// Dieselbe Form an der senkrechten Mitte (x = 50) gespiegelt.
    var gespiegelt: SilhouetteForm {
        func spiegel(_ r: CGRect) -> CGRect { CGRect(x: SilhouetteBild.breite - r.maxX, y: r.minY, width: r.width, height: r.height) }
        switch self {
        case .ellipse(let r): return .ellipse(spiegel(r))
        case .rund(let r, let radius): return .rund(spiegel(r), radius: radius)
        case .vieleck(let punkte): return .vieleck(punkte.map { CGPoint(x: SilhouetteBild.breite - $0.x, y: $0.y) })
        }
    }

    /// Der Pfad im Rechteck `rahmen`: der Raum 100 x 200 wird eingepasst, das Seitenverhältnis bleibt.
    func pfad(in rahmen: CGRect) -> Path {
        let faktor = min(rahmen.width / SilhouetteBild.breite, rahmen.height / SilhouetteBild.hoehe)
        let ox = rahmen.minX + (rahmen.width - SilhouetteBild.breite * faktor) / 2
        let oy = rahmen.minY + (rahmen.height - SilhouetteBild.hoehe * faktor) / 2
        func rect(_ r: CGRect) -> CGRect { CGRect(x: ox + r.minX * faktor, y: oy + r.minY * faktor, width: r.width * faktor, height: r.height * faktor) }
        switch self {
        case .ellipse(let r): return Path(ellipseIn: rect(r))
        case .rund(let r, let radius): return Path(roundedRect: rect(r), cornerRadius: radius * faktor)
        case .vieleck(let punkte):
            var pfad = Path()
            guard let erster = punkte.first else { return pfad }
            pfad.move(to: CGPoint(x: ox + erster.x * faktor, y: oy + erster.y * faktor))
            for p in punkte.dropFirst() { pfad.addLine(to: CGPoint(x: ox + p.x * faktor, y: oy + p.y * faktor)) }
            pfad.closeSubpath()
            return pfad
        }
    }
}

/// Eine antippbare und einfärbbare Fläche der Karte: ihre Teile liegen alle in einer Gruppe.
struct SilhouetteFlaeche: Identifiable, Sendable {
    let id: String
    let gruppe: MuskelGruppe
    let teile: [MuskelTeil]
    let seite: SilhouetteSeite
    let formen: [SilhouetteForm]

    func pfad(in rahmen: CGRect) -> Path {
        var pfad = Path()
        for f in formen { pfad.addPath(f.pfad(in: rahmen)) }
        return pfad
    }
}

/// Die Körperkarte vorne und hinten. Die Umrisse (Kopf, Rumpf, Arme, Beine) stehen als stille Formen darunter.
enum SilhouetteBild {
    nonisolated static let breite: CGFloat = 100
    nonisolated static let hoehe: CGFloat = 200

    /// Stille Umrisse: Kopf, Hals, Rumpf, Arme, Hände, Beine, Füße.
    static let umriss: [SilhouetteForm] = {
        let mitte: [SilhouetteForm] = [
            .ellipse(CGRect(x: 40, y: 4, width: 20, height: 24)),                 // Kopf
            .rund(CGRect(x: 45, y: 26, width: 10, height: 12), radius: 3),        // Hals
            .rund(CGRect(x: 36, y: 36, width: 28, height: 58), radius: 8),        // Rumpf
        ]
        let links: [SilhouetteForm] = [
            .rund(CGRect(x: 14, y: 40, width: 12, height: 72), radius: 6),        // Arm
            .ellipse(CGRect(x: 11, y: 110, width: 12, height: 12)),               // Hand
            .rund(CGRect(x: 33, y: 92, width: 16, height: 98), radius: 8),        // Bein
            .ellipse(CGRect(x: 32, y: 188, width: 18, height: 9)),                // Fuß
        ]
        let rechts: [SilhouetteForm] = links.map { $0.gespiegelt }
        return mitte + links + rechts
    }()

    static func flaechen(_ seite: SilhouetteSeite) -> [SilhouetteFlaeche] { seite == .vorne ? vorne : hinten }

    static var alle: [SilhouetteFlaeche] { vorne + hinten }

    /// Links gezeichnet, rechts gespiegelt.
    private static func paar(_ f: SilhouetteForm) -> [SilhouetteForm] { [f, f.gespiegelt] }

    private static func flaeche(_ id: String, _ gruppe: MuskelGruppe, _ teile: [MuskelTeil], _ seite: SilhouetteSeite, _ formen: [SilhouetteForm]) -> SilhouetteFlaeche {
        SilhouetteFlaeche(id: "\(seite.rawValue)-\(id)", gruppe: gruppe, teile: teile, seite: seite, formen: formen)
    }

    static let vorne: [SilhouetteFlaeche] = [
        flaeche("nacken", .nacken, [.nVorne], .vorne, [.rund(CGRect(x: 44, y: 27, width: 12, height: 10), radius: 3)]),
        flaeche("schulter", .schulter, [.sVorne, .sSeitlich], .vorne, paar(.ellipse(CGRect(x: 21, y: 37, width: 15, height: 17)))),
        flaeche("brust-oben", .brust, [.bOben], .vorne, [.rund(CGRect(x: 37, y: 38, width: 26, height: 9), radius: 4)]),
        flaeche("brust-unten", .brust, [.bUnten], .vorne, [.rund(CGRect(x: 37, y: 48, width: 26, height: 13), radius: 5)]),
        flaeche("bizeps", .bizeps, [.biLang, .biKurz], .vorne, paar(.rund(CGRect(x: 15, y: 55, width: 11, height: 24), radius: 5))),
        flaeche("unterarm", .unterarme, [.uBeuger, .uSpeiche], .vorne, paar(.rund(CGRect(x: 13, y: 81, width: 10, height: 28), radius: 5))),
        flaeche("bauch", .bauch, [.baGerade], .vorne, [.rund(CGRect(x: 43, y: 64, width: 14, height: 28), radius: 4)]),
        flaeche("bauch-schraeg", .bauch, [.baSeitlich], .vorne, paar(.rund(CGRect(x: 36, y: 64, width: 6, height: 26), radius: 3))),
        flaeche("quadrizeps", .beine, [.beQuads], .vorne, paar(.rund(CGRect(x: 34, y: 104, width: 14, height: 42), radius: 6))),
        flaeche("adduktoren", .beine, [.beAdd], .vorne, [.rund(CGRect(x: 47, y: 106, width: 6, height: 28), radius: 3)]),
        flaeche("waden", .beine, [.beWaden], .vorne, paar(.rund(CGRect(x: 35, y: 152, width: 11, height: 34), radius: 5))),
    ]

    static let hinten: [SilhouetteFlaeche] = [
        flaeche("nacken", .nacken, [.nHinten], .hinten, [.rund(CGRect(x: 44, y: 27, width: 12, height: 10), radius: 3)]),
        flaeche("trapez-oben", .ruecken, [.rTrapezOben], .hinten,
                [.vieleck([CGPoint(x: 44, y: 36), CGPoint(x: 56, y: 36), CGPoint(x: 66, y: 43), CGPoint(x: 50, y: 56), CGPoint(x: 34, y: 43)])]),
        flaeche("schulter", .schulter, [.sHinten], .hinten, paar(.ellipse(CGRect(x: 21, y: 37, width: 15, height: 17)))),
        flaeche("ruecken-oben", .ruecken, [.rOben], .hinten, [.rund(CGRect(x: 38, y: 57, width: 24, height: 9), radius: 4)]),
        flaeche("trapez-unten", .ruecken, [.rTrapezUnten], .hinten, [.rund(CGRect(x: 44, y: 67, width: 12, height: 10), radius: 3)]),
        flaeche("latissimus", .ruecken, [.rLat], .hinten, paar(.vieleck([CGPoint(x: 37, y: 58), CGPoint(x: 37, y: 84), CGPoint(x: 29, y: 82), CGPoint(x: 28, y: 62)]))),
        flaeche("ruecken-unten", .ruecken, [.rUnten], .hinten, [.rund(CGRect(x: 40, y: 78, width: 20, height: 14), radius: 4)]),
        flaeche("trizeps", .trizeps, [.triLang, .triSeitlich, .triMittel], .hinten, paar(.rund(CGRect(x: 15, y: 55, width: 11, height: 24), radius: 5))),
        flaeche("unterarm", .unterarme, [.uStrecker], .hinten, paar(.rund(CGRect(x: 13, y: 81, width: 10, height: 28), radius: 5))),
        flaeche("po", .beine, [.bePo], .hinten, paar(.ellipse(CGRect(x: 35, y: 93, width: 15, height: 17)))),
        flaeche("beinbeuger", .beine, [.beBeuger], .hinten, paar(.rund(CGRect(x: 34, y: 112, width: 14, height: 36), radius: 6))),
        flaeche("waden", .beine, [.beWaden], .hinten, paar(.rund(CGRect(x: 35, y: 152, width: 11, height: 34), radius: 5))),
    ]
}

/// Wie eine Fläche aussieht: Deckkraft und Muster je Stufe. Die Stufe steht nie allein in der Farbe, jede hat ein eigenes Muster.
enum SilhouetteStufe: CaseIterable, Sendable {
    case leer, erholt, fast, muede

    enum Muster: Sendable { case keins, punkte, streifen, voll }

    var deckkraft: Double {
        switch self {
        case .leer: 0.0
        case .erholt: 0.16
        case .fast: 0.30
        case .muede: 0.80
        }
    }

    var muster: Muster {
        switch self {
        case .leer: .keins
        case .erholt: .punkte
        case .fast: .streifen
        case .muede: .voll
        }
    }

    /// Das Wort in der Liste und für VoiceOver.
    var wort: String {
        switch self {
        case .leer: "Kein Training"
        case .erholt: "Erholt"
        case .fast: "Fast erholt"
        case .muede: "Müde"
        }
    }

    init(_ stufe: ErholungsStufe?) {
        switch stufe {
        case .none: self = .leer
        case .erholt?: self = .erholt
        case .fast?: self = .fast
        case .muede?: self = .muede
        }
    }
}
