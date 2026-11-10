import SwiftUI

/// Kalender als eigene Seite (Zeile im Training). Der Inhalt ist die `KalenderKarte`, die auch oben auf "Kalender und Verlauf" steht.
struct KalenderView: View {
    var body: some View {
        ScrollView {
            KalenderKarte()
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Monatsraster Mo bis So mit trainierten Tagen (gefüllt), geplanten Tagen nach vorn (Umriss mit Anfangsbuchstabe), ausgefallenen Plantagen
/// (gestrichelt) und, wenn ein Partner verbunden ist, einem kleinen zweiten Punkt je Tag. Tipp auf einen Tag zeigt in der Karte die Einheit,
/// den Plantag oder den Ruhetag; an einem vergangenen Tag ohne Einheit "Training nachtragen". Braucht einen `NavigationStack` darüber.
struct KalenderKarte: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    /// nil = der Monat von heute.
    @State private var monat: String?
    @State private var gewaehlt: String?
    @State private var nachtragen: FortNachtrag?
    @State private var tipp = 0

    private static let wochentage: [LocalizedStringKey] = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    private struct FortNachtrag: Identifiable {
        let datum: String
        var id: String { datum }
    }

    /// Partner-Zusammenfassung, wenn verbunden (auch veraltet); sonst nil. Ohne Freigabe fehlen Tage und Plan darin einfach.
    private var partnerDatei: ZusammenfassungDatei? {
        switch umgebung.daten?.verbindung.partner {
        case .verbunden(let d)?, .veraltet(let d)?: d
        default: nil
        }
    }

    private var partnerFarbe: Color { LumenFarben.tief(.bewegen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased) }

    var body: some View {
        let heute = Datum.text(umgebung.uhr())
        let angezeigt = monat ?? String(heute.prefix(7))
        let training = umgebung.daten?.training
        let partner = partnerDatei
        let tage = KalenderLogik.tage(monat: angezeigt, sessions: training?.sessions ?? [], plan: training?.plan ?? .leer,
                                      partnerTage: partner?.heute.gymTage ?? [], partnerPlan: partner?.heute.plan, heute: heute)
        let aktiv = tage.first { $0.imMonat && $0.datum == (gewaehlt ?? heute) }
        VStack(alignment: .leading, spacing: Abstand.m) {
            kopf(angezeigt)
            raster(tage, aktiv: aktiv?.datum)
            legende(mitPartner: partner != nil)
            detail(aktiv, training: training, heute: heute)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
        .haptik(.auswahl, bei: tipp)
        .sheet(item: $nachtragen) { EinheitNachtragenBlatt(datum: $0.datum, jetzt: umgebung.uhr()) }
    }

    private func kopf(_ angezeigt: String) -> some View {
        HStack {
            pfeil("chevron.left", "Vorheriger Monat") { wechsle(angezeigt, -1) }
            Spacer()
            Text(KalenderLogik.monatText(angezeigt)).font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Spacer()
            pfeil("chevron.right", "Nächster Monat") { wechsle(angezeigt, 1) }
        }
    }

    private func pfeil(_ symbol: String, _ text: LocalizedStringKey, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                .background(palette.haar, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
    }

    private func wechsle(_ angezeigt: String, _ schritt: Int) {
        monat = KalenderLogik.naechster(angezeigt, schritt: schritt)
        gewaehlt = nil
        tipp += 1
    }

    private func raster(_ tage: [KalenderTag], aktiv: String?) -> some View {
        let spalten = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: Abstand.xs) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { Text(Self.wochentage[$0]).font(.caption.weight(.semibold)).foregroundStyle(palette.text2).frame(maxWidth: .infinity) }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: spalten, spacing: Abstand.xs) {
                ForEach(tage) { t in
                    if t.imMonat { zelle(t, aktiv: aktiv) } else { Color.clear.frame(height: Abstand.tippflaeche).accessibilityHidden(true) }
                }
            }
        }
    }

    private func zelle(_ t: KalenderTag, aktiv: String?) -> some View {
        let gewaehltTag = t.datum == aktiv
        return Button { gewaehlt = t.datum; tipp += 1 } label: {
            VStack(spacing: 2) {
                zahl(t)
                marke(t)
                partnerPunkt(t)
            }
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche + 12)
            .background(gewaehltTag ? palette.haar : Color.clear, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KalenderLogik.sprechtext(t))
        .accessibilityAddTraits(gewaehltTag ? .isSelected : [])
    }

    private func zahl(_ t: KalenderTag) -> some View {
        Text("\(Int(t.datum.suffix(2)) ?? 0)")
            .font(.footnote.weight(.semibold)).monospacedDigit()
            .foregroundStyle(t.heute ? palette.grund : palette.text)
            .frame(width: 24, height: 24)
            .background(t.heute ? palette.text : Color.clear, in: .circle)
    }

    /// Gefüllt = trainiert, Umriss mit Anfangsbuchstabe = geplant, gestrichelt = ausgefallen; die Form trägt die Aussage, nicht die Farbe.
    @ViewBuilder
    private func marke(_ t: KalenderTag) -> some View {
        if t.trainiert {
            Circle().fill(palette.akzentFlaeche).frame(width: 22, height: 22)
        } else if let geplant = t.geplant {
            Text(String(geplant.prefix(1)).uppercased()).font(.caption2.weight(.bold)).foregroundStyle(palette.akzent)
                .frame(width: 22, height: 22).overlay(Circle().strokeBorder(palette.akzent, lineWidth: 1.5))
        } else if t.ausgefallen {
            Circle().strokeBorder(palette.text2, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])).frame(width: 22, height: 22)
        } else {
            Color.clear.frame(width: 22, height: 22)
        }
    }

    @ViewBuilder
    private func partnerPunkt(_ t: KalenderTag) -> some View {
        if t.partnerTrainiert {
            Circle().fill(partnerFarbe).frame(width: 6, height: 6)
        } else if t.partnerGeplant {
            Circle().strokeBorder(partnerFarbe, lineWidth: 1.5).frame(width: 6, height: 6)
        } else {
            Color.clear.frame(width: 6, height: 6)
        }
    }

    private func legende(mitPartner: Bool) -> some View {
        HStack(spacing: Abstand.m) {
            legendenPunkt("Trainiert") { Circle().fill(palette.akzentFlaeche) }
            legendenPunkt("Geplant") { Circle().strokeBorder(palette.akzent, lineWidth: 1.5) }
            legendenPunkt("Ausgefallen") { Circle().strokeBorder(palette.text2, style: StrokeStyle(lineWidth: 1, dash: [2, 2])) }
            if mitPartner { legendenPunkt("Partner") { Circle().fill(partnerFarbe) } }
        }
        .font(.caption).foregroundStyle(palette.text2)
        .lineLimit(1).minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mitPartner ? "Legende: gefüllt trainiert, Umriss geplant, gestrichelt ausgefallen, kleiner Punkt Partner"
                            : "Legende: gefüllt trainiert, Umriss geplant, gestrichelt ausgefallen")
    }

    private func legendenPunkt<Form: View>(_ text: LocalizedStringKey, @ViewBuilder form: () -> Form) -> some View {
        HStack(spacing: Abstand.xs) { form().frame(width: 10, height: 10); Text(text) }
    }

    @ViewBuilder
    private func detail(_ t: KalenderTag?, training: TrainingStore?, heute: String) -> some View {
        if let t {
            let einheiten = (training?.sessions ?? []).filter { Datum.text($0.start) == t.datum }
            VStack(alignment: .leading, spacing: Abstand.xs) {
                if !einheiten.isEmpty {
                    ForEach(einheiten) { s in
                        NavigationLink { EinheitNachlesenView(sessionId: s.id) } label: {
                            HStack(spacing: Abstand.s) {
                                Image(systemName: "calendar").foregroundStyle(palette.akzent).accessibilityHidden(true)
                                Text("\(Datum.anzeige(t.datum)) · \(training?.tag(id: s.tag)?.name ?? String(localized: "Training")), \(Datum.uhrzeit(s.start)) Uhr")
                                    .foregroundStyle(palette.text)
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.text2).accessibilityHidden(true)
                            }
                            .frame(minHeight: Abstand.tippflaeche).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: Abstand.s) {
                        Image(systemName: "calendar").foregroundStyle(palette.akzent).accessibilityHidden(true)
                        Text(Self.detailText(t, heute: heute)).foregroundStyle(palette.text)
                        Spacer(minLength: Abstand.s)
                        if t.datum <= heute {
                            Button("Nachtragen") { nachtragen = FortNachtrag(datum: t.datum) }
                                .font(.subheadline.weight(.semibold)).foregroundStyle(palette.akzent)
                                .frame(minHeight: Abstand.tippflaeche)
                                .accessibilityLabel("Training für diesen Tag nachtragen")
                        }
                    }
                    .frame(minHeight: Abstand.tippflaeche)
                }
                if t.partnerTrainiert || t.partnerGeplant {
                    HStack {
                        if t.partnerTrainiert { Pille(text: String(localized: "Partner trainiert"), symbolName: "checkmark") }
                        if t.partnerGeplant { Pille(text: String(localized: "Partner geplant"), symbolName: "calendar") }
                    }
                }
            }
            .font(.subheadline)
            .padding(.horizontal, Abstand.m)
            .background(palette.haar, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
        } else {
            Text("Tipp auf einen Tag zeigt die Einheit oder den Plan.").font(.footnote).foregroundStyle(palette.text2)
        }
    }

    /// "Do., 12. Nov. · Geplant: Push", "… · Ausgefallen", "… · Ruhetag".
    static func detailText(_ t: KalenderTag, heute: String) -> String {
        let tag = FortschrittLogik.kurzDatum(Datum.datum(t.datum))
        if let geplant = t.geplant { return String(localized: "\(tag) · Geplant: \(geplant)") }
        if t.ausgefallen { return String(localized: "\(tag) · Ausgefallen") }
        return t.datum < heute ? String(localized: "\(tag) · Kein Training") : String(localized: "\(tag) · Ruhetag")
    }
}
