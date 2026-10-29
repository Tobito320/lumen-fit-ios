import SwiftUI

/// Kleiner Leser für SVG-Pfaddaten (M, L, C, Q, Z, groß und klein, mehrere Zahlengruppen je Befehl), damit die Lumi-Vorlagen
/// (`docs/research/lumi/*.svg`) unverändert als Text in den Quelltext wandern. Unbekannte Befehle brechen den Pfad ab (leerer Rest).
enum SVGPfad {
    nonisolated static func pfad(_ daten: String) -> Path {
        var pfad = Path()
        var befehl: Character = "M"
        var zahlen: [CGFloat] = []
        var aktuell = CGPoint.zero
        var anfang = CGPoint.zero

        func verbrauche(_ n: Int) -> [CGFloat]? {
            guard zahlen.count >= n else { return nil }
            let teil = Array(zahlen.prefix(n))
            zahlen.removeFirst(n)
            return teil
        }

        func ausfuehren() {
            let relativ = befehl.isLowercase
            let basis = relativ ? aktuell : .zero
            switch befehl.uppercased().first ?? "Z" {
            case "M":
                guard let p = verbrauche(2) else { return }
                aktuell = CGPoint(x: basis.x + p[0], y: basis.y + p[1]); anfang = aktuell
                pfad.move(to: aktuell)
                befehl = relativ ? "l" : "L"        // weitere Paare nach M sind Linien
                ausfuehren()
            case "L":
                while let p = verbrauche(2) { aktuell = CGPoint(x: (relativ ? aktuell.x : 0) + p[0], y: (relativ ? aktuell.y : 0) + p[1]); pfad.addLine(to: aktuell) }
            case "C":
                while let p = verbrauche(6) {
                    let b = relativ ? aktuell : .zero
                    let ziel = CGPoint(x: b.x + p[4], y: b.y + p[5])
                    pfad.addCurve(to: ziel, control1: CGPoint(x: b.x + p[0], y: b.y + p[1]), control2: CGPoint(x: b.x + p[2], y: b.y + p[3]))
                    aktuell = ziel
                }
            case "Q":
                while let p = verbrauche(4) {
                    let b = relativ ? aktuell : .zero
                    let ziel = CGPoint(x: b.x + p[2], y: b.y + p[3])
                    pfad.addQuadCurve(to: ziel, control: CGPoint(x: b.x + p[0], y: b.y + p[1]))
                    aktuell = ziel
                }
            case "Z":
                pfad.closeSubpath(); aktuell = anfang
            default:
                zahlen.removeAll()
            }
        }

        var zahl = ""
        func zahlAbschliessen() {
            if let w = Double(zahl) { zahlen.append(CGFloat(w)) }
            zahl = ""
        }

        for zeichen in daten {
            if zeichen.isLetter && zeichen != "e" {
                zahlAbschliessen(); ausfuehren(); zahlen.removeAll(); befehl = zeichen
                if zeichen == "z" || zeichen == "Z" { ausfuehren() }
            } else if zeichen == "-" {
                zahlAbschliessen(); zahl = "-"
            } else if zeichen == " " || zeichen == "," || zeichen == "\n" {
                zahlAbschliessen()
            } else if zeichen == ".", zahl.contains(".") {
                zahlAbschliessen(); zahl = "."
            } else {
                zahl.append(zeichen)
            }
        }
        zahlAbschliessen(); ausfuehren()
        return pfad
    }
}
