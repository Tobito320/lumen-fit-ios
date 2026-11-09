import SwiftUI

/// Kalender im Training: Monatsraster Mo bis So mit trainierten Tagen (gefüllt), geplanten Tagen nach vorn (Umriss mit Anfangsbuchstabe)
/// und, wenn ein Partner verbunden ist, einem kleinen zweiten Punkt je Tag. Tipp auf einen Tag zeigt darunter die Einheit, den Plantag oder den Ruhetag.
/// Eine Unterseite des Training-Tabs: braucht einen `NavigationStack` darüber und keine Eingaben.
struct KalenderView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    /// nil = der Monat von heute.
    @State private var monat: String?
    @State private var gewaehlt: String?
    @State private var tipp = 0

    private static let wochentage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

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
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                ListenKarte {
                    VStack(alignment: .leading, spacing: Abstand.m) {
                        kopf(angezeigt)
                        raster(tage, aktiv: aktiv?.datum)
                        legende(mitPartner: partner != nil)
                    }
                    .padding(Abstand.l)
                }
                detail(aktiv, training: training, heute: heute)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .haptik(.auswahl, bei: tipp)
    }

    private func kopf(_ angezeigt: String) -> some View {
        HStack {
            Button { wechsle(angezeigt, -1) } label: { Image(systemName: "chevron.left").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche).contentShape(.rect) }
                .accessibilityLabel("Vorheriger Monat")
            Spacer()
            Text(KalenderLogik.monatText(angezeigt)).font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { wechsle(angezeigt, 1) } label: { Image(systemName: "chevron.right").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche).contentShape(.rect) }
                .accessibilityLabel("Nächster Monat")
        }
        .foregroundStyle(palette.akzent)
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
                ForEach(Self.wochentage, id: \.self) { Text($0).font(.caption.weight(.semibold)).foregroundStyle(palette.text2).frame(maxWidth: .infinity) }
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
            .frame(width: 26, height: 26)
            .background(t.heute ? palette.text : Color.clear, in: .circle)
    }

    /// Gefüllt mit Haken = trainiert, Umriss mit Anfangsbuchstabe = geplant; die Form trägt die Aussage, nicht die Farbe.
    @ViewBuilder
    private func marke(_ t: KalenderTag) -> some View {
        if t.trainiert {
            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(palette.aufAkzent)
                .frame(width: 26, height: 26).background(palette.akzent, in: .circle)
        } else if let geplant = t.geplant {
            Text(String(geplant.prefix(1)).uppercased()).font(.caption2.weight(.bold)).foregroundStyle(palette.akzent)
                .frame(width: 26, height: 26).overlay(Circle().strokeBorder(palette.akzent, lineWidth: 1.5))
        } else {
            Color.clear.frame(width: 26, height: 26)
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
            legendenPunkt("Trainiert") { Circle().fill(palette.akzent) }
            legendenPunkt("Geplant") { Circle().strokeBorder(palette.akzent, lineWidth: 1.5) }
            if mitPartner { legendenPunkt("Partner") { Circle().fill(partnerFarbe) } }
        }
        .font(.caption).foregroundStyle(palette.text2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mitPartner ? "Legende: gefüllt trainiert, Umriss geplant, kleiner Punkt Partner" : "Legende: gefüllt trainiert, Umriss geplant")
    }

    private func legendenPunkt<Form: View>(_ text: String, @ViewBuilder form: () -> Form) -> some View {
        HStack(spacing: Abstand.xs) { form().frame(width: 10, height: 10); Text(text) }
    }

    @ViewBuilder
    private func detail(_ t: KalenderTag?, training: TrainingStore?, heute: String) -> some View {
        if let t {
            let einheiten = (training?.sessions ?? []).filter { Datum.text($0.start) == t.datum }
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text(Datum.anzeige(t.datum)).font(.headline).foregroundStyle(palette.text)
                    if !einheiten.isEmpty {
                        ForEach(einheiten) { s in
                            NavigationLink { EinheitNachlesenView(sessionId: s.id) } label: {
                                HStack {
                                    Text("\(training?.tag(id: s.tag)?.name ?? "Training"), \(Datum.uhrzeit(s.start)) Uhr").foregroundStyle(palette.text)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.text2).accessibilityHidden(true)
                                }
                                .frame(minHeight: Abstand.tippflaeche).contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if let geplant = t.geplant {
                        Text("Geplant: \(geplant)").foregroundStyle(palette.text)
                    } else {
                        Text(t.datum < heute ? "Kein Training" : "Ruhetag").foregroundStyle(palette.text2)
                    }
                    if t.partnerTrainiert || t.partnerGeplant {
                        HStack {
                            if t.partnerTrainiert { Pille(text: "Partner trainiert", symbolName: "checkmark") }
                            if t.partnerGeplant { Pille(text: "Partner geplant", symbolName: "calendar") }
                        }
                    }
                }
                .padding(Abstand.l)
            }
        } else {
            Text("Tipp auf einen Tag zeigt die Einheit oder den Plan.").font(.footnote).foregroundStyle(palette.text2)
        }
    }
}
