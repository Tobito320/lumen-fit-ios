import SwiftUI

/// Die gezeichnete Körperkarte einer Seite. Jede Stufe hat ein eigenes Muster: erholt Punkte, fast erholt Streifen, müde ausgefüllt, kein Training nur Umriss.
/// Für VoiceOver verborgen: die Liste daneben sagt dasselbe in Worten.
struct SilhouetteAnsicht: View {
    let seite: SilhouetteSeite
    let daten: KoerperDaten
    @Environment(\.palette) private var palette

    var body: some View {
        let flaechen = SilhouetteBild.flaechen(seite).map { ($0, SilhouetteStufe(daten.stufe(teile: $0.teile))) }
        let text = palette.text, rand = palette.text2, umriss = palette.haar
        Canvas { kontext, groesse in
            let rahmen = CGRect(origin: .zero, size: groesse)
            for form in SilhouetteBild.umriss { kontext.fill(form.pfad(in: rahmen), with: .color(umriss)) }
            for (flaeche, stufe) in flaechen {
                let pfad = flaeche.pfad(in: rahmen)
                if stufe.deckkraft > 0 { kontext.fill(pfad, with: .color(text.opacity(stufe.deckkraft))) }
                var ausschnitt = kontext
                ausschnitt.clip(to: pfad)
                switch stufe.muster {
                case .punkte: ausschnitt.fill(MusterZeichner.punkte(groesse, raster: 5, radius: 0.9), with: .color(text.opacity(0.75)))
                case .streifen: ausschnitt.stroke(MusterZeichner.streifen(groesse, winkel: 135, abstand: 4), with: .color(text.opacity(0.75)), lineWidth: 1)
                case .keins, .voll: break
                }
                kontext.stroke(pfad, with: .color(rand), lineWidth: stufe == .leer ? 0.75 : 1)
            }
        }
        .aspectRatio(SilhouetteBild.breite / SilhouetteBild.hoehe, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Idee 33: Erholung je Muskel. Links die Karte (vorne oder hinten), rechts die Liste mit Prozent und Wort; bei großer Schrift untereinander.
struct SilhouetteKarte: View {
    let daten: KoerperDaten
    @State private var seite = SilhouetteSeite.vorne
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var schriftgroesse

    var body: some View {
        let zeilen = SilhouetteZeile.zeilen(daten, reihenfolge: daten.ziele.reihenfolge)
        let legende = KoerperLogik.legende(daten.erholung, reihenfolge: daten.ziele.reihenfolge)
        DiagrammKarte(aussage: aussage(zeilen), kernzeile: legende.keinTraining ? "Noch kein Training erfasst. Tipp auf Starten, Lumi zählt mit." : "Prozent: so erholt ist der müdeste Teil der Gruppe.") {
            VStack(alignment: .leading, spacing: Abstand.m) {
                Picker("Seite", selection: $seite) {
                    ForEach(SilhouetteSeite.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                let layout = schriftgroesse.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Abstand.m)) : AnyLayout(HStackLayout(alignment: .top, spacing: Abstand.l))
                layout {
                    SilhouetteAnsicht(seite: seite, daten: daten)
                        .frame(width: 120)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(zeilen) { zeile in
                            zeilenAnsicht(zeile)
                            if zeile.id != zeilen.last?.id { Haarlinie() }
                        }
                    }
                }
                legendeAnsicht
            }
        }
    }

    private func aussage(_ zeilen: [SilhouetteZeile]) -> String {
        guard let muedeste = zeilen.first, muedeste.stufe == .muede || muedeste.stufe == .fast else {
            return zeilen.contains { $0.stufe != .leer } ? "Alle trainierten Muskeln sind erholt" : "Noch kein Muskel trainiert"
        }
        return "\(muedeste.gruppe.name) ist erst zu \(muedeste.prozent) Prozent erholt"
    }

    private func zeilenAnsicht(_ z: SilhouetteZeile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(z.gruppe.name).font(.subheadline.weight(.semibold))
                Spacer(minLength: Abstand.s)
                Text("\(z.prozent) %").font(.subheadline.weight(.bold)).fontDesign(.rounded).monospacedDigit()
            }
            Text(z.stufe.wort).font(.caption).foregroundStyle(palette.text2)
            if let teil = z.teilText { Text(teil).font(.caption).foregroundStyle(palette.text2) }
            if let letztes = z.letztes { Text(letztes).font(.caption).foregroundStyle(palette.text2) }
        }
        .foregroundStyle(palette.text)
        .padding(.vertical, Abstand.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(z.sprechtext)
    }

    /// Die vier Muster mit ihren Wörtern, damit die Karte ohne Farbe lesbar ist.
    private var legendeAnsicht: some View {
        HStack(spacing: Abstand.m) {
            ForEach([SilhouetteStufe.muede, .fast, .erholt, .leer], id: \.self) { stufe in
                HStack(spacing: Abstand.xs) {
                    SilhouetteProbe(stufe: stufe).frame(width: 14, height: 14)
                    Text(stufe.wort).font(.caption2).foregroundStyle(palette.text2).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Ein kleines Quadrat im Muster einer Stufe (für die Legende).
private struct SilhouetteProbe: View {
    let stufe: SilhouetteStufe
    @Environment(\.palette) private var palette

    var body: some View {
        let text = palette.text, rand = palette.text2
        Canvas { kontext, groesse in
            let pfad = Path(roundedRect: CGRect(origin: .zero, size: groesse), cornerRadius: 3)
            if stufe.deckkraft > 0 { kontext.fill(pfad, with: .color(text.opacity(stufe.deckkraft))) }
            var ausschnitt = kontext
            ausschnitt.clip(to: pfad)
            switch stufe.muster {
            case .punkte: ausschnitt.fill(MusterZeichner.punkte(groesse, raster: 4, radius: 0.8), with: .color(text.opacity(0.75)))
            case .streifen: ausschnitt.stroke(MusterZeichner.streifen(groesse, winkel: 135, abstand: 3), with: .color(text.opacity(0.75)), lineWidth: 1)
            case .keins, .voll: break
            }
            kontext.stroke(pfad, with: .color(rand), lineWidth: 1)
        }
    }
}
