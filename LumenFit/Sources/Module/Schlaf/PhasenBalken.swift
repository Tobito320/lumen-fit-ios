import SwiftUI

/// Das Muster je Schlafphase: Tief ist voll, Kern senkrecht gestreift, REM schräg gestreift, Wach gepunktet, "Schlaf" (nur Dauer) flach hell.
/// Jede Phase hat Muster und Beschriftung, nie nur Farbe.
enum SchlafPhasenZeichner {
    /// `voll`: "Schlaf" ohne Phasen in voller Farbe (der Zeitbalken der Nächte nur mit iPhone braucht mindestens 3:1 zum Grund).
    nonisolated static func fuelle(_ phase: SchlafPhase, rect: CGRect, linie: Color, grund: Color, voll: Bool = false, in kontext: inout GraphicsContext) {
        guard rect.width > 0, rect.height > 0 else { return }
        let flaeche = Path(rect)
        switch phase {
        case .tief:
            kontext.fill(flaeche, with: .color(linie))
        case .kern:
            kontext.fill(flaeche, with: .color(linie.opacity(0.3)))
            muster(MusterZeichner.streifen(rect.size, winkel: 0, abstand: 4), rect: rect, linie: linie, breite: 2, in: &kontext)
        case .rem:
            kontext.fill(flaeche, with: .color(linie.opacity(0.3)))
            muster(MusterZeichner.streifen(rect.size, winkel: 45, abstand: 5), rect: rect, linie: linie, breite: 2, in: &kontext)
        case .wach:
            kontext.fill(flaeche, with: .color(grund))
            kontext.drawLayer { ebene in
                ebene.clip(to: flaeche)
                ebene.translateBy(x: rect.minX, y: rect.minY)
                ebene.fill(MusterZeichner.punkte(rect.size, raster: 5, radius: 1.1), with: .color(linie))
            }
        case .unbestimmt:
            kontext.fill(flaeche, with: .color(voll ? linie : linie.opacity(0.45)))
        }
    }

    private nonisolated static func muster(_ pfad: Path, rect: CGRect, linie: Color, breite: CGFloat, in kontext: inout GraphicsContext) {
        kontext.drawLayer { ebene in
            ebene.clip(to: Path(rect))
            ebene.translateBy(x: rect.minX, y: rect.minY)
            ebene.stroke(pfad, with: .color(linie), lineWidth: breite)
        }
    }

    /// Die Dauer der Phase und ihr Anteil am Schlaf in Prozent, für Legende und VoiceOver.
    static func anteil(_ minuten: Int, von gesamt: Int) -> Int {
        gesamt > 0 ? Int((Double(minuten) / Double(gesamt) * 100).rounded()) : 0
    }
}

private struct SchlafPhasenTeil: Identifiable {
    let phase: SchlafPhase
    let minuten: Int
    var id: Int { phase.rawValue }
}

/// Eine Legendenzeile: Muster-Feld plus Name, Dauer und Anteil.
private struct SchlafPhasenLegende: View {
    let phase: SchlafPhase
    let minuten: Int
    let anteil: Int?
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        let linie = LumenFarben.tief(.erholen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let grund = palette.flaeche
        HStack(spacing: Abstand.s) {
            Canvas { kontext, groesse in
                SchlafPhasenZeichner.fuelle(phase, rect: CGRect(origin: .zero, size: groesse), linie: linie, grund: grund, in: &kontext)
            }
            .frame(width: 22, height: 14)
            .clipShape(.rect(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(linie, lineWidth: 1))
            .accessibilityHidden(true)
            Text(phase.name).font(.footnote.weight(.semibold))
            Text(SchlafFormat.dauer(minuten)).font(.footnote).monospacedDigit().foregroundStyle(palette.text2)
            if let anteil { Text("\(anteil) %").font(.footnote).monospacedDigit().foregroundStyle(palette.text2) }
        }
        .foregroundStyle(palette.text)
        .frame(minHeight: 24)
    }
}

/// Idee 52, Phasen-Balken: Tief, Kern, REM und Wach als Teile der Nacht mit Muster und Beschriftung.
/// Ohne Phasen (nur iPhone) wird daraus ein einfacher Zeitbalken mit dem Satz "Phasen kennt nur eine Uhr oder das Band".
/// Der Balken ist kein Swift-Charts-Diagramm, sondern eine gezeichnete Fläche: VoiceOver liest die Kernzeile mit den Minuten je Phase.
struct PhasenBalken: View {
    let nacht: SchlafNacht
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    private var hatPhasen: Bool { SchlafQuellenWahl.hatPhasen(nacht) }

    /// Phasen, die vorkommen, mit Minuten.
    private var teile: [SchlafPhasenTeil] {
        nacht.phasen.map { SchlafPhasenTeil(phase: $0, minuten: nacht.minuten($0)) }.filter { $0.minuten > 0 }
    }

    /// "Tief 1 h 20 min, Kern 3 h 50 min, REM 1 h 30 min"; ohne Phasen die Dauer.
    var kernzeile: String {
        guard hatPhasen else { return String(localized: "Geschlafen \(SchlafFormat.dauer(nacht.schlafMinuten)). Phasen kennt nur eine Uhr oder das Band.") }
        return teile.map { "\($0.phase.name) \(SchlafFormat.dauer($0.minuten))" }.joined(separator: ", ")
    }

    var body: some View {
        let linie = LumenFarben.tief(.erholen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let grund = palette.flaeche
        let von = nacht.von
        let spanne = max(nacht.bis.timeIntervalSince(nacht.von), 1)
        let abschnitte = nacht.abschnitte
        let voll = !hatPhasen
        VStack(alignment: .leading, spacing: Abstand.s) {
            Canvas { kontext, groesse in
                // Lücken zwischen Abschnitten sind Wachzeit und bleiben leer (Grund).
                for a in abschnitte {
                    let x0 = groesse.width * a.von.timeIntervalSince(von) / spanne
                    let x1 = groesse.width * a.bis.timeIntervalSince(von) / spanne
                    let rect = CGRect(x: x0, y: 0, width: max(x1 - x0 - 1, 1), height: groesse.height)
                    SchlafPhasenZeichner.fuelle(a.phase, rect: rect, linie: linie, grund: grund, voll: voll, in: &kontext)
                }
            }
            .frame(height: 32)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(linie, lineWidth: 1))
            .accessibilityHidden(true)
            HStack {
                Text(Datum.uhrzeit(nacht.von))
                Spacer(minLength: Abstand.s)
                Text(Datum.uhrzeit(nacht.bis))
            }
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(palette.text2)
            .accessibilityHidden(true)
            if hatPhasen {
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    ForEach(teile) { teil in
                        SchlafPhasenLegende(phase: teil.phase, minuten: teil.minuten,
                                            anteil: SchlafPhasenZeichner.anteil(teil.minuten, von: nacht.schlafMinuten + nacht.minuten(.wach)))
                    }
                }
                .accessibilityHidden(true)
            } else {
                Label("Phasen kennt nur eine Uhr oder das Band.", systemImage: "applewatch")
                    .font(.footnote)
                    .foregroundStyle(palette.text2)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hatPhasen ? String(localized: "Schlafphasen von \(Datum.uhrzeit(nacht.von)) bis \(Datum.uhrzeit(nacht.bis)). \(kernzeile)") : kernzeile)
        .accessibilityChartDescriptor(SchlafDiagrammBeschreibung(
            titel: String(localized: "Schlafphasen"), zusammenfassung: kernzeile, achseX: String(localized: "Phase"), reihe: String(localized: "Minuten je Phase"),
            punkte: teile.map { SchlafDiagrammBeschreibung.Punkt(name: $0.phase.name, minuten: Double($0.minuten)) }))
    }
}
