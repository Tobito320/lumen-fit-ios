// Quelle: Lovea Zyklus/ZyklusKalenderView.swift
import SwiftUI

/// Monatsraster mit Periode, Vorhersage, fruchtbarem Fenster, Eisprung und Logpunkten. Jede Art hat eine eigene Form, nicht nur eine Farbe.
struct ZyklusKalenderView: View {
    let store: ZyklusStore
    @State private var monat: String
    @State private var modus = ZyklusKalenderModus.eintragen
    @State private var blatt: ZyklusAuswahl?
    @State private var geaendert = 0
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.bewegungAus) private var bewegungAus

    init(store: ZyklusStore) {
        self.store = store
        _monat = State(initialValue: ZyklusKalenderLogik.monatsStart(store.heute))
    }

    var body: some View {
        let heute = store.heute
        let logik = store.logik(heute: heute)
        let tage = store.tage
        ScrollView {
            VStack(spacing: Abstand.l) {
                kopf
                ZyklusKarte {
                    VStack(spacing: Abstand.xs) {
                        wochentage
                        ForEach(Array(ZyklusKalenderLogik.raster(monat: monat).enumerated()), id: \.offset) { _, woche in
                            HStack(spacing: Abstand.xs) {
                                ForEach(0..<7, id: \.self) { i in
                                    if let id = woche[i] {
                                        zelle(id, status: ZyklusKalenderLogik.status(id, logik: logik, tage: tage, heute: heute), heute: heute)
                                    } else {
                                        Color.clear.frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                                    }
                                }
                            }
                        }
                    }
                }
                modusLeiste
                legende
            }
            .padding(Abstand.l)
        }
        .lumenHintergrund()
        .haptik(.auswahl, bei: geaendert)
        .sheet(item: $blatt) { a in ZyklusEintragBlatt(store: store, datum: a.id) }
    }

    private var kopf: some View {
        HStack {
            Button { wechsle(-1) } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.bold)).frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel("Vorheriger Monat")
            Spacer()
            Text(ZyklusKalenderLogik.monatTitel(monat))
                .font(.title2.bold())
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { wechsle(1) } label: {
                Image(systemName: "chevron.right").font(.title3.weight(.bold)).frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel("Nächster Monat")
        }
        .foregroundStyle(palette.text)
        .buttonStyle(.federnd)
    }

    private func wechsle(_ schritt: Int) {
        let neu = ZyklusKalenderLogik.monatVerschieben(monat, um: schritt)
        if bewegungAus { monat = neu } else { withAnimation(Feder.schnell) { monat = neu } }
        geaendert += 1
    }

    private var wochentage: some View {
        HStack(spacing: Abstand.xs) {
            ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { n in
                Text(n).font(.caption.weight(.bold)).foregroundStyle(palette.text2).frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func zelle(_ id: String, status s: ZyklusTagStatus, heute: String) -> some View {
        let nummer = Datum.kalender.component(.day, from: Datum.datum(id))
        let dunkel = schema == .dark
        let periodeTon = ZyklusPhaseStil.farbe(.periode, dunkel: dunkel)
        let fruchtTon = ZyklusPhaseStil.farbe(.fruchtbar, dunkel: dunkel)
        let eisTon = ZyklusPhaseStil.farbe(.eisprung, dunkel: dunkel)
        // Auf der Periodenfläche: schwarz im dunklen Modus (helles Rosa), sonst weiß.
        let aufPeriode: Color = dunkel ? .black : .white
        return Button { tippen(id) } label: {
            ZStack {
                if s.periode {
                    Circle().fill(periodeTon)
                } else if s.eisprung {
                    Circle().fill(eisTon.opacity(0.25)).overlay(Circle().strokeBorder(eisTon, lineWidth: 2.5))
                } else if s.fruchtbar {
                    Circle().fill(fruchtTon.opacity(dunkel ? 0.3 : 0.18))
                        .overlay(Circle().strokeBorder(fruchtTon, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 4])))
                }
                if s.vorhersage {
                    Circle().strokeBorder(periodeTon, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
                if id == heute {
                    Circle().strokeBorder(palette.text, lineWidth: 2.5).padding(-2)
                }
                Text("\(nummer)")
                    .font(.callout.weight(id == heute ? .heavy : .semibold))
                    .foregroundStyle(s.periode ? aufPeriode : palette.text)
                if s.log {
                    Circle()
                        .fill(s.periode ? aufPeriode : palette.text)
                        .frame(width: 5, height: 5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 3)
                }
            }
            .padding(2)
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ZyklusKalenderLogik.tagBeschreibung(id, status: s))
    }

    private func tippen(_ id: String) {
        switch modus {
        case .eintragen:
            blatt = ZyklusAuswahl(id: id)
        case .periodeStart:
            if let t = ZyklusKalenderLogik.startSetzen(id, tage: store.tage) { store.setze(t) }
            modus = .eintragen
        case .periodeEnde:
            for t in ZyklusKalenderLogik.endeSetzen(id, tage: store.tage, logik: store.logik()) { store.setze(t) }
            modus = .eintragen
        }
        geaendert += 1
    }

    private var modusLeiste: some View {
        VStack(spacing: Abstand.s) {
            ZyklusFluss {
                modusChip("Eintragen", .eintragen)
                modusChip("Periode Start", .periodeStart)
                modusChip("Periode Ende", .periodeEnde)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if modus != .eintragen {
                ZyklusLeise(modus == .periodeStart ? "Tippe den ersten Tag deiner Periode." : "Tippe den letzten Tag deiner Periode.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func modusChip(_ titel: String, _ wert: ZyklusKalenderModus) -> some View {
        Button { modus = wert } label: { ZyklusWahlChip(titel: titel, gewaehlt: modus == wert) }
            .buttonStyle(.federnd)
    }

    private var legende: some View {
        let dunkel = schema == .dark
        let periodeTon = ZyklusPhaseStil.farbe(.periode, dunkel: dunkel)
        let fruchtTon = ZyklusPhaseStil.farbe(.fruchtbar, dunkel: dunkel)
        return ZyklusKarte(titel: "Zeichen") {
            VStack(alignment: .leading, spacing: Abstand.s) {
                legendeZeile("Periode") { Circle().fill(periodeTon) }
                legendeZeile("Periode erwartet") { Circle().strokeBorder(periodeTon, style: StrokeStyle(lineWidth: 2, dash: [4, 3])) }
                legendeZeile("Fruchtbar") {
                    Circle().fill(fruchtTon.opacity(0.3))
                        .overlay(Circle().strokeBorder(fruchtTon, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 4])))
                }
                legendeZeile("Eisprung") { Circle().strokeBorder(ZyklusPhaseStil.farbe(.eisprung, dunkel: dunkel), lineWidth: 2.5) }
                legendeZeile("Eintrag vorhanden") { Circle().fill(palette.text).padding(6) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func legendeZeile<F: View>(_ titel: String, @ViewBuilder _ form: () -> F) -> some View {
        HStack(spacing: Abstand.m) {
            form().frame(width: 20, height: 20)
            Text(titel).font(.footnote).foregroundStyle(palette.text)
        }
    }
}
