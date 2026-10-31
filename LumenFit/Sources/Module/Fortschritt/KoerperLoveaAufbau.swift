// Quelle: Lovea Health/Koerper/KoerperView.swift (KoerperInhalt :431, Streifen :500, Feld :594, PushKarte :666), KoerperKarte.swift (:3-173)
import SwiftUI
import UIKit

/// Die Körper-Seite im Lovea-Aufbau (`LumenAufbau.lovea`): Streifen, Bilanz, Figur vorne und hinten, Ziel-Karte, "Sätze diese Woche", Nächstes.
/// Alle Daten kommen aus `KoerperDaten` (dieselben wie im Lumen-Aufbau); hier steht nur die Darstellung. Zustand steht nie nur in der Farbe:
/// Muster in der Figur, Wort im Feld, Prozent und Wort in der Liste.
enum KoerperLoveaAbschnitt: Hashable, CaseIterable, Sendable {
    case streifen, figur, zielKarte, felder, naechstes
}

enum KoerperLoveaLogik {
    /// Die Abschnitte in Lovea-Reihenfolge (Lovea `KoerperInhalt` :448-463). In Lumen sind die Ziele nie leer (`KoerperZiele.lesen` hat Standardziele),
    /// deshalb entscheidet die Befragung (`zieleGesetzt`): Ziel-Karte bis sie gemacht ist, "Nächstes" erst danach und nur mit Plan.
    static func abschnitte(zieleGesetzt: Bool, hatNaechstes: Bool) -> [KoerperLoveaAbschnitt] {
        var liste: [KoerperLoveaAbschnitt] = [.streifen, .figur]
        if !zieleGesetzt { liste.append(.zielKarte) }
        liste.append(.felder)
        if zieleGesetzt, hatNaechstes { liste.append(.naechstes) }
        return liste
    }
}

/// Farben der Körper-Seite im Lovea-Aufbau, als Hex (testbar). Felder: Lovea `KoerperFarbe` (:381-386). Figur: Lovea `KartenFarben` (KoerperKarte.swift:16-23),
/// hell und dunkel getrennt gewählt.
enum KoerperLoveaFarbe {
    static func feldHex(_ stufe: ErholungsStufe) -> UInt32 {
        switch stufe {
        case .erholt: 0x30D158
        case .fast: 0xFF7A59
        case .muede: 0xFF3B5C
        }
    }

    static func feld(_ stufe: ErholungsStufe) -> Color { LumenFarben.farbe(feldHex(stufe)) }

    static func figurHex(_ stufe: SilhouetteStufe, dunkel: Bool) -> UInt32 {
        switch (stufe, dunkel) {
        case (.erholt, false): 0x2A9A4A
        case (.fast, false): 0xE4502A
        case (.muede, false): 0xE0284A
        case (.leer, false): 0xC3C3CA
        case (.erholt, true): 0x2FA454
        case (.fast, true): 0xFF7A59
        case (.muede, true): 0xFF3B5C
        case (.leer, true): 0x4A4A50
        }
    }

    static func figur(_ stufe: SilhouetteStufe, dunkel: Bool) -> Color { LumenFarben.farbe(figurHex(stufe, dunkel: dunkel)) }

    /// Kopf, Hände, Füße und die Fugen um die Muskeln.
    static func silhouette(dunkel: Bool) -> Color { LumenFarben.farbe(dunkel ? 0x3A3A3F : 0xD9D9DF) }
}

// MARK: - Seite

struct KoerperLoveaSeite: View {
    let daten: KoerperDaten
    let zieleGesetzt: Bool
    let beiGruppe: (MuskelGruppe, MuskelTeil?) -> Void
    let beiZiele: () -> Void
    let beiTraining: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        let abschnitte = KoerperLoveaLogik.abschnitte(zieleGesetzt: zieleGesetzt, hatNaechstes: daten.naechstes != nil)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(abschnitte, id: \.self) { abschnitt in
                switch abschnitt {
                case .streifen:
                    KoerperLoveaStreifen(woche: daten.streifen)
                    Text(daten.streifen.bilanz)
                        .font(.footnote)
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                case .figur:
                    KoerperLoveaFigurKarte(daten: daten, beiGruppe: beiGruppe).padding(.top, 14)
                case .zielKarte:
                    KoerperLoveaPushKarte(titel: "Ziele festlegen", meta: "Drei Fragen. Danach füllen sich die Felder bis zu deinen eigenen Zielen.",
                                          chips: [], knopf: "Befragung starten", symbol: nil, aktion: beiZiele)
                        .padding(.top, 18)
                case .felder:
                    Text("Sätze diese Woche")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.text)
                        .padding(.top, 22)
                        .padding(.bottom, 10)
                        .accessibilityAddTraits(.isHeader)
                    KoerperLoveaFelder(daten: daten) { beiGruppe($0, nil) }
                case .naechstes:
                    if let n = daten.naechstes {
                        KoerperLoveaPushKarte(titel: n.titel, meta: n.meta, chips: n.chips, knopf: "Training starten", symbol: "play.fill", aktion: beiTraining)
                            .padding(.top, 18)
                    }
                }
            }
        }
    }
}

// MARK: - Wochenstreifen

/// Lovea `Streifen` (:500-591): grüner Kreis mit schwerem Haken = trainiert, Rosé-Ring = heute, grauer Ring und "Beine" oder "Ober" = Plan-Tag, der kommt,
/// gestrichelter Ring = Plan-Tag, der ausfiel, graue Scheibe = Ruhetag. Ohne Punkte je Person (Lumen ist eine Person), ohne Auswahl.
struct KoerperLoveaStreifen: View {
    let woche: KoerperWoche
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(woche.tage, id: \.datum) { tag in
                spalte(tag)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tag.sprechtext)
            }
        }
        .padding(.top, 12)
    }

    private func spalte(_ tag: KoerperWoche.Tag) -> some View {
        VStack(spacing: 5) {
            Text(tag.kuerzel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tag.heute ? palette.text : palette.text2)
            kreis(tag).frame(width: 36, height: 36)
            // Das Wort steht in jeder Spalte (leer als Leerzeichen), damit alle Spalten gleich hoch sind.
            Text(tag.planWort ?? " ")
                .font(.caption2)
                .foregroundStyle(palette.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
    }

    @ViewBuilder private func kreis(_ tag: KoerperWoche.Tag) -> some View {
        switch tag.anzeige {
        case .fertig:
            ZStack {
                Circle().fill(KoerperLoveaFarbe.feld(.erholt))
                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(LumenFarben.farbe(0x062A12))
            }
        case .heute:
            ring(tag, LumenFarben.loveaRose, StrokeStyle(lineWidth: 2), palette.text)
        case .kommt:
            ring(tag, palette.text2.opacity(0.45), StrokeStyle(lineWidth: 1.5), palette.text)
        case .verpasst:
            ring(tag, palette.text2.opacity(0.25), StrokeStyle(lineWidth: 1.5, dash: [3, 3]), palette.text2)
        case .ruhe:
            ZStack {
                Circle().fill(Color(uiColor: .tertiarySystemBackground))
                zahl(tag.nummer, palette.text2)
            }
        }
    }

    private func ring(_ tag: KoerperWoche.Tag, _ farbe: Color, _ strich: StrokeStyle, _ zahlFarbe: Color) -> some View {
        ZStack {
            Circle().strokeBorder(farbe, style: strich)
            zahl(tag.nummer, zahlFarbe)
        }
    }

    private func zahl(_ n: Int, _ farbe: Color) -> some View {
        Text("\(n)").font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(farbe)
    }
}

// MARK: - Figur

/// Eine Seite der Körperkarte in Lovea-Farben, mit dem Muster der Stufe darüber (erholt Punkte, fast erholt Streifen, müde voll, kein Training leer).
/// Die Flächen und der Fingerradius sind die der Lumen-Silhouette (`SilhouetteBild`, `SilhouetteTreffer`).
struct KoerperLoveaFigur: View {
    let seite: SilhouetteSeite
    let daten: KoerperDaten
    var onTipp: ((SilhouetteFlaeche) -> Void)?
    @State private var groesse: CGSize = .zero
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let dunkel = schema == .dark
        let flaechen = SilhouetteBild.flaechen(seite).map { ($0, SilhouetteStufe(daten.stufe(teile: $0.teile))) }
        let koerper = KoerperLoveaFarbe.silhouette(dunkel: dunkel)
        let muster = palette.grund.opacity(0.6)
        Canvas { kontext, groesse in
            let rahmen = CGRect(origin: .zero, size: groesse)
            for form in SilhouetteBild.umriss { kontext.fill(form.pfad(in: rahmen), with: .color(koerper)) }
            for (flaeche, stufe) in flaechen {
                let pfad = flaeche.pfad(in: rahmen)
                kontext.fill(pfad, with: .color(KoerperLoveaFarbe.figur(stufe, dunkel: dunkel)))
                var ausschnitt = kontext
                ausschnitt.clip(to: pfad)
                switch stufe.muster {
                case .punkte: ausschnitt.fill(MusterZeichner.punkte(groesse, raster: 5, radius: 0.9), with: .color(muster))
                case .streifen: ausschnitt.stroke(MusterZeichner.streifen(groesse, winkel: 135, abstand: 4), with: .color(muster), lineWidth: 1)
                case .keins, .voll: break
                }
                kontext.stroke(pfad, with: .color(koerper), lineWidth: 0.75)
            }
        }
        .aspectRatio(SilhouetteBild.breite / SilhouetteBild.hoehe, contentMode: .fit)
        .onGeometryChange(for: CGSize.self, of: \.size) { groesse = $0 }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tipp in
            guard let onTipp, let treffer = SilhouetteTreffer.flaeche(seite, bei: tipp.location, in: CGRect(origin: .zero, size: groesse)) else { return }
            onTipp(treffer)
        })
        .accessibilityHidden(true)
    }
}

/// Ein Quadrat im Farbton und Muster einer Stufe (Lovea `swatch`, KoerperKarte.swift:167), 12 pt.
struct KoerperLoveaProbe: View {
    let stufe: SilhouetteStufe
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let dunkel = schema == .dark
        let farbe = KoerperLoveaFarbe.figur(stufe, dunkel: dunkel)
        let muster = palette.grund.opacity(0.6)
        Canvas { kontext, groesse in
            let pfad = Path(roundedRect: CGRect(origin: .zero, size: groesse), cornerRadius: 3)
            kontext.fill(pfad, with: .color(farbe))
            var ausschnitt = kontext
            ausschnitt.clip(to: pfad)
            switch stufe.muster {
            case .punkte: ausschnitt.fill(MusterZeichner.punkte(groesse, raster: 4, radius: 0.8), with: .color(muster))
            case .streifen: ausschnitt.stroke(MusterZeichner.streifen(groesse, winkel: 135, abstand: 3), with: .color(muster), lineWidth: 1)
            case .keins, .voll: break
            }
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }
}

/// Lovea `KoerperKarte` (KoerperKarte.swift:43-173): vorne und hinten nebeneinander (300 pt hoch), darunter als Liste, was noch nicht erholt ist
/// (48 pt hoch, tippbar), dann je eine Zeile für "Erholt" und "Kein Training erfasst".
struct KoerperLoveaFigurKarte: View {
    let daten: KoerperDaten
    let beiGruppe: (MuskelGruppe, MuskelTeil?) -> Void
    @State private var tipp = 0
    @Environment(\.palette) private var palette

    private var legende: KoerperLegende { KoerperLogik.legende(daten.erholung, reihenfolge: daten.ziele.reihenfolge) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                seite(.vorne)
                seite(.hinten)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Muskelkarte, vorne und hinten")
            .accessibilityValue(legende.sprechtext)
            liste
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.flaeche, in: RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous))
        .haptik(.auswahl, bei: tipp)
    }

    private func seite(_ seite: SilhouetteSeite) -> some View {
        VStack(spacing: 4) {
            KoerperLoveaFigur(seite: seite, daten: daten) { f in
                tipp += 1
                beiGruppe(f.gruppe, KoerperLogik.tippTeil(daten.erholung, gruppe: f.gruppe, flaeche: f.teile))
            }
            .frame(height: 300)
            Text(seite.name).font(.caption2.weight(.semibold)).foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity)
    }

    private var liste: some View {
        let l = legende
        return VStack(alignment: .leading, spacing: 0) {
            if l.keinTraining {
                Text("Noch kein Training erfasst. Im Tab Gym hakst du Sätze ab, dann färbt sich dein Körper.")
                    .font(.subheadline)
                    .foregroundStyle(palette.text2)
            } else {
                if !l.offen.isEmpty {
                    Text("Noch nicht erholt")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.text2)
                        .padding(.bottom, 2)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(l.offen) { zeile($0) }
                }
                if !l.erholt.isEmpty { sammel(.erholt, "Erholt", l.erholt) }
                if !l.leer.isEmpty { sammel(.leer, "Kein Training erfasst", l.leer) }
            }
        }
    }

    private func zeile(_ e: KoerperLegende.Eintrag) -> some View {
        Button {
            tipp += 1
            beiGruppe(e.gruppe, e.teil)
        } label: {
            HStack(spacing: 12) {
                KoerperLoveaProbe(stufe: SilhouetteStufe(e.stufe))
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.name).font(.body).foregroundStyle(palette.text)
                    Text(untertitel(e)).font(.caption).foregroundStyle(palette.text2)
                }
                Spacer(minLength: 8)
                Text("\(e.prozent) %").font(.body.weight(.semibold)).monospacedDigit().fixedSize().foregroundStyle(palette.text)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.text2)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityLabel("\(e.name), \(e.prozent) Prozent, \(e.wort.lowercased())")
        .accessibilityHint("Öffnet die Details")
    }

    /// "müde · zuletzt Mo 13.10.": das Wort trägt die Stufe, Farbe und Muster davor nur die Zuordnung zur Karte.
    private func untertitel(_ e: KoerperLegende.Eintrag) -> String {
        let wort = e.wort.lowercased()
        guard let tag = daten.letzte[e.teil]?.tag else { return wort }
        return "\(wort) · zuletzt \(KoerperLogik.tagKurz(tag))"
    }

    private func sammel(_ stufe: SilhouetteStufe, _ wort: String, _ gruppen: [MuskelGruppe]) -> some View {
        let namen = gruppen.map(\.name).joined(separator: ", ")
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            KoerperLoveaProbe(stufe: stufe)
            Text("\(Text(wort + ": ").fontWeight(.semibold).foregroundStyle(palette.text))\(namen)")
                .font(.footnote)
                .foregroundStyle(palette.text2)
        }
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Felder

/// Die neun Felder (3 x 3, Prio zuerst), Lovea :473-486.
struct KoerperLoveaFelder: View {
    let daten: KoerperDaten
    let beiGruppe: (MuskelGruppe) -> Void

    var body: some View {
        let reihe = daten.ziele.reihenfolge
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { zeile in
                GridRow {
                    ForEach(0..<3, id: \.self) { spalte in
                        let i = zeile * 3 + spalte
                        if i < reihe.count {
                            KoerperLoveaFeld(daten: daten, gruppe: reihe[i], nummer: daten.ziele.prio.firstIndex(of: reihe[i]).map { $0 + 1 }, index: i) {
                                beiGruppe(reihe[i])
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Lovea `Feld` (:594-662): füllt sich in der Erholungsfarbe bis zum Wochenziel (Füllung 20 %, Strich 1,5 pt oben), versetzt `Feder.weich.delay(index * 0.035)`.
/// Mindesthöhe 66 pt wie in Lovea, wächst bei großer Schrift. Das Wort im Feld ("62 %", "erholt", "geschafft", "kein Training") trägt die Stufe.
struct KoerperLoveaFeld: View {
    let daten: KoerperDaten
    let gruppe: MuskelGruppe
    let nummer: Int?
    let index: Int
    let aktion: () -> Void
    @State private var geladen = false
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion

    private var farbe: Color { KoerperLoveaFarbe.feld(daten.stufe(gruppe)) }
    private var ziel: Int? { daten.ziele.saetze[gruppe] }
    private var anteil: Double { SaetzeFelderLogik.anteil(saetze: daten.saetze(gruppe), ziel: ziel) }
    private var label: String {
        let von = ziel.map { " von \($0)" } ?? ""
        return "\(gruppe.name), \(KoerperLogik.komma(daten.saetze(gruppe)))\(von) Sätze, \(daten.wort(gruppe))"
    }

    var body: some View {
        Button(action: aktion) { inhalt }
            .buttonStyle(.federnd)
            .accessibilityLabel(label)
            .accessibilityHint("Öffnet die Details")
            .onAppear { geladen = true }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(gruppe.name).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                if let nummer { Text("\(nummer)").font(.caption2.weight(.semibold)).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(KoerperLogik.komma(daten.saetze(gruppe))).font(.title3.weight(.bold)).monospacedDigit()
                Text(ziel.map { "/\($0)" } ?? " Sätze").font(.caption).foregroundStyle(palette.text2)
                Spacer(minLength: 2)
                Text(daten.wort(gruppe)).font(.caption2).foregroundStyle(palette.text2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .foregroundStyle(palette.text)
        .padding(.init(top: 9, leading: 10, bottom: 8, trailing: 10))
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(alignment: .bottom) { pegel }
        .background(palette.flaeche)
        .clipShape(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous))
    }

    private var pegel: some View {
        GeometryReader { g in
            Rectangle()
                .fill(farbe.opacity(0.2))
                .overlay(alignment: .top) { if anteil > 0 { Rectangle().fill(farbe).frame(height: 1.5) } }
                .frame(height: g.size.height * (geladen || reduceMotion ? anteil : 0))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(reduceMotion ? nil : Feder.weich.delay(SaetzeFelderLogik.verzoegerung(index)), value: geladen)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Push-Karte

/// Lovea `PushKarte` (:666-723): Rosé-Verlauf (20 % nach 5 %), Radialverlauf oben rechts 34 %, Rand Rosé 24 %, schmale schwarze Versalien, heller Knopf.
/// Lovea setzt weißen Text fest; auf der hellen Kartenfläche des Systems wäre der unlesbar, deshalb folgt der Text im hellen Modus `palette.text`
/// (dunkel bleibt wie in Lovea).
struct KoerperLoveaPushKarte: View {
    let titel: String
    let meta: String
    let chips: [String]
    let knopf: String
    let symbol: String?
    let aktion: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    private var dunkel: Bool { schema == .dark }
    private var form: RoundedRectangle { RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titel)
                .font(.system(size: 44, weight: .black, design: .default).width(.compressed))
                .textCase(.uppercase)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Text(meta)
                .font(.footnote)
                .foregroundStyle(dunkel ? LumenFarben.farbe(0xFFD3DB) : palette.text2)
                .padding(.top, 6)
            if !chips.isEmpty {
                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        HStack(spacing: 6) {
                            Circle().fill(LumenFarben.loveaRose).frame(width: 7, height: 7).accessibilityHidden(true)
                            Text(chip).font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(palette.text.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.top, 12)
            }
            Button(action: aktion) {
                HStack(spacing: 8) {
                    if let symbol { Image(systemName: symbol).font(.system(size: 14)).accessibilityHidden(true) }
                    Text(knopf).font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(dunkel ? Color(white: 0.07) : palette.grund)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(dunkel ? Color(white: 0.96) : palette.text, in: Capsule())
            }
            .buttonStyle(.federnd)
            .padding(.top, 14)
        }
        .padding(.init(top: 16, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(palette.text)
        .background { hintergrund }
        .clipShape(form)
        .overlay { form.strokeBorder(LumenFarben.loveaRose.opacity(0.24), lineWidth: 1) }
    }

    private var hintergrund: some View {
        ZStack {
            palette.flaeche
            LinearGradient(colors: [LumenFarben.loveaRose.opacity(0.2), LumenFarben.loveaRose.opacity(0.05)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [LumenFarben.loveaRose.opacity(0.34), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
        }
    }
}
