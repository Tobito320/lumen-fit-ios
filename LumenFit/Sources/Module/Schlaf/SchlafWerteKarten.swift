import SwiftUI

/// Öffnet die Health-App, wenn Werte fehlen. HealthKit verrät nie, ob jemand etwas abgelehnt hat; darum steht nirgends "abgelehnt",
/// nur "Keine Daten" und die Handlung "In Health prüfen".
enum SchlafHealthLink {
    @MainActor static func oeffnen(_ aktion: OpenURLAction) {
        if let url = URL(string: "x-apple-health://") { aktion(url) }
    }
}

/// Idee 55, Werte-Chips: Ruhepuls, SpO2, Atmung, Temperatur und VO2max mit Trendpfeil gegen deinen Schnitt (Symbol, Zahl und Text).
struct SchlafWerteChips: View {
    let staende: [SchlafVitalStand]
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @Environment(\.openURL) private var openURL

    private let spalten = [GridItem(.adaptive(minimum: 150), spacing: Abstand.s, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: spalten, alignment: .leading, spacing: Abstand.s) {
            ForEach(staende) { stand in chip(stand) }
        }
    }

    private func chip(_ stand: SchlafVitalStand) -> some View {
        let tief = LumenFarben.tief(.erholen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        return VStack(alignment: .leading, spacing: Abstand.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Label(SchlafVitalInfo.name(stand.art), systemImage: SchlafVitalInfo.symbolName(stand.art))
                    .font(.footnote.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tief)
                Text(stand.aktuell.map { SchlafVitalInfo.text(stand.art, $0.wert) } ?? "Keine Daten")
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
                if stand.aktuell != nil {
                    HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                        if let bereich = stand.bereich {
                            Image(systemName: bereich.trend.symbolName).accessibilityHidden(true)
                        }
                        Text(stand.untertitel)
                    }
                    .font(.footnote)
                    .foregroundStyle(palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stand.sprechSatz)
            if stand.aktuell == nil {
                Button("In Health prüfen") { SchlafHealthLink.oeffnen(openURL) }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: Abstand.tippflaeche, alignment: .leading)
            }
        }
        .padding(Abstand.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
    }
}

/// Idee 54, HRV im eigenen Bereich, mit Idee 58, Erholung in einfacher Sprache: der Bereich der letzten 60 Tage, ein Punkt nach Lage, der Satz dazu.
struct SchlafBereichKarte: View {
    let hrv: SchlafVitalStand
    let erholung: ErholungsKlartext.Ergebnis
    let coachFragen: @MainActor (String) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @Environment(\.openURL) private var openURL

    private var aussage: String {
        guard let aktuell = hrv.aktuell else { return "HRV: Keine Daten" }
        let wert = SchlafVitalInfo.text(.hrv, aktuell.wert)
        guard let bereich = hrv.bereich else { return "HRV \(wert)" }
        return "HRV \(wert), \(bereich.lage.name)"
    }

    private var kernzeile: String {
        guard hrv.aktuell != nil else { return "Die HRV liefert eine Apple Watch." }
        guard let bereich = hrv.bereich else {
            return "Zu wenig Daten für deinen 60-Tage-Bereich (\(hrv.vorhanden) von \(PersoenlicherBereich.mindestWerte) Tagen)."
        }
        return "Dein Bereich der letzten \(PersoenlicherBereich.tage) Tage: \(bereich.bereichText)"
    }

    var body: some View {
        DiagrammKarte(aussage: aussage, kernzeile: kernzeile) {
            VStack(alignment: .leading, spacing: Abstand.m) {
                if let bereich = hrv.bereich {
                    bereichsBalken(bereich)
                } else if hrv.aktuell == nil {
                    Button("In Health prüfen") { SchlafHealthLink.oeffnen(openURL) }
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: Abstand.tippflaeche, alignment: .leading)
                }
                Pille(text: erholung.stufe.name, symbolName: erholung.stufe.symbolName)
                Text(erholung.satz)
                    .font(.body)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Coach erklärt es") { coachFragen(erholung.coachFrage) }
                    .buttonStyle(.bordered)
                    .frame(minHeight: Abstand.tippflaeche)
            }
            .padding(.top, Abstand.xs)
        }
    }

    /// Spur, dein Bereich (Mittel plus minus eine Streuung) als helle Fläche mit Rand, der Punkt nach Lage. Position und Text tragen die Aussage, nicht die Farbe.
    private func bereichsBalken(_ bereich: PersoenlicherBereich) -> some View {
        let tief = LumenFarben.tief(.erholen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        return GeometryReader { geo in
            let breite = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(palette.haar).frame(height: 10)
                Capsule().fill(tief.opacity(0.3))
                    .overlay(Capsule().stroke(tief, lineWidth: 1))
                    .frame(width: breite * 0.5, height: 14)
                    .offset(x: breite * 0.25)
                Circle().fill(tief)
                    .overlay(Circle().stroke(palette.grund, lineWidth: 2))
                    .frame(width: 20, height: 20)
                    .offset(x: breite * bereich.position - 10)
            }
            .frame(height: 20)
        }
        .frame(height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HRV \(SchlafVitalInfo.sprechText(.hrv, bereich.aktuell)), \(bereich.lage.name). Dein Bereich: \(bereich.bereichText)")
    }
}

/// Idee 53, Schlafschuld über 7 Nächte gegen dein Ziel, mit dem Vorschlag "heute 45 Minuten früher".
struct SchlafSchuldKarte: View {
    let schuld: SchlafSchuld.Ergebnis?
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte {
            HStack(alignment: .top, spacing: Abstand.m) {
                Image(systemName: "moon.zzz.fill").font(.title3).foregroundStyle(palette.text2).frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text("Schlafschuld, 7 Nächte").font(.headline).foregroundStyle(palette.text)
                    if let schuld {
                        Text(schuld.satz).font(.subheadline).foregroundStyle(palette.text)
                        if let vorschlag = schuld.vorschlagSatz {
                            Label(vorschlag, systemImage: "bed.double.fill").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                        }
                    } else {
                        Text("Zu wenig Daten: ab \(SchlafSchuld.mindestNaechte) Nächten rechne ich deine Schuld gegen dein Ziel.")
                            .font(.subheadline).foregroundStyle(palette.text2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Idee 57, Regelmäßigkeit: wie stark die Einschlafzeit streut, als ruhiger Wert statt Vorwurf.
struct SchlafRegelKarte: View {
    let ergebnis: Regelmaessigkeit.Ergebnis?
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        let tief = LumenFarben.tief(.erholen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Regelmäßigkeit").font(.headline).foregroundStyle(palette.text)
                if let ergebnis {
                    HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                        Text("\(ergebnis.score)").font(.title.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text)
                        Text("von 100").font(.subheadline).foregroundStyle(palette.text2)
                        Spacer(minLength: Abstand.s)
                        Label(ergebnis.stufe.name, systemImage: ergebnis.stufe.symbolName).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.haar)
                            Capsule().fill(tief).frame(width: geo.size.width * CGFloat(ergebnis.score) / 100)
                        }
                    }
                    .frame(height: 8)
                    .accessibilityHidden(true)
                    Text(ergebnis.satz).font(.subheadline).foregroundStyle(palette.text2)
                } else {
                    Text("Zu wenig Daten: ab \(Regelmaessigkeit.mindestNaechte) Nächten in \(Regelmaessigkeit.fenster) Tagen zeige ich, wie gleichmäßig du einschläfst.")
                        .font(.subheadline).foregroundStyle(palette.text2)
                }
            }
            .padding(Abstand.l)
            .accessibilityElement(children: .combine)
        }
    }
}
