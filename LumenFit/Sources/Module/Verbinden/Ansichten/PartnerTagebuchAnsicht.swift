import SwiftUI

/// Das Tagebuch des Partners (Gleichstand Lovea "Partner-Tag ansehen"): ein Tag der letzten sieben mit Kalorien, Makros und den Einträgen nach Mahlzeit.
/// Blättern mit den zwei Pfeilen, die Seite schiebt sich dabei weg (unter "Bewegung reduzieren" blendet sie über). Keine Fotos, nur Namen und Kalorien.
struct PartnerTagebuchAnsicht: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        PartnerAnsichtRahmen(art: .tagebuch, titel: String(localized: "Tagebuch")) { datei in
            PartnerTagebuchInhalt(datei: datei, heute: Datum.text(umgebung.uhr()))
        }
    }
}

private struct PartnerTagebuchInhalt: View {
    let datei: ZusammenfassungDatei
    let heute: String
    @State private var tag: String
    @State private var vorwaerts = true
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig

    init(datei: ZusammenfassungDatei, heute: String) {
        self.datei = datei
        self.heute = heute
        _tag = State(initialValue: heute)
    }

    private var eintrag: PartnerTagebuchTag? { PartnerAnsichtLogik.tagebuchTage(datei).first { $0.tag == tag } }

    var body: some View {
        leiste
        VStack(alignment: .leading, spacing: Abstand.l) {
            if let eintrag {
                kopf(eintrag).partnerErscheint(0)
                makros(eintrag).partnerErscheint(1)
                ForEach(Array(PartnerAnsichtLogik.gruppen(eintrag).enumerated()), id: \.element.id) { i, gruppe in
                    gruppenKarte(gruppe).partnerErscheint(i + 2)
                }
            } else {
                Text("An diesem Tag hat \(datei.profilName) nichts eingetragen.")
                    .font(.body).foregroundStyle(palette.text2).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(Abstand.xl)
                    .lumenKartenFlaeche()
            }
        }
        .id(tag)
        .transition(ruhig ? AnyTransition.opacity : AnyTransition.push(from: vorwaerts ? .trailing : .leading))
    }

    // MARK: Tagwahl

    private var leiste: some View {
        HStack {
            pfeil("chevron.left", String(localized: "Ein Tag zurück"), richtung: -1)
            Spacer()
            VStack(spacing: 2) {
                Text(PartnerAnsichtLogik.tagTitel(tag, heute: heute)).font(.headline).foregroundStyle(palette.text)
                if tag == heute || tag == Datum.addTage(heute, -1) {
                    Text(Datum.anzeige(tag)).font(.caption).foregroundStyle(palette.text2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            pfeil("chevron.right", String(localized: "Ein Tag weiter"), richtung: 1)
        }
        .padding(.horizontal, Abstand.s)
        .lumenKartenFlaeche()
        .haptik(.auswahl, bei: tag)
    }

    private func pfeil(_ symbol: String, _ beschriftung: String, richtung: Int) -> some View {
        let neu = PartnerAnsichtLogik.blaettern(von: tag, richtung: richtung, heute: heute)
        return Button {
            vorwaerts = richtung > 0
            withAnimation(ruhig ? nil : Feder.weich) { tag = neu }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(neu == tag ? palette.text2.opacity(0.4) : palette.text)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .buttonStyle(.federnd)
        .disabled(neu == tag)
        .accessibilityLabel(beschriftung)
    }

    // MARK: Inhalt

    private func kopf(_ t: PartnerTagebuchTag) -> some View {
        let ziel = datei.heute.tagebuchZiele?.kcal
        return HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Kalorien von \(datei.profilName)").font(.footnote.weight(.semibold))
                HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                    RollZahl(wert: Double(t.kcal), format: .number.precision(.fractionLength(0))).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    Text(ziel.map { String(localized: "von \(PartnerAnsichtLogik.zahl($0)) kcal") } ?? "kcal").font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func makros(_ t: PartnerTagebuchTag) -> some View {
        let ziele = datei.heute.tagebuchZiele
        return VStack(alignment: .leading, spacing: Abstand.m) {
            makroZeile(String(localized: "Protein"), t.protein, ziel: ziele?.protein)
            makroZeile(String(localized: "Kohlenhydrate"), t.kohlenhydrate, ziel: ziele?.kohlenhydrate)
            makroZeile(String(localized: "Fett"), t.fett, ziel: ziele?.fett)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
    }

    private func makroZeile(_ titel: String, _ wert: Int, ziel: Int?) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            HStack {
                Text(titel).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.m)
                Text(ziel.map { String(localized: "\(wert) von \($0) g") } ?? "\(wert) g").font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
            }
            if let ziel { PartnerBalken(anteil: PartnerAnsichtLogik.anteil(wert, ziel: ziel)) }
        }
        .accessibilityElement(children: .combine)
    }

    private func gruppenKarte(_ g: PartnerAnsichtLogik.Gruppe) -> some View {
        ListenKarte {
            HStack(spacing: Abstand.m) {
                Image(systemName: g.mahlzeit.symbol).frame(width: 28).foregroundStyle(palette.text2).accessibilityHidden(true)
                Text(g.mahlzeit.name).font(.headline).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.m)
                Text("\(PartnerAnsichtLogik.zahl(g.kcal)) kcal").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
            }
            .padding(Abstand.l)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(Array(g.eintraege.enumerated()), id: \.offset) { _, e in
                Haarlinie()
                HStack(spacing: Abstand.m) {
                    Text(e.name).foregroundStyle(palette.text).lineLimit(2)
                    Spacer(minLength: Abstand.m)
                    Text("\(e.kcal) kcal").font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                }
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
