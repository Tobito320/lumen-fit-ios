import SwiftUI

/// Die gezeichnete Körperkarte einer Seite. Jede Stufe hat ein eigenes Muster: erholt Punkte, fast erholt Streifen, müde ausgefüllt, kein Training nur Umriss.
/// Für VoiceOver verborgen: die Liste daneben sagt dasselbe in Worten. Mit `onTipp` ist die Karte antippbar (Fingerradius 12 pt, `SilhouetteTreffer`);
/// `fokus` zeigt nur eine Gruppe gefüllt, die anderen bleiben Umriss (Kopf des Blatts).
struct SilhouetteAnsicht: View {
    let seite: SilhouetteSeite
    let daten: KoerperDaten
    var fokus: MuskelGruppe?
    var onTipp: ((SilhouetteFlaeche) -> Void)?
    @State private var groesse: CGSize = .zero
    @Environment(\.palette) private var palette

    var body: some View {
        let flaechen = SilhouetteBild.flaechen(seite).map { ($0, SilhouetteStufe(daten.stufe(teile: $0.teile))) }
        let text = palette.text, rand = palette.text2, umriss = palette.haar
        let fokus = self.fokus
        Canvas { kontext, groesse in
            let rahmen = CGRect(origin: .zero, size: groesse)
            for form in SilhouetteBild.umriss { kontext.fill(form.pfad(in: rahmen), with: .color(umriss)) }
            for (flaeche, stufe) in flaechen {
                let pfad = flaeche.pfad(in: rahmen)
                if let fokus, flaeche.gruppe != fokus {
                    kontext.stroke(pfad, with: .color(rand.opacity(0.4)), lineWidth: 0.75)
                    continue
                }
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
        .onGeometryChange(for: CGSize.self, of: \.size) { groesse = $0 }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tipp in
            guard let onTipp, let treffer = SilhouetteTreffer.flaeche(seite, bei: tipp.location, in: CGRect(origin: .zero, size: groesse)) else { return }
            onTipp(treffer)
        })
        .accessibilityHidden(true)
    }
}

/// Idee 33: Erholung je Muskel. Links die Karte (vorne oder hinten, antippbar), rechts die Legende in drei Gruppen: noch nicht erholt (jeder Teil unter 90 %
/// einzeln), erholt, kein Training erfasst. Jede Zeile öffnet das Blatt der Gruppe (`beiGruppe`). Bei großer Schrift untereinander.
struct SilhouetteKarte: View {
    let daten: KoerperDaten
    var beiGruppe: (MuskelGruppe, MuskelTeil?) -> Void = { _, _ in }
    @State private var seite = SilhouetteSeite.vorne
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var schriftgroesse

    var body: some View {
        let zeilen = SilhouetteZeile.zeilen(daten, reihenfolge: daten.ziele.reihenfolge)
        let legende = KoerperLogik.legende(daten.erholung, reihenfolge: daten.ziele.reihenfolge)
        DiagrammKarte(aussage: aussage(zeilen), kernzeile: legende.keinTraining ? String(localized: "Noch kein Training erfasst. Tipp auf Starten, Lumi zählt mit.") : String(localized: "Prozent: so erholt ist der müdeste Teil der Gruppe.")) {
            VStack(alignment: .leading, spacing: Abstand.m) {
                Picker("Seite", selection: $seite) {
                    ForEach(SilhouetteSeite.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .haptik(.auswahl, bei: seite)
                let layout = schriftgroesse.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Abstand.m)) : AnyLayout(HStackLayout(alignment: .top, spacing: Abstand.l))
                layout {
                    SilhouetteAnsicht(seite: seite, daten: daten) { f in
                        beiGruppe(f.gruppe, KoerperLogik.tippTeil(daten.erholung, gruppe: f.gruppe, flaeche: f.teile))
                    }
                    .frame(width: 120)
                    .accessibilityHidden(true)
                    legendeListe(legende)
                }
                legendeAnsicht
            }
        }
    }

    private func aussage(_ zeilen: [SilhouetteZeile]) -> String {
        guard let muedeste = zeilen.first, muedeste.stufe == .muede || muedeste.stufe == .fast else {
            return zeilen.contains { $0.stufe != .leer } ? String(localized: "Alle trainierten Muskeln sind erholt") : String(localized: "Noch kein Muskel trainiert")
        }
        return String(localized: "\(muedeste.gruppe.name) ist erst zu \(muedeste.prozent) Prozent erholt")
    }

    // MARK: Legende in drei Gruppen

    @ViewBuilder private func legendeListe(_ l: KoerperLegende) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if l.keinTraining {
                Text("Noch kein Training erfasst. Im Tab Training hakst du Sätze ab, dann zeigt die Karte deine Erholung.")
                    .font(.subheadline).foregroundStyle(palette.text2)
            } else {
                if !l.offen.isEmpty {
                    kopf(String(localized: "Noch nicht erholt"))
                    ForEach(l.offen) { e in
                        zeile(name: e.name, stufe: SilhouetteStufe(e.stufe), prozent: e.prozent, detail: untertitel(e),
                              sprech: String(localized: "\(e.name), \(e.prozent) Prozent, \(e.wort.lowercased())")) { beiGruppe(e.gruppe, e.teil) }
                    }
                }
                if !l.erholt.isEmpty {
                    kopf(String(localized: "Erholt"))
                    ForEach(l.erholt, id: \.self) { g in
                        zeile(name: g.name, stufe: .erholt, prozent: nil, detail: nil, sprech: String(localized: "\(g.name), erholt")) { beiGruppe(g, nil) }
                    }
                }
                if !l.leer.isEmpty {
                    kopf(String(localized: "Kein Training erfasst"))
                    ForEach(l.leer, id: \.self) { g in
                        zeile(name: g.name, stufe: .leer, prozent: nil, detail: nil, sprech: String(localized: "\(g.name), kein Training erfasst")) { beiGruppe(g, nil) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kopf(_ titel: String) -> some View {
        Text(titel)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.text2)
            .padding(.top, Abstand.s)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }

    /// "müde · zuletzt Mo 13.10.": das Wort trägt die Stufe, das Muster davor nur die Zuordnung zur Karte.
    private func untertitel(_ e: KoerperLegende.Eintrag) -> String {
        let wort = e.wort.lowercased()
        guard let tag = daten.letzte[e.teil]?.tag else { return wort }
        return String(localized: "\(wort) · zuletzt \(KoerperLogik.tagKurz(tag))")
    }

    private func zeile(name: String, stufe: SilhouetteStufe, prozent: Int?, detail: String?, sprech: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: Abstand.m) {
                SilhouetteProbe(stufe: stufe).frame(width: 14, height: 14).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.subheadline.weight(.semibold))
                    if let detail { Text(detail).font(.caption).foregroundStyle(palette.text2) }
                }
                Spacer(minLength: Abstand.s)
                if let prozent {
                    HStack(spacing: 0) {
                        RollZahl(wert: Double(prozent), format: .number.precision(.fractionLength(0)))
                        Text(" %").monospacedDigit()
                    }
                    .font(.subheadline.weight(.bold)).fontDesign(.rounded).fixedSize()
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
            .foregroundStyle(palette.text)
            .frame(minHeight: Abstand.tippflaeche)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Haarlinie() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprech)
        .accessibilityHint("Öffnet die Details")
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
struct SilhouetteProbe: View {
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
